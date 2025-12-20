# HOMEROUTER PLAYBOOK
A simple playbook to deploy SSK public key to an host

## Usage
Install Ansible on ubuntu:
```
sudo apt install python3-pip sshpass qemu-utils
pip install -U ansible ansible-lint jmespath passlib
```
Then restart to ensure $HOME/.local/bin is well sourced

Install the dependencies:
```
ansible-galaxy install -r requirements.yml
```

To run the playbook you need to have your own ssh keypair, or generate a new one
To generate it:
```
ssh-keygen -b 4096 -t rsa
```


Then you can create a ssh-agent and register your ssh private key:

https://docs.github.com/en/authentication/connecting-to-github-with-ssh/working-with-ssh-key-passphrases

Add this script to your ~/.bashrc file:
```
env=~/.ssh/agent.env

agent_load_env () { test -f "$env" && . "$env" >| /dev/null ; }

agent_start () {
    (umask 077; ssh-agent >| "$env")
    . "$env" >| /dev/null ; }

agent_load_env

# agent_run_state: 0=agent running w/ key; 1=agent w/o key; 2=agent not running
agent_run_state=$(ssh-add -l >| /dev/null 2>&1; echo $?)

if [ ! "$SSH_AUTH_SOCK" ] || [ $agent_run_state = 2 ]; then
    agent_start
    ssh-add
elif [ "$SSH_AUTH_SOCK" ] && [ $agent_run_state = 1 ]; then
    ssh-add
fi

unset env
```

Then run the playbook:

```
ansible-playbook playbook.yml
```

Activate the project's Python virtual environment before running Ansible (if you created one):

```bash
# from the repository root
source .venv/bin/activate
# then run the playbook
ansible-playbook playbook.yml
```

## Libvirt / virt-manager (Arch/CachyOS): DHCP on the WAN NAT network

If your OpenWrt VM gets link on the WAN interface but never receives a DHCP lease from the libvirt NAT network (e.g. `openwrt_eth3` / `virbr3`), the following items matter.

### 1) Ensure MAC addresses are unique

If two VM NICs share the same MAC address, bridging/DHCP can behave unpredictably.

- In virt-manager, ensure every NIC has a different MAC.
- Quick check:

```sh
sudo virsh domiflist openwrt
```

### 2) Use libvirt firewall backend `iptables` (still compatible with nftables)

On Arch/CachyOS, libvirt can use either the `nft` or the `iptables` API to program firewall rules. Even on nftables-based systems, `iptables` is often provided as **iptables-nft** (iptables commands generating nft rules).

If DHCP is blocked with the nftables backend, forcing libvirt to use the iptables backend can fix it.

1. Edit `/etc/libvirt/network.conf` and set:

```conf
firewall_backend = "iptables"
```

2. Restart libvirt and reload the network:

```sh
sudo systemctl restart libvirtd.service
sudo virsh net-destroy openwrt_eth3 || true
sudo virsh net-start openwrt_eth3
```

3. Verify that libvirt chains exist:

```sh
sudo iptables -S | grep -E 'LIBVIRT' | head
```

4. (fish) Verify whether `iptables` is actually iptables-nft:

```sh
readlink -f (command -v iptables)
```

### Notes

- Disabling IPv6 on the libvirt network is fine; it does not prevent DHCPv4.


# INIT-SSH PLAYBOOK
A simple playbook to deploy SSK public key to an host

## Usage
Install Ansible on ubuntu:
```
sudo apt install python3-pip sshpass qemu-utils
pip install -U ansible ansible-lint
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


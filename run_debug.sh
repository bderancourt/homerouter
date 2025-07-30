#!/bin/bash
ANSIBLE_KEEP_REMOTE_FILES=1 ansible-playbook install.yml -vvvv -k
#ansible-playbook playbook.yml -vv --step
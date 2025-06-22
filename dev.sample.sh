#!/usr/bin/env bash

# Copy to dev.env, change values and source before running play

export ANSIBLE_HOST_ALMA=192.168.1.11
export ANSIBLE_HOST_ALPINE=192.168.1.12
export ANSIBLE_HOST_DEBIAN=192.168.1.13
export ANSIBLE_HOST_UBUNTU=192.168.1.14

export ANSIBLE_USER=demo-ssh-user
export ANSIBLE_USER_PASS=demo-ssh-user-pass

ssh_ansible_alma()    { ssh "${ANSIBLE_USER}@${ANSIBLE_HOST_ALMA}"; }
ssh_ansible_alpine()  { ssh "${ANSIBLE_USER}@${ANSIBLE_HOST_ALPINE}"; }
ssh_ansible_debian()  { ssh "${ANSIBLE_USER}@${ANSIBLE_HOST_DEBIAN}"; }
ssh_ansible_ubuntu()  { ssh "${ANSIBLE_USER}@${ANSIBLE_HOST_UBUNTU}"; }

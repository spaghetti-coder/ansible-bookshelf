# TODO

## Requirements

Ansible control node:

* OS: any that supports ansible installation
* ansible
* openssh-client
* bash (optional, in case you want to take advantage of helper bash scripts)
* sshpass (optional, for password-based ssh connections)

Ansible managed nodes:

* OS: latest versions of Alpine, Debian or alike (for Ubuntu latest LTS version), CentOS or alike
* openssh-server (running)
* ansible user (must be sudoer)
* python

<details><summary>Tips</summary>

  **Alpine** managed node:
  ```sh
  # Install prereqs
  apk add --update --no-cache openssh-server python3 sudo shadow

  # Ensure ssh server running
  rc-update add sshd
  rc-service sshd start

  # Create ansible user, replace USERNAME
  useradd -m USERNAME
  passwd USERNAME

  # Make ansible user sudoer
  echo '%wheel ALL=(ALL) ALL' > /etc/sudoers.d/wheel
  usermod -aG wheel USERNAME
  ```
</details>

## Usage

1.  Initialize installation. This step doesn't break anything, so it can be repeated at any point of time, but must be performed on initial install and after playbook update

    ~~~sh
    ./bin/init.sh
    ~~~

2.  Copy configurations from sample directory and edit them:

    ~~~sh
    cp -rfp ./sample/* ./
    ~~~

## Development

See `docker` and `demo-noapp` roles for demos on how to write roles and run `.dev/build.sh` when completed to add configurations to sample vars file.

## Usage

TODO

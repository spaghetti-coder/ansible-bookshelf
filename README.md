<a id="top"></a>

# Ansible Bookshelf

This a basic playbook and roles collection.

* [Requirements](#requirements)
* [Project structure](#project-structure)
* [Usage](#usage)
* [Tailscale integration](#tailscale-integration)
* [Limitations and specifics](#limitations-and-specifics)
* [Issues](#issues)
* [Development](#development)
* [Skeleton](#skeleton)
* [Standalones](#standalones)

[To top]

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

  **Debian**-like managed node:
  ```sh
  # Performed by root user

  # Install prereqs
  apt-get update
  apt-get install -y openssh-server python3 sudo

  # Ensure ssh server running
  systemctl enable --now sshd

  # Create ansible user, replace USERNAME
  useradd -m USERNAME
  passwd USERNAME

  # Make ansible user sudoer
  usermod -aG sudo USERNAME
  ```

  **Alpine** managed node:
  ```sh
  # Performed by root user

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

[To top]

## Project structure

```sh
├── .dev                # <- Development convenience scripts
├── ansible.cfg
├── bin                 # <- Playbook convenience scripts
├── playbook.yaml
├── requirements.yaml   # <- Required roles and collections declaretions
├── roles       # <- Categorized roles
├── sample      # <- Configuration samples
├── vaulted.txt # <- (optional) Create this empty file to trigger vault pass prompt
└── vendor      # <- Vendor directory
```

[To top]

## Usage

1.  Copy configurations from sample directory and edit them:

    ~~~sh
    cp -rp ./sample/* ./
    ~~~

2.  Use `ansible-playbook` wrapper scripts from `bin` directory to deploy  
    In order to provoke vault password prompt by `bin` scripts create `vaulted.txt` file in the project root directory
    ```sh
    touch ./vaulted.txt
    ```

[To top]

## Tailscale integration

Some services have capability to be proxied via tailscale. Mostly these are traffic intensive ones, and they gain in afficiency when routed via tailnet (vs subnet routing).

Tailscale is just my personal preference. I don't get payed from them (wouldn't mind though :smirk:)

[To top]

## Limitations and specifics

* `base/snapd` role is not supported by Alpine
* `base/tmuxp` role is not supported by Alpine
* `desktop/*` roles are mostly oriented to Debian-based (sometimes narrowed to Ubuntu-based) distros
* `service/*` roles are primarely deployed with docker

## Issues

* Due to keyserver.ubuntu.com sometimes switches comment in PGP keys, all tasks that download them from there are `changed_when: false`.  
  Issues:
  * https://answers.launchpad.net/launchpad/+question/818969
  * https://github.com/ClickHouse/ClickHouse/issues/57415


## Development

1.  If your playbook development is under git source control run `.dev/dev-init.sh` script to ensure hooks.
2.  See `base/docker` and `base/demo-noapp` roles for demos on how to write roles.
3.  Run `.dev/sample-vars.sh` when completed to add configurations to sample vars file.

The goal of all these `*_done` variables is to reduce noise in the ansible-playbook log when roles are played more than once.

### `factum` role

A lot of roles depend on data collected by `factum`, so it's better to be the first role in the playbook. It provides the following:

```yaml
getent_passwd:
  root:
    - ...   # <- Useless
    - UID   # [1]
    - GID   # [2]
    - ...   # <- Useless
    - HOME  # [4]
    - SHELL # [5]
  # ...  # <- Other users

factum_os_family:         # <- Lowercase ansible_os_family
factum_os_like:           # <- More prioritized OS like
factum_ubuntu_codename:   # <- Ubuntu code name for Ubuntu-like distros
```

### `init` role

Performs all necessary initialization tasks (`factum` included), so it basically must be the first role in the playbook.

```yaml
- name: 'MyBook'
  hosts: all
  roles:
    - { role: init, tags: [always] }  # <- Required initial tasks
    # ... more roles
```

[To top]

## Skeleton

In order to create a project cloned from this one, issue

```sh
curl -fsSL https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/.dev/remote-proj.sh | bash -s -- install \
  path/to/new/project \
  master `# <- Optional tree-ish`
```

To sync libraries and tools in the new project with the upstream issue:

```sh
# Alway `git commit` before this action
.dev/remote-proj.sh pull-upstream
```

## Standalones

* [`envar`](./roles/base/envar)
* [`ps1-git`](./roles/base/ps1-git)

[To top]

[To top]: #top

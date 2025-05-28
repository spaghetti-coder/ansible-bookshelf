TODO

[Main](./../../..)

## Vanilla installation

```sh
mkdir -p ~/.bashrc.d \
&& ( set -o pipefail
  curl -fsSL https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/ps1-git/files/ps1-git.sh \
  | tee ~/.bashrc.d/ps1-git.sh >/dev/null
) \
&& ( set -o pipefail
  grep -qFx '. "${HOME}/.bashrc.d/ps1-git.sh"' ~/.bashrc \
  || { echo '. "${HOME}/.bashrc.d/ps1-git.sh"' | tee -a ~/.bashrc >/dev/null; }
) && . ~/.bashrc
```

## Installation with [`envar`](./../envar) tool installed

```sh
( set -o pipefail
  curl -fsSL https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/ps1-git/files/ps1-git.sh \
  | tee ~/.envar.d/500-ps1-git.sh
) && . ~/.bashrc
```

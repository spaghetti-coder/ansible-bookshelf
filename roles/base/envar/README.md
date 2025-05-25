TODO

```sh
# View help
curl -fsSL https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/envar/files/envar.sh | bash -s -- --help
```

```sh
# Install in the system and setup for the current user.
# 'sudo' in the install command can be omitted if the current user is root.
curl -fsSL https://github.com/spaghetti-coder/ansible-bookshelf/raw/master/roles/base/envar/files/envar.sh | sudo bash -s -- install
/opt/varlog/envar/envar.sh setup
```

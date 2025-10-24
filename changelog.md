**`service/auidobookshelf`**:
  * `config` and `metadata` directories under `{{ audiobookshelf_conf_dir }}` now owned by `{{ audiobookshelf_user }}`

**`service/filebrowser`**:
  * `config` and `database` directories moved from `{{ filebrowser_conf_dir }}/filebrowser` to `{{ filebrowser_conf_dir }}` and now owned by `{{ filebrowser_user }}`

**`service/jellyfin`**:
  * `{{ jellyfin_conf_dir }}/jellyfin` directory moved to `{{ jellyfin_conf_dir }}/config` and now owned by `{{ jellyfin_user }}`

**`service/metube`**:
  * `{{ metube_conf_dir }}` directory contents moved to `{{ metube_conf_dir }}/config` and it's owned by `{{ metube_user }}`

**`service/qbittorrent`**:
  * `{{ qbittorrent_conf_dir }}` directory contents moved to `{{ qbittorrent_conf_dir }}/config` and it's owned by `{{ qbittorrent_user }}`
  * `{{ qbittorrent_compose_dir }}/scripts` directory contents moved to `{{ qbittorrent_conf_dir }}/scripts` and it's owned by `{{ qbittorrent_user }}`

**`service/syncthing`**:
  * `{{ syncthing_conf_dir }}/syncthing` directory moved to `{{ syncthing_conf_dir }}/config` and now owned by `{{ syncthing_user }}`

**`service/adguard`**:
  * `conf` and `work` directories content is moved to config root directory

**`service/auidobookshelf`**:
  * `metadata` directory content is moved to `config` directory

**`service/filebrowser`**:
  * `database` directory content is moved to `config` directory

**`service/heimdall`**:
  * main configuration directory content is moved to `config` directory
  * `heimdall_ext_port` is renamed to `heimdall_web_ui_port_ext`

**`service/portainer`**:
  * main configuration directory content is moved to `config` directory

**`service/silverbullet`**:
  * `space` directory content is moved to `config` directory

**`service/tailscale`**:
  * main configuration directory content is moved to `config` directory

**`service/vaultwarden`**:
  * main configuration directory content is moved to `config` directory

**`service/wg-easy`**:
  * main configuration directory content is moved to `config` directory

**`service/wg-easy`**:
  * `navidrome_extra_dir` is changed to `navidrome_extra_mounts`

**`service/uptime-kuma`**:
  * default bookshelf version is changed from 1.* to 2.*. Apart from that no changes in the role. See the github page on how to migrate

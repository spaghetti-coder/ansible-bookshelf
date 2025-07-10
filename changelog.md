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

#!/bin/sh

#
# USAGE:
#   THE_SCRIPT USER_NAME USER_PASS [USER_DBNAME]
# With USER_DBNAME will only have privileges for it
#

USER="${1}"
PASS="${2}"
DBNAME="${3-*}"

SCRIPT_DIR="$(realpath "$(dirname -- "${0}")")"

sql_escape_value() {
  # https://stackoverflow.com/a/64440379 # <- Not applicable
  #
  # USAGE:
  #   sql_do "SELECT * FROM mysql.user WHERE user = '$(sql_escape_value 'root')'"

  printf -- '%s' "${1}" | sed -e 's/['\''"\\]/\\&/g'
}

sql_escape_field() {
  printf -- '%s' "${1}" | sed -e 's/`/\\&/g'
}

sql_do() (
  # USAGE:
  #   sql_do "SELECT * FROM mysql.user; show databases;"  # <- Executed from root

  cd -- "${SCRIPT_DIR}" || return
  # shellcheck disable=SC1091
  . ./secret.env || return
  docker compose exec mariadb11 mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}" -se "${1-cat}"
)

Q_USER="$(sql_escape_value "${USER}")"
Q_PASS="$(sql_escape_value "${PASS}")"
Q_DBNAME="$(sql_escape_field "${DBNAME}")"

main() {
  if [ "${Q_DBNAME}" != '*' ]; then
    Q_DBNAME="\`${Q_DBNAME}\`"
    sql_do "CREATE DATABASE IF NOT EXISTS ${Q_DBNAME};" || return
  fi

  sql_do "
    -- Ensure the user
    CREATE USER IF NOT EXISTS '${Q_USER}'@'localhost' IDENTIFIED BY '${Q_PASS}';
    CREATE USER IF NOT EXISTS '${Q_USER}'@'%' IDENTIFIED BY '${Q_PASS}';
    -- Ensure the correct password
    ALTER USER '${Q_USER}'@'localhost' IDENTIFIED BY '${Q_PASS}';
    ALTER USER '${Q_USER}'@'%' IDENTIFIED BY '${Q_PASS}';
    -- Grant privileges
    GRANT ALL PRIVILEGES ON ${Q_DBNAME}.* TO '${Q_USER}'@'localhost' WITH GRANT OPTION;
    GRANT ALL PRIVILEGES ON ${Q_DBNAME}.* TO '${Q_USER}'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  " || return
}

main

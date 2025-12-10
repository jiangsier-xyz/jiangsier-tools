#!/usr/bin/env bash

set -e

user=""
host=""

while getopts "u:h:" opt; do
  case "$opt" in
    u) user="$OPTARG" ;;
    h) host="$OPTARG" ;;
    *) exit 1 ;;
  esac
done

[ -n "$user" ] && [ -n "$host" ] || {
  echo "need -u <user> and -h <hoster>" >&2
  exit 1
}

if ! command -v sshfs >/dev/null 2>&1; then
  brew list --formula | grep -q '^macfuse$' || brew install macfuse
  brew list --formula | grep -q '^sshfs$'   || brew install gromgit/fuse/sshfs
fi

if [ -d "$HOME/mnt/$host" ]; then
  umount -f "$HOME/mnt/$host"
else
  mkdir -p "$HOME/mnt/$host"
fi

sshfs \
  "${user}@${host}:/home/${user}" \
  "$HOME/mnt/$host"

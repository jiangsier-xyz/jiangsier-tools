#!/usr/bin/env bash

set -e

usage() {
  cat <<EOF
Usage: $(basename "$0") -u <user> -h <host> [-t <target_dir>] [-i]

Mount a remote directory on macOS via SSHFS.

Options:
  -u <user>        Remote SSH username (required)
  -h <host>        Remote SSH host (required)
  -t <target_dir>  Remote directory to mount (default: /home/<user>)
  -i               Use the default SSH private key (~/.ssh/id_rsa)

Examples:
  $(basename "$0") -u alice -h example.com
  $(basename "$0") -u bob -h 192.168.1.10 -t /data -i
EOF
}

user=""
host=""
target=""
id_rsa=""

while getopts "u:h:t:i?" opt; do
  case "$opt" in
    u) user="$OPTARG" ;;
    h) host="$OPTARG" ;;
    t) target="$OPTARG" ;;
    i) id_rsa="$HOME/.ssh/id_rsa" ;;
    \?)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$target" ]; then
  target="/home/${user}"
fi

[ -n "$user" ] && [ -n "$host" ] || {
  usage >&2
  exit 1
}

if ! command -v sshfs >/dev/null 2>&1; then
  brew list --formula | grep -q '^macfuse$' || brew install macfuse
  brew list --formula | grep -q '^sshfs$'   || brew install gromgit/fuse/sshfs
fi

if [ -d "$HOME/mnt/$host" ]; then
  umount -f "$HOME/mnt/$host" &>/dev/null || true
else
  mkdir -p "$HOME/mnt/$host"
fi

if [ -n "$id_rsa" ]; then
  sshfs \
    "${user}@${host}:$target" \
    "$HOME/mnt/$host" \
    -i "$id_rsa" \
    -o reconnect,idmap=user,defer_permissions,ServerAliveInterval=15,ServerAliveCountMax=3
else
  sshfs \
    "${user}@${host}:$target" \
    "$HOME/mnt/$host" \
    -o reconnect,idmap=user,defer_permissions,ServerAliveInterval=15,ServerAliveCountMax=3
fi

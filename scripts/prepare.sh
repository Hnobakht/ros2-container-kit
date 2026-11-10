#!/usr/bin/env bash
# Run from your Ubuntu desktop session before `docker compose build`.
# This script only creates files in this project; it does NOT alter the host OS.
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
auth_file="${project_dir}/.docker/Xauthority"
env_file="${project_dir}/.env"

if [[ "$(id -u)" == "0" ]]; then
  echo "ERROR: Run this script as your normal desktop user, not root/sudo." >&2
  exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
  echo "ERROR: DISPLAY is empty. Run from an X11/XWayland desktop terminal." >&2
  exit 1
fi

if [[ ! -d /tmp/.X11-unix ]]; then
  echo "ERROR: /tmp/.X11-unix is missing. An X11/XWayland server is required." >&2
  exit 1
fi

if ! command -v xauth >/dev/null 2>&1; then
  echo "ERROR: xauth is missing on the host. Install only the small xauth utility." >&2
  exit 1
fi

mkdir -p "${project_dir}/.docker" "${project_dir}/ros2_ws/src"
umask 077

# The cookie is copied only into a project-local auth file; no broad xhost ACLs.
tmp_auth="$(mktemp "${project_dir}/.docker/Xauthority.XXXXXXXX")"
trap 'rm -f "${tmp_auth}"' EXIT
if ! xauth nlist "${DISPLAY}" | sed -e 's/^..../ffff/' | xauth -f "${tmp_auth}" nmerge -; then
  echo "ERROR: Could not generate an X11 authorization file." >&2
  exit 1
fi

if [[ -z "$(xauth -f "${tmp_auth}" list 2>/dev/null)" ]]; then
  echo "ERROR: No X11 cookie found. Check DISPLAY and XAUTHORITY on the host." >&2
  exit 1
fi

mv -f "${tmp_auth}" "${auth_file}"
trap - EXIT
chmod 600 "${auth_file}"

# ROS_DOMAIN_ID can be overridden explicitly before running prepare.sh.
domain_id="${ROS_DOMAIN_ID:-42}"
if [[ ! "${domain_id}" =~ ^[0-9]+$ ]] || (( domain_id > 232 )); then
  echo "ERROR: ROS_DOMAIN_ID should be an integer between 0 and 232." >&2
  exit 1
fi

printf 'LOCAL_UID=%s\nLOCAL_GID=%s\nROS_DISPLAY=%s\nROS_XAUTHORITY=%s\nROS_DOMAIN_ID=%s\n' \
  "$(id -u)" "$(id -g)" "${DISPLAY}" "${auth_file}" "${domain_id}" > "${env_file}"
chmod 600 "${env_file}"

echo "Prepared ROS container configuration."
echo "Next: docker compose build ros"
echo "Then: docker compose up -d ros"

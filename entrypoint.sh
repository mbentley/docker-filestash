#!/bin/sh

set -e

# name of the user and group to run filestash as
USERNAME="filestash"
GROUPNAME="filestash"

# uid/gid to run filestash as
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# directory filestash writes its state to (relative to the binary)
DATA_DIR="/opt/filestash/data"

# the entrypoint must run as root to create the user and set ownership; `--user` is not supported
if [ "$(id -u)" != "0" ]
then
  echo "ERROR: running as $(id -u):$(id -g); do not use '--user', set PUID and PGID instead"
  exit 1
fi

# make sure the uid/gid are numeric and not root
for ID in "${PUID}" "${PGID}"
do
  case "${ID}" in
    ''|*[!0-9]*)
      echo "ERROR: PUID and PGID must be numeric (PUID='${PUID}', PGID='${PGID}')"
      exit 1
      ;;
  esac
done

if [ "${PUID}" = "0" ] || [ "${PGID}" = "0" ]
then
  echo "ERROR: refusing to run filestash as root; set PUID and PGID to a non-zero value"
  exit 1
fi


# if the user exists but with a different uid/gid, remove it so it can be recreated (this also removes its group)
if getent passwd "${USERNAME}" > /dev/null 2>&1
then
  EXISTING_UID="$(getent passwd "${USERNAME}" | cut -d ':' -f 3)"
  EXISTING_GID="$(getent passwd "${USERNAME}" | cut -d ':' -f 4)"

  if [ "${EXISTING_UID}" = "${PUID}" ] && [ "${EXISTING_GID}" = "${PGID}" ]
  then
    echo "INFO: user ${USERNAME} exists with ${PUID}:${PGID}; skipping creation"
  else
    echo "INFO: user ${USERNAME} exists with ${EXISTING_UID}:${EXISTING_GID}; removing to recreate with ${PUID}:${PGID}..."
    deluser "${USERNAME}"
  fi
fi

if ! getent passwd "${USERNAME}" > /dev/null 2>&1
then
  # if the uid is already taken by another user, remove that user so the uid can be used
  CONFLICTING_USER="$(getent passwd "${PUID}" | cut -d ':' -f 1)"
  if [ -n "${CONFLICTING_USER}" ]
  then
    echo "INFO: uid ${PUID} is in use by user ${CONFLICTING_USER}; removing..."
    deluser "${CONFLICTING_USER}"
  fi

  # if the gid is already taken by another group, use that group as the primary group instead of creating a new one
  EXISTING_GROUP="$(getent group "${PGID}" | cut -d ':' -f 1)"
  if [ -n "${EXISTING_GROUP}" ]
  then
    echo "INFO: gid ${PGID} already exists as group ${EXISTING_GROUP}; using it as the primary group"
    GROUPNAME="${EXISTING_GROUP}"
  else
    # remove a leftover group with the same name but a different gid
    if getent group "${GROUPNAME}" > /dev/null 2>&1
    then
      echo "INFO: group ${GROUPNAME} exists with a different gid; removing to recreate with ${PGID}..."
      delgroup "${GROUPNAME}"
    fi

    echo "INFO: creating group ${GROUPNAME} (${PGID})..."
    addgroup -g "${PGID}" "${GROUPNAME}"
  fi

  echo "INFO: creating user ${USERNAME} (${PUID})..."
  adduser -u "${PUID}" -G "${GROUPNAME}" -H -h /opt/filestash -s /sbin/nologin -D "${USERNAME}"
else
  GROUPNAME="$(getent group "${PGID}" | cut -d ':' -f 1)"
fi


# create the data directory, if needed
mkdir -p "${DATA_DIR}"

# only change ownership of files that don't already match so restarts are fast and nothing is touched unnecessarily
if [ -n "$(find "${DATA_DIR}" \( ! -user "${PUID}" -o ! -group "${PGID}" \) -print -quit)" ]
then
  echo "INFO: setting ownership of ${DATA_DIR} to ${USERNAME}:${GROUPNAME} (${PUID}:${PGID})..."
  find "${DATA_DIR}" \( ! -user "${PUID}" -o ! -group "${PGID}" \) -exec chown -h "${PUID}:${PGID}" {} +
fi

# drop privileges and run CMD
echo "INFO: entrypoint complete; executing '${*}' as ${USERNAME}:${GROUPNAME} (${PUID}:${PGID})"
exec gosu "${USERNAME}" "${@}"

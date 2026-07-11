#!/bin/bash
export IMG=$(docker build -q --pull --no-cache -t 'get-version' .)

export DEBIAN_VERSION=$(docker run --rm -t "$IMG" cat /etc/debian_version | tail -n1 | tr -d '\r')
export DIRVISH_VERSION=$(docker run --rm -t "$IMG" dpkg --list dirvish | grep '^ii' | sed 's/^[^0-9]*//g' | cut -d ' ' -f1 | sed 's/[+=]/_/g' | tr -d '\r')
[ -z "$DEBIAN_VERSION" ] && exit 1

export IMGTAG=$(echo "$1""d$DEBIAN_VERSION-dv$DIRVISH_VERSION-cv0.0.3")
# FORCE_REBUILD (set by the workflow for push / manual runs) rebuilds even if
# the versioned image already exists, so code/config changes get republished.
# the nightly schedule leaves it unset and keeps deduping on the version tag.
if [ -n "$FORCE_REBUILD" ]; then
  echo "$IMGTAG"
  exit 0
fi

export IMAGE_EXISTS=$(docker pull "$IMGTAG" 2>/dev/null >/dev/null; echo $?)

# return latest, if container is already available :)
if [ "$IMAGE_EXISTS" -eq 0 ]; then
  echo "$1""latest"
else
  echo "$IMGTAG"
fi

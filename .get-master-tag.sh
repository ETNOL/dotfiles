#!/bin/bash

# Fetch latest from remote "o" to ensure we have current refs
git fetch o --tags
# Get the commit SHA of the remote o/master branch
MASTER_COMMIT=$(git rev-parse o/master)

# Get the tag(s) pointing to that commit, sorted by creation date (newest first)
TAG=$(git tag --points-at "$MASTER_COMMIT" --sort=-creatordate | head -n 1)

if [ -z "$TAG" ]; then
  echo "No tag found for o/master commit ($MASTER_COMMIT)" >&2
  exit 1
fi

echo "$TAG"

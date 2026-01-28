#!/bin/bash

set -e

# Get the current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if branch matches {two-letters}/ADT-nnnn-suffix format
if [[ ! "$BRANCH" =~ ^[a-zA-Z]{2}/ADT-[0-9]+-(.+)$ ]]; then
  echo "Error: Branch name '$BRANCH' does not match required format '{prefix}/ADT-nnnn-suffix' (e.g., 'en/ADT-1234-suffix')" >&2
  exit 1
fi

# Extract the suffix and ADT ticket number
SUFFIX="${BASH_REMATCH[1]}"
ADT_TICKET=$(echo "$BRANCH" | grep -oE 'ADT-[0-9]+')

# Check for uncommitted changes (staged or unstaged)
if ! git diff-index --quiet HEAD --; then
  echo "Error: You have uncommitted changes. Please commit or stash them first." >&2
  exit 1
fi

# Fetch latest from remote "o" to ensure we have current refs
echo "Fetching from remote 'o'..."
git fetch o --tags

# Get the commit SHA of the remote o/master branch
MASTER_COMMIT=$(git rev-parse o/master)

# Get the tag(s) pointing to that commit, sorted by creation date (newest first)
MASTER_TAG=$(git tag --points-at "$MASTER_COMMIT" --sort=-creatordate | head -n 1)

if [ -z "$MASTER_TAG" ]; then
  echo "Error: No tag found for o/master commit ($MASTER_COMMIT)" >&2
  exit 1
fi

# Extract semver portion from the tag (handles tags like 3.14.4 or 3.14.4-suffix)
SEMVER=$(echo "$MASTER_TAG" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$SEMVER" ]; then
  echo "Error: Master branch tag '$MASTER_TAG' does not match semver format (x.y.z)" >&2
  exit 1
fi

# Create the base tag name
BASE_TAG="${SEMVER}-${SUFFIX}"
NEW_TAG="$BASE_TAG"

# If tag exists, find the next available .N suffix
if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  COUNT=1
  while git rev-parse "${BASE_TAG}.${COUNT}" >/dev/null 2>&1; do
    ((COUNT++))
  done
  NEW_TAG="${BASE_TAG}.${COUNT}"
fi

echo "Creating tag: $NEW_TAG (annotated with: $ADT_TICKET)"

# Create annotated tag
git tag -a "$NEW_TAG" -m "$ADT_TICKET"

# Push the tag to remote "o"
echo "Pushing tag to remote 'o'..."
git push o "$NEW_TAG"

echo "Successfully created and pushed tag: $NEW_TAG"

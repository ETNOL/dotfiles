#!/bin/bash

set -e

# Colors for output
CYAN='\033[1;36m'
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# Parse flags
INCLUDE_HOTFIX=false
for arg in "$@"; do
  case $arg in
    --include-hotfix)
      INCLUDE_HOTFIX=true
      ;;
  esac
done

# Get the current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Check if branch matches {two-letters}/ADT-nnnn-suffix format
if [[ ! "$BRANCH" =~ ^[a-zA-Z]{2}/ADT-[0-9]+-(.+)$ ]]; then
  echo -e "${RED}Error: Branch name '$BRANCH' does not match required format '{prefix}/ADT-nnnn-suffix' (e.g., 'en/ADT-1234-suffix')${NC}" >&2
  exit 1
fi

# Extract the suffix and ADT ticket number
SUFFIX="${BASH_REMATCH[1]}"
ADT_TICKET=$(echo "$BRANCH" | grep -oE 'ADT-[0-9]+')

# Check for uncommitted changes (staged or unstaged)
if ! git diff-index --quiet HEAD --; then
  echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}" >&2
  exit 1
fi

# Fetch latest from remote "o" to ensure we have current refs
echo -e "${CYAN}==> Fetching from remote 'o'...${NC}"
git fetch o --tags

# Pull changes from o for the current branch (no fast-forward) if it exists
if git rev-parse --verify "o/$BRANCH" >/dev/null 2>&1; then
  echo -e "${CYAN}==> Pulling changes from 'o/$BRANCH' with --no-ff...${NC}"
  ORIG_HEAD=$(git rev-parse HEAD)
  if ! git merge --no-ff "o/$BRANCH" -m "Merge o/$BRANCH into $BRANCH" 2>/dev/null; then
    echo -e "${RED}Error: Merge conflicts occurred. Resetting to previous state.${NC}" >&2
    git merge --abort 2>/dev/null || git reset --hard "$ORIG_HEAD"
    exit 1
  fi
else
  echo -e "${CYAN}==> Remote branch 'o/$BRANCH' does not exist yet, skipping pull.${NC}"
fi

# Push the current branch to remote "o"
echo -e "${CYAN}==> Pushing branch '$BRANCH' to remote 'o'...${NC}"
if ! git push o "$BRANCH"; then
  echo -e "${RED}Error: Failed to push branch '$BRANCH' to remote 'o'. Aborting.${NC}" >&2
  exit 1
fi

# Ensure current branch is up to date with o/master
if ! git merge-base --is-ancestor o/master HEAD; then
  echo -e "${RED}Error: Current branch is not up to date with o/master. Please rebase or merge first.${NC}" >&2
  exit 1
fi

# Get the commit SHA of the remote o/master branch
MASTER_COMMIT=$(git rev-parse o/master)

# Get the tag(s) pointing to that commit, sorted by creation date (newest first)
MASTER_TAG=$(git tag --points-at "$MASTER_COMMIT" --sort=-creatordate | head -n 1)

if [ -z "$MASTER_TAG" ]; then
  echo -e "${RED}Error: No tag found for o/master commit ($MASTER_COMMIT)${NC}" >&2
  exit 1
fi

# Extract semver portion from the tag (handles tags like 3.14.4 or 3.14.4-suffix)
SEMVER=$(echo "$MASTER_TAG" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$SEMVER" ]; then
  echo -e "${RED}Error: Master branch tag '$MASTER_TAG' does not match semver format (x.y.z)${NC}" >&2
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

# Check tag length (max 40 - "-beta-control".length = 27 characters)
MAX_TAG_LEN=$((40 - 13))
if [ ${#NEW_TAG} -gt $MAX_TAG_LEN ]; then
  echo -e "${RED}Error: Tag name '$NEW_TAG' is too long (${#NEW_TAG} chars, max $MAX_TAG_LEN).${NC}" >&2
  exit 1
fi
if [ "$INCLUDE_HOTFIX" = true ]; then
  HF_TAG="${NEW_TAG}HF"
  if [ ${#HF_TAG} -gt $MAX_TAG_LEN ]; then
    echo -e "${RED}Error: Hotfix tag name '$HF_TAG' would be too long (${#HF_TAG} chars, max $MAX_TAG_LEN).${NC}" >&2
    exit 1
  fi
fi

echo -e "${CYAN}==> Creating tag: $NEW_TAG (annotated with: $ADT_TICKET)${NC}"

# Create annotated tag
git tag -a "$NEW_TAG" -m "$ADT_TICKET"

# Push the tag to remote "o"
echo -e "${CYAN}==> Pushing tag to remote 'o'...${NC}"
git push o "$NEW_TAG"

echo -e "${GREEN}==> Successfully created and pushed tag: $NEW_TAG${NC}"

# Create and push hotfix tag if requested
if [ "$INCLUDE_HOTFIX" = true ]; then
  echo -e "${CYAN}==> Creating hotfix tag: $HF_TAG (annotated with: $ADT_TICKET)${NC}"
  git tag -a "$HF_TAG" -m "$ADT_TICKET"
  echo -e "${CYAN}==> Pushing hotfix tag to remote 'o'...${NC}"
  git push o "$HF_TAG"
  echo -e "${GREEN}==> Successfully created and pushed hotfix tag: $HF_TAG${NC}"
fi

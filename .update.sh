#!/usr/bin/env bash
# Usage 
# up {current_release tag} {targeted_old_tag} {branch_name}
TAG=$1 
TAG_TO_UPDATE=$2
BRANCH_NAME=$3
OLD_SUFFIX=$(echo "$TAG_TO_UPDATE" | sed -n 's/[0-9]*\.[0-9]*\.[0-9]*\(.*\)/\1/p')
NEW_TAG="$TAG$OLD_SUFFIX"
TAG_ANNOTATION=$(git tag -l -n "$TAG_TO_UPDATE" | sed -n 's/[0-9]*\.[0-9]*\.[0-9]*-[a-zA-Z0-9]*[ ]\(.*\)/\1/p')
echo "Updating tag" $TAG_TO_UPDATE "to" $NEW_TAG
echo "Tag Annotation" $TAG_ANNOTATION
# # Update the Tag
git checkout $TAG_TO_UPDATE
git pull --commit --no-edit origin $TAG 

if [[ -n "$TAG_ANNOTATION" ]]; then
  git tag $NEW_TAG -a -m "$TAG_ANNOTATION"
elif [[ -z "$TAG_ANNOTATION" ]]; then
  git tag $NEW_TAG
fi

git push origin $NEW_TAG
# Update the branch
if [[ -n "$BRANCH_NAME" ]]; then
  git checkout $BRANCH_NAME 
  git pull --commit --no-edit origin master
  git push origin $BRANCH_NAME
elif [[ -z "$BRANCH_NAME" ]]; then
  echo "No branch provided, skipping branch update!"
fi
git checkout master

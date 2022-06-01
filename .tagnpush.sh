#!/usr/bin/env bash
TAG=$1 
ANNOTATION=$2
echo "Creating" $TAG "annotated with" $ANNOTATION

if [[ -n "$ANNOTATION" ]]; then
  git tag $TAG -a -m "$ANNOTATION"
elif [[ -z "$ANNOTATION" ]]; then
  git tag $NEW_TAG
fi

git push origin $TAG

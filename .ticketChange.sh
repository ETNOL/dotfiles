TAG=$1 


if [[ -n "$TAG" ]]; then
  git branch --list | grep $TAG | xargs git switch 
elif [[ -z "$TAG" ]]; then
	echo "No tag provided!"
fi


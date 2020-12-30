#!/bin/bash

# find -type f | xargs -I '{}' git log --diff-filter=A -- {} | grep Author

for FILE in $(find -type f); do
  LOG=$(git log --diff-filter=A -- $FILE)
  AUTHOR=$(echo "$LOG" | grep Author)
  AUTHOR_NAME=$(echo "$AUTHOR" | cut -c 9-)
  echo "$FILE,$AUTHOR_NAME"
done


#!/bin/bash

NAME=$1
if [[ -z "$NAME" ]]; then
    echo "Folder name not provided"
else
    echo "Creating folder: $NAME"
    dconf write "/org/gnome/desktop/app-folders/folders/$NAME/name" "'$NAME'"
    dconf write "/org/gnome/desktop/app-folders/folders/$NAME/translate" "false"
    dconf write "/org/gnome/desktop/app-folders/folders/$NAME/excluded-apps" "[]"
    dconf write "/org/gnome/desktop/app-folders/folders/$NAME/categories" "[]"
    dconf write "/org/gnome/desktop/app-folders/folders/$NAME/apps" "[]"
fi


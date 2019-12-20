function deploy-war {
    TOMCAT_DIR="/opt/tomcat/current"

    WAR_FILES=()
    for WAR_FILE in "$@"; do
        if [[ "$WAR_FILE" == *.war ]]; then
            WAR_FILES=(${WAR_FILES[@]} "$WAR_FILE")
        else
            WAR_FILES=(${WAR_FILES[@]} "$WAR_FILE.war")
        fi
    done

    ALL_FILE_EXISTS=1
    for WAR_FILE in "${WAR_FILES[@]}"; do
        if ! [[ -f "$WAR_FILE" ]]; then
            ALL_FILE_EXISTS=0
            echo "File does not exist: $WAR_FILE"
        fi
    done

    if [[ $ALL_FILE_EXISTS -eq 0 ]]; then
        return
    fi

    if ! [[ -d "$TOMCAT_DIR/webapps" ]]; then
        echo "Unable to find tomcat directory"
        return
    fi

    echo "Stopping tomcat"
    sudo systemctl stop tomcat

    for WAR_FILE in "${WAR_FILES[@]}"; do
        echo "Deploying: $WAR_FILE"

        NAME_LEN=$(echo "$WAR_FILE" | wc -m)
        let "NAME_END = $NAME_LEN - 5"
        NAME=$(echo "$WAR_FILE" | cut -c -$NAME_END)

        sudo rm -rf "$TOMCAT_DIR/webapps/$WAR_FILE" 2> /dev/null
        sudo rm -rf "$TOMCAT_DIR/webapps/$NAME" 2> /dev/null
        sudo mv "$WAR_FILE" "$TOMCAT_DIR/webapps/"
    done

    echo "Starting tomcat"
    sudo systemctl start tomcat
}

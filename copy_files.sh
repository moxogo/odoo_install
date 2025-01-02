#!/bin/bash

# Define the source and destination directories
SOURCE_DIRECTORY="$HOME/odoo_install"
DESTINATION_DIRECTORY="/odoo"

# List of files to copy (as per the provided format)
# Get the latest changes of files from the current Git pull
# LATEST_CHANGES=$(git pull --no-commit | grep "Copying" | cut -d' ' -f2- | sed -e 's/^ *//g' -e 's/ *$//g')
# echo "Latest changes: ${LATEST_CHANGES[@]}"

FILES_TO_COPY=(
    "docker-compose.yml"
    "config/nginx.conf"
    "config/main.conf"
    "copy_files.sh"
  )

# Function to copy files, creating necessary directories
copy_files() {
    for FILE_PATH in "${FILES_TO_COPY[@]}"; do
        SRC="$SOURCE_DIRECTORY/$FILE_PATH"
        DEST="$DESTINATION_DIRECTORY/$FILE_PATH"
        
        # Create subdirectories in the destination directory if they do not exist
        mkdir -p "$(dirname "$DEST")"

        # Copy the file
        if [ -e "$SRC" ]; then
            cp "$SRC" "$DEST"
            echo "Copied $SRC to $DEST"
        else
            echo "File not found: $SRC"
        fi
    done
}

# Run the copy_files function
copy_files

echo "File copying completed."
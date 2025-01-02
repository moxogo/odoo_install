#!/bin/bash

# Define the source and destination directories
SOURCE_DIRECTORY="~/odoo_install"
DESTINATION_DIRECTORY="/odoo/"

# List of files to copy (as per the provided format)
FILES_TO_COPY=(
    "config/locations.inc"
    "config/nginx.conf"
    "docker-compose.yml"
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
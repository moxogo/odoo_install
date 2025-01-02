#!/bin/bash

# Define the source and destination directories
SOURCE_DIRECTORY="$HOME/odoo_install"
DESTINATION_DIRECTORY="/odoo"

# List of files to copy (as per the provided format)
# Get the latest changes of files from the current Git commit
LATEST_CHANGES=$(git diff-tree --no-commit-id --name-only -r HEAD | grep -v odoo_install/copy_files.sh)

# Split the output into an array
read -r -a FILES_TO_COPY <<< "$LATEST_CHANGES"

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
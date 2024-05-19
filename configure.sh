#!/bin/bash

# Define the path to your dotfiles repository
DOTFILES_REPO="$HOME/dotfyles"

# List of dotfiles you want to symlink
declare -a dotfiles=(
    ".zshrc"
    ".gitignore"
    ".gitconfig"
    # Add other dotfiles here
)

# Create symlinks for each dotfile
for file in "${dotfiles[@]}"; do
    target="$HOME/$file"
    source="$DOTFILES_REPO/$file"
    
    # Backup existing dotfile if it exists
    if [ -e "$target" ]; then
        mv "$target" "$target.bak"
        echo "Moved existing $file to $file.bak"
    fi
    
    # Create symlink
    ln -s "$source" "$target"
    echo "Created symlink for $file"
done

echo "All dotfiles have been symlinked."

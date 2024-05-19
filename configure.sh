#! /bin/bash

DOTFILES=(.gitconfig .gitignore .zshrc)

for dotfile in $(echo ${DOTFILES[*]});
do
    cp ~/dotfyles/$(echo $dotfile) ~/$(echo $dotfile)
done
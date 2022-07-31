#!/bin/bash


## Configure vim for convinience
cp -r vim/.vim vim/.vimrc ~


## configure git
git config --global user.email yoavklein25@gmail.com
git config --global user.email yoavklein25@gmail.com

if [ ! -f ~/.git_askpass ]; then
    read -p "Enter GitHub token: " github_token
    echo "echo $github_token" > ~/.git_askpass
fi
chmod +x ~/.git_askpass


echo "export GIT_ASKPASS=~/.git_askpass" >> ~/.bashrc
export GIT_ASKPASS=~/.git_askpass

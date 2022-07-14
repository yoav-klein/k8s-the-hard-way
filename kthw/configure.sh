#!/bin/bash

sed  "s@{{pwd}}@$(pwd)@" env > .env
cp -r vim/.vim vim/.vimrc ~
sudo apt-get update
sudo apt-get install -y jq make

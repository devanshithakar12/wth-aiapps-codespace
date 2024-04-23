#!/bin/sh

# Install Angular and Azure Function tools.
npm install -g @angular/cli azure-functions-core-tools@4

# Install Bicep CLI, and add it to path.
az bicep install
echo "PATH=$PATH:~/.azure/bin" >> ~/.bashrc
source ~/.bashrc


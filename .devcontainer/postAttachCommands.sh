#!/bin/sh

# Log some info we might need to troubleshoot.
ls /workspaces > ~/postAttachCommands.log
env >> ~/postAttachCommands.log

# Change the backend port visibility to public...
gh codespace ports -c $CODESPACE_NAME >> ~/postAttachCommands.log
gh codespace ports visibility 7072:public -c $CODESPACE_NAME
gh codespace ports -c $CODESPACE_NAME >> ~/postAttachCommands.log

# ... and update our envrionment.ts file with the new public URL.
ADDRESS=`gh codespace ports -c $CODESPACE_NAME -q ".[0] | .browseUrl " --json browseUrl`
sed -i 's|http://localhost:7072|'$ADDRESS'|g' $CODESPACE_VSCODE_FOLDER/Challenge-00/ContosoAIAppsFrontend/src/environments/environment.ts

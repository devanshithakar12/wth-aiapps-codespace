#!/bin/sh

# Change the backend port visibility to public...
gh codespace ports visibility 7072:public -c $CODESPACE_NAME

# ... and update our envrionment.ts file with the new public URL.
ADDRESS=`gh codespace ports -c $CODESPACE_NAME -q ".[0] | .browseUrl " --json browseUrl`
sed -i 's/http:\/\/localhost:7072/$(ADDRESS)/g' ../Challenge-00/ContosoAIAppsFrontend/src/environments/environment.ts

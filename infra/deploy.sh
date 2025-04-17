#!/bin/bash

# Function to display error messages
function error_exit {
    echo -e "\e[31mERROR: $1\e[0m"
    exit 1
}

# Default values
LOCATION="East US 2"
DOCUMENT_INTELLIGENCE_LOCATION="East US"
OPENAI_LOCATION="East US 2"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --subscription-id) SUBSCRIPTION_ID="$2"; shift ;;
        --resource-group-name) RESOURCE_GROUP_NAME="$2"; shift ;;
        --location) LOCATION="$2"; shift ;;
        --tenant-id) TENANT_ID="$2"; shift ;;
        --use-service-principal) USE_SERVICE_PRINCIPAL=true ;;
        --service-principal-id) SERVICE_PRINCIPAL_ID="$2"; shift ;;
        --service-principal-password) SERVICE_PRINCIPAL_PASSWORD="$2"; shift ;;
        --openai-location) OPENAI_LOCATION="$2"; shift ;;
        --document-intelligence-location) DOCUMENT_INTELLIGENCE_LOCATION="$2"; shift ;;
        *) error_exit "Unknown parameter passed: $1" ;;
    esac
    shift
done

# Validate mandatory parameters
if [[ -z "$SUBSCRIPTION_ID" || -z "$RESOURCE_GROUP_NAME" ]]; then
    error_exit "Subscription ID and Resource Group Name are mandatory."
fi

# Check if Bicep CLI is installed
if ! command -v bicep &> /dev/null; then
    error_exit "Bicep CLI not found. Install it using 'az bicep install'."
fi

echo -e "\n\t\t\e[32mWHAT THE HACK - AZURE OPENAI APPS\e[0m"
echo -e "\tcreated with love by the Americas GPS Tech Team!\n"

# Authenticate with Azure
if [[ "$USE_SERVICE_PRINCIPAL" == true ]]; then
    if [[ -z "$TENANT_ID" || -z "$SERVICE_PRINCIPAL_ID" || -z "$SERVICE_PRINCIPAL_PASSWORD" ]]; then
        error_exit "Service Principal ID, Password, and Tenant ID are required for Service Principal authentication."
    fi
    az login --service-principal -u "$SERVICE_PRINCIPAL_ID" -p "$SERVICE_PRINCIPAL_PASSWORD" --tenant "$TENANT_ID" || error_exit "Failed to authenticate using Service Principal."
else
    az login || error_exit "Failed to authenticate with Azure."
fi

# Set the subscription
az account set --subscription "$SUBSCRIPTION_ID" || error_exit "Failed to set subscription."

# Display deployment parameters
echo -e "The resources will be provisioned using the following parameters:"
echo -e "\t          TenantId: \e[33m$TENANT_ID\e[0m"
echo -e "\t    SubscriptionId: \e[33m$SUBSCRIPTION_ID\e[0m"
echo -e "\t    Resource Group: \e[33m$RESOURCE_GROUP_NAME\e[0m"
echo -e "\t            Region: \e[33m$LOCATION\e[0m"
echo -e "\t   OpenAI Location: \e[33m$OPENAI_LOCATION\e[0m"
echo -e "\t Azure DI Location: \e[33m$DOCUMENT_INTELLIGENCE_LOCATION\e[0m"
echo -e "\e[31mIf any parameter is incorrect, abort this script, correct, and try again.\e[0m"
echo -e "It will take around \e[32m15 minutes\e[0m to deploy all resources. You can monitor the progress from the deployments page in the resource group in Azure Portal.\n"

read -p "Press Y to proceed to deploy the resources using these parameters: " proceed
if [[ "$proceed" != "Y" ]]; then
    echo -e "\e[31mAborting deployment script.\e[0m"
    exit 1
fi

start=$(date +%s)

# Create resource group
echo -e "\n- Creating resource group: "
az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION" || error_exit "Failed to create resource group."

# Deploy resources
echo -e "\n- Deploying resources: "
result=$(az deployment group create --resource-group "$RESOURCE_GROUP_NAME" --template-file ./main.bicep \
    --parameters openAILocation="$OPENAI_LOCATION" documentIntelligenceLocation="$DOCUMENT_INTELLIGENCE_LOCATION") || error_exit "Azure deployment failed."

# Extract outputs
outputs=$(echo "$result" | jq -r '.properties.outputs')

# Create settings file
echo -e "\n- Creating the settings file:"
settings_file="../ContosoAIAppsBackend/local.settings.json"
example_file="../ContosoAIAppsBackend/local.settings.json.example"

if [[ ! -f "$example_file" ]]; then
    error_exit "Example settings file not found at $example_file."
fi

cp "$example_file" "$settings_file"

# Populate settings file
jq --arg openAIKey "$(echo "$outputs" | jq -r '.openAIKey.value')" \
   --arg openAIEndpoint "$(echo "$outputs" | jq -r '.openAIEndpoint.value')" \
   --arg searchKey "$(echo "$outputs" | jq -r '.searchKey.value')" \
   --arg searchEndpoint "$(echo "$outputs" | jq -r '.searchEndpoint.value')" \
   --arg redisHost "$(echo "$outputs" | jq -r '.redisHostname.value')" \
   --arg redisPassword "$(echo "$outputs" | jq -r '.redisPrimaryKey.value')" \
   --arg cosmosConnection "$(echo "$outputs" | jq -r '.cosmosDBConnectionString.value')" \
   --arg cosmosDatabase "$(echo "$outputs" | jq -r '.cosmosDBDatabaseName.value')" \
   --arg documentEndpoint "$(echo "$outputs" | jq -r '.documentEndpoint.value')" \
   --arg documentKey "$(echo "$outputs" | jq -r '.documentKey.value')" \
   --arg webjobsConnection "$(echo "$outputs" | jq -r '.webjobsConnectionString.value')" \
   --arg storageConnection "$(echo "$outputs" | jq -r '.storageConnectionString.value')" \
   --arg appInsightsConnection "$(echo "$outputs" | jq -r '.appInsightsConnectionString.value')" \
   --arg serviceBusConnection "$(echo "$outputs" | jq -r '.serviceBusConnectionString.value')" \
   '.Values.AZURE_OPENAI_API_KEY = $openAIKey |
    .Values.AZURE_OPENAI_ENDPOINT = $openAIEndpoint |
    .Values.AZURE_AI_SEARCH_ADMIN_KEY = $searchKey |
    .Values.AZURE_AI_SEARCH_ENDPOINT = $searchEndpoint |
    .Values.REDIS_HOST = $redisHost |
    .Values.REDIS_PASSWORD = $redisPassword |
    .Values.COSMOS_CONNECTION = $cosmosConnection |
    .Values.COSMOS_DATABASE_NAME = $cosmosDatabase |
    .Values.DOCUMENT_INTELLIGENCE_ENDPOINT = $documentEndpoint |
    .Values.DOCUMENT_INTELLIGENCE_KEY = $documentKey |
    .Values.AzureWebJobsStorage = $webjobsConnection |
    .Values.DOCUMENT_STORAGE = $storageConnection |
    .Values.APPLICATIONINSIGHTS_CONNECTION_STRING = $appInsightsConnection |
    .Values.SERVICE_BUS_CONNECTION_STRING = $serviceBusConnection' \
   "$settings_file" > tmp.json && mv tmp.json "$settings_file"

echo -e "\e[32mSettings file created successfully.\e[0m"

# Copy files to Azure Storage
echo -e "\n- Copying files:"
storage_connection=$(echo "$outputs" | jq -r '.storageConnectionString.value')

# Declare an associative array
declare -A hashtable

# Add key-value pairs to the hashtable
hashtable["../artifacts/contoso-education/F01-Civics-Geography and Climate/"]="f01-geo-climate"
hashtable["../artifacts/contoso-education/F02-Civics-Tourism and Economy/"]="f02-tour-economy"
hashtable["../artifacts/contoso-education/F03-Civics-Government and Politics/"]="f03-gov-politics"
hashtable["../artifacts/contoso-education/F04-Activity-Preferences/"]="f04-activity-preferences"

# Iterate over the hashtable
for sourceDir in "${!hashtable[@]}"; do
    az storage blob upload-batch --overwrite --source "$sourceDir" --destination "classifications/"${hashtable[$sourceDir]} --connection-string "$storage_connection" || error_exit "Failed to upload files."
done

end=$(date +%s)
echo -e "\nThe deployment took: $((end - start)) seconds."
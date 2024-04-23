<#
    .SYNOPSIS
    Deploy the resources needed for this What The Hack!

    .PARAMETER $SubscriptionId
    The subscription id where the resources will be deployed.

    .PARAMETER $Location
    Region where the resources will be deployed.

    .PARAMETER $ResourceGroupName
    The resource group where the resources will be deployed.

    .PARAMETER $TenantId
    The tenant id where the resources will be deployed.

    .PARAMETER $UseServicePrincipal
    Use service principal, instead of the current logged in user.

    .PARAMETER $ServicePrincipalId
    The service principal id.

    .PARAMETER $ServicePrincipalPassword
    The service principal password.
#>

param(
    [Parameter(Mandatory = $True)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $True)]
    [string]$Location,

    [Parameter(Mandatory = $True)]
    [string]$ResourceGroupName,    

    [Parameter(Mandatory = $False)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $False)]
    [switch]$UseServicePrincipal,

    [Parameter(Mandatory = $False)]
    [string]$ServicePrincipalId,

    [Parameter(Mandatory = $False)]
    [string]$ServicePrincipalPassword
)

# Make sure Bicep is in the path. GH Codespaces should have installed it during the provision process.
$env:Path += ';~/.azure/bin'

if ($UseServicePrincipal -eq $True) {
    Write-Host -ForegroundColor Yellow "`nUsing Service Principal to authenticate.`n"

    $SecurePassword = ConvertTo-SecureString -String $ServicePrincipalPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalId, $SecurePassword

    Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Subscription $SubscriptionId -Credential $Credential    
}
else {
    if ($env:CODESPACES -eq "true") {
        Write-Host -ForegroundColor Yellow "`nLogging from GitHub Codespaces, using device authentication.`n"
        Connect-AzAccount -Subscription $SubscriptionId -UseDeviceAuthentication
    } else {
        Write-Host -ForegroundColor Yellow "`nUsing standard authentication.`n"
        Connect-AzAccount -Subscription $SubscriptionId
    }    
}

Write-Host "`n`t`tWHAT THE HACK - AZURE OPENAI APPS" -ForegroundColor Green
Write-Host "`tcreated with love by the Americas GPS Tech Team!`n"

$context = Get-AzContext

Write-Host "The resources will be provisioned using the following parameters:"
Write-Host -NoNewline "`t       TenantId: " 
Write-Host -ForegroundColor Yellow $context.Tenant.Id
Write-Host -NoNewline "`t SubscriptionId: "
Write-Host -ForegroundColor Yellow $context.Subscription.Id
Write-Host -NoNewline "`t Resource Group: "
Write-Host -ForegroundColor Yellow $ResourceGroupName
Write-Host -NoNewline "`t         Region: "
Write-Host -ForegroundColor Yellow $Location
Write-Host -ForegroundColor Red "`nIf the subscription is incorrect, abort this script, point to the correct one "
Write-Host -ForegroundColor Red "using Set-AzContext -Subscription <id>, and try again.`n"

$r = Read-Host "Press Y to proceed to deploy the resouces using this parameters"

if ($r -ne "Y") {
    Write-Host -ForegroundColor Red "Aborting deployment script."
    [Environment]::Exit(1)
}

Write-Host -ForegroundColor White "`n- Creating resource group: "
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

Write-Host -ForegroundColor White "`n- Deploying resources: "
$result = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile .\main.bicep

Write-Host -ForegroundColor White "`n- Creating the settings file:"
$object = Get-Content -Raw ../Challenge-00/ContosoAIAppsBackend/local.settings.json.example | ConvertFrom-Json

# Azure OpenAI settings
$object.Values.AZURE_OPENAI_API_KEY = $result.Outputs.openAIKey.Value
$object.Values.AZURE_OPENAI_ENDPOINT = $result.Outputs.openAIEndpoint.Value
Write-Host -ForegroundColor Green "`t- Azure OpenAI"

# Azure AI Search
$object.Values.AZURE_AI_SEARCH_ADMIN_KEY = $result.Outputs.searchKey.Value
$object.Values.AZURE_AI_SEARCH_ENDPOINT = $result.Outputs.searchEndpoint.Value
Write-Host -ForegroundColor Green "`t- Azure AI Search"

# Azure Cache for Redis
$object.Values.REDIS_HOST = $result.Outputs.redisHostname.Value
$object.Values.REDIS_PASSWORD = $result.Outputs.redisPrimaryKey.Value
Write-Host -ForegroundColor Green "`t- Azure Cache for Redis"

# Azure CosmosDB
$object.Values.COSMOS_CONNECTION = $result.Outputs.cosmosDBConnectionString.Value
$object.Values.COSMOS_DATABASE_NAME = $result.Outputs.cosmosDBDatabaseName.Value
Write-Host -ForegroundColor Green "`t- Azure CosmosDB"

# Azure AI Document Intelligence
$object.Values.DOCUMENT_INTELLIGENCE_ENDPOINT = $result.Outputs.documentEndpoint.Value
$object.Values.DOCUMENT_INTELLIGENCE_KEY = $result.Outputs.documentKey.Value
Write-Host -ForegroundColor Green "`t- Azure AI Document Intelligence"

# Azure Storage Account for WebJobs
$object.Values.AzureWebJobsStorage = $result.Outputs.webjobsConnectionString.Value
Write-Host -ForegroundColor Green "`t- Azure Storage Account for WebJobs"

# Azure Storage Account for Documents
$object.Values.DOCUMENT_STORAGE = $result.Outputs.storageConnectionString.Value
Write-Host -ForegroundColor Green "`t- Azure Storage Account for Documents"

# Azure Service Bus
$object.Values.SERVICE_BUS_CONNECTION_STRING = $result.Outputs.serviceBusConnectionString.Value
Write-Host -ForegroundColor Green "`t- Azure Service Bus"

$object | ConvertTo-Json | Out-File -FilePath ../Challenge-00/ContosoAIAppsBackend/local.settings.json
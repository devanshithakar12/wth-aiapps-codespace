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

    .PARAMETER $OpenAILocation
    Region where the OpenAI service should be deployed.
    
    .PARAMETER $DocumentIntelligenceLocation
    Region where the Document Intelligence service should be deployed.
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
    [string]$ServicePrincipalPassword,

    [Parameter(Mandatory = $False)]
    [string]$OpenAILocation,
    
    [Parameter(Mandatory = $False)]
    [string]$DocumentIntelligenceLocation
)

# Make sure Bicep is in the path. GH Codespaces should have installed it during the provision process.
$env:Path += ':/home/vscode/.azure/bin'

Write-Host "`n`t`tWHAT THE HACK - AZURE OPENAI APPS" -ForegroundColor Green
Write-Host "`tcreated with love by the Americas GPS Tech Team!`n"

if ($DocumentIntelligenceLocation -eq "") {
    Write-Host -ForegroundColor Yellow "- Document Intelligence location not provided, using East US."
    $DocumentIntelligenceLocation = "East US"
}

if ($OpenAILocation -eq "") {
    Write-Host -ForegroundColor Yellow "- OpenAI location not provided, using East US 2."
    $OpenAILocation = "East US 2"
}

if ($UseServicePrincipal -eq $True) {
    Write-Host -ForegroundColor Yellow "- Using Service Principal to authenticate."
    
    if ($TenantId -eq "" -or  $ServicePrincipalId -eq $null -or $ServicePrincipalPassword -eq $null) {
        Write-Host -ForegroundColor Red "`nERROR: Service principal id (-ServicePrincipalId), password (-ServicePrincipalPassword), and tenant id (-TenantId) are required when using service principal authentication.`n"
        [Environment]::Exit(1)
    }

    $SecurePassword = ConvertTo-SecureString -String $ServicePrincipalPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalId, $SecurePassword

    Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Subscription $SubscriptionId -Credential $Credential    
}
else {
    if ($env:CODESPACES -eq "true") {
        Write-Host -ForegroundColor Yellow "- Logging from GitHub Codespaces, using device authentication."
        Connect-AzAccount -Subscription $SubscriptionId -UseDeviceAuthentication
    } else {
        Write-Host -ForegroundColor Yellow "- Using standard authentication."
        Connect-AzAccount -Subscription $SubscriptionId
    }    
}

$context = Get-AzContext

Write-Host "The resources will be provisioned using the following parameters:"
Write-Host -NoNewline "`t          TenantId: " 
Write-Host -ForegroundColor Yellow $context.Tenant.Id
Write-Host -NoNewline "`t    SubscriptionId: "
Write-Host -ForegroundColor Yellow $context.Subscription.Id
Write-Host -NoNewline "`t    Resource Group: "
Write-Host -ForegroundColor Yellow $ResourceGroupName
Write-Host -NoNewline "`t            Region: "
Write-Host -ForegroundColor Yellow $Location
Write-Host -NoNewline "`t   OpenAI Location: "
Write-Host -ForegroundColor Yellow $OpenAILocation
Write-Host -NoNewline "`t Azure DI Location: "
Write-Host -ForegroundColor Yellow $DocumentIntelligenceLocation
Write-Host -ForegroundColor Red "`nIf any parameter is incorrect, abort this script, correct, and try again."
Write-Host -ForegroundColor White "It will take around " -NoNewline 
Write-Host -ForegroundColor Green "15 minutes " -NoNewline
Write-Host -ForegroundColor White "to deploy all resources. You can monitor the progress from the deployments page in the resource group in Azure Portal.`n"

$r = Read-Host "Press Y to proceed to deploy the resouces using this parameters"

if ($r -ne "Y") {
    Write-Host -ForegroundColor Red "Aborting deployment script."
    [Environment]::Exit(1)
}

$start = Get-Date

Write-Host -ForegroundColor White "`n- Creating resource group: "
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

Write-Host -ForegroundColor White "`n- Deploying resources: "
$result = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile .\main.bicep -openAILocation $OpenAILocation -documentIntelligenceLocation $DocumentIntelligenceLocation

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

Write-Host "`nThe deployment took: " (New-TimeSpan –Start $start –End (Get-Date)).TotalSeconds " seconds."

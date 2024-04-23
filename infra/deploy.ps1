<#
    .SYNOPSIS
    Deploy the resources needed for this What The Hack!

    .PARAMETER $ResourceGroupName
    The resource group where the resources will be deployed.

    .PARAMETER $TenantId
    The tenant id where the resources will be deployed.

    .PARAMETER $SubscriptionId
    The subscription id where the resources will be deployed.

    .PARAMETER $Location
    Region where the resources will be deployed. Default is East US 2.
#>

param(
    [Parameter(Mandatory = $True)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $True)]
    [string]$Location,

    [Parameter(Mandatory = $True)]
    [string]$ResourceGroupName,    

    [Parameter(Mandatory = $True)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $False)]
    [switch]$UseServicePrincipal,

    [Parameter(Mandatory = $False)]
    [string]$ServicePrincipalId,

    [Parameter(Mandatory = $False)]
    [securestring]$ServicePrincipalPassword
)

if ($UseServicePrincipal -eq $True) {
    $SecurePassword = ConvertTo-SecureString -String $ServicePrincipalPassword -AsPlainText -Force
    $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipalId, $SecurePassword

    Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Subscription $SubscriptionId -Credential $Credential    
}
else {
    Connect-AzAccount -Subscription $SubscriptionId
}

Clear-Host
Write-Host "`n`tWHAT THE HACK - AZURE OPENAI APPS" -ForegroundColor Green
Write-Host "created with love by the Americas GPS Tech Team!`n"

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
Write-Host -ForegroundColor Red "`nIf the subscription is incorrect, abort this script, point Azure Cloud Shell "
Write-Host -ForegroundColor Red "to the correct one using Set-AzContext -Subscription <id>, and try again.`n"

$r = Read-Host "Press Y to proceed to deploy the resouces using this parameters"

if ($r -ne "Y") {
    Write-Host -ForegroundColor Red "Aborting deployment script."
    return
}

New-AzResourceGroup -Name $ResourceGroupName -Location $Location

$result = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile .\main.bicep


$object = Get-Content -Raw template.json | ConvertFrom-Json


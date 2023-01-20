Clear-Host
write-host "Starting script at $(Get-Date)"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

$resourceGroupName="Spielwiese_Ilia_Sinev"
$synapseWorkspace = "synapsedp00009"
$dataLakeAccountName="datalakedp00009"
$sqlDatabaseName = "sqldp00009"
$sqlUser="SQLuser"
$sqlPassword="SC1004i$"
# $Region="westeurope"
# $sparkPool="sparkdp00006"
$suffix="dp00009"

# Create Synapse workspace
$synapseWorkspace = "synapse$suffix"
$dataLakeAccountName = "datalake$suffix"
$sqlDatabaseName = "sql$suffix"

write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile "setup.json" `
  -Mode Complete `
  -workspaceName $synapseWorkspace `
  -dataLakeAccountName $dataLakeAccountName `
  -uniqueSuffix $suffix `
  -sqlDatabaseName $sqlDatabaseName `
  -sqlUser $sqlUser `
  -sqlPassword $sqlPassword `
  -Force
Write-Host "Synapse Analytics workspace $synapseWorkspace created"

# Make the current user and the Synapse service principal owners of the data lake blob store
write-host "Granting permissions on the $dataLakeAccountName storage account..."
write-host "(you can ignore any warnings!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).id
New-AzRoleAssignment -Objectid $id -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;

# Pause SQL Pool
write-host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

write-host "Script completed at $(Get-Date)"
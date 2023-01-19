Clear-Host
write-host "Starting script at $(Get-Date)"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

$resourceGroupName="Spielwiese_Ilia_Sinev"
$synapseWorkspace = "synapsedp00006"
$dataLakeAccountName="datalakedp00006"
# $sqlDatabaseName = "sql-dp000"
$sqlUser="SQLuser"
$sqlPassword="SC1004i$"
$Region="westeurope"
$sparkPool="sparkdp00006"
$suffix="dp00006"

# Create Synapse workspace
write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile "setup.json" `
  -Mode Complete `
  -workspaceName $synapseWorkspace `
  -dataLakeAccountName $dataLakeAccountName `
  -sparkPoolName $sparkPool `
  -sqlUser $sqlUser `
  -sqlPassword $sqlPassword `
  -uniqueSuffix $suffix `
  -Force

# Make the current user and the Synapse service principal owners of the data lake blob store
write-host "Granting permissions on the $dataLakeAccountName storage account..."
write-host "(you can ignore any warnings!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).id
New-AzRoleAssignment -Objectid $id -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;

Write-Host "Creating Cosmos DB account...";
# Try the same region as Synapse, and if that fails try others...
$stop = 0
$attempt = 0
$tried_cosmos = New-Object Collections.Generic.List[string]
while ($stop -ne 1){
    try {
        write-host "Trying $Region..."
        $attempt = $attempt + 1
        $cosmosDB = "cosmos$suffix$attempt"
        New-AzCosmosDBAccount -ResourceGroupName $resourceGroupName -Name $cosmosDB -Location $Region -ErrorAction Stop | Out-Null
        $stop = 1
    }
    catch {
      $stop = 0
      Remove-AzCosmosDBAccount -ResourceGroupName $resourceGroupName -Name $cosmosDB -AsJob | Out-Null
      $tried_cosmos.Add($Region)
      $locations = $locations | Where-Object {$_.Location -notin $tried_cosmos}
      if ($locations.Count -ne 1)
      {
        $rand = (0..$($locations.Count - 1)) | Get-Random
        $Region = $locations.Get($rand).Location
      }
      else {
          Write-Host "Could not create a Cosmos DB account."
          Write-Host "Use the Azure portal to add one to the $resourceGroupName resource group."
          $stop = 1
      }
    }
}

write-host "Script completed at $(Get-Date)"
Param(
    [string]$ResourceGroupName,
    [string]$StorageAccountName
)

$global:ErrorActionPreference = 'Stop'
$TableName = 'FormData'
$GroupsPartition = 'local-groups'

Write-Output "Starting form data sync."

try
{
    Connect-AzAccount -Identity | Out-Null
    $StorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
    $Context = $StorageAccount.Context

    Write-Output "Connected to Storage Account named '$($Context.StorageAccountName)'."

    # check if table exists
    $StorageTable = Get-AzStorageTable -Name $TableName -Context $Context -EA SilentlyContinue

    if ($null -eq $StorageTable)
    {
        New-AzStorageTable -Name $TableName -Context $Context
        $StorageTable = Get-AzStorageTable -Name $TableName -Context $Context
    }

    $CloudTable = $StorageTable.CloudTable

    Write-Output "Selected table named '$($CloudTable.Name)'."

    # remove rows and recreate them rather than try to discover changes
    Get-AzTableRow -Table $CloudTable -PartitionKey $GroupsPartition | Remove-AzTableRow -Table $CloudTable | Out-Null

    # wait to ensure changes to the table have been applied
    Start-Sleep -Seconds 5

    Write-Output "Adding rows..."

    $Groups = @(Get-LocalGroup)
    foreach ($Group in $Groups)
    {
        Add-AzTableRow `
            -Table $CloudTable `
            -PartitionKey $GroupsPartition -RowKey ($Group.SID.Value) `
            -Property @{
                'Name' = $Group.Name
            } -EA Continue | Out-Null
    }

    Write-Output "Completed."
}
catch
{
    throw $_.ToString()
}
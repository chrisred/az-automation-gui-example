Param(
	[object]$WebhookData
)

$RequestBody = $WebhookData.RequestBody | ConvertFrom-Json
$Message  = $RequestBody.inputMessage
$Count = $RequestBody.inputCount
$Wait = $RequestBody.selectWait
$Randomise = $RequestBody.checkboxWait

Write-Output "Printing Runbook output..."
Write-Output ""

foreach($n in 1..$Count)
{
    Write-Output "$Message (count $n)"
    if ($Randomise) { $Sleep = Get-Random -Minimum 0 -Maximum $Wait } else { $Sleep = $Wait }
    Start-Sleep -Seconds $Sleep
}

# write request body json
$Body = $WebhookData.RequestBody | ConvertFrom-Json
Write-Output $Body | Out-String
Param(
    [object]$WebhookData
)

try
{
    $RequestBody = $WebhookData.RequestBody | ConvertFrom-Json
    $UserName  = [string]$RequestBody.inputName
    $FullName = [string]$RequestBody.inputFullName
    $Password = [string]$RequestBody.inputPassword
    $Groups = [array]$RequestBody.selectGroups
    $PasswordExpire = [bool]$RequestBody.checkboxExpire

    Write-Output "Creating local user: $($UserName)"

    if (Get-LocalUser -Name $UserName -EA 'SilentlyContinue') {throw "User '$UserName' already exists."}

    New-LocalUser -Name $UserName -FullName $FullName -PasswordNeverExpires:$PasswordExpire `
        -Password (ConvertTo-SecureString $Password -AsPlainText -Force)

    # get the newly created user, New-LocalUser can return $null but still create a user when certain errors are raised
    $User = Get-LocalUser -Name $Username -EA 'SilentlyContinue'
    if ($null -eq $User) {throw "Failed to create user."}

    # get group names from SID and filter for $null in pipeline iteration
    $GroupNames = $Groups | where {$_} | foreach {(Get-LocalGroup -SID $_).Name}
    Write-Output "Adding user to the following group(s): $($GroupNames -join ', ')"
    Write-Output ""

    $Groups | where {$_} | foreach {Add-LocalGroupMember -SID $_ -Member $User}
    Write-Output "User created successfully."

    $User | fl * | Out-String
}
catch
{
    throw $_.ToString()
}
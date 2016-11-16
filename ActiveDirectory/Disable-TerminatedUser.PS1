function Disable-TerminatedUser{
# Author: Tim Waring
# Goes through and terminates an Active Directory user in a certain way, according to set requirements
Param(
[Parameter(Mandatory=$True,Position=1)][string]$Identity,
[Parameter(Mandatory=$True,Position=2)][AllowEmptyString()][string]$EmployeeID,
[Parameter(Position=3)][AllowEmptyString()][string]$Reason,
[Parameter(Position=4)][AllowEmptyString()][string]$ToEmail,
[Parameter()][switch]$Transfer = $false
)

Function On-Exit {
# End the script by finishing off the log file
Add-Content -Path $logLoc -Value "`r`n***************************************************************************************************"
Add-Content -Path $logLoc -Value "`r`nFinished processing at [$([DateTime]::Now)]."
Add-Content -Path $logLoc -Value "`r`n***************************************************************************************************"
Disconnect-ExchangeServer
Break
}

Connect-ExchangeServer

# Create log file in the user profile
$logpath = "$env:USERPROFILE\Documents\Logs\$(([cultureinfo]::InvariantCulture).DateTimeFormat.GetMonthName($(Get-Date).Month))$((Get-Date).Year)"
$logFile = "Disable-TerminatedUser-$(if($Reason -eq ''){$null}Else{$Reason})-$Identity-$(get-date -format "ddMMyyyy-HHmmss").log"
# Check if folder exists, and create if not
Try{
Get-ChildItem $logPath | Out-Null
}
Catch{
New-Item $logPath -ItemType Directory | Out-Null
}
# Create the file
$logLoc = "$logPath\$logFile"
Try{
New-Item -Path "$logLoc" -ItemType File -ErrorAction Stop | Out-Null
}
Catch{
Write-Warning "Cannot create log file, exiting"
Break
}
Add-Content -Path $logLoc -Value "***************************************************************************************************"
Add-Content -Path $logLoc -Value "`r`nTerminating Network Access for user account [$Identity].`r`n"
Add-Content -Path $logLoc -Value "***************************************************************************************************"

# Get user details for later use
Try{
    $userName = (Get-ADUser $Identity).Name
    $userID = (Get-ADUser $Identity -Properties EmployeeID).EmployeeID
}
Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    Write-Warning "User account could not be found, so no further changes will be made"
    Add-Content -Path $logLoc -Value "`r`nUser account could not be found, so no further changes will be made."
    On-Exit
}

# Check if Employee ID matches and exit if not
If($userID){
if ($EmployeeID -ne $userID){
    Write-Host "User Employee ID does not match, so no further changes will be made"
    Add-Content -Path $logLoc -Value "`r`nUser Employee ID does not match, so no further changes will be made."
    On-Exit
}
}

# Output the users group list in a human readable format
$readableGroups = (get-aduser $Identity -Properties MemberOf | select MemberOf).MemberOf | % {$_.split(",")[0].replace("CN=","")}
if ($readableGroups -eq ""){
    Add-Content -Path $logLoc -Value "`r`n$Identity does not belong to any groups."
}
Else{
    Add-Content -Path $logLoc -Value "`r`n$Identity has been removed from the following groups:`r`n"
    Add-Content -Path $logLoc -Value $readableGroups
}
# Goes through and removes user from all AD groups
$userDetails = get-aduser $Identity -Properties MemberOf
$userGroups = $userDetails.MemberOf
if ($userGroups -ne ""){
    $userGroups | %{Get-ADGroup $_ | Remove-ADGroupMember -confirm:$false -member $Identity}
}

# disable the AD account, checking first if it already has been, but only if not transferring.
if ($Transfer -eq $false){
    $userDisabled = (Get-ADUser -Identity $Identity | select Enabled).Enabled
    if ($userDisabled -ne $false){
        Disable-ADAccount -Identity $Identity
    }
}

}

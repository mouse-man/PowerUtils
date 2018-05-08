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

#################################################
# Initialise Variables                          #
#################################################

$CurrentMonth = ([cultureinfo]::InvariantCulture).DateTimeFormat.GetMonthName($(Get-Date).Month)
$CurrentYear = (Get-Date).year
$DomainDN = (Get-ADDomain).DistinguishedName
$ADForest = (Get-ADDomain).Forest

switch($CurrentMonth){
'January'{$OUName = "Jan to Mar $CurrentYear - delete Jul 1 $CurrentYear"}
'February'{$OUName = "Jan to Mar $CurrentYear - delete Jul 1 $CurrentYear"}
'March'{$OUName = "Jan to Mar $CurrentYear - delete Jul 1 $CurrentYear"}
'April'{$OUName = "Apr to Jun $CurrentYear - delete Oct 1 $CurrentYear"}
'May'{$OUName = "Apr to Jun $CurrentYear - delete Oct 1 $CurrentYear"}
'June'{$OUName = "Apr to Jun $CurrentYear - delete Oct 1 $CurrentYear"}
'July'{$OUName = "Jul to Sep $CurrentYear - delete Jan 1 $($CurrentYear + 1)"}
'August'{$OUName = "Jul to Sep $CurrentYear - delete Jan 1 $($CurrentYear + 1)"}
'September'{$OUName = "Jul to Sep $CurrentYear - delete Jan 1 $($CurrentYear + 1)"}
'October'{$OUName = "Oct to Dec $CurrentYear - delete Apr 1 $($CurrentYear + 1)"}
'November'{$OUName = "Oct to Dec $CurrentYear - delete Apr 1 $($CurrentYear + 1)"}
'December'{$OUName = "Oct to Dec $CurrentYear - delete Apr 1 $($CurrentYear + 1)"}

#################################################
# End Initialise Variables                      #
#################################################

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

# Move the AD account into resigned users OU, but to do this, need to get the DN. And check first that it is not already there.
$userDN = (Get-ADUser -Identity $Identity).DistinguishedName
$userOU = ($userDN -split “,”, 2)[1] # Splits the UserDN into a 2 part array using the commas as seperators, then select only the 2nd object of the array
if ($Transfer -eq $false){
    if ($userOU -ne "OU=$OUName,OU=Resigned Users,$DomainDN"){
        Add-Content -Path $logLoc -Value "`r`n$Identity Old Distinguished Name:`r`n`r`n$userDN"
        Move-ADObject -Identity $userDN -TargetPath "OU=$OUName,OU=Resigned Users,$DomainDN"
        $userInBin = $false
    }
    Else{
        Add-Content -Path $logLoc -Value "`r`n$Identity is already in the Terminated Users OU.`r`n`r`n$userDN"
        $userInBin = $True
    }
}
Else{
    if ($userOU -ne "OU=Transferring Users,$DomainDN"){
        Add-Content -Path $logLoc -Value "`r`n$Identity Old Distinguished Name:`r`n`r`n$userDN"
        Move-ADObject -Identity $userDN -TargetPath "OU=Transferring Users,$DomainDN"
        $userInBin = $false
    }
    Else{
        Add-Content -Path $logLoc -Value "`r`n$Identity is already in the Transferring Users OU.`r`n`r`n$userDN"
        $userInBin = $True
    }
}

# Rename AD Object to show it is terminated, need to get Distinguished Name again as it changes in the move.
# But check first if it already has Terminated in the name.
$userCurrentName = (Get-ADUser $Identity).Name
if ($Transfer -eq $false){
    if ($userCurrentName -like "*Terminated"){
        Add-Content -Path $logLoc -Value "`r`n$Identity already renamed as terminated"
    }
    Else{
        $userDN2 = (Get-ADUser -Identity $Identity).DistinguishedName
        $UserDNCount = 0
        Do{
        # Pause for 1 second as user move needs to replicate. This repeats until the change is seen.
            $userDN2 = (Get-ADUser -Identity $Identity).DistinguishedName
            Start-Sleep -s 1
            $UserDNCount++
        } while  (($userdn2 -eq $userdn) -and ($UserDNCount -lt 120) -and ($userInBin -eq $false))
        $userDN = $userDN2
        $userNewName = (Get-ADUser $Identity).Name + " Terminated"
        Try{
            Rename-ADObject -Identity $userDN -NewName $userNewName -ErrorAction Stop
        }
        Catch{
            Add-Content -Path $logLoc -Value "`r`nError changing AD Object Name - Name has not been changed"
            $renameError = $True
        }
        #Log the move and name change
        $UserDNCount = 0
        $userDN = (Get-ADUser -Identity $Identity).DistinguishedName
        if ($renameError -ne $True){
            do{
                $userDN = (Get-ADUser -Identity $Identity).DistinguishedName
                Start-Sleep -s 1
                $UserDNCount++
            } while (($userDN -notlike "*Terminated*") -and ($UserDNCount -lt 120))
        }
        Add-Content -Path $logLoc -Value "`r`n$Identity New Distinguished Name:`r`n`r`n$userDN"
    }
}
Else{ # If transfer
    if ($userCurrentName -like "*Transferred"){
        Add-Content -Path $logLoc -Value "`r`n$Identity already renamed as transferred"
    }
    Else{
        $userDN2 = (Get-ADUser -Identity $Identity).DistinguishedName
        $UserDNCount = 0
        Do{
        # Pause for 1 second as user move needs to replicate. This repeats until the change is seen.
            $userDN2 = (Get-ADUser -Identity $Identity).DistinguishedName
            Start-Sleep -s 1
            $UserDNCount++
        } while  (($userdn2 -eq $userdn) -and ($UserDNCount -lt 120) -and ($userInBin -eq $false))
        $userDN = $userDN2
        $userNewName = (Get-ADUser $Identity).Name + " Transferred"
        Try{
            Rename-ADObject -Identity $userDN -NewName $userNewName -ErrorAction Stop
        }
        Catch{
            Add-Content -Path $logLoc -Value "`r`nError changing AD Object Name - Name has not been changed"
            $renameError = $True
        }
        #Log the move and name change
        $UserDNCount = 0
        $userDN = (Get-ADUser -Identity $Identity).DistinguishedName
        if ($renameError -ne $True){
            do{
                $userDN = (Get-ADUser -Identity $Identity).DistinguishedName
                Start-Sleep -s 1
                $UserDNCount++
            } while (($userDN -notlike "*Transferred*") -and ($UserDNCount -lt 120))
        }
    Add-Content -Path $logLoc -Value "`r`n$Identity New Distinguished Name:`r`n`r`n$userDN"
    }
}

# Append user discription with details entered under Reason variable.
$currentdesc = (Get-ADUser -Identity $userLogon -Properties Description).Description
If ($Transfer -eq $false){
    $newdesc = "$currentdesc - Disabled due to: $Reason"
}
Else{
    $newdesc = "$currentdesc - Groups removed due to: $Reason"
}
Set-ADUser $Identity -Description $newdesc

# check for mail attributes on user account, if mail attribute is not null, hide from address list
$userEMail = (Get-ADUser $userLogon -Properties Mail).mail

# Nesting in a Try/Catch in case of issues with changing mailbox properties.
Try{
if($userEMail -ne $null){
    $userHidden = (get-mailbox $Identity | select HiddenFromAddressListsEnabled).HiddenFromAddressListsEnabled
    if ($userHidden -eq $True)
    {
        Write-Verbose "$Identity has already been hidden from address list"
        Add-Content -Path $logLoc -Value "`r`n$Identity has already been hidden from address list."
    }
    Else{
        Try{
            Set-Mailbox -HiddenFromAddressListsEnabled $true -Identity $Identity -WarningAction SilentlyContinue -ea SilentlyContinue
            Write-Verbose "$Identity has been hidden from address list"
            Add-Content -Path $logLoc -Value "`r`n$Identity has been hidden from address list."
        }
        Catch{
            Write-Verbose "$Identity has not been hidden from address list. Please action manually"
            Add-Content -Path $logLoc -Value "`r`n$Identity has not been hidden from address list. Please action manually."
        }
    }
}
Else{
        Write-Verbose "$Identity did not have a mailbox attached"
        Add-Content -Path $logLoc -Value "`r`n$Identity did not have a mailbox attached."
}
}
Catch{
        Write-Warning "Error running Exchange Commands"
        Add-Content -Path $logLoc -Value "`r`nError running Exchange commands to hide mailbox from address list. This can be expected if not run from Exchange Shell."
}

If ($Transfer -eq $false){
# Check if user has personal logon script, or any script other than SSWAHS.bat
    Try{
        $logonScriptBAT = (Get-ADUser -Identity $Identity -Properties ScriptPath).ScriptPath
        $logonScript = $logonScriptBAT | % {$_.split(".")[0]}
    }
    Catch{
        $logonscript = ""
    }
    Try{
        $homeDir = (Get-ADUser -Identity $Identity -Properties HomeDirectory).HomeDirectory
    }
    Catch{
        $homeDir = ""
    }
# If logonscript is same as user logon, automatically move the .bat file to the root of their home directory, so that script is removed along with user
    if ($logonScript -eq $Identity){
        Write-Host -BackgroundColor DarkRed -NoNewline "User has a personal logon script"
        Add-Content -Path $logLoc -Value "`r`n$Identity has a personal logon script."
        If ($homeDir -ne ""){
            Try{    
                Get-Item -Path "\\$ADForest\NETLOGON\$logonScriptBAT" | Move-Item -Destination $homeDir
                Add-Content -Path $logLoc -Value "`r`n$logonScriptBAT has been moved to $homeDir. Therefore will be cleaned up with account deletion script."
                Write-Host -BackgroundColor DarkRed ", which was moved from NETLOGON successfully to the users Home Drive."
                Set-ADUser -Identity $Identity -ScriptPath $null
            }
            Catch{
                Write-Host -BackgroundColor DarkRed ", in which an error occurred while attemping to move. Please move manually."
                Add-Content -Path $logLoc -Value "`r`nError moving $logonScriptBAT to $homeDir. Please check and move manually."
            }
        }
        Else{
            Write-Host -BackgroundColor DarkRed "$userLogon has no Home Drive set. Please remove manually."
            Add-Content -Path $logLoc -Value "`r`n$userLogon has no Home Directory. Please check and remove manually."
        }
    }
    elseif ($logonScript -ne $null){
        $usernameNoSpaces = $userCurrentName.replace(' ','')
        if($logonScript -eq $usernameNoSpaces){
            Try{
                Get-Item -Path "\\$ADForest\NETLOGON\$logonScriptBAT" | Move-Item -Destination $homeDir
                Write-Host -BackgroundColor DarkRed "User has a custom logon script. This logon script is their name without spaces."
                 Write-Host -BackgroundColor DarkRed "This login script file was moved from NETLOGON successfully to the users Home Drive."
                Add-Content -Path $logLoc -Value "`r`n$logonScriptBAT has been moved to $homeDir. Therefore will be cleaned up with account deletion script."
                Set-ADUser -Identity $Identity -ScriptPath $null
            }
            Catch{
                Write-Host -BackgroundColor DarkRed ", in which an error occurred while attemping to move. Please move manually."
                Add-Content -Path $logLoc -Value "`r`nError moving $logonScriptBAT to $homeDir. Please check and move manually."
            }
        }
        Else{
            Write-Host -BackgroundColor DarkRed "User has a custom logon script. Please check if this needs removal, or is a department script."
            Add-Content -Path $logLoc -Value "`r`n$Identity has a custom logon script. Logon Script is $logonScriptBAT. `r`nPlease determine if this requires removal, or is a department script."
        }

        If ($homeDir -ne ""){
            Add-Content -Path $logLoc -Value "`r`n$Identity Home Directory is located at $homeDir."
        }
        Else{
            Add-Content -Path $logLoc -Value "`r`n$Identity has no logon script."
            Write-Host -BackgroundColor DarkRed "$Identity has no Home Drive set. Please remove manually."
            Add-Content -Path $logLoc -Value "`r`n$Identity has no Home Directory. Please check and remove manually."
        }
    }
    Else{
        If ($homeDir -ne ""){
            Add-Content -Path $logLoc -Value "`r`n$Identity Home Directory is located at $homeDir."
        }
        Else{
            Add-Content -Path $logLoc -Value "`r`n$Identity has no Home Directory."
        }
    }
}

}

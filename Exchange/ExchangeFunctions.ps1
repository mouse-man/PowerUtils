Function Connect-ExchangeServer{
# The function to get the Exchange Server listing in the AD site was borrowed from the below site:
# http://mikepfeiffer.net/2010/04/find-exchange-servers-in-the-local-active-directory-site-using-powershell/
# Script from that site has been adapted to suit the requirements of this script.

Function Get-ExchangeServerInSite {
    $ADSite = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]
    $siteDN = $ADSite::GetComputerSite().GetDirectoryEntry().distinguishedName
    $configNC=([ADSI]"LDAP://RootDse").configurationNamingContext
    $search = new-object DirectoryServices.DirectorySearcher([ADSI]"LDAP://$configNC")
    $objectClass = "objectClass=msExchExchangeServer"
    $version = "versionNumber>=1937801568"
    $site = "msExchServerSite=$siteDN"
    $search.Filter = "(&($objectClass)($version)($site))"
    $search.PageSize=1000
    [void] $search.PropertiesToLoad.Add("name")
    [void] $search.PropertiesToLoad.Add("msexchcurrentserverroles")
    [void] $search.PropertiesToLoad.Add("networkaddress")
    $search.FindAll() | %{
        New-Object PSObject -Property @{
            Name = $_.Properties.name[0]
            FQDN = $_.Properties.networkaddress |
                %{if ($_ -match "ncacn_ip_tcp") {$_.split(":")[1]}}
            Roles = $_.Properties.msexchcurrentserverroles[0]
        }
    }
}

$role = @{
    2  = "MB"
    4  = "CAS"
    16 = "UM"
    32 = "HT"
    64 = "ET"
}

$serverList = @()

foreach ($server in Get-ExchangeServerinSite) {
  $roles = ($role.keys | ?{$_ -band $server.roles} | %{$role.Get_Item($_)}) -join ", "
  #$server | select Name, @{n="Roles";e={$roles}}
  if ($roles -like "*CAS*"){
  $ServerListing = New-Object psobject
  $ServerListing | Add-Member NoteProperty -Name "Name" -Value $server.fqdn
  $ServerListing | Add-Member NoteProperty -Name "Roles" -Value $roles
  $serverList += $ServerListing
  }
}

# Check an Exchange Commandlet to see if user is running from Exchange Shell, otherwise use PSSession Remoting.
Try{
[void](Get-ExchangeServer)
}
Catch{
# Connect to a random Microsoft Exchange Client Access Server
$params =   @{
    ConfigurationName = 'Microsoft.Exchange'
    ConnectionUri = "http://$(Get-Random -InputObject $serverlist.name)/PowerShell/"
    Authentication = 'Kerberos'
                    }
$global:sess = New-PSSession @params
[void](Import-PSSession $sess -DisableNameChecking -AllowClobber)
}

}

function Disconnect-ExchangeServer{

try{
Remove-PSSession $sess
}
Catch{
Write-Verbose "No session to disconnect"
}

}

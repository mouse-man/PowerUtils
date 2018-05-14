<#
.Synopsis
Gets a list of AD DHCP Servers in the current domain
.DESCRIPTION
Gets a list of AD DHCP Servers in the current domain
Based off information taken from this article.
https://blogs.technet.microsoft.com/heyscriptingguy/2013/01/10/use-powershell-to-query-ad-ds-for-dhcp-servers/
.EXAMPLE
Get-ADDHCPServers
#>
function Get-ADDHCPServers
{

    Begin
    {
        $DomainDN = Get-ADDomain.distinguishedname
        $DHCPServers = Get-ADObject -SearchBase "CN=Configuration,$($DomainDN)" -Filter "objectclass -eq 'dhcpclass' -AND Name -ne 'dhcproot'"
    }
    Process
    {
        foreach($svr in $DHCPServers){
            # One of my test servers was coming up as a conflict, so put the \ into the code to remove that section also if it exists.
            $server = (($svr.DistinguishedName -replace 'cn=','' -split ',')[0] -split '\',-1,'SimpleMatch')[0]
            try{
                # Again, more messed up details in my test domain, some are showing as IP addresses. So enumerate IP addresses as hostnames.
                $IsIP = [ipaddress]$Server
                $svrname = [System.Net.Dns]::gethostentry($IsIP)
                try{
                    Test-Connection -ComputerName $svrname.hostname -Count 1 -ErrorAction Stop
                }
                Catch{
                    Write-Host "$svrname.hostname is not online"
                }
            }
            Catch{
                try{
                    Test-Connection -ComputerName $server -Count 1 -ErrorAction Stop
                }
                Catch{
                    Write-Host "$server is not online"
                }
            }
        }
    }
    End
    {
        # To output in a way that can be piped to another command or a report generated
    }
}
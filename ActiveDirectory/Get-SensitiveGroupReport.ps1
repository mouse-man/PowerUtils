<#
.Synopsis
Get the membership of any predefined Sensitive Groups and flag any anomalies for removal.
.DESCRIPTION
Get the membership of any predefined Sensitive Groups and flag any anomalies for removal.
.EXAMPLE
Get-SensitiveGroupReport
#>
#requires -modules ActiveDirectory,ImportExcel
function Get-SensitiveGroupReport
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Position=0)]
        [ValidateScript({Get-ChildItem -File $_})]
        [string]
        $ListPath = 'C:\Temp\SensitiveGroups.csv'
    )

    Begin
    {
        $GroupList = Import-Csv -Path $ListPath
        if($GroupList -notcontains 'Domain Admins'){
            $GroupList += 'Domain Admins'
        }
        if($GroupList -notcontains 'Account Operators'){
            $GroupList += 'Account Operators'
        }
        if($GroupList -notcontains 'Administrators'){
            $GroupList += 'Administrators'
        }
        if($GroupList -notcontains 'Backup Operators'){
            $GroupList += 'Backup Operators'
        }
        if($GroupList -notcontains 'Print Operators'){
            $GroupList += 'Print Operators'
        }
        if($GroupList -notcontains 'Remote Desktop Users'){
            $GroupList += 'Remote Desktop Users'
        }
        $searchRoot = (Get-ADDomain).DistinguishedName
        $ADserver = (Get-ADDomainController -Discover).name
        $OutFileName = "C:\Temp\$(([cultureinfo]::InvariantCulture).DateTimeFormat.GetMonthName($(Get-Date).Month))$((Get-Date).Year)\Get-SensitiveGroupReport-$(get-date -format "ddMMyyyy").xlsx"
        Try{
            $AlreadyRunToday = Get-ChildItem -File $OutFileName -ErrorAction Stop
        }
        Catch{
            $AlreadyRunToday = $false
        }
    }
    Process
    {
        if($AlreadyRunToday -eq $false){
            foreach($grp in $GroupList){
                $groupDN = Get-ADGroup -Filter:{ name -eq $grp } -ResultSetSize:1 -Server $ADserver | Select-Object -ExpandProperty 'DistinguishedName'
                $ldapFilter = '(&(objectclass=user)(objectcategory=person)(memberof:1.2.840.113556.1.4.1941:={0}))' -f $groupDN
                $users = Get-ADObject -LDAPFilter:$ldapFilter -SearchBase:$searchRoot -ResultSetSize:$null -ResultPageSize:1000 -Properties:@('samAccountName','mail','DisplayName') -Server $ADserver | Select-Object 'Name', 'samAccountName', 'mail', 'DisplayName' | Sort-Object -Property 'Name'
                $users | Export-Excel -Path $OutFileName -WorksheetName $($wksname = $grp -replace ' ','';$wksname.Substring(0, [System.Math]::Min(30,$wksname.length))) -AutoSize -FreezeTopRow -BoldTopRow
                #TODO: Compare to yesterday
            }
        }
    }
    End
    {
    }
}
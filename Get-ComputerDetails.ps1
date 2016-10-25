function Get-ComputerDetails{
param(
[parameter(Position=0)][ValidateScript({Test-Connection -ComputerName $_ -Count 1 -Quiet})][string[]]$ComputerName = $env:COMPUTERNAME
) 
$Diskreport = @()
$report = @()
$ipreport = @()
$compinfo = ""

foreach ($computer in $ComputerName){
$fileObj = New-Object PSObject
$os = Get-WmiObject -Computer $computer -Class Win32_OperatingSystem | select Caption

$osname = $os.Caption -replace '\(R\)', "" -replace "Microsoft ", "" -replace " Edition", "" -replace ',',''

$fileobj | Add-Member NoteProperty -Name "Operating System" -Value $osname

$TotalMemory = [math]::Round((Get-WmiObject -Computer $computer -Class Win32_OperatingSystem).TotalVisibleMemorySize/1mB,3)

$fileobj | Add-Member NoteProperty -Name "Memory (GB)" -Value $TotalMemory

$compinfo = Get-WmiObject Win32_ComputerSystem -ComputerName $computer | Select-Object model,manufacturer

$fileobj | Add-Member NoteProperty -Name "Machine Model" -Value $compinfo.model
$fileobj | Add-Member NoteProperty -Name "Machine Manufacturer" -Value $compinfo.manufacturer

$compDomain = [System.Net.Dns]::GetHostEntry([string]$computer).HostName -replace "$computer.",''

$fileobj | Add-Member NoteProperty -Name "Domain" -Value $compDomain

$iplist = [System.Net.Dns]::GetHostAddresses("$computer")
Foreach ($ip in $iplist){
$ipfileobj = New-Object PSObject
$ipfileobj | Add-Member NoteProperty -Name "IP Addr" -Value $ip.IPAddressToString
$ipreport += $ipfileobj
}

if (($OS.Caption) -like "Microsoft Windows 2000*"){
$Disk = Get-WmiObject -ComputerName $computer -Class Win32_logicaldisk | select DeviceID,@{n='FreeSpace';e={"{0:N1}" -F ($_.FreeSpace/1GB)}},@{n="DiskSize";e={'{0:N1}' -f ($_.Size/1GB)}}
foreach ($diskitem in $Disk){
$diskfileobj = New-Object PSObject
$diskfileobj | Add-Member NoteProperty -Name "Device ID" -Value $diskitem.DeviceID
$diskfileobj | Add-Member NoteProperty -Name "Free Space (GB)" -Value $diskitem.FreeSpace
$diskfileobj | Add-Member NoteProperty -Name "Disk Size (GB)" -Value $diskitem.DiskSize
$Diskreport = $Diskreport += $diskfileobj
}
}
Else{
$Disk = Get-WmiObject –ComputerName $computer –Class Win32_Volume | select DriveLetter,Label,@{n=”Free”;Expression={“{0:N0}” –F ($_.FreeSpace/1GB)}},@{n=”PercentFree”;Expression={“{0:P0}” –F ($_.FreeSpace/$_.Capacity)}},@{n=”DiskSize”;e={'{0:N0}' -f ($_.Capacity/1GB)}}
foreach ($diskitem in $Disk){
$diskfileobj = New-Object PSObject
$diskfileobj | Add-Member NoteProperty -Name "Device ID" -Value $diskitem.DriveLetter
$diskfileobj | Add-Member NoteProperty -Name "Disk Label" -Value $diskitem.label
$diskfileobj | Add-Member NoteProperty -Name "Free Space (GB)" -Value $diskitem.Free
$diskfileobj | Add-Member NoteProperty -Name "Free Percent" -Value $diskitem.PercentFree
$diskfileobj | Add-Member NoteProperty -Name "Disk Size (GB)" -Value $diskitem.DiskSize
$Diskreport = $Diskreport += $diskfileobj
}
}

# Get any non-default shares on machine
Try{
# Solution 1 - CIM
$CIMsession = New-CimSession -ComputerName $computer -ErrorAction SilentlyContinue
$ShareList = Get-SmbShare -CimSession $CIMsession -Special:$false
Remove-CimSession -CimSession $CIMsession
$UsedCIM = $true
}
Catch{
# Solution 2 - WMI
$ShareList2 = Get-WmiObject -Class Win32_Share -ComputerName $computer -filter "Type = 0"
}

$report = $report += $fileObj
}
Write-Host -ForegroundColor Yellow "Machine Details"
$report | ft -AutoSize
Write-Host -ForegroundColor Yellow "IP Details"
$ipreport | ft -AutoSize
Write-Host -ForegroundColor Yellow "Disk Details"
$diskreport | sort "Device ID" | ft
Write-Host -ForegroundColor Yellow "Share Details"
If($UsedCIM -eq $true){
$ShareList | ft Name,Path,Description
}
Else{
$ShareList2 | ft
}
}

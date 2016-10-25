. $PSScriptRoot\Get-ComputerDetails.ps1

function Get-Uptime { 
 $os = Get-WmiObject win32_operatingsystem
 $uptime = (Get-Date) - ($os.ConvertToDateTime($os.lastbootuptime))
 $Display = "" + $Uptime.Days + " days / " + $Uptime.Hours + " hours / " + $Uptime.Minutes + " minutes"
 Write-Output $Display
}

Function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name,
    [switch]$RemoveSpaces
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  if($PSBoundParameters['RemoveSpaces']){
    return ($Name -replace $re -replace ' ')
  }
  Else{
    return ($Name -replace $re)
  }
}

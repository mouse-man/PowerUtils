. $PSScriptRoot\Windows\Get-ComputerDetails.ps1
. $PSScriptRoot\Windows\Convert-VHDtoWIM.ps1
. $PSScriptRoot\ActiveDirectory\Get-SensitiveGroupReport.ps1
. $PSScriptRoot\Exchange\ExchangeFunctions.ps1

function Get-Uptime { 
 $os = Get-WmiObject win32_operatingsystem
 $uptime = (Get-Date) - ($os.ConvertToDateTime($os.lastbootuptime))
 $Display = "" + $Uptime.Days + " days / " + $Uptime.Hours + " hours / " + $Uptime.Minutes + " minutes"
 Write-Output $Display
}

Function Read-TimedPrompt($prompt,$secondsToWait){   
    Write-Host -NoNewline $prompt
    $secondsCounter = 0
    $subCounter = 0
    While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
        start-sleep -m 10
        $subCounter = $subCounter + 10
        if($subCounter -eq 1000)
        {
            $secondsCounter++
            $subCounter = 0
            Write-Host -NoNewline "."
        }       
        If ($secondsCounter -eq $secondsToWait) { 
            Write-Host "`r`n"
            return $false;
        }
    }
    Write-Host "`r`n"
    return $true;
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

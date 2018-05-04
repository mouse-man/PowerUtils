<#
.Synopsis
Convert all *.VHDx files in a folder to *.WIM files
.DESCRIPTION
Adapted from https://gallery.technet.microsoft.com/Convert-VHDx-to-WIM-files-d160be4a by Rasmus Nørgaard
.EXAMPLE
Convert-VHDtoWIM -VHDFileName c:\Temp\WinImage.vhdx -WIMFileName c:\temp\WinImage.wim
#>
function Convert-VHDtoWIM
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [ValidateScript({Get-ChildItem -File $_})]
        [string]
        $VHDFileName,

        # Param2 help description
        [Parameter(Mandatory=$true,Position=1)]
        #[ValidateScript({Get-ChildItem -Directory ([io.fileinfo]$_).DirectoryName})]
        [string]
        $WIMFileName
    )

    Begin
    {
        $MountPoint = 'c:\temp\mount'
        [void](New-Item -ItemType Directory -Path $MountPoint)
    }
    Process
    {
        Mount-WindowsImage -ImagePath $VHDFileName -Path $MountPoint -Index 1
        New-WindowsImage -CapturePath $MountPoint -Name $VHDFileName -ImagePath $WIMFileName -Description $(([io.fileinfo]$vhdfilename).BaseName) -Verify -
        Dismount-WindowsImage -Path $MountPoint -Discard
    }
    End
    {
        Remove-Item $MountPoint
    }
}
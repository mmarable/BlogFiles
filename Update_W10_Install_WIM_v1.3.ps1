# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# File:  Update_W10_Install_WIM_v#.#.ps1
# Version: 1.0
# Date:    28 Jun 2018
# Author:  Mike Marable
#
# Update the factory original install.wim with the latest CU and Service Stack Update (SSU)

# Version: 1.1
# Date:    28 Jun 2018
# Author:  Mike Marable
#
# Updated to parse multiple updates and select the newest one automatically

# Version: 1.2
# Date:    6 Jul 2018
# Author:  Mike Marable
#
# Changed how .NET is installed (per Mike Horton @mikeh36)

# Version: 1.3
# Date:    9 Jul 2018
# Author:  Adam Gross
#
# Moved .NET install until after the SSU and LCU to allow /cleanup-wim to work without error (per Sudhagar Thirumoolan @sudhagart)
# Added Image cleanup for Install.wim and WinRe.wim to reduce file size (per David Segura @SeguraOSD)

# Version:
# Date:
# Author:

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

[cmdletbinding(SupportsShouldProcess=$True)]

Param(
    [parameter(mandatory=$false)] 
    [ValidateSet("1709","1803","1809","1903","1909","2003","2009")] 
    [String] $BuildNum = "1709"
    )


# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Functions

#----------------------------
FUNCTION Get-ScriptDirectory
#----------------------------
    { 
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    Split-Path $Invocation.MyCommand.Path
    } 
    #end function Get-ScriptDirectory

#----------------------------
FUNCTION Get-NewestFile
#----------------------------
    {

    Param
        (
        [parameter(Mandatory=$true)]
        [String[]]
        $RootPath
        )

    $Latest = $NULL
    $Latest = Get-ChildItem -Path "$RootPath" -Recurse | Sort-Object CreationTime -Descending | Select-Object -First 1
    Return $Latest
    }
    #end funtion Get-NewestFile



# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# *** Entry Point to Script ***

########################
# Start of Code Block ##
########################
$MyVersion = "1.3"
$MyModule = "UpdateInstallWIM"

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Clear-Host

Write-Host "-----------------------------------------------"
Write-Host "Starting: $MyModule ver. $MyVersion"
Write-Host "-----------------------------------------------"

#Get the location the script is running from
	Write-Host "Getting Script Dir..."
	$scriptFolder = Get-ScriptDirectory
	Write-Host "Script Dir set to: $ScriptFolder"

# Configuring the script to use the Windows ADK 10 version of DISM
    $DISMFile = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe'
    If (!(Test-Path $DISMFile))
        {
        Write-Warning "DISM in Windows ADK not found, aborting..."; Break
        }

# Pull the ISO and update file for the selected build
$ISO =              (Get-NewestFile -RootPath "$scriptFolder\ISOs\$BuildNum").FullName
$ServicingUpdate =  (Get-NewestFile -RootPath "$scriptFolder\Updates\$BuildNum\SSU").FullName
$AdobeFlashUpdate = (Get-NewestFile -RootPath "$scriptFolder\Updates\$BuildNum\AdobeFlash").FullName
$MonthlyCU =        (Get-NewestFile -RootPath "$scriptFolder\Updates\$BuildNum\CU").FullName

# Specify out working folders
$ImageMountFolder     = "$scriptFolder\Mount_Image"
$BootImageMountFolder = "$scriptFolder\Mount_BootImage"
$WIMImageFolder       = "$scriptFolder\WIMs\$BuildNum"
$TmpImage             = "$WIMImageFolder\tmp_install.wim"
$TmpWinREImage        = "$WIMImageFolder\tmp_winre.wim"
$RefImage             = "$WIMImageFolder\install.wim"
$BootImage            = "$WIMImageFolder\boot.wim"

# Verify that everything exists
IF (!(Test-Path -path $ISO))                  {Write-Warning "Could not find Windows 10 ISO file. Aborting...";Break}
IF (!(Test-Path -path $ServicingUpdate))      {Write-Warning "Could not find Servicing Update for Windows 10. Aborting...";Break}
IF (!(Test-Path -path $AdobeFLashUpdate))     {Write-Warning "Could not find Adobe Flash Update for Windows 10. Aborting...";Break}
IF (!(Test-Path -path $MonthlyCU))            {Write-Warning "Could not find Monthly Update for Windows 10. Aborting...";Break}
IF (!(Test-Path -path $ImageMountFolder))     {New-Item -path $ImageMountFolder     -ItemType Directory}
IF (!(Test-Path -path $BootImageMountFolder)) {New-Item -path $BootImageMountFolder -ItemType Directory}
IF (!(Test-Path -path $WIMImageFolder))       {New-Item -path $WIMImageFolder       -ItemType Directory}

# Check Local Windows Version
$OSCaption = (Get-WmiObject win32_operatingsystem).caption
IF ($OSCaption -like "Microsoft Windows 10*" -or $OSCaption -like "Microsoft Windows Server 2016*")
    {
    # All OK
    }
ELSE
    {
    Write-Warning "$Env:Computername Oupps, you really should use Windows 10 or Windows Server 2016 when servicing Windows 10 offline"
    Write-Warning "$Env:Computername Aborting script..."
    Break
    }


# Now, on to the heavy lifting...

# Mount the Windows 10 ISO
    Mount-DiskImage -ImagePath $ISO
    $ISOImage = Get-DiskImage -ImagePath $ISO | Get-Volume
    $ISODrive = [string]$ISOImage.DriveLetter+":"

# Export the Windows 10 Enterprise index to a new (temporary) WIM
    Export-WindowsImage -SourceImagePath "$ISODrive\Sources\install.wim" -SourceName "Windows 10 Enterprise" -DestinationImagePath $TmpImage

# Mount the Windows 10 Enterprise image/index with the Optimize option (reduces initial mount time)
    Mount-WindowsImage -ImagePath $TmpImage -Index 1 -Path $ImageMountFolder -Optimize

# Add the Updates to the Windows 10 Enterprise image
    & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
    & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$AdobeFlashUpdate
    & $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Cleanup the image BEFORE installing .NET to prevent errors
# Using the /ResetBase switch with the /StartComponentCleanup parameter of DISM.exe on a running version of Windows 10 removes all superseded versions of every component in the component store.
# https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/clean-up-the-winsxs-folder#span-iddismexespanspan-iddismexespandismexe
    & $DISMFile /Image:$ImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase 

# Add .NET Framework 3.5.1 to the Windows 10 Enterprise image 
    #& $DISMFile /Image:$ImageMountFolder /Add-Package /PackagePath:$ISODrive\sources\sxs\microsoft-windows-netfx3-ondemand-package.cab
    & $DISMFile /Image:$ImageMountFolder  /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"$ISODrive\sources\sxs"

#Move WinRE Image to temp location
    Move-Item -Path $ImageMountFolder\Windows\System32\Recovery\winre.wim -Destination $TmpWinREImage

# Mount the WinRE Image (which resides inside the mounted Windows 10 image)
    Mount-WindowsImage -ImagePath $TmpWinREImage -Index 1 -Path $BootImageMountFolder

# Add the Updates to the WinRE image (adds about 100 MB in size)
    & $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
    & $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$MonthlyCU
    
#Cleanup wim
    & $DISMFile /Image:$BootImageMountFolder /Cleanup-Image /StartComponentCleanup /ResetBase 

# Dismount the WinRE image
    DisMount-WindowsImage -Path $BootImageMountFolder -Save

# Export new WinRE wim back to original location
    Export-WindowsImage -SourceImagePath $TmpWinREImage -SourceName "Microsoft Windows Recovery Environment (x64)" -DestinationImagePath $ImageMountFolder\Windows\System32\Recovery\winre.wim

# Dismount the Windows 10 Enterprise image
    DisMount-WindowsImage -Path $ImageMountFolder -Save

# Export the Windows 10 Enterprise index to a new WIM (the export operation reduces the WIM size with about 400 - 500 MB)
    Export-WindowsImage -SourceImagePath $TmpImage -SourceName "Windows 10 Enterprise" -DestinationImagePath $RefImage

# Remove the temporary WIM
    IF (Test-Path -path $TmpImage) {Remove-Item -Path $TmpImage -Force}
    IF (Test-Path -path $TmpWinREImage) {Remove-Item -Path $TmpImage -Force}
    

# Mount index 2 of the Windows 10 boot image (boot.wim)
    Copy-Item "$ISODrive\Sources\boot.wim" $WIMImageFolder
    Attrib -r $BootImage
    Mount-WindowsImage -ImagePath $BootImage -Index 2 -Path $BootImageMountFolder

# Add the Updates to the boot image
    & $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$ServicingUpdate
    & $DISMFile /Image:$BootImageMountFolder /Add-Package /PackagePath:$MonthlyCU

# Dismount the boot image
DisMount-WindowsImage -Path $BootImageMountFolder -Save

# Dismount the Windows 10 ISO
Dismount-DiskImage -ImagePath $ISO 

Set-Location $ScriptFolder

Write-Host "-----------------------------------------------"
Write-Host "Finished: $MyModule ver. $MyVersion"
Write-Host "-----------------------------------------------"
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

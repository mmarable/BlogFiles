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

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

########################
# Start of Code Block ##
########################
$MyVersion = "1.0"
$MyModule  = "MapNestedTS"
$SiteCode  = "MM1"

Clear-Host

Write-Host "-----------------------------------------------"
Write-Host "Starting: $MyModule ver. $MyVersion"
Write-Host "-----------------------------------------------"

#If we're running from MM1 temporarly set it to C: to allow external path lookups to function properly
    $ResetLocation = $null
    If (((Get-Location) -split ":")[0] -eq "$SiteCode")
        {
        $ResetLocation = Get-Location
        Set-Location c:\
        }

#Get the location the script is running from
    #Write-Host "Getting Script Dir..."
    $scriptFolder = Get-ScriptDirectory
    #Write-Host "Script Dir set to: $ScriptFolder"

#Load the ConfigMgr module
	Write-Host "Importing ConfigMgr Module..."
	Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
	If (-not (Get-Module -Name "ConfigurationManager"))
		{
		Write-Host "ERROR: Unable to import the ConfigMgr module!" -ForegroundColor Red
		Exit
		}


$SrcTSID = (Read-Host "Enter the Task Sequence ID")

Set-Location $SiteCode`:
$SrcTSobj = (Get-CMTaskSequence -TaskSequencePackageId $SrcTSID)
Clear-Host

Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
Write-Host "Main Task Sequence Info:"
Write-Host "Boot Image ID:      " $SrcTSobj.BootImageID
Write-Host "Description:        " $SrcTSobj.Description
Write-Host "Task Sequence Name: " $SrcTSobj.Name
Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

Write-Host " "

Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
Write-Host "Nested Task Sequences:"

$NestedTSesMain = (Get-CMTaskSequenceStep -TaskSequenceId $SrcTSID -ActionClassName "SMS_TaskSequence_SubTasksequence")

FOREACH ($ChildTS in $NestedTSesMain)
    {
    $ChildTSName = (Get-CMTaskSequence -TaskSequencePackageId $ChildTS.TsPackageID).Name

    Write-Host "    * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *" -ForegroundColor Gray
    Write-Host "    Step Name:          " $ChildTS.Name        -ForegroundColor Gray
    Write-Host "    Task Sequence Name: " $ChildTSName         -ForegroundColor Gray
    Write-Host "    Task Sequence ID:   " $ChildTS.TsPackageID -ForegroundColor Gray

    # Check for nested sequences 2 layers deep
    $NestedTSesLvl2 = (Get-CMTaskSequenceStep -TaskSequenceId $ChildTS.TsPackageID -ActionClassName "SMS_TaskSequence_SubTasksequence")
    FOREACH ($ChildTSL2 in $NestedTSesLvl2)
        {
        $ChildTSName2 = (Get-CMTaskSequence -TaskSequencePackageId $ChildTSL2.TsPackageID).Name

        Write-Host "         * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *" -ForegroundColor Cyan
        Write-Host "         Step Name:          " $ChildTSL2.Name        -ForegroundColor Cyan
        Write-Host "         Task Sequence Name: " $ChildTSName2          -ForegroundColor Cyan
        Write-Host "         Task Sequence ID:   " $ChildTSL2.TsPackageID -ForegroundColor Cyan

            # Check for nested sequences 3 layers deep
            $NestedTSesLvl3 = (Get-CMTaskSequenceStep -TaskSequenceId $ChildTSL2.TsPackageID -ActionClassName "SMS_TaskSequence_SubTasksequence")
            FOREACH ($ChildTSL3 in $NestedTSesLvl3)
                {
                $ChildTSName3 = (Get-CMTaskSequence -TaskSequencePackageId $ChildTSL3.TsPackageID).Name

                Write-Host "              * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *" -ForegroundColor Green
                Write-Host "              Step Name:          " $ChildTSL3.Name        -ForegroundColor Green
                Write-Host "              Task Sequence Name: " $ChildTSName3          -ForegroundColor Green
                Write-Host "              Task Sequence ID:   " $ChildTSL3.TsPackageID -ForegroundColor Green
                }
        }
    }


#Reset our runspace location if we changed it
If ($ResetLocation)
    {
        Set-Location $ResetLocation
    }
else 
    {
        Set-Location $scriptFolder
    }

Write-Host " "
Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
Write-Host "Finished!"
Write-Host "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="

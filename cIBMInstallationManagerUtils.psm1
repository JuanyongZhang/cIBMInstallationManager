##############################################################################################################
########                           IBM Installation Manager CmdLets                                  #########
##############################################################################################################

# Global Variables / Resource Configuration
$IIM_PATH = "HKLM:\Software\IBM\Installation Manager"
$IIM_PATH_64 = "HKLM:\Software\Wow6432Node\IBM\Installation Manager"
$IIM_PATH_USER = "HKCU:\Software\IBM\Installation Manager"
$IIM_PATH_USER_64 = "HKCU:\Software\Wow6432Node\IBM\Installation Manager"

##############################################################################################################
# Get-IBMInstallationManagerRegistryPath
#   Returns the registry path for IBM Installation Manager or $null if there isn't any
##############################################################################################################
Function Get-IBMInstallationManagerRegistryPath() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param()
    
    $iimPath = $null
    if ([IntPtr]::Size -eq 8) {
        $iimPath = $IIM_PATH_64
        if (!(Test-Path($iimPath))) {
            $iimPath = $IIM_PATH_USER_64
            if (!(Test-Path($iimPath))) {
                $iimPath = $IIM_PATH
                if (!(Test-Path($iimPath))) {
                    $iimPath = $IIM_PATH_USER
                    if (!(Test-Path($iimPath))) {
                        $iimPath = $null
                    }
                }
            }
        }
    } else {
        $iimPath = $IIM_PATH
        if (!(Test-Path($iimPath))) {
            $iimPath = $IIM_PATH_USER
            if (!(Test-Path($iimPath))) {
                $iimPath = $null
            }
        }
    }
    
    Write-Debug "Get-IBMInstallationManagerRegistryPath returning path: $iimPath"
    
    Return $iimPath
}

##############################################################################################################
# Get-IBMInstallationManagerHome
#   Returns the location where IBM Installation Manager is installed
##############################################################################################################
Function Get-IBMInstallationManagerHome() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param()
    
    $iimPath = Get-IBMInstallationManagerRegistryPath
    
    if (($iimPath) -and (Test-Path($iimPath))) {
        $iimHome = (Get-ItemProperty($iimPath)).location
        if (Test-Path $iimHome) {
            Write-Verbose "Get-IBMInstallationManagerHome returning $iimHome"
            Return $iimHome
        }
    }
    Return $null
}

##############################################################################################################
# Install-IBMInstallationManager
#   Installs IBM Installation Mananger
##############################################################################################################
Function Install-IBMInstallationManager() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
    	[parameter(Mandatory = $true)]
		[System.String]
    	$iimHome,

    	[parameter(Mandatory = $true)]
		[System.String]
		$iimMedia, 

        [System.Management.Automation.PSCredential]
		$iimMediaCredential
	)

	Write-Verbose "Installing IBM Installation Manager"
    
    $sevenZipExe = Get-SevenZipExecutable
    if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
        Set-Alias zip $sevenZipExe

        #Make temp directory for IIM files
        $iimTempDir = Join-Path $env:TEMP -ChildPath "iim_install"
        Write-Verbose "Creating/Resteting temporary folder: $iimTempDir"
        if (Test-Path -Path $iimTempDir) {
            Remove-Item $iimTempDir -Recurse -Force
        }
        New-Item -ItemType directory -Path $iimTempDir | Out-Null

        $networkShare = $false
        if (($iimMedia.StartsWith("\\")) -and (!(Test-Path($iimMedia)))) {
            Write-Verbose "Network Share detected, need to map"
            Set-NetUse -SharePath $iimMedia -SharePathCredential $iimMediaCredential -Ensure "Present" | Out-Null
            $networkShare = $true
        }

        try {
            if (!(Test-Path($iimMedia))) {
                Write-Error "Unable to access media: $iimMedia"
                Return $null
            }
            
            #Unzip in temp install folder
            Write-Verbose "Extracting installation files to $iimTempDir from $iimMedia"    
            zip x "-o$iimTempDir" $iimMedia | Out-Null
        
            $installLog = Join-Path -Path $iimTempDir -ChildPath "IIM_install_log.txt"

            #Setup IIM Install Process
            $iim_install = New-object System.Diagnostics.ProcessStartInfo
            $iim_install.CreateNoWindow = $true
            $iim_install.UseShellExecute = $false
            $iim_install.RedirectStandardOutput = $true
            $iim_install.RedirectStandardError = $true
            $iim_install.WorkingDirectory = $iimTempDir
            $iim_install.FileName = (Join-Path -Path $iimTempDir -ChildPath "install.exe")
            $iim_install.Arguments = @("--launcher.ini","silent-install.ini","-installationDirectory",$iimHome,"-log",$installLog,"-acceptLicense") 
        
            #Start installation
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $iim_install
            [void]$process.Start()
            $output = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit()

            Write-Debug $output
        
            if((Test-Path($iimHome)) -and (Get-IBMInstallationManagerRegistryPath)) {
                Write-Verbose "IBM Installation Manager installed successfully"
                
                # Clean up / Workaround for AntiVirus issue - hangs while deleting files
                Write-Verbose "Attempting to remove temporary installation files, after 1 minute the job will timeout and you may need to delete $iimTempDir directory manually."
                $rmjob = Start-Job { param($tdir) Remove-Item $tdir -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $iimTempDir
                Wait-Job $rmjob -Timeout 60 | Out-Null
                Stop-Job $rmjob | Out-Null
                Receive-Job $rmjob | Out-Null
                Remove-Job $rmjob | Out-Null
            } else {
                Write-Error "IBM Installation Manager was not installed.  Please check the installation logs"
            }
        } finally {
            if ($networkShare) {
                Set-NetUse -SharePath $iimMedia -SharePathCredential $iimMediaCredential -Ensure "Absent" | Out-Null
            }
        }
    } else {
        Write-Error "IBM Installation Manager installation/update depends on 7-Zip, please ensure 7-Zip is installed first"
    }
}

##############################################################################################################
# Update-IBMInstallationManager
#   Updates IBM Installation Mananger to a newer version
##############################################################################################################
Function Update-IBMInstallationManager() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
    	[parameter(Mandatory = $true)]
		[System.String]
    	$iimHome,

    	[parameter(Mandatory = $true)]
		[System.String]
		$iimMedia,
        
        [parameter(Mandatory = $true)]
        [System.String]
		$Version,

        [System.Management.Automation.PSCredential]
		$iimMediaCredential
	)

	Write-Verbose "Updating IBM Installation Manager"
    
    $sevenZipExe = Get-SevenZipExecutable
    if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
        Set-Alias zip $sevenZipExe
        
        #Make temp directory for IIM files
        $iimTempDir = Join-Path $env:TEMP -ChildPath "iim_update"
        Write-Verbose "Creating/Resteting temporary folder: $iimTempDir"
        if (Test-Path -Path $iimTempDir) {
            Remove-Item $iimTempDir -Recurse -Force
        }
        New-Item -ItemType directory -Path $iimTempDir | Out-Null
        
        $networkShare = $false
        try {
            if (($iimMedia.StartsWith("\\")) -and (!(Test-Path($iimMedia)))) {
                Write-Verbose "Network Share detected, need to map"
                Set-NetUse -SharePath (Split-Path($iimMedia)) -SharePathCredential $iimMediaCredential -Ensure "Present" | Out-Null
                $networkShare = $true
            }
        } catch [System.UnauthorizedAccessException] {
            Write-Verbose "Network Share detected, need to map"
            Set-NetUse -SharePath (Split-Path($iimMedia)) -SharePathCredential $iimMediaCredential -Ensure "Present" | Out-Null
            $networkShare = $true
        }

        try {
            if (!(Test-Path($iimMedia))) {
                Write-Error "Unable to access media: $iimMedia"
                Return $null
            }
            
            #Unzip in temp install folder
            Write-Verbose "Extracting installation files to $iimTempDir from $iimMedia"
            zip x "-o$iimTempDir" $iimMedia | Out-Null
        
            $updateLog = Join-Path -Path (Split-Path($iimTempDir)) -ChildPath "IIM_update_log.txt"
            $repoFile = Join-Path -Path $iimTempDir -ChildPath "repository.config"
            
            $iimupdate_args = @("install", "com.ibm.cic.agent", 
                                "-repositories", ($repoFile),
                                "-preferences", "offering.service.repositories.areUsed=false", "-log", $updateLog, "-acceptLicense")

            # Update IIM
            $iimToolsDir = Join-Path -Path $iimTempDir -ChildPath "tools" 
            $iimCLExe = Join-Path -Path $iimToolsDir -ChildPath "imcl.exe"
            
            #Setup IIM Update Process
            $iim_update = New-object System.Diagnostics.ProcessStartInfo
            $iim_update.CreateNoWindow = $true
            $iim_update.UseShellExecute = $false
            $iim_update.RedirectStandardOutput = $true
            $iim_update.RedirectStandardError = $true
            $iim_update.WorkingDirectory = $iimToolsDir
            $iim_update.FileName = $iimCLExe
            $iim_update.Arguments = $iimupdate_args 
        
            #Start installation
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $iim_update
            [void]$process.Start()
            $output = $process.StandardOutput.ReadToEnd()
            $process.WaitForExit()
            
            Write-Debug $output
            
            $updatedVersion = (Get-ItemProperty(Get-IBMInstallationManagerRegistryPath)).version
        
            if($Version -eq $updatedVersion) {
                Write-Verbose "IBM Installation Manager updated successfully"
                
                # Clean up / Workaround for AntiVirus issue - hangs while deleting files
                Write-Verbose "Attempting to remove temporary installation files, after 1 minute the job will timeout and you may need to delete $iimTempDir directory manually."
                $rmjob = Start-Job { param($tdir) Remove-Item $tdir -Recurse -Force -ErrorAction SilentlyContinue } -ArgumentList $iimTempDir
                Wait-Job $rmjob -Timeout 60 | Out-Null
                Stop-Job $rmjob | Out-Null
                Receive-Job $rmjob | Out-Null
                Remove-Job $rmjob | Out-Null
            } else {
                Write-Error "IBM Installation Manager was not updated.  Please check the update logs"
            }
        } finally {
            if ($networkShare) {
                Set-NetUse -SharePath (Split-Path($iimMedia)) -SharePathCredential $iimMediaCredential -Ensure "Absent" | Out-Null
            }
        }
    } else {
        Write-Error "IBM Installation Manager installation/update depends on 7-Zip, please ensure 7-Zip is installed first"
    }
}

##############################################################################################################
# Set-IBMInstallationManagerTempDir
#   Updates the temporary directory that IBM Installation Manager
##############################################################################################################
Function Set-IBMInstallationManagerTempDir() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [parameter(Mandatory=$true,position=0)]
        [string]
        $tempDir
    )
    if (Test-Path($tempDir)) {
        $iimHome = Get-IBMInstallationManagerHome
        $iimIniPath = Join-Path -Path $iimHome -ChildPath "eclipse\IBMIM.ini"
        if (Test-Path $iimIniPath) {
            [string] $updatedIniFile = ""
            [bool] $afterVMArgs = $false
            [bool] $hasTempDir = $false
            $iniFile = gc $iimIniPath
            
            foreach($line in $iniFile) {
                if ($afterVMArgs) {
                    if ($line.Contains("java.io.tmpdir")) {
                        # Replace Temp Dir setting
                        $line = "-Djava.io.tmpdir=$tempDir"
                    } else {
                        # Append temp dir setting
                        $updatedIniFile += "-Djava.io.tmpdir=$tempDir`n"
                    }
                    $afterVMArgs = $false
                }
                if ($line.StartsWith("-vmargs")) {
                    $afterVMArgs = $true
                }
                if ([string]::IsNullOrEmpty($line)) {
                    $updatedIniFile += "$line"
                } else {
                    $updatedIniFile += "$line`n"
                }
            }
            $updatedIniFile | out-file "$iimIniPath" -encoding "ASCII"
        } else {
            Write-Error "$iimIniPath could not be located"
        }
    } else {
        Write-Error "The temp directory specified: $tempDir is invalid"
    }
}

##############################################################################################################
# ConvertTo-HashedPassword
#   Generates a hashed password from password specified using the IBM Installation Manager Command Line
##############################################################################################################
Function ConvertTo-HashedPassword() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param (
        [Parameter(Mandatory=$True, Position=0)]
        [System.Management.Automation.PSCredential]
        $UserCredential
    )

    Write-Verbose "ConvertTo-HashedPassword called"

    if (Test-Path($IIM_PATH)) {
        $iimHome = (Get-ItemProperty($IIM_PATH)).location
        $iimcPath = Join-Path -Path $iimHome -ChildPath "eclipse\IBMIMc.exe"
        if (Test-Path($iimcPath)) {
            $plainpwd = $UserCredential.GetNetworkCredential().Password
            $iimExpression = '& ' + $iimcPath + ' -noSplash -silent encryptstring ' + $plainpwd
            $hashedPwd = Invoke-Expression $iimExpression
            Write-Verbose "ConvertTo-HashedPassword returning hashed password"
            Return $hashedPwd
        }
    }

    Write-Verbose "ConvertTo-HashedPassword did not return anything"
}

##############################################################################################################
# Get-SevenZipExecutable
#   Gets the path to the 7-zip executable if present, otherwise returns null
##############################################################################################################
Function Get-SevenZipExecutable {
    [CmdletBinding(SupportsShouldProcess=$False)]
    Param()
    
	$sevenZipExe = $null
	if (Test-Path("HKLM:\Software\7-Zip")) {
		$sevenZipExe = (Get-ItemProperty -Path "HKLM:\SOFTWARE\7-Zip").Path + "7z.exe"
	} else {
		if (Test-Path("HKCU:\Software\7-Zip")) {
			$sevenZipExe = (Get-ItemProperty -Path "HKCU:\SOFTWARE\7-Zip").Path + "7z.exe"
		}
	}
	return $sevenZipExe
}

##############################################################################################################
# Set-NetUse
#   Mounts or Unmounts a file share via "net use" using the specified credentials 
##############################################################################################################
Function Set-NetUse {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (   
        [parameter(Mandatory = $true)]
        [string] $SharePath,
        
        [parameter(Mandatory = $false)]
        [PSCredential] $SharePathCredential,
        
        [string] $Ensure = "Present",
        
        [switch] $MapToDrive
    )
    
    [string] $randomDrive = $null

    Write-Verbose -Message "NetUse set share $SharePath ..."

    if ($Ensure -eq "Absent") {
        $cmd = 'net use "' + $SharePath + '" /DELETE'
    } else {
        $credCmdOption = ""
        if ($SharePathCredential) {
            $cred = $SharePathCredential.GetNetworkCredential()
            $pwd = $cred.Password
            $user = $cred.UserName
            if ($cred.Domain) {
                $user = $cred.Domain + "\" + $cred.UserName
            }
            $credCmdOption = " $pwd /user:$user"
        }
        
        if ($MapToDrive) {
            $randomDrive = Get-AvailableDrive
            $cmd = 'net use ' + $randomDrive + ' "' + $SharePath + '"' + $credCmdOption
        } else {
            $cmd = 'net use "' + $SharePath + '"' + $credCmdOption
        }
    }

    Invoke-Expression $cmd | Out-Null
    
    Return $randomDrive
}

##############################################################################################################
# Expand-IBMInstallationMedia
#   Utility cmdlet for expanding IBM media files. Supports files in local drive as well as network share.
#   Depends on 7-Zip being installed
##############################################################################################################
Function Expand-IBMInstallationMedia() {
    [CmdletBinding(SupportsShouldProcess=$False)]
    param (
        [parameter(Mandatory = $true)]
        [string[]]
        $MediaPath,
        
        [parameter(Mandatory = $true)]
        [string]
        $TargetPath,
        
        [switch]
        $Cleanup,
        
        [switch]
        $ExpandChildren,
        
        [string]
        $ExpandChildrenPattern = $null,

        [System.Management.Automation.PSCredential]
        $MediaCredential
    )
    
    $RetExpendedDir = $null
    
    if (!(Test-Path alias:zip)) {
        #Setup 7-Zip Alias
        $sevenZipExe = Get-SevenZipExecutable
        if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
            Set-Alias zip $sevenZipExe
        } else {
            Write-Error "Expand-IBMInstallationMedia depends on 7-Zip, please ensure 7-Zip is installed first"
            Return
        }
    }
    
    if (($Cleanup) -and (!([string]::IsNullOrEmpty($TargetPath))) -and (Test-Path($TargetPath))) {
        Write-Verbose "Cleaning up existing target path for installation media: $TargetPath"
        Remove-Item $TargetPath -Recurse -Force
    }
    
    New-Item -ItemType directory -Path $TargetPath | Out-Null

    #Make sure media is available, map to random drive if network drive
    $networkShare = $false
    try {
        if (($MediaPath.StartsWith("\\")) -and (!(Test-Path($MediaPath)))) {
            Write-Verbose "Network Share detected, need to map"
            Set-NetUse -SharePath (Split-Path($MediaPath)) -SharePathCredential $MediaCredential -Ensure "Present" | Out-Null
            $networkShare = $true
        }
    } catch [System.UnauthorizedAccessException] {
        Write-Verbose "Network Share detected, need to map"
        Set-NetUse -SharePath (Split-Path($MediaPath)) -SharePathCredential $MediaCredential -Ensure "Present" | Out-Null
        $networkShare = $true
    }

    try {
        if (Test-Path($MediaPath)) {
            Write-Verbose "Extracting installation media from: $MediaPath"
    
            zip x "-o$TargetPath" $MediaPath | Out-Null
            
            $RetExpendedDir = $TargetPath
            
            if ($ExpandChildren) {
                $childItemPattern = "*.zip"
                if ($ExpandChildrenPattern) {
                    $childItemPattern = $ExpandChildrenPattern
                }
                
                Get-ChildItem $childItemPattern -Path $TargetPath | % {
                    $childPath = Join-Path -Path $TargetPath -ChildPath ($_.BaseName)
                    zip x "-o$childPath" $_.FullName | Out-Null
                    Remove-Item $_.FullName -force
                    $RetExpendedDir = $childPath
                }
            }
            Write-Verbose "Completed extracting media files to directory: $TargetPath"
        } else {
            Write-Error "Unable to access media files.  Media Path is: $MediaPath"
        }
    } finally {
        if ($networkShare) {
            Set-NetUse -SharePath (Split-Path($MediaPath)) -SharePathCredential $MediaCredential -Ensure "Absent" | Out-Null
        }
    }

    Return $RetExpendedDir
}
# Import IBM Installation Manager Utils Module
Import-Module $PSScriptRoot\cIBMInstallationManagerUtils.psm1 -ErrorAction Stop

enum Ensure {
    Absent
    Present
}

<#
   DSC resource to manage the installation of IBM Installation Manager.
   Key features: 
    - Install IBM Installation Manager for the first time
    - Update an existing installation
    - Can use media on the local drive as well as from a network share which may require specifying credentials
#>

[DscResource()]
class cIBMInstallationManager {
    [DscProperty(Key)]
    [String] $Version

    [DscProperty(Mandatory)]
    [Ensure] $Ensure
    
    [DscProperty()]
    [String] $InstallationDirectory = "C:\IBM\InstallationManager"

    [DscProperty()]
    [String] $SourcePath
    
    [DscProperty()]
    [System.Management.Automation.PSCredential] $SourcePathCredential

    <#
        Performs the installation or udpate of IBM Installation Manager.  It will only update an existing
        installation if the desired version is newer
    #>
    [void] Set () {
        try {
            if ($this.Ensure -eq [Ensure]::Present) {
                Write-Verbose -Message 'Starting installation of IBM Installation Manager'
                $sevenZipExe = Get-SevenZipExecutable
                if (!([string]::IsNullOrEmpty($sevenZipExe)) -and (Test-Path($sevenZipExe))) {
                    #7-Zip is installed, proceed with installation
                    Set-Alias zip $sevenZipExe
                    $iimRsrc = $this.Get()
                    if ($iimRsrc.Version) {
                        # There's an IBM Installation Manager installed, we may need to update it
                        [System.Version] $currentVersion = New-Object -TypeName System.Version -ArgumentList $iimRsrc.Version
                        [System.Version] $newVersion = New-Object -TypeName System.Version -ArgumentList $this.Version
                        if ($newVersion.CompareTo($currentVersion) -gt 0) {
                            Update-IBMInstallationManager -iimHome $this.InstallationDirectory -iimMedia $this.SourcePath -Version $this.Version -iimMediaCredential $this.SourcePathCredential
                        } else {
                            Write-Error "IBM Installation Manager already installed and its version ($currentVersion) is greater than the version specified ($newVersion)"
                        }
                    } else {
                        Install-IBMInstallationManager -iimHome $this.InstallationDirectory -iimMedia $this.SourcePath -iimMediaCredential $this.SourcePathCredential
                    }
                } else {
                    Write-Error "IBM Installation Manager installation/update depends on 7-Zip, please ensure 7-Zip is installed first"
                }
            } else {
                Write-Verbose "Uninstalling IBM Installation Manager (Not Yet Implemented)"
            }
        } catch {
            Write-Error -ErrorRecord $_ -ErrorAction Stop
        }
    }

    <#
        Performs test to check if IBM Installation Manager is in the desired state, includes 
        validation of installation directory and version
    #>
    [bool] Test () {
        Write-Verbose "Checking for IBM Installation Manager installation"
        $iimConfiguredCorrectly = $false
        $iimRsrc = $this.Get()
        
        if (($iimRsrc.Ensure -eq $this.Ensure) -and ($iimRsrc.Ensure -eq [Ensure]::Present)) {
            if ($iimRsrc.Version -eq $this.Version) {
                if (((Get-Item($iimRsrc.InstallationDirectory)).Name -eq 
                    (Get-Item($this.InstallationDirectory)).Name) -and (
                    (Get-Item($iimRsrc.InstallationDirectory)).Parent.FullName -eq 
                    (Get-Item($this.InstallationDirectory)).Parent.FullName)) {
                    Write-Verbose "IBM Installation Manager is installed and configured correctly"
                    $iimConfiguredCorrectly = $true
                }
            }
        } elseif (($iimRsrc.Ensure -eq $this.Ensure) -and ($iimRsrc.Ensure -eq [Ensure]::Absent)) {
            $iimConfiguredCorrectly = $true
        }

        if (!($iimConfiguredCorrectly)) {
            Write-Verbose "IBM Installation Manager not configured correctly"
        }
        
        return $iimConfiguredCorrectly
    }

    <#
        Leverages the information stored in the registry to populate the properties of an existing
        installation of IBM Installation Manager
    #>
    [cIBMInstallationManager] Get () {
        $RetEnsure = [Ensure]::Absent
        $RetInsDir = $null
        $RetVersion = $null
        
        $iimRegistryPath = Get-IBMInstallationManagerRegistryPath

        if((Test-Path($this.InstallationDirectory)) -and ($iimRegistryPath) -and (Test-Path($iimRegistryPath))) {
            $iimSWTagFile = Join-Path -Path $this.InstallationDirectory -ChildPath "properties\version\*.swtag"
            if(Test-Path($iimSWTagFile)) {
                Write-Verbose "IBM Installation Manager is Present"
                $RetEnsure = [Ensure]::Present
                $RetInsDir = (Get-ItemProperty($iimRegistryPath)).location
                Write-Verbose "IBM Installation Manager Directory: $RetInsDir"
                $RetVersion = (Get-ItemProperty($iimRegistryPath)).version
                Write-Verbose "IBM Installation Manager Version: $RetVersion"
            }
        } else {
            Write-Verbose "IBM Installation Manager is NOT Present"
        }

        $returnValue = @{
            InstallationDirectory = $RetInsDir
            Version = $RetVersion
            Ensure = $RetEnsure
        }

        return $returnValue
    }
}
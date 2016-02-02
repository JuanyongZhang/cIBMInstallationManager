#cIBMInstallationManager

PowerShell CmdLets and Class-Based DSC resources to manage IBM Installation Manager on Windows Environments.

## Resources

* **cIBMInstallationManager** installs IBM Installation Manager on target machine.

### cIBMInstallationManager

* **Ensure**: (Required) Ensures that IBM Installation Manager is Present or Absent on the machine.
* **Version**: (Key) The version of IBM Installation Manager to install/update.
* **InstallationDirectory**: Installation path.  Default: C:\IBM\InstallationManager.
* **SourcePath**: UNC or local file path to the zip file needed for the installation.
* **SourcePathCredential**: Credential to be used to map sourcepath if a remote share is being specified.

## Depedencies
[7-Zip](http://www.7-zip.org/ "7-Zip") needs to be installed on the target machine.  You can add 7-Zip to your DSC configuration by using the Package
DSC Resource or by leveraging the [x7Zip DSC Module](https://www.powershellgallery.com/packages/x7Zip/ "x7Zip at PowerShell Gallery")

## Versions

### 1.0.0

* Initial release with the following resources 
    - cIBMInstallationManager

## Examples

### Install IBM Installation Manager

This configuration will install [7-Zip](http://www.7-zip.org/ "7-Zip") using the DSC Package Resource and install
IBM Installation Manager version 1.8.3 onto the C:\IBM\IIM directory

Note: This requires the following DSC modules:
* xPsDesiredStateConfiguration

```powershell
Configuration IIM
{
    Import-DSCResource -module cIBMInstallationManager
    Package SevenZip {
        Ensure = 'Present'
        Name = '7-Zip 9.20 (x64 edition)'
        ProductId = '23170F69-40C1-2702-0920-000001000000'
        Path = 'C:\Media\7z920-x64.msi'
    }
    cIBMInstallationManager iimInstall
    {
        Ensure = 'Present'
        InstallationDirectory = 'C:\IBM\IIM'
        Version = '1.8.3'
        SourcePath = 'C:\Media\agent.installer.win32.win32.x86_1.8.3000.20150606_0047.zip'
        DependsOn= "[Package]SevenZip"
    }
}
IIM
Start-DscConfiguration -Wait -Force -Verbose IIM
```
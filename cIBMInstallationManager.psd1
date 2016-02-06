#
# Module manifest for module 'cIBMInstallationManager'
#
# Generated by: Denny Pichardo
# Generated on: 1/31/2016

@{
# Script module or binary module file associated with this manifest.
RootModule = 'cIBMInstallationManager.psm1'

# Version number of this module.
ModuleVersion = '1.0.1'

# ID used to uniquely identify this module
GUID = 'fc4c2ed1-00c4-4fee-93c8-13447d062921'

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @('Classes\IBMProductMedia.ps1')

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('cIBMInstallationManagerUtils')

# DSC resources to export from this module
DscResourcesToExport = 'cIBMInstallationManager'

# Author of this module
Author = 'Denny Pichardo'

# Company or vendor of this module
CompanyName = 'Unknown'

# Copyright statement for this module
Copyright = '(c) 2016 Denny Pichardo. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Installs IBM Installation Manager and provides CmdLets for management of products installed via IBM Installation Manager'

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = 'None'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
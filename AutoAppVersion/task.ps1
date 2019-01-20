Trace-VstsEnteringInvocation $MyInvocation

function ConvertTo-Boolean {
    param
    (
        [Parameter(Mandatory = $false)][string] $value
    )
    switch ($value) {
        "True" { return $true; }
        "true" { return $true; }
        1 { return $true; }
        "false" { return $false; }
        "False" { return $false; } 
        0 { return $false; }
    }
}

$DevOpsPAT = Get-VstsInput -Name DevOpsPAT -Require
$VersionVariable = Get-VstsInput -Name VersionVariable -Require
$ProjectFile = Get-VstsInput -Name ProjectFile -Require

$SetAssemblyVersionString = Get-VstsInput -Name SetAssemblyVersion  -Require
$SetAssemblyVersion = ConvertTo-Boolean($SetAssemblyVersionString)

$SetFileVersionString = Get-VstsInput -Name SetFileVersion  -Require
$SetFileVersion = ConvertTo-Boolean($SetFileVersionString)

$StopOnNoMaskString = Get-VstsInput -Name StopOnNoMask  -Require
$StopOnNoMask = ConvertTo-Boolean ($StopOnNoMaskString)

$StopOnDowngradeString = Get-VstsInput -Name StopOnDowngrade  -Require
$StopOnDowngrade = ConvertTo-Boolean($StopOnDowngradeString)

$devOpsUri = $env:SYSTEM_TEAMFOUNDATIONSERVERURI
$projectName = $env:SYSTEM_TEAMPROJECT
$projectId = $env:SYSTEM_TEAMPROJECTID 
$buildId = $env:BUILD_BUILDID

Write-Output "ProjectFile          : $($ProjectFile)";
Write-Output "VersionVariable      : $($VersionVariable)";
Write-Output "DevOpsPAT            : $(if (![System.String]::IsNullOrWhiteSpace($DevOpsPAT)) { '***'; } else { '<not present>'; })"; ;
Write-Output "DevOps Uri           : $($devOpsUri)";
Write-Output "Project Name         : $($projectName)";
Write-Output "Project Id           : $($projectId)";
Write-Output "BuildId              : $($buildId)";

Write-Host "=============================================================================="

# ========================= Get Mask From Project File

Write-Host "Reading project file: $($ProjectFile)."

$csp = [xml](Get-Content $ProjectFile)

$numberOfPropertyGroups = $csp.CreateNavigator().Evaluate('count(//PropertyGroup)')

if ($numberOfPropertyGroups -eq 1) {
    $propertyGroup = $csp.Project.PropertyGroup
}
else {
    $propertyGroup = $csp.Project.PropertyGroup[0]
}

if (-not $propertyGroup.Version) {
    Write-Error "<Version> element not found in the first instance of <PropertyGroup>. Check your csproj file."
    exit 0
}

$versionMask = $propertyGroup.Version 
$fileVersion = $propertyGroup.FileVersion
$assemblyVersion = $propertyGroup.AssemblyVersion

# ========================= Validate Mask Value

$maskItems = $versionMask.split('.')

if ($maskItems.Count -gt 3 -or $maskItems.Count -lt 3) {
    Write-Error "Your version number mask needs to be in the following format 'X.X.X' where X is an integer or the $ symbol. Expected 'X.X.X' but got '$($versionMask)'"
    exit 0
}

if ($maskItems[2] -like '*-*') {
    Write-Error "Unsupported Mask Value: AutoAppVersion currently doesn't support pre-release suffix. Expected 'X.X.X' but got '$($versionMask)'. Check your csproj file."
    exit 0
}

$maskMajorVersionVar = $maskItems[0]
$maskMinorVersionVar = $maskItems[1]
$maskPatchVersionVar = $maskItems[2]

if (-not ($maskMajorVersionVar -eq "$" -or $maskMinorVersionVar -eq "$" -or $maskPatchVersionVar -eq "$")) {    
    if ($StopOnNoMask) {
        Write-Error "Your project file's version has been found '$($versionMask)' but the version value doesn't contain any masked elements. e.g. '$($maskMajorVersionVar).$($maskMinorVersionVar).$'. See task option 'Stop On No Mask'."
        exit 0;
    }
    else {
        Write-Warning "Your project file's version has been found '$($versionMask)' but the version value doesn't contain any masked elements. e.g. '$($maskMajorVersionVar).$($maskMinorVersionVar).$'"
    }
}
else {
    Write-Host "Valid Version Mask Found: '$($versionMask)'"
}

# ========================= Get Build And VersionVariable From DevOps via APi

$buildUri = "$($devOpsUri)$($projectName)/_apis/build/builds/$($buildId)?api-version=4.1"

$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $DevOpsPAT)))
$devOpsHeader = @{Authorization = ("Basic {0}" -f $base64AuthInfo)}

Write-Host "Trying to retrieve build with the url: $($buildUri)."

$buildDef = Invoke-RestMethod -Uri $buildUri -Method Get -ContentType "application/json" -Headers $devOpsHeader

if (-not ($buildDef -and $buildDef.definition)) {
    Write-Error "Unexpected response from Azure DevOps Api. Please check your parameters including your PAT."
    exit 0
}

$definitionId = $buildDef.definition.id
$defUri = "$($devOpsUri)$($projectName)/_apis/build/definitions/$($definitionId)?api-version=4.1"

Write-Host "Trying to retrieve the build definition with the url: $($defUri)."
$definition = Invoke-RestMethod -Method Get -Uri $defUri -Headers $devOpsHeader -ContentType "application/json"

$currentVersion = $definition.variables.$VersionVariable.Value

if (!$currentVersion) {
    Write-Warning "Initial value of VersionVariable '$($VersionVariable)' is empty. '0.0.0' will be used."
    $currentVersion = "0.0.0"
}
else {
    Write-Host "VersionVariable '$($VersionVariable)' current value: $($currentVersion)."
}

# ========================= Validate Current Version

$currentVersionItems = $currentVersion.split('.')
   
if ($currentVersionItems.Count -gt 3 -or $currentVersionItems.Count -lt 3) {
    Write-Error "Your VersionVariable value needs to be in the following format 'X.X.X' where X is an integer or the $ symbol. Expected 'X.X.X' but got '$($currentVersion)'"
    exit 0
}

if ($currentVersionItems[2] -like '*-*') {
    Write-Error "Unsported VersionVariable Value: AutoAppVersion currently doesn't support pre-release suffix. Expected 'X.X.X' but got '$($currentVersion)'"
    exit 0
}

$currentMajorVersionVar = $currentVersionItems[0]
$currentMinorVersionVar = $currentVersionItems[1]
$currentPatchVersionVar = $currentVersionItems[2]

if (-not [string]($currentMajorVersionVar -as [int])) {
    Write-Error "Unexpected current Major version. Expected integer but got '$($currentMajorVersionVar)'"
    exit 0
}

if (-not [string]($currentMinorVersionVar -as [int])) {
    Write-Error "Unexpected current Minor version. Expected integer but got '$($currentMinorVersionVar)'"
    exit 0
}

if (-not [string]($currentPatchVersionVar -as [int])) {
    Write-Error "Unexpected current Patch version. Expected integer but got '$($currentPatchVersionVar)'"
    exit 0
}

$currentMajorVersion = [convert]::ToInt32($currentMajorVersionVar, 10)
$currentMinorVersion = [convert]::ToInt32($currentMinorVersionVar, 10)
$currentPatchVersion = [convert]::ToInt32($currentPatchVersionVar, 10)

# ========================= Mutate

$nextMajorVersion = 0
$nextMinorVersion = 0
$nextPatchVersion = 0

$resetPatch = $false
$resetMinor = $false
    
if ($maskMajorVersionVar -eq "$") {
    $nextMajorVersion = $currentMajorVersion + 1
    $resetPatch = $true
    $resetMinor = $true
}
else {
    if (-not [string]($maskMajorVersionVar -as [int])) {
        Write-Error "Unexpected Mask Major version. Expected integer but got '$($maskMajorVersionVar)'"
        exit 0
    }

    $nextMajorVersion = [convert]::ToInt32($maskMajorVersionVar, 10)
    
    if ($nextMajorVersion -gt $currentMajorVersion) {
        Write-Host "Observed Major version increase. Any lower priority masked values will be set back to 0"
        $resetPatch = $true
        $resetMinor = $true
    }

    if ($nextMajorVersion -lt $currentMajorVersion) {
        if ($StopOnDowngrade) {
            Write-Error "Observed Major version has decreased. This indicates your project file has been updated with a value '$($nextMajorVersion)' lower than the current value '$($currentMajorVersion)'. See task option 'Stop On Downgrade'."
            exit 0
        }
        else {
            Write-Warning "Observed Major version has decreased. This indicates your project file has been updated with a value '$($nextMajorVersion)' lower than the current value '$($currentMajorVersion)'."
        }
    }
}
    
if ($maskMinorVersionVar -eq "$") {
    if ($resetMinor) {
        $nextMinorVersion = 0
    }
    else {
        $nextMinorVersion = $currentMinorVersion + 1
    }
    $resetPatch = $true
}
else {
    if (-not [string]($maskMinorVersionVar -as [int])) {
        Write-Error "Unexpected Mask Minor version. Expected integer but got '$($maskMinorVersionVar)'"
        exit 0
    }

    $nextMinorVersion = [convert]::ToInt32($maskMinorVersionVar, 10)
    
    if ($nextMinorVersion -gt $currentMinorVersion) {
        Write-Host "Observed Minor version number increase. Any lower priority masked values will be set back to 0"
        $resetPatch = $true
    }

    if ($nextMinorVersion -lt $currentMinorVersion -and (-not $resetMinor)) {
        if ($StopOnDowngrade) {
            Write-Error "Observed Minor version has decreased. This indicates your project file has been updated with a value '$($nextMinorVersion)' lower than the current value '$($currentMinorVersion)'. See task option 'Stop On Downgrade'."
            exit 0
        }
        else {
            Write-Warning "Observed Minor version has decreased. This indicates your project file has been updated with a value '$($nextMinorVersion)' lower than the current value '$($currentMinorVersion)'."
        }
    }
}
    
if ($maskPatchVersionVar -eq "$") {
    if ($resetPatch) {
        $nextPatchVersion = 0
    }
    else {
        $nextPatchVersion = $currentPatchVersion + 1
    }
}
else {
    if (-not [string]($maskPatchVersionVar -as [int])) {
        Write-Error "Unexpected Mask Patch version. Expected integer but got '$($maskPatchVersionVar)'"
        exit 0
    }

    $nextPatchVersion = [convert]::ToInt32($maskPatchVersionVar, 10)

    if ($nextPatchVersion -lt $currentPatchVersion -and (-not $resetPatch)) {
        if ($StopOnDowngrade) {
            Write-Error "Observed Patch version has decreased. This indicates your project file has been updated with a value '$($nextPatchVersion)' lower than the current value '$($currentPatchVersion)'. See task option 'Stop On Downgrade'."    
            exit 0
        }
        else {
            Write-Warning "Observed Patch version has decreased. This indicates your project file has been updated with a value '$($nextPatchVersion)' lower than the current value '$($currentPatchVersion)'."    
        }
    }
}

Write-Host "=============================================================================="

$versionPattern = "$($maskMajorVersionVar).$($maskMinorVersionVar).$($maskPatchVersionVar)"

Write-Host "> Version Pattern: $($versionPattern)" -ForegroundColor Cyan
Write-Host "-> Current App version: $($currentMajorVersion).$($currentMinorVersion).$($currentPatchVersion)" -ForegroundColor Yellow
Write-Host "--> New App Version: $($nextMajorVersion).$($nextMinorVersion).$($nextPatchVersion)" -ForegroundColor Green

$newVersion = "$($nextMajorVersion).$($nextMinorVersion).$($nextPatchVersion)"

Write-Host "=============================================================================="

# ========================= Save Via Api

$definition.variables.$VersionVariable.Value = $newVersion

$definitionJson = $definition | ConvertTo-Json -Depth 50 -Compress

Write-Host "Trying to update VersionVariable '$($VersionVariable)' with the url: $($defUri)."

Invoke-RestMethod -Method Put -Uri $defUri -Headers $devOpsHeader -ContentType "application/json" -Body $definitionJson | Out-Null

Write-Host "VersionVariable '$($VersionVariable)' updated."

# ========================= Save Locally

Write-Host "Updating Project file '$($ProjectFile)'. Replacing '$($versionPattern)' with '$($newVersion)'"

$propertyGroup.Version = $newVersion

if ($null -ne $fileVersion -and $SetFileVersion) {
    $fileVersion = "$($newVersion).0"
    Write-Host "Setting project FileVersion to '$($fileVersion)'"
    $propertyGroup.FileVersion = $fileVersion
}

if ($null -ne $assemblyVersion -and $SetAssemblyVersion) {
    $assemblyVersion = "$($newVersion).0"
    Write-Host "Setting project AssemblyVersion to '$($assemblyVersion)'"
    $propertyGroup.AssemblyVersion = $assemblyVersion
}

$csp.Save($ProjectFile) 

Write-Host "Project file updated."
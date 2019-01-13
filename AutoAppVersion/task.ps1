Trace-VstsEnteringInvocation $MyInvocation

$DevOpsPAT = Get-VstsInput -Name DevOpsPAT -Require
$VersionVariable = Get-VstsInput -Name VersionVariable -Require
$ProjectFile = Get-VstsInput -Name ProjectFile -Require

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

$buildUri = "$($devOpsUri)$($projectName)/_apis/build/builds/$($buildId)?api-version=4.1"

# enconding PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $DevOpsPAT)))
$devOpsHeader = @{Authorization = ("Basic {0}" -f $base64AuthInfo)}

$buildDef = Invoke-RestMethod -Uri $buildUri -Method Get -ContentType "application/json" -Headers $devOpsHeader

if ($buildDef) {


    $definitionId = $buildDef.definition.id
    $defUri = "$($devOpsUri)$($projectName)/_apis/build/definitions/$($definitionId)?api-version=4.1"

    Write-Host "Trying to retrieve the build definition with the url: $($defUri)."
    $definition = Invoke-RestMethod -Method Get -Uri $defUri -Headers $devOpsHeader -ContentType "application/json"

    $myValue = $definition.variables.$VersionVariable.Value

    # ==========================================================

    if (!$myValue ) {
        $myValue  = "0.0.0"
    }

    Write-Host "VersionVariable '$($VersionVariable)' current value: $($myValue)."

    $last = $myValue
        
    $csprojFile = $ProjectFile
    
    Write-Host "Reading project file: $($csprojFile)."

    $csp = [xml](Get-Content $csprojFile)
    
    $numberOfPropertyGroups = $csp.CreateNavigator().Evaluate('count(//PropertyGroup)')
    
    if ($numberOfPropertyGroups -eq 1) {
        $propertyGroup = $csp.Project.PropertyGroup
    }
    else {
        Write-Host "Multiple PropertyGroup elements found. Targeting first instance."
        $propertyGroup = $csp.Project.PropertyGroup[0]
    }
    
    $version = $propertyGroup.Version 
    
    $lastItems = $last.split('.')
    
    $lastMajorVersionVar = $lastItems[0]
    $lastMinorVersionVar = $lastItems[1]
    $lastPatchVersionVar = $lastItems[2]
    
    $lastMajorVersion = [convert]::ToInt32($lastMajorVersionVar, 10)
    $lastMinorVersion = [convert]::ToInt32($lastMinorVersionVar, 10)
    $lastPatchVersion = [convert]::ToInt32($lastPatchVersionVar, 10)
    
    $items = $version.split('.')
    
    $majorVersionVar = $items[0]
    $minorVersionVar = $items[1]
    $patchVersionVar = $items[2]
    
    $nextMajorVersion = 0
    $nextMinorVersion = 0
    $nextPatchVersion = 0
    
    $resetPatch = $false
    $resetMinor = $false
    
    if ($majorVersionVar -eq "$") {
        $nextMajorVersion = $lastMajorVersion + 1
        $resetPatch = $true
        $resetMinor = $true
    }
    else {
        $nextMajorVersion = [convert]::ToInt32($majorVersionVar, 10)
    
        if ($nextMajorVersion -gt $lastMajorVersion) {
            $resetPatch = $true
        }
    }
    
    if ($minorVersionVar -eq "$") {
        if ($resetMinor) {
            $nextMinorVersion = 0
        }
        else {
            $nextMinorVersion = $lastMinorVersion + 1
        }
        $resetPatch = $true
    }
    else {
        $nextMinorVersion = [convert]::ToInt32($minorVersionVar, 10)
    
        if ($nextMinorVersion -gt $lastMinorVersion) {
            $resetPatch = $true
        }
    }
    
    if ($patchVersionVar -eq "$") {
        if ($resetPatch) {
            $nextPatchVersion = 0
        }
        else {
            $nextPatchVersion = $lastPatchVersion + 1
        }
        
    }
    else {
        $nextPatchVersion = [convert]::ToInt32($patchVersionVar, 10)
    }
    
    $versionPattern="$($majorVersionVar).$($minorVersionVar).$($patchVersionVar)"

    Write-Host "> Version Pattern: $($versionPattern)" -ForegroundColor Cyan
    Write-Host "> Current App version: $($lastMajorVersion).$($lastMinorVersionVar).$($lastPatchVersionVar)" -ForegroundColor Yellow
    Write-Host "> New App Version: $($nextMajorVersion).$($nextMinorVersion).$($nextPatchVersion)" -ForegroundColor Green
    
    $newVersion = "$($nextMajorVersion).$($nextMinorVersion).$($nextPatchVersion)"

    $propertyGroup.Version = $newVersion

    # ==========================================================

    Write-Host "Updating VersionVariable '$($VersionVariable)'."

    $definition.variables.$VersionVariable.Value = $newVersion

    $definitionJson = $definition | ConvertTo-Json -Depth 50 -Compress
    
    Invoke-RestMethod -Method Put -Uri $defUri -Headers $devOpsHeader -ContentType "application/json" -Body $definitionJson | Out-Null

    Write-Host "VersionVariable '$($VersionVariable)' updated."

    # ==========================================================

    Write-Host "Updating Project file. Replacing '$($versionPattern)' with '$($newVersion)'"

    $csp.Save($csprojFile) 

    Write-Host "Project file updated."

}

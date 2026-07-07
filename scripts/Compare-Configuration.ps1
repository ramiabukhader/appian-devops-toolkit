#Requires -Version 5.1
<#
.SYNOPSIS
    Compares two JSON configuration files and reports the differences.

.DESCRIPTION
    Flattens both configuration files to dotted key paths and reports which keys
    were added, removed, or changed between a reference file and a difference
    file. Handy for spotting drift between environments (for example DEV vs UAT)
    before a release.

    Values are shown as-is; do not run this against files that contain real
    secrets. Use the placeholder samples provided in this repository.

.PARAMETER ReferencePath
    The baseline configuration file (for example the DEV config).

.PARAMETER DifferencePath
    The configuration file to compare against the baseline (for example UAT).

.EXAMPLE
    ./Compare-Configuration.ps1 -ReferencePath ../config/sample.environment.json -DifferencePath ../config/sample.environment.uat.json

.OUTPUTS
    One object per differing key with Change (Added/Removed/Changed) and values.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ReferencePath,

    [Parameter(Mandatory)]
    [string]$DifferencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-FlatMap {
    param([object]$Object, [string]$Prefix = '')
    $map = @{}
    if ($null -eq $Object) { return $map }

    if ($Object -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $Object.PSObject.Properties) {
            $key = if ($Prefix) { "$Prefix.$($prop.Name)" } else { $prop.Name }
            $child = ConvertTo-FlatMap -Object $prop.Value -Prefix $key
            foreach ($k in $child.Keys) { $map[$k] = $child[$k] }
        }
    }
    elseif ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
        $i = 0
        foreach ($item in $Object) {
            $key = "$Prefix[$i]"
            $child = ConvertTo-FlatMap -Object $item -Prefix $key
            foreach ($k in $child.Keys) { $map[$k] = $child[$k] }
            $i++
        }
    }
    else {
        $map[$Prefix] = $Object
    }
    return $map
}

function Read-JsonFile {
    param([string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) {
        throw "File not found: $FilePath"
    }
    return Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json
}

$refMap  = ConvertTo-FlatMap -Object (Read-JsonFile -FilePath $ReferencePath)
$diffMap = ConvertTo-FlatMap -Object (Read-JsonFile -FilePath $DifferencePath)

$allKeys = @($refMap.Keys) + @($diffMap.Keys) | Sort-Object -Unique
$differences = New-Object System.Collections.Generic.List[object]

foreach ($key in $allKeys) {
    $inRef  = $refMap.ContainsKey($key)
    $inDiff = $diffMap.ContainsKey($key)

    if ($inRef -and -not $inDiff) {
        $differences.Add([pscustomobject]@{ Key = $key; Change = 'Removed'; Reference = $refMap[$key]; Difference = $null })
    }
    elseif (-not $inRef -and $inDiff) {
        $differences.Add([pscustomobject]@{ Key = $key; Change = 'Added'; Reference = $null; Difference = $diffMap[$key] })
    }
    elseif ("$($refMap[$key])" -ne "$($diffMap[$key])") {
        $differences.Add([pscustomobject]@{ Key = $key; Change = 'Changed'; Reference = $refMap[$key]; Difference = $diffMap[$key] })
    }
}

if ($differences.Count -eq 0) {
    Write-Host "No differences found between the two configurations." -ForegroundColor Green
}

$differences

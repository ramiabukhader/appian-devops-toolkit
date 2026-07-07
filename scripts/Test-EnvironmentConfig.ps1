#Requires -Version 5.1
<#
.SYNOPSIS
    Validates an environment configuration file before a deployment.

.DESCRIPTION
    Reads a JSON environment configuration and checks that every required key is
    present and non-empty, and that no placeholder values (for example
    "REPLACE_ME" or values wrapped in angle brackets) were left behind.

    The script never prints secret values; it only reports key names and status.

.PARAMETER ConfigPath
    Path to the environment configuration JSON file.

.PARAMETER RequiredKeys
    Dotted key names that must be present and non-empty. Defaults to a generic
    set suitable for the sample configuration in this repository.

.PARAMETER Strict
    Treat warnings (such as leftover placeholders) as failures.

.EXAMPLE
    ./Test-EnvironmentConfig.ps1 -ConfigPath ../config/sample.environment.json

.OUTPUTS
    A summary object. Exit code 0 = valid, 1 = problems found.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [string[]]$RequiredKeys = @(
        'environmentName',
        'api.baseUrl',
        'api.timeoutSeconds',
        'logging.level'
    ),

    [switch]$Strict
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FlatValue {
    param([object]$Object, [string]$DottedKey)
    $current = $Object
    foreach ($part in $DottedKey.Split('.')) {
        if ($null -eq $current) { return $null }
        $prop = $current.PSObject.Properties[$part]
        if ($null -eq $prop) { return $null }
        $current = $prop.Value
    }
    return $current
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    Write-Error "Configuration file not found: $ConfigPath"
    exit 1
}

try {
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Configuration file is not valid JSON: $($_.Exception.Message)"
    exit 1
}

$placeholderPattern = 'REPLACE_ME|CHANGE_ME|CHANGEME|^<.*>$|TODO'
$errors   = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

foreach ($key in $RequiredKeys) {
    $value = Get-FlatValue -Object $config -DottedKey $key
    if ($null -eq $value -or ([string]::IsNullOrWhiteSpace([string]$value))) {
        $errors.Add("Missing or empty required key: '$key'")
        continue
    }
    if ([string]$value -match $placeholderPattern) {
        $warnings.Add("Key '$key' still contains a placeholder value.")
    }
}

foreach ($w in $warnings) { Write-Warning $w }
foreach ($e in $errors)   { Write-Host "ERROR: $e" -ForegroundColor Red }

$failed = $errors.Count -gt 0 -or ($Strict -and $warnings.Count -gt 0)

$result = [pscustomobject]@{
    ConfigPath   = (Resolve-Path -LiteralPath $ConfigPath).Path
    CheckedKeys  = $RequiredKeys.Count
    ErrorCount   = $errors.Count
    WarningCount = $warnings.Count
    IsValid      = -not $failed
}

$result | Format-List | Out-String | Write-Host

if ($failed) { exit 1 } else { Write-Host "Environment configuration looks valid." -ForegroundColor Green; exit 0 }

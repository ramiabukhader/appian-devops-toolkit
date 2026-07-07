#Requires -Version 5.1
<#
.SYNOPSIS
    Performs pre-deployment checks on a release package folder.

.DESCRIPTION
    Verifies that a release package directory contains every required artifact
    and none of the forbidden files (backups, local secrets, editor junk) that
    should never ship. Helps catch a bad package before it reaches an
    environment.

.PARAMETER PackagePath
    Path to the release package directory to inspect.

.PARAMETER RequiredFiles
    File names (relative to the package root) that must be present.

.PARAMETER ForbiddenPatterns
    Wildcard patterns that must NOT match any file in the package.

.EXAMPLE
    ./Test-ReleasePackage.ps1 -PackagePath ../samples/release-package

.OUTPUTS
    A summary object. Exit code 0 = package OK, 1 = problems found.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PackagePath,

    [string[]]$RequiredFiles = @('manifest.json', 'README.md'),

    [string[]]$ForbiddenPatterns = @('*.bak', '*.tmp', '*.pfx', '*secret*', '*.env')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PackagePath -PathType Container)) {
    Write-Error "Release package directory not found: $PackagePath"
    exit 1
}

$root  = (Resolve-Path -LiteralPath $PackagePath).Path
$files = Get-ChildItem -LiteralPath $root -Recurse -File

$errors = New-Object System.Collections.Generic.List[string]

# Required files present?
foreach ($required in $RequiredFiles) {
    $match = $files | Where-Object { $_.Name -eq $required }
    if (-not $match) {
        $errors.Add("Required file missing from package: '$required'")
    }
}

# Forbidden files absent?
foreach ($pattern in $ForbiddenPatterns) {
    $hits = $files | Where-Object { $_.Name -like $pattern }
    foreach ($hit in $hits) {
        $relative = $hit.FullName.Substring($root.Length).TrimStart('\', '/')
        $errors.Add("Forbidden file present ('$pattern'): $relative")
    }
}

foreach ($e in $errors) { Write-Host "ERROR: $e" -ForegroundColor Red }

$result = [pscustomobject]@{
    PackagePath   = $root
    FileCount     = $files.Count
    RequiredFiles = $RequiredFiles.Count
    ErrorCount    = $errors.Count
    IsValid       = $errors.Count -eq 0
}

$result | Format-List | Out-String | Write-Host

if ($errors.Count -gt 0) { exit 1 }
Write-Host "Release package passed all checks." -ForegroundColor Green
exit 0

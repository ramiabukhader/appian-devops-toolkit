#Requires -Version 5.1
<#
.SYNOPSIS
    Filters structured log files by level, time window, and text pattern.

.DESCRIPTION
    Reads one or more log files whose lines start with an ISO-8601 timestamp and
    a bracketed level, for example:

        2026-07-08T10:15:30Z [INFO] Service started

    and returns only the entries that match the requested level(s), fall on or
    after the -Since time, and contain the -Pattern text. Useful for pulling the
    signal out of a noisy application log during a release or incident.

.PARAMETER Path
    One or more log file paths.

.PARAMETER Level
    Levels to keep (e.g. ERROR, WARN). Defaults to all levels.

.PARAMETER Since
    Only return entries at or after this UTC timestamp.

.PARAMETER Pattern
    Case-insensitive text or regex the message must contain.

.EXAMPLE
    ./Select-LogEntries.ps1 -Path ../samples/logs/app.log -Level ERROR,WARN

.EXAMPLE
    ./Select-LogEntries.ps1 -Path ../samples/logs/app.log -Since '2026-07-08T10:16:00Z' -Pattern timeout
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Path,

    [ValidateSet('TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')]
    [string[]]$Level,

    [datetime]$Since,

    [string]$Pattern
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$lineRegex = '^(?<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z?)\s+\[(?<level>[A-Z]+)\]\s+(?<msg>.*)$'

foreach ($file in $Path) {
    if (-not (Test-Path -LiteralPath $file)) {
        Write-Warning "Log file not found, skipping: $file"
        continue
    }

    Get-Content -LiteralPath $file | ForEach-Object {
        $line = $_
        $m = [regex]::Match($line, $lineRegex)
        if (-not $m.Success) { return }

        $entryLevel = $m.Groups['level'].Value
        $entryMsg   = $m.Groups['msg'].Value

        if ($Level -and ($entryLevel -notin $Level)) { return }

        if ($PSBoundParameters.ContainsKey('Since')) {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse($m.Groups['ts'].Value, [ref]$parsed)) {
                if ($parsed.ToUniversalTime() -lt $Since.ToUniversalTime()) { return }
            }
        }

        if ($Pattern -and ($entryMsg -notmatch $Pattern)) { return }

        [pscustomobject]@{
            Timestamp = $m.Groups['ts'].Value
            Level     = $entryLevel
            Message   = $entryMsg
            Source    = Split-Path -Leaf $file
        }
    }
}

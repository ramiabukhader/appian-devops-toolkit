# Appian DevOps Toolkit

A small set of **safe, dependency-free PowerShell scripts** that support the
day-to-day operational tasks around an [Appian](https://appian.com) project:
validating environment configuration, sanity-checking release packages,
filtering application logs, and comparing configuration between environments.

> **Disclaimer & safety**
> These scripts are generic developer utilities. They ship with **placeholder
> sample data only** — no passwords, no real URLs, no environment values, and no
> proprietary code. Never commit real secrets; the included `.gitignore` blocks
> common secret file patterns as a safety net.

## Problem

Operational mistakes around low-code projects are usually boring: a missing
config key, a backup file that sneaks into a release package, or unnoticed drift
between DEV and UAT. These scripts turn those checks into repeatable commands you
can run locally or in a pipeline.

## Scope

Four standalone scripts, each with full comment-based help
(`Get-Help ./scripts/<name>.ps1 -Full`):

| Script                       | What it does                                                        |
|------------------------------|---------------------------------------------------------------------|
| `Test-EnvironmentConfig.ps1` | Validates a config file: required keys present, no leftover placeholders. |
| `Test-ReleasePackage.ps1`    | Checks a release package for required files and forbidden files.    |
| `Select-LogEntries.ps1`      | Filters logs by level, time window, and text/regex pattern.        |
| `Compare-Configuration.ps1`  | Reports added/removed/changed keys between two config files.        |

## Quick start

Requires **PowerShell 5.1+** (Windows PowerShell) or **PowerShell 7+** (cross-platform).

```powershell
# 1. Validate the sample environment config
./scripts/Test-EnvironmentConfig.ps1 -ConfigPath ./config/sample.environment.json

# 2. Check the sample release package
./scripts/Test-ReleasePackage.ps1 -PackagePath ./samples/release-package

# 3. Pull ERROR/WARN entries out of a log
./scripts/Select-LogEntries.ps1 -Path ./samples/logs/app.log -Level ERROR,WARN

# 4. Diff DEV vs UAT configuration
./scripts/Compare-Configuration.ps1 `
    -ReferencePath ./config/sample.environment.json `
    -DifferencePath ./config/sample.environment.uat.json
```

## Copy-paste recipes

Run these from the repository root. Every example uses the fictional files
included in the repository and can be adapted by replacing the paths.

### Validate an environment configuration

Fail when a required value is missing or still contains a placeholder:

```powershell
./scripts/Test-EnvironmentConfig.ps1 `
    -ConfigPath ./config/sample.environment.json `
    -RequiredKeys 'environmentName','api.baseUrl','api.timeoutSeconds','logging.level' `
    -Strict
```

Use the same command as a pipeline gate; the script returns exit code `1` when
validation fails.

### Check a release package before promotion

Require the manifest and release notes while rejecting common secret and
backup file patterns:

```powershell
./scripts/Test-ReleasePackage.ps1 `
    -PackagePath ./samples/release-package `
    -RequiredFiles 'manifest.json','README.md' `
    -ForbiddenPatterns '*.bak','*.tmp','*.pfx','*.env','*secret*'
```

This also returns exit code `1` when the package is unsafe or incomplete.

### Investigate recent errors and warnings

Filter the sample log to authentication-related warnings and errors, then
format the returned objects as a table:

```powershell
./scripts/Select-LogEntries.ps1 `
    -Path ./samples/logs/app.log `
    -Level ERROR,WARN `
    -Since '2026-07-08T10:15:00Z' `
    -Pattern 'auth|timeout' |
    Format-Table Timestamp,Level,Message,Source -AutoSize
```

Export the same structured results for incident analysis:

```powershell
./scripts/Select-LogEntries.ps1 `
    -Path ./samples/logs/app.log `
    -Level ERROR,WARN |
    Export-Csv ./filtered-log.csv -NoTypeInformation
```

### Review configuration drift

Compare DEV with UAT and keep the differences as normal PowerShell objects for
filtering or export:

```powershell
$drift = @(
    ./scripts/Compare-Configuration.ps1 `
        -ReferencePath ./config/sample.environment.json `
        -DifferencePath ./config/sample.environment.uat.json
)

$drift | Sort-Object Change,Key | Format-Table -AutoSize
$drift | Where-Object Change -eq 'Changed' | Export-Csv ./changed-values.csv -NoTypeInformation
```

## Script reference

### `Test-EnvironmentConfig.ps1`
Reads a JSON config and confirms every required key (dotted paths such as
`api.baseUrl`) is present and non-empty. Flags values that still contain
placeholders like `REPLACE_ME` or `<...>`. Use `-Strict` to fail on those
warnings. Never prints values — only key names and status. Exit code `0` = valid,
`1` = problems.

### `Test-ReleasePackage.ps1`
Walks a release package directory and confirms all `-RequiredFiles` are present
and none of the `-ForbiddenPatterns` (e.g. `*.bak`, `*secret*`, `*.env`) appear.
Catches accidental inclusions before they ship. Exit code `0` = OK, `1` = problems.

### `Select-LogEntries.ps1`
Parses lines of the form `TIMESTAMP [LEVEL] message` and returns objects filtered
by `-Level`, `-Since`, and `-Pattern`. Output is normal PowerShell objects, so you
can pipe to `Format-Table`, `Export-Csv`, etc.

### `Compare-Configuration.ps1`
Flattens two JSON files to dotted key paths and reports each `Added`, `Removed`,
or `Changed` key. Ideal for catching configuration drift between environments.

## Folder structure

```
appian-devops-toolkit/
├── README.md
├── LICENSE
├── .gitignore
├── scripts/
│   ├── Test-EnvironmentConfig.ps1
│   ├── Test-ReleasePackage.ps1
│   ├── Select-LogEntries.ps1
│   └── Compare-Configuration.ps1
├── config/
│   ├── sample.environment.json        # placeholder DEV config
│   └── sample.environment.uat.json    # placeholder UAT config
└── samples/
    ├── logs/app.log                   # sample structured log
    └── release-package/               # sample package for Test-ReleasePackage
```

## Limitations

- Scripts assume the sample JSON/log conventions shown above; adapt the regex or
  required-key defaults to your own formats.
- No platform APIs are called — these are file-based utilities by design, which
  keeps them safe to run anywhere.

## Roadmap

- [ ] Pester tests for each script
- [ ] Optional JSON output mode for pipeline consumption
- [ ] A thin module manifest so the scripts install as a module

## License

Released under the [MIT License](LICENSE).

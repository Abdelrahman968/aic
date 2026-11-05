<#
.SYNOPSIS  Runs the aic test-suite (Pester 5). No Ollama server is needed: a mock is started in-process.
.PARAMETER AicPath  aic.ps1 to test (default: ../aic.ps1, or $env:AIC_PATH). Point it at your real file to test that.
.PARAMETER Tag      Only run tests with these tags: Regression, Control, Characterization, Spec, B01 .. B13
.PARAMETER Path     Restrict to a test file or folder.
#>
[CmdletBinding()]
param([string]$AicPath, [string[]]$Tag, [string]$Path = $PSScriptRoot, [ValidateSet('Minimal', 'Normal', 'Detailed')][string]$Output = 'Normal', [string]$ResultJson)
$ErrorActionPreference = 'Stop'
Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop
if ($AicPath) { $env:AIC_PATH = (Resolve-Path -LiteralPath $AicPath).Path }
$cfg = New-PesterConfiguration
$cfg.Run.Path = $Path; $cfg.Run.PassThru = $true
$cfg.Output.Verbosity = $Output
$cfg.TestResult.Enabled = $false      # NUnit XML cannot hold the ESC characters some tests assert on; use -ResultJson
if ($Tag) { $cfg.Filter.Tag = $Tag }
$r = Invoke-Pester -Configuration $cfg
if ($ResultJson) {
    $r.Tests | ForEach-Object { [pscustomobject]@{ File = (Split-Path $_.ScriptBlock.File -Leaf); Name = $_.ExpandedPath; Result = $_.Result; Tags = ($_.Tag -join ','); Error = (($_.ErrorRecord | Select-Object -First 1 | ForEach-Object { $_.Exception.Message }) -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', '?') } } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ResultJson -Encoding utf8
}
"RESULT: passed=$($r.PassedCount) failed=$($r.FailedCount) skipped=$($r.SkippedCount) notrun=$($r.NotRunCount)"

# Locating aic.ps1, building the AST harness, and running aic (end-to-end or function-level) in a child process.

function Get-AicPath {
    if ($env:AIC_PATH) { return (Resolve-Path -LiteralPath $env:AIC_PATH).Path }
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..' 'aic.ps1')).Path
}

# Build `function aic_harness { <param block> <everything aic does BEFORE its main try{}> <init> & $block }`.
# Nothing in aic.ps1 is modified: we only slice its source text by AST offsets.
function ConvertTo-AicHarnessSource([string]$AicPath) {
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($AicPath, [ref]$tokens, [ref]$errs)
    if ($errs.Count) { throw "aic.ps1 has $($errs.Count) parse error(s): $($errs[0].Message) (line $($errs[0].Extent.StartLineNumber))" }
    $fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'aic' }, $true)
    if (-not $fn) { throw 'function aic not found' }
    $src   = $ast.Extent.Text
    $pb    = $fn.Body.ParamBlock
    $stmts = @($fn.Body.EndBlock.Statements)
    $last  = $stmts[$stmts.Count - 1]
    if ($last -isnot [System.Management.Automation.Language.TryStatementAst]) {
        throw "harness incompatible: the last statement of aic is a $($last.GetType().Name), expected the main try/finally"
    }
    $paramText = $pb.Extent.Text
    if ($paramText -notmatch '^\s*\[CmdletBinding') { $paramText = "[CmdletBinding()]`n" + $paramText }
    $pre = $src.Substring($pb.Extent.EndOffset, $last.Extent.StartOffset - $pb.Extent.EndOffset)
    $init = @'

    # ---- harness init: what the real main section sets up before it starts working ----
    $root     = [string](git rev-parse --show-toplevel 2>$null)
    $inRepo   = $true
    $gitC     = '-C', $root, '-c', 'core.quotepath=false'
    $pathArgs = Get-PathArgs
    $branch   = [string](git @gitC symbolic-ref --short -q HEAD 2>$null)
    if (-not $branch) { $branch = 'detached HEAD' }
    $st = @{
        Model = $Model; Hint = $Hint; Type = $Type; Scope = $Scope; NoScope = $false; Bang = [bool]$Breaking
        Regen = 0; Msg = ''; Problems = @(); Meta = ''; CommitOk = $false; Ack = $false; Findings = @()
    }
    # ---- test block runs here, in the same scope as every nested aic function ----
    & $global:AicHarnessBlock
}
'@
    "function aic_harness {`n$paramText$pre$init"
}

function New-RunnerFile($Sandbox, [string]$Name) { Join-Path $Sandbox.Base $Name }

function Start-ChildAndWait {
    param($Sandbox, [string[]]$ChildArgs, $Mock, [string]$Cwd, [int]$TimeoutSec)
    $pwsh = (Get-Process -Id $PID).Path
    $psi = [Diagnostics.ProcessStartInfo]::new($pwsh)
    foreach ($a in (@('-NoProfile', '-NonInteractive', '-File') + $ChildArgs)) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = if ($Cwd) { $Cwd } else { $Sandbox.Repo }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.RedirectStandardInput = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8; $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.UseShellExecute = $false
    foreach ($k in $Sandbox.Env.Keys) { $psi.Environment[$k] = [string]$Sandbox.Env[$k] }
    if ($Mock) { $psi.Environment['OLLAMA_HOST'] = "127.0.0.1:$($Mock.State.Port)" } else { [void]$psi.Environment.Remove('OLLAMA_HOST') }
    [void]$psi.Environment.Remove('NO_COLOR')
    $proc = [Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Close()                                   # stdin redirected + closed: aic must never block on a prompt
    $outT = $proc.StandardOutput.ReadToEndAsync(); $errT = $proc.StandardError.ReadToEndAsync()
    $timedOut = $false
    if (-not $proc.WaitForExit($TimeoutSec * 1000)) { $timedOut = $true; try { $proc.Kill($true) } catch { } }
    $proc.WaitForExit()
    [pscustomobject]@{ Stdout = $outT.Result; Stderr = $errT.Result; ExitCode = $proc.ExitCode; TimedOut = $timedOut }
}

function Read-JsonFile([string]$Path) {
    if (Test-Path -LiteralPath $Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json } else { $null }
}

# End-to-end: `aic @Params` in a child process, cwd = sandbox repo, Ollama = mock.
function Invoke-Aic {
    param([Parameter(Mandatory)]$Sandbox, [hashtable]$Params = @{}, $Mock, [string]$Cwd, [int]$TimeoutSec = 120)
    $p = @{} + $Params
    if ($Mock -and -not $p.ContainsKey('OllamaUrl')) { $p['OllamaUrl'] = $Mock.Url }
    if (-not $p.ContainsKey('TimeoutSec')) { $p['TimeoutSec'] = 30 }
    $id = [guid]::NewGuid().ToString('N').Substring(0, 6)
    $argsFile = Join-Path $Sandbox.Base "args-$id.json"; $resFile = Join-Path $Sandbox.Base "res-$id.json"
    $p | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $argsFile -Encoding utf8
    $runner = Join-Path $PSScriptRoot 'Invoke-AicChild.ps1'
    $r = Start-ChildAndWait -Sandbox $Sandbox -Mock $Mock -Cwd $Cwd -TimeoutSec $TimeoutSec `
        -ChildArgs @($runner, '-AicPath', (Get-AicPath), '-ArgsFile', $argsFile, '-ResultFile', $resFile)
    $j = Read-JsonFile $resFile
    [pscustomobject]@{
        Stdout = $r.Stdout; Stderr = $r.Stderr; ExitCode = $r.ExitCode; TimedOut = $r.TimedOut
        Pipeline = @($(if ($j) { $j.Pipeline })); Code = $(if ($j) { $j.Code }); Error = $(if ($j) { $j.Error } else { 'runner produced no result file' })
    }
}

# Function-level: run $Script inside aic's own scope (all nested functions + variables are available).
# $Vars are exposed to the block as $AicVars.<name>. $AicParams are passed to the aic parameter block (e.g. @{ Yes = $true }).
# Define mock functions (e.g. `function Pick-Many { ... }`) inside the block: they shadow aic's real ones.
function Invoke-AicHarness {
    param([Parameter(Mandatory)]$Sandbox, [Parameter(Mandatory)][scriptblock]$Script, [hashtable]$AicParams = @{}, [hashtable]$Vars = @{}, $Mock, [string]$Cwd, [int]$TimeoutSec = 90)
    $fnFile = Join-Path $Sandbox.Base 'harness-fn.ps1'
    [IO.File]::WriteAllText($fnFile, (ConvertTo-AicHarnessSource (Get-AicPath)), [Text.UTF8Encoding]::new($false))
    $id = [guid]::NewGuid().ToString('N').Substring(0, 6)
    $blockFile = Join-Path $Sandbox.Base "block-$id.ps1"; $varsFile = Join-Path $Sandbox.Base "vars-$id.json"
    $parFile = Join-Path $Sandbox.Base "par-$id.json"; $resFile = Join-Path $Sandbox.Base "hres-$id.json"
    [IO.File]::WriteAllText($blockFile, $Script.ToString(), [Text.UTF8Encoding]::new($false))
    $Vars | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $varsFile -Encoding utf8
    $AicParams | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $parFile -Encoding utf8
    $runner = Join-Path $PSScriptRoot 'Invoke-HarnessChild.ps1'
    $r = Start-ChildAndWait -Sandbox $Sandbox -Mock $Mock -Cwd $Cwd -TimeoutSec $TimeoutSec `
        -ChildArgs @($runner, '-FnFile', $fnFile, '-BlockFile', $blockFile, '-VarsFile', $varsFile, '-ParamsFile', $parFile, '-ResultFile', $resFile)
    $j = Read-JsonFile $resFile
    [pscustomobject]@{
        Output = $(if ($j) { $j.Output }); Leaked = $(if ($j) { $j.Leaked } else { 0 }); Error = $(if ($j) { $j.Error } else { "runner produced no result file. stderr: $($r.Stderr)" })
        Stdout = $r.Stdout; Stderr = $r.Stderr; TimedOut = $r.TimedOut
    }
}

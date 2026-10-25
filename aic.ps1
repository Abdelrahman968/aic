<#
.SYNOPSIS
    aic/cli - AI Commit: Conventional Commit messages for your staged changes, written by a LOCAL Ollama model.

.DESCRIPTION
    stage -> aic -> review (single key) -> commit.
    Live spinner + token progress bar, colour-coded diffstat, format validation with auto-retry, arrow-key pickers,
    file-staging checklist, AI-file staging (prompts, agent rules, editor AI config), secret / .env warning,
    message variants, doctor, pretty log, per-repo AND global settings, themes, borders, banners, undo, amend, push.
    Written for PowerShell 7+ (Windows Terminal / VS Code terminal). Falls back to plain text when output is
    redirected, with -Plain, or when NO_COLOR is set.

    REVIEW KEYS
      Enter commit | e edit in git editor | r retry | v pick from variants | h retry with a hint | m pick model
      t pick type  | s set scope | b toggle breaking "!" | x toggle gitmoji | a stage AI files | f re-pick files
      c copy | p commit+push | d view diff | q / Esc quit

    AI FILES (what counts as "related to AI")
      .aic.json, CLAUDE.md / AGENTS.md / GEMINI.md / COPILOT.md, .cursorrules, .windsurfrules, .clinerules, .aider*,
      .claude/ .cursor/ .continue/ .windsurf/ .roo/ .cline/ .codex/ .gemini/ .ollama/ .tabby/ .agents/,
      .github/copilot-instructions.md + instructions/ prompts/ chatmodes/ agents/, mcp.json / .mcp.json,
      Modelfile, llms.txt, prompts/ folders, *.prompt.md, *.prompty, *.mdc, skills/*/SKILL.md
      Add your own globs with -AiPattern or "aiFiles" in .aic.json.

    PRECEDENCE of settings:
      flag you type > $PSDefaultParameterValues > .aic.json in the repo root > ~/.aic.json > built-in default

.EXAMPLE
    aic                                   # nothing staged? a checklist lets you pick files (AI files are tagged), then generate -> review -> commit
.EXAMPLE
    aic -AiFiles                          # git add every changed AI-related file, then generate -> review -> commit
.EXAMPLE
    aic -AiOnly                           # commit ONLY AI files (other staged files are unstaged, not touched on disk)
.EXAMPLE
    aic -ListAi                           # show which changed files are AI-related and whether they are staged
.EXAMPLE
    aic -AiFiles -AiPattern 'agents/*','*.skill.md'
.EXAMPLE
    aic -All -Push                        # git add -A, then commit and push
.EXAMPLE
    aic -Pick                             # re-pick exactly which files go into this commit
.EXAMPLE
    aic -DryRun -Type fix -Scope auth     # preview only, force "fix(auth): ..."
.EXAMPLE
    aic -Model qwen2.5-coder:3b -Yes      # lighter model, commit without asking
.EXAMPLE
    aic -Amend -Hint "mention the retry logic"
.EXAMPLE
    aic -Undo                             # soft-undo the last commit (changes stay staged)
.EXAMPLE
    aic -Init                             # write a starter .aic.json (scopes inferred from your repo layout)
.EXAMPLE
    aic -Doctor                           # health check: PowerShell, git, Ollama, model, settings, AI files
.EXAMPLE
    aic -Log 12                           # last 12 commits as coloured type pills + a type histogram
.EXAMPLE
    aic -ListThemes                       # preview every colour theme
.EXAMPLE
    aic -Theme dracula -Border double -Banner big -Spinner star
.EXAMPLE
    $msg = aic -DryRun -PassThru          # message as a string (scripts / hooks)

.PARAMETER Model
    Ollama model. Tab-completes with the models you have installed.
.PARAMETER OllamaUrl
    Server URL. Default: $env:OLLAMA_HOST, else http://localhost:11434
.PARAMETER MaxChars
    Diff size cap, shared fairly between files (small files free budget for big ones).
.PARAMETER NumCtx
    Context window; auto-raised when the prompt needs more.
.PARAMETER NumPredict
    Max tokens in the answer.
.PARAMETER Temperature
    Sampling temperature (rises a little on every retry for variety).
.PARAMETER KeepAlive
    How long Ollama keeps the model in memory, e.g. 10m.
.PARAMETER TimeoutSec
    Whole-generation timeout (first call includes model load).
.PARAMETER StartOllama
    Start `ollama serve` automatically if the server is not running (otherwise it asks).
.PARAMETER Unload
    Unload the model from (V)RAM when aic finishes.
.PARAMETER Type
    Force the commit type.
.PARAMETER Scope
    Force the scope.
.PARAMETER Breaking
    Mark as a breaking change: type(scope)!:
.PARAMETER Emoji
    Gitmoji after the colon, e.g. "feat: <sparkles> add login". Toggle live with the x key.
.PARAMETER Hint
    Extra context for the model.
.PARAMETER Language
    Language of subject + bullets (type and scope stay English).
.PARAMETER Bullets
    Max body bullets (0 = subject line only).
.PARAMETER History
    How many recent commit subjects the model sees as a style reference (0 = none).
.PARAMETER Ref
    Footer reference, e.g. -Ref '#42' adds "Refs: #42".
.PARAMETER Exclude
    Extra pathspecs hidden from the model, e.g. '*.svg'.
.PARAMETER Retries
    Automatic retries when the format check fails.
.PARAMETER Variants
    How many alternatives the v key generates (2-6).
.PARAMETER NoScan
    Skip the secrets / sensitive-file warning.
.PARAMETER All
    git add -A first.
.PARAMETER AiFiles
    git add every changed AI-related file first (works together with other staged files and with -Pick).
.PARAMETER AiOnly
    Make this commit hold ONLY AI-related files: stages them and unstages everything else (working tree untouched).
.PARAMETER AiPattern
    Extra globs that count as AI-related, e.g. 'agents/*','*.skill.md'.
.PARAMETER ListAi
    List the changed AI-related files (and whether they are staged), then exit.
.PARAMETER Pick
    Show the file checklist even when something is already staged.
.PARAMETER Amend
    Rewrite the message of the last commit.
.PARAMETER Push
    Push after committing (sets upstream on a new branch).
.PARAMETER NoVerify
    Skip git hooks.
.PARAMETER Signoff
    Add Signed-off-by.
.PARAMETER Undo
    Soft-undo the last commit and exit.
.PARAMETER Init
    Create a starter .aic.json in the repo root and exit.
.PARAMETER Doctor
    Run a health check and exit.
.PARAMETER Log
    Show the last N commits as coloured type pills and exit.
.PARAMETER ListThemes
    Preview every theme and exit.
.PARAMETER Yes
    Skip the review prompt and commit (refuses when the format check or secret scan complains).
.PARAMETER DryRun
    Show the message, commit nothing.
.PARAMETER Copy
    Copy the message to the clipboard, commit nothing.
.PARAMETER PassThru
    Also return the final message as a string.
.PARAMETER Theme
    ocean | sunset | forest | neon | mono | aurora | rose | gold | dracula | candy
.PARAMETER Spinner
    dots | arc | bounce | pulse | grow | line | star | orbit
.PARAMETER Border
    Card border style: rounded | square | double | heavy
.PARAMETER Banner
    mini (one line) | big (2-row gradient logo) | none
.PARAMETER Width
    Maximum card width (50-140).
.PARAMETER Bell
    Ring the terminal bell when the commit is done.
.PARAMETER NoAnim
    Keep colours, drop animations.
.PARAMETER Plain
    ASCII only, no colour, no animation.

.NOTES
    Defaults once, in $PROFILE:
        $PSDefaultParameterValues['aic:Model']   = 'qwen2.5-coder:3b'
        $PSDefaultParameterValues['aic:Theme']   = 'dracula'
    Per repo: run  aic -Init  and edit .aic.json
        (model, language, bullets, emoji, history, theme, spinner, border, banner, width,
         scopes, exclude, aiFiles, autoStageAi)
    Same keys work in ~/.aic.json as personal defaults for every repo.
    "autoStageAi": true  = every run behaves like -AiFiles.
#>
function aic {
    [CmdletBinding()]
    param(
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $bound)
            $b = if ($bound['OllamaUrl']) { $bound['OllamaUrl'] } elseif ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { 'http://localhost:11434' }
            if ($b -notmatch '^https?://') { $b = "http://$b" }
            try {
                (Invoke-RestMethod -Uri "$($b.TrimEnd('/'))/api/tags" -TimeoutSec 2).models.name |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
            } catch { }
        })]
        [string]$Model = 'qwen2.5-coder:7b',
        [string]$OllamaUrl,
        [int]   $MaxChars    = 6000,
        [int]   $NumCtx      = 4096,
        [int]   $NumPredict  = 256,
        [ValidateRange(0.0, 2.0)][double]$Temperature = 0.2,
        [string]$KeepAlive   = '10m',
        [int]   $TimeoutSec  = 180,
        [switch]$StartOllama,
        [switch]$Unload,

        [ValidateSet('feat', 'fix', 'refactor', 'perf', 'docs', 'style', 'test', 'build', 'ci', 'chore', 'revert')]
        [string]$Type,
        [string]$Scope,
        [switch]$Breaking,
        [switch]$Emoji,
        [string]$Hint,
        [string]$Language = 'English',
        [ValidateRange(0, 6)][int]$Bullets = 3,
        [ValidateRange(0, 20)][int]$History = 3,
        [string]$Ref,
        [string[]]$Exclude,
        [ValidateRange(0, 5)][int]$Retries = 1,
        [ValidateRange(2, 6)][int]$Variants = 3,
        [switch]$NoScan,

        [switch]$All,
        [switch]$AiFiles,
        [switch]$AiOnly,
        [string[]]$AiPattern,
        [switch]$ListAi,
        [switch]$Pick,
        [switch]$Amend,
        [switch]$Push,
        [switch]$NoVerify,
        [switch]$Signoff,
        [switch]$Undo,
        [switch]$Init,
        [switch]$Doctor,
        [ValidateRange(0, 100)][int]$Log = 0,
        [switch]$ListThemes,

        [switch]$Yes,
        [switch]$DryRun,
        [switch]$Copy,
        [switch]$PassThru,

        [ValidateSet('ocean', 'sunset', 'forest', 'neon', 'mono', 'aurora', 'rose', 'gold', 'dracula', 'candy')][string]$Theme = 'ocean',
        [ValidateSet('dots', 'arc', 'bounce', 'pulse', 'grow', 'line', 'star', 'orbit')][string]$Spinner = 'dots',
        [ValidateSet('rounded', 'square', 'double', 'heavy')][string]$Border = 'rounded',
        [ValidateSet('mini', 'big', 'none')][string]$Banner = 'mini',
        [ValidateRange(50, 140)][int]$Width = 78,
        [switch]$Bell,
        [switch]$NoAnim,
        [switch]$Plain
    )
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $esc = [char]27
    $inv = [System.Globalization.CultureInfo]::InvariantCulture   # numbers look the same on every locale
    $sessionSw = [System.Diagnostics.Stopwatch]::StartNew()

    # =========================================================================================
    # 0) settings files: ~/.aic.json (personal) then <repo>/.aic.json (wins). Flags you type win over both.
    #    Nested functions get their own $PSBoundParameters, so remember what was typed in $bound.
    # =========================================================================================
    $bound = @{}
    foreach ($k in $PSBoundParameters.Keys) { $bound[$k] = $true }
    $validThemes   = 'ocean', 'sunset', 'forest', 'neon', 'mono', 'aurora', 'rose', 'gold', 'dracula', 'candy'
    $validSpinners = 'dots', 'arc', 'bounce', 'pulse', 'grow', 'line', 'star', 'orbit'
    $validBorders  = 'rounded', 'square', 'double', 'heavy'
    $validBanners  = 'mini', 'big', 'none'

    $cfg     = @{}
    $cfgWarn = [System.Collections.Generic.List[string]]::new()
    $rootEarly = ''
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $rootEarly = [string](git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -ne 0) { $rootEarly = '' }
    }
    $cfgSources = @(Join-Path $HOME '.aic.json')
    if ($rootEarly -and -not $Init) { $cfgSources += (Join-Path $rootEarly '.aic.json') }
    foreach ($cf in $cfgSources) {
        if (-not (Test-Path -LiteralPath $cf)) { continue }
        try {
            $j = Get-Content -LiteralPath $cf -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $cfg[$p.Name] = $p.Value }
        } catch { $cfgWarn.Add("$cf could not be read, ignoring it ($($_.Exception.Message))") }
    }

    if ($cfg['model']    -and -not $bound.ContainsKey('Model'))    { $Model    = [string]$cfg['model'] }
    if ($cfg['language'] -and -not $bound.ContainsKey('Language')) { $Language = [string]$cfg['language'] }
    if ($null -ne $cfg['bullets'] -and -not $bound.ContainsKey('Bullets')) { $Bullets = [Math]::Min(6,   [Math]::Max(0,  [int]$cfg['bullets'])) }
    if ($null -ne $cfg['history'] -and -not $bound.ContainsKey('History')) { $History = [Math]::Min(20,  [Math]::Max(0,  [int]$cfg['history'])) }
    if ($null -ne $cfg['width']   -and -not $bound.ContainsKey('Width'))   { $Width   = [Math]::Min(140, [Math]::Max(50, [int]$cfg['width'])) }
    if ($cfg['theme']   -in $validThemes   -and -not $bound.ContainsKey('Theme'))   { $Theme   = [string]$cfg['theme'] }
    if ($cfg['spinner'] -in $validSpinners -and -not $bound.ContainsKey('Spinner')) { $Spinner = [string]$cfg['spinner'] }
    if ($cfg['border']  -in $validBorders  -and -not $bound.ContainsKey('Border'))  { $Border  = [string]$cfg['border'] }
    if ($cfg['banner']  -in $validBanners  -and -not $bound.ContainsKey('Banner'))  { $Banner  = [string]$cfg['banner'] }
    $useEmoji = [bool]$Emoji
    if ($cfg['emoji'] -eq $true -and -not $bound.ContainsKey('Emoji')) { $useEmoji = $true }
    if ($cfg['exclude']) { $Exclude = @($Exclude) + @($cfg['exclude'] | ForEach-Object { [string]$_ }) }
    $cfgScopes = @()
    if ($cfg['scopes']) { $cfgScopes = @($cfg['scopes'] | ForEach-Object { [string]$_ } | Where-Object { $_ }) }
    $aiGlobs = @(@($AiPattern) + @($cfg['aiFiles']) | ForEach-Object { [string]$_ } | Where-Object { $_ })
    $autoAi  = ($cfg['autoStageAi'] -eq $true)

    # =========================================================================================
    # 1) terminal capabilities
    # =========================================================================================
    $isTty = -not [Console]::IsOutputRedirected
    $vtOk  = ($PSVersionTable.PSVersion.Major -ge 7) -or $env:WT_SESSION -or $env:TERM_PROGRAM -or ($env:ConEmuANSI -eq 'ON')
    $fancy = [bool]($isTty -and $vtOk -and -not $Plain)
    $ui = @{
        Plain = -not $fancy
        Color = [bool]($fancy -and -not $env:NO_COLOR)
        Anim  = [bool]($fancy -and -not $NoAnim)
        Keys  = [bool]($isTty -and -not [Console]::IsInputRedirected)
        Fancy = $fancy
    }

    # =========================================================================================
    # 2) UI toolkit. Nested on purpose: only `aic` itself lands in your profile scope.
    #    This file is pure ASCII: glyphs are built from code points, so any editor/encoding is safe.
    # =========================================================================================
    function U([int[]]$cp) { -join ($cp | ForEach-Object { [string][char]$_ }) }

    $spinFrames = @{
        dots   = 0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F
        arc    = 0x25DC, 0x25E0, 0x25DD, 0x25DE, 0x25E1, 0x25DF
        bounce = 0x2801, 0x2802, 0x2804, 0x2840, 0x2880, 0x2820, 0x2810, 0x2808
        pulse  = 0x2591, 0x2592, 0x2593, 0x2588, 0x2593, 0x2592
        grow   = 0x2581, 0x2582, 0x2583, 0x2584, 0x2585, 0x2586, 0x2587, 0x2588, 0x2587, 0x2586, 0x2585, 0x2584, 0x2583, 0x2582
        star   = 0x2736, 0x2738, 0x2739, 0x273A, 0x2739, 0x2738
        orbit  = 0x25D0, 0x25D3, 0x25D1, 0x25D2
    }
    # card borders: top-left, bottom-left, vertical, horizontal
    $borders = @{
        rounded = 0x256D, 0x2570, 0x2502, 0x2500
        square  = 0x250C, 0x2514, 0x2502, 0x2500
        double  = 0x2554, 0x255A, 0x2551, 0x2550
        heavy   = 0x250F, 0x2517, 0x2503, 0x2501
    }
    $bd = $borders[$Border]
    $g = if ($ui.Plain) {
        @{ tl = '+-'; bl = '+-'; v = '|'; h = '-'; dot = '*'; ok = 'OK'; bad = 'x'; warn = '!'; sel = '>'
           del = '-'; full = '#'; empty = '.'; bfull = '#'; bempty = '.'; mid = '-'; star = '*'; on = 'x'; off = ' '; spin = @('|', '/', '-', '\') }
    } else {
        @{ tl = (U $bd[0], $bd[3]); bl = (U $bd[1], $bd[3]); v = (U $bd[2]); h = (U $bd[3]); dot = (U 0x25CF)
           ok = (U 0x2714); bad = (U 0x2716); warn = (U 0x25B2); sel = (U 0x203A); del = (U 0x2212)
           full = (U 0x2588); empty = (U 0x2591); bfull = (U 0x25B0); bempty = (U 0x25B1)
           mid = (U 0x00B7); star = (U 0x2726); on = (U 0x2714); off = ' '
           spin = $(if ($Spinner -eq 'line') { @('-', '\', '|', '/') } else { @($spinFrames[$Spinner] | ForEach-Object { U $_ }) }) }
    }

    # themes: accent colour, scope colour and the two ends of the logo gradient
    $themes = @{
        ocean   = @{ a = '110;190;255'; s = '120;220;230'; g1 = 110, 190, 255; g2 = 190, 140, 255 }
        sunset  = @{ a = '255;165;90';  s = '255;205;120'; g1 = 255, 170, 80;  g2 = 255, 90, 150 }
        forest  = @{ a = '120;220;150'; s = '170;235;190'; g1 = 110, 230, 150; g2 = 60, 180, 200 }
        neon    = @{ a = '255;110;220'; s = '120;240;255'; g1 = 255, 90, 220;  g2 = 80, 230, 255 }
        mono    = @{ a = '215;215;220'; s = '190;190;196'; g1 = 240, 240, 245; g2 = 130, 130, 140 }
        aurora  = @{ a = '100;240;200'; s = '150;200;255'; g1 = 100, 240, 200; g2 = 170, 120, 255 }
        rose    = @{ a = '255;140;170'; s = '255;190;205'; g1 = 255, 150, 170; g2 = 255, 200, 120 }
        gold    = @{ a = '255;210;90';  s = '255;230;150'; g1 = 255, 220, 100; g2 = 255, 150, 60 }
        dracula = @{ a = '189;147;249'; s = '139;233;253'; g1 = 189, 147, 249; g2 = 255, 121, 198 }
        candy   = @{ a = '255;130;200'; s = '130;220;255'; g1 = 255, 130, 200; g2 = 130, 200, 255 }
    }
    $th  = $themes[$Theme]
    $aiRgb = '200;150;255'                                              # the colour of everything AI-related
    $pal = @{
        bold = '1'; dim = '90'; text = '97'; mute = '38;2;150;156;170'
        accent = "38;2;$($th.a)"; accentb = "1;38;2;$($th.a)"; scope = "38;2;$($th.s)"
        ok = '38;2;110;220;140'; warn = '38;2;255;200;90'; err = '38;2;255;110;110'
        okb = '1;38;2;110;220;140'; errb = '1;38;2;255;110;110'
        ai = "38;2;$aiRgb"
    }
    $typeRgb = @{
        feat = '80;200;120'; fix = '240;100;100'; refactor = '180;130;255'; perf = '255;180;60'; docs = '90;170;255'; style = '255;130;200'
        test = '240;220;90'; build = '160;165;175'; ci = '100;210;210'; chore = '140;145;155'; revert = '255;120;80'
    }
    $quips = @(
        'Shipped. Your future self says thanks.', 'Clean history, clean conscience.', 'Another tiny victory for the changelog.',
        'git blame will be kind to you today.', 'Committed. No "fix stuff" was harmed.', 'Conventional, tidy and fully local. Nice.',
        'The model did the typing, you did the thinking.', 'Zero tokens left the building.'
    )

    function Get-Prop($obj, [string]$name) {                        # safe read: fine under Set-StrictMode, on $null, on missing properties
        if ($null -ne $obj -and $obj.PSObject.Properties[$name]) { $obj.PSObject.Properties[$name].Value } else { $null }
    }
    function Say([string]$s = '', [switch]$NoNewline) { Write-Host $s -NoNewline:$NoNewline }
    function Paint([string]$t, [string]$k) {
        if (-not $ui.Color -or -not $t) { return $t }
        $code = if ($pal.ContainsKey($k)) { $pal[$k] } else { $k }
        "$esc[${code}m$t$esc[0m"
    }
    function Gradient([string]$t, [int[]]$a, [int[]]$b) {            # per-character 24-bit gradient
        if (-not $ui.Color) { return $t }
        $n = [Math]::Max(1, $t.Length - 1)
        $sb = [System.Text.StringBuilder]::new()
        for ($i = 0; $i -lt $t.Length; $i++) {
            $c = for ($k = 0; $k -lt 3; $k++) { [int]($a[$k] + ($b[$k] - $a[$k]) * $i / $n) }
            [void]$sb.Append("$esc[1;38;2;$($c -join ';')m$($t[$i])")
        }
        [void]$sb.Append("$esc[0m")
        $sb.ToString()
    }
    # a coloured "pill" (inverse badge) with dark text; [text] in plain mode
    function Pill([string]$t, [string]$rgb) {
        if (-not $ui.Color) { return "[$t]" }
        "$esc[1;38;2;16;16;22;48;2;${rgb}m $t $esc[0m"
    }
    # plain progress bar: Bar 41 256 8 -> "##......"
    function Bar([int]$val, [int]$max, [int]$len = 10) {
        $fill = [Math]::Max(0, [Math]::Min($len, [int][Math]::Round($len * $val / [Math]::Max(1, $max))))
        ($g.bfull * $fill) + ($g.bempty * ($len - $fill))
    }
    function VisLen([string]$s) { ($s -replace "$esc\[[0-9;]*m", '').Length }            # length without colour codes
    function WinWidth { $w = 0; try { $w = $Host.UI.RawUI.WindowSize.Width } catch { }; if ($w -lt 40) { $w = 100 }; $w }
    function RuleWidth { [Math]::Max(40, [Math]::Min($Width, (WinWidth) - 2)) }
    function F1([double]$x) { $x.ToString('0.0', $inv) }
    function Cap([string]$k) { if ($ui.Color) { Paint " $k " '7' } else { "[$k]" } }       # inverse-video key cap
    function SetTitle([string]$t) { if ($ui.Fancy) { try { $Host.UI.RawUI.WindowTitle = $t } catch { } } }

    # "left rail" cards: no right border, so nothing misaligns with wide glyphs or Arabic text
    function CardTop([string]$title, [string]$tag = '') {
        $tagLen = if ($tag) { 1 + (VisLen $tag) } else { 0 }
        $fill   = [Math]::Max(2, (RuleWidth) - (2 + 2 + 1 + $title.Length + 1) - $tagLen)
        Say ('  ' + (Paint $g.tl 'dim') + ' ' + (Paint $title 'bold') + ' ' + (Paint ($g.h * $fill) 'dim') + $(if ($tag) { ' ' + $tag } else { '' }))
    }
    function CardBottom([string]$text = '') { Say ('  ' + (Paint $g.bl 'dim') + $(if ($text) { ' ' + (Paint $text 'mute') } else { '' })) }
    function Rail([string]$content = '') { Say ('  ' + (Paint $g.v 'dim') + ' ' + $content) }
    function Fail([string]$what, [string]$why = '') {
        Say ''
        Say ('  ' + (Paint "$($g.bad) $what" 'errb'))
        if ($why) { Say ('    ' + (Paint $why 'mute')) }
    }
    function Warn([string]$what) { Say ('  ' + (Paint "$($g.warn) $what" 'warn')) }

    # typewriter: prints colour codes atomically and the text a few characters at a time
    function Reveal([string]$s, [switch]$Instant) {
        if ($Instant -or -not $ui.Anim) { Say $s; return }
        $buf = [System.Text.StringBuilder]::new(); $vis = 0
        foreach ($m in [regex]::Matches($s, "$esc\[[0-9;]*m|[\uD800-\uDBFF][\uDC00-\uDFFF]|.")) {
            [void]$buf.Append($m.Value)
            if ($m.Value[0] -ne $esc) { $vis++ }
            if ($vis -ge 3) { Say $buf.ToString() -NoNewline; [void]$buf.Clear(); $vis = 0; Start-Sleep -Milliseconds 6 }
        }
        Say $buf.ToString()
    }

    # a bright band sweeps across a line of text (success animation); the caller prints the final line afterwards
    function Shimmer([string]$text) {
        if (-not $ui.Anim) { return }
        $n = $text.Length
        for ($pos = -3; $pos -le $n + 3; $pos++) {
            $sb = [System.Text.StringBuilder]::new('  ')
            for ($i = 0; $i -lt $n; $i++) {
                $t = [Math]::Max(0.0, 1.0 - [Math]::Abs($i - $pos) / 3.0)            # 0 = base green, 1 = white
                [void]$sb.Append("$esc[1;38;2;$([int](110 + 145 * $t));$([int](220 + 35 * $t));$([int](140 + 115 * $t))m$($text[$i])")
            }
            [void]$sb.Append("$esc[0m")
            Say ("`r" + $sb.ToString()) -NoNewline
            Start-Sleep -Milliseconds 22
        }
        Say "`r$esc[2K" -NoNewline
    }

    # one spinner frame: "<spinner> label  1.2s - 41 tok <bar> - esc to cancel   <live tail of the message>"
    # toks < 0 means "not a generation": no token counter, no bar, no key hint
    function Draw-Spin([int]$n, [string]$label, [double]$secs, [int]$toks, [string]$tail) {
        if (-not $ui.Anim) { return }
        $meta = if ($toks -ge 0) { ' {0}s {1} {2} tok' -f (F1 $secs), $g.mid, $toks } else { ' {0}s' -f (F1 $secs) }
        $bar  = if ($toks -ge 0) { ' ' + (Bar $toks $NumPredict 8) } else { '' }
        $keys = if ($toks -ge 0 -and $ui.Keys) { " $($g.mid) esc to cancel" } else { '' }
        $room = (WinWidth) - 3 - (2 + 1 + $label.Length + $meta.Length + $bar.Length + $keys.Length) - 3
        $tailTxt = ''
        if ($tail -and $room -gt 8) {
            $t = $tail -replace '\s+', ' '
            if ($t.Length -gt $room) { $t = $t.Substring($t.Length - $room) }
            $tailTxt = '  ' + $t
        }
        Say ("`r$esc[2K  " + (Paint $g.spin[$n % $g.spin.Count] 'accent') + ' ' + (Paint $label 'text') + (Paint $meta 'mute') + (Paint $bar 'accent') + (Paint $keys 'dim') + (Paint $tailTxt 'mute')) -NoNewline
    }
    function Clear-Line { if ($ui.Anim) { Say "`r$esc[2K" -NoNewline } }
    function Poll-Abort {                                                   # Esc during generation
        if (-not $ui.Keys) { return $false }
        try {
            while ([Console]::KeyAvailable) {
                if ([Console]::ReadKey($true).Key -eq [ConsoleKey]::Escape) { return $true }
            }
        } catch { $ui.Keys = $false }
        $false
    }

    # ---- input helpers (raw keys, so nothing depends on Read-Host or terminal queries) --------
    # single-key action; $null-safe fallback to a typed line where raw keys are unavailable (ISE, redirected input)
    function Read-Action {
        if ($ui.Keys) {
            try { $k = [Console]::ReadKey($true); return @{ Key = "$($k.Key)"; Char = "$($k.KeyChar)".ToLower() } } catch { $ui.Keys = $false }
        }
        $line = ([string](Read-Host '  action [Enter=commit e r v h m t s b x a f c p d q]')).Trim().ToLower()
        @{ Key = $(if ($line -eq '') { 'Enter' } else { 'Other' }); Char = $(if ($line.Length) { $line.Substring(0, 1) } else { '' }) }
    }

    # tiny line editor: Enter accepts, Esc cancels (returns $null), Backspace edits, Ctrl+U clears
    function Read-Line([string]$prompt) {
        if (-not $ui.Keys) { return [string](Read-Host "  $prompt") }
        $buf = [System.Text.StringBuilder]::new()
        $max = [Math]::Max(10, (WinWidth) - $prompt.Length - 8)
        $draw = { Say ("`r$esc[2K  " + (Paint $prompt 'accent') + ' ' + $buf.ToString()) -NoNewline }
        & $draw
        while ($true) {
            try { $k = [Console]::ReadKey($true) } catch { $ui.Keys = $false; Say ''; return [string](Read-Host "  $prompt") }
            if ($k.Key -eq [ConsoleKey]::Enter)  { Say ''; return $buf.ToString() }
            if ($k.Key -eq [ConsoleKey]::Escape) { Say (Paint '  (cancelled)' 'dim'); return $null }
            if ($k.Key -eq [ConsoleKey]::Backspace) {
                if ($buf.Length -gt 0) {
                    $cut = if ($buf.Length -ge 2 -and [char]::IsLowSurrogate($buf[$buf.Length - 1])) { 2 } else { 1 }
                    [void]$buf.Remove($buf.Length - $cut, $cut)
                }
            } elseif ($k.Key -eq [ConsoleKey]::U -and ($k.Modifiers -band [ConsoleModifiers]::Control)) {
                [void]$buf.Clear()
            } elseif ($k.KeyChar -and -not [char]::IsControl($k.KeyChar) -and $buf.Length -lt $max) {
                [void]$buf.Append($k.KeyChar)
            }
            & $draw
        }
    }

    function Confirm-Key([string]$question, [bool]$defaultYes = $false) {
        $opt = if ($defaultYes) { 'Y/n' } else { 'y/N' }
        if ($ui.Keys) {
            Say ('  ' + (Paint $question 'warn') + (Paint " [$opt] " 'dim')) -NoNewline
            $k = $null
            try { $k = [Console]::ReadKey($true) } catch { $ui.Keys = $false }
            if ($k) {
                $yes = if ($k.Key -eq [ConsoleKey]::Enter) { $defaultYes } else { "$($k.KeyChar)".ToLower() -eq 'y' }
                Say (Paint $(if ($yes) { 'yes' } else { 'no' }) 'mute')
                return [bool]$yes
            }
            Say ''
        }
        $a = ([string](Read-Host "  $question [$opt]")).Trim().ToLower()
        if ($a -eq '') { return $defaultYes }
        ($a -eq 'y' -or $a -eq 'yes')
    }

    # arrow-key picker (numbered prompt where raw keys / ANSI are unavailable). Returns index or -1.
    function Pick-One([string]$title, [string[]]$labels, [int]$start = 0) {
        $n = $labels.Count
        if ($n -eq 0) { return -1 }
        if (-not ($ui.Fancy -and $ui.Keys)) {
            Say (Paint $title 'accent')
            for ($i = 0; $i -lt $n; $i++) { Say ('  {0,2}) {1}' -f ($i + 1), $labels[$i]) }
            $num = 0
            if ([int]::TryParse([string](Read-Host '  number (blank = cancel)'), [ref]$num) -and $num -ge 1 -and $num -le $n) { return $num - 1 }
            return -1
        }
        $rows = [Math]::Min($n, 12); $sel = [Math]::Min([Math]::Max($start, 0), $n - 1); $top = 0; $w = WinWidth
        Say ''
        Say ('  ' + (Paint $title 'accentb'))
        Say ('  ' + (Paint "up/down move $($g.mid) Enter select $($g.mid) Esc cancel" 'dim'))
        Say "$esc[?25l" -NoNewline
        $first = $true
        try {
            while ($true) {
                if ($sel -lt $top) { $top = $sel } elseif ($sel -ge $top + $rows) { $top = $sel - $rows + 1 }
                if (-not $first) { Say "$esc[${rows}A" -NoNewline }
                $first = $false
                for ($i = $top; $i -lt $top + $rows; $i++) {
                    $t = $labels[$i]; if ($t.Length -gt $w - 8) { $t = $t.Substring(0, $w - 9) + '~' }
                    if ($i -eq $sel) { Say ("`r$esc[2K  " + (Paint "$($g.sel) $t" 'accentb')) } else { Say ("`r$esc[2K    " + (Paint $t 'mute')) }
                }
                $k = [Console]::ReadKey($true)
                switch ("$($k.Key)") {
                    'UpArrow'   { $sel = ($sel - 1 + $n) % $n }
                    'DownArrow' { $sel = ($sel + 1) % $n }
                    'Home'      { $sel = 0 }
                    'End'       { $sel = $n - 1 }
                    'Enter'     { return $sel }
                    'Escape'    { return -1 }
                    default {
                        if ($k.KeyChar -eq 'k') { $sel = ($sel - 1 + $n) % $n }
                        elseif ($k.KeyChar -eq 'j') { $sel = ($sel + 1) % $n }
                        elseif ($k.KeyChar -eq 'q') { return -1 }
                    }
                }
            }
        } finally {
            Say "$esc[$($rows + 3)A$esc[J$esc[?25h" -NoNewline        # erase the picker, show the cursor again
        }
    }

    # checklist picker: Space toggles, a = all, n = none, i = tick AI files, Enter confirms.
    # $ai is an optional bool[] marking AI-related rows. Returns bool[] or $null (cancelled / no raw keys)
    function Pick-Many([string]$title, [string[]]$labels, [bool[]]$checked, $ai = $null) {
        $n = $labels.Count
        if ($n -eq 0 -or -not ($ui.Fancy -and $ui.Keys)) { return $null }
        $rows = [Math]::Min($n, 14); $sel = 0; $top = 0; $w = WinWidth
        $on = [bool[]]@($checked)
        $hasAi = [bool]($ai -and @($ai | Where-Object { $_ }).Count)
        $hint = "Space toggle $($g.mid) a all $($g.mid) n none $($g.mid) " + $(if ($hasAi) { "i AI files $($g.mid) " } else { '' }) + "Enter confirm $($g.mid) Esc cancel"
        Say ''
        Say ('  ' + (Paint $title 'accentb'))
        Say ('  ' + (Paint $hint 'dim'))
        Say "$esc[?25l" -NoNewline
        $first = $true
        try {
            while ($true) {
                if ($sel -lt $top) { $top = $sel } elseif ($sel -ge $top + $rows) { $top = $sel - $rows + 1 }
                if (-not $first) { Say "$esc[$($rows + 1)A" -NoNewline }
                $first = $false
                for ($i = $top; $i -lt $top + $rows; $i++) {
                    $t = $labels[$i]; if ($t.Length -gt $w - 17) { $t = $t.Substring(0, $w - 18) + '~' }
                    $box = if ($on[$i]) { Paint "[$($g.on)]" 'ok' } else { Paint "[$($g.off)]" 'dim' }
                    $lead = if ($i -eq $sel) { Paint $g.sel 'accentb' } else { ' ' }
                    $tag = if ($ai -and $ai[$i]) { Paint 'AI' 'ai' } else { '  ' }
                    $body = if ($t -match '^([MADRCU?])  (.*)$') {                         # git status letter, coloured
                        $c = switch ($Matches[1]) { 'M' { 'warn' } 'A' { 'ok' } 'D' { 'err' } 'R' { 'accent' } 'C' { 'accent' } default { 'mute' } }
                        (Paint $Matches[1] $c) + '  ' + $(if ($i -eq $sel) { Paint $Matches[2] 'text' } else { Paint $Matches[2] 'mute' })
                    } else { $(if ($i -eq $sel) { Paint $t 'text' } else { Paint $t 'mute' }) }
                    Say ("`r$esc[2K  $lead $box $tag $body")
                }
                $cnt = @($on | Where-Object { $_ }).Count
                Say ("`r$esc[2K  " + (Paint "$cnt of $n selected" 'dim'))
                $k = [Console]::ReadKey($true)
                switch ("$($k.Key)") {
                    'UpArrow'   { $sel = ($sel - 1 + $n) % $n }
                    'DownArrow' { $sel = ($sel + 1) % $n }
                    'Home'      { $sel = 0 }
                    'End'       { $sel = $n - 1 }
                    'Spacebar'  { $on[$sel] = -not $on[$sel] }
                    'Enter'     { return , $on }
                    'Escape'    { return $null }
                    default {
                        switch ("$($k.KeyChar)".ToLower()) {
                            'k' { $sel = ($sel - 1 + $n) % $n }
                            'j' { $sel = ($sel + 1) % $n }
                            'a' { for ($i = 0; $i -lt $n; $i++) { $on[$i] = $true } }
                            'n' { for ($i = 0; $i -lt $n; $i++) { $on[$i] = $false } }
                            'i' { if ($ai) { for ($i = 0; $i -lt $n; $i++) { if ($ai[$i]) { $on[$i] = $true } } } }
                            'q' { return $null }
                        }
                    }
                }
            }
        } finally {
            Say "$esc[$($rows + 4)A$esc[J$esc[?25h" -NoNewline
        }
    }

    # =========================================================================================
    # 3) message logic: prompt, clean-up, validation
    # =========================================================================================
    $types     = 'feat', 'fix', 'refactor', 'perf', 'docs', 'style', 'test', 'build', 'ci', 'chore', 'revert'
    $trimChars = [char[]](96, 34, 39, 32)                                  # ` " ' and space
    $rxParse   = '^(?<type>[A-Za-z]+)(?:\((?<scope>[^)\r\n]*)\))?(?<bang>!)?:\s*(?<subj>.*)$'
    $rxStrict  = '^(feat|fix|refactor|perf|docs|style|test|build|ci|chore|revert)(\([^)\r\n]+\))?!?: \S.*$'

    # ---- AI-related files -----------------------------------------------------------------------------
    # regexes on the repo-relative path (forward slashes, case-insensitive) + your own globs (-AiPattern / "aiFiles")
    $aiRx = @(
        '(^|/)\.aic\.json$'
        '(^|/)(claude|agents|gemini|copilot|qwen|codex)\.md$'
        '(^|/)\.(cursorrules|windsurfrules)$'
        '(^|/)\.clinerules(/|$)'
        '(^|/)\.aider[^/]*$'
        '(^|/)\.(claude|cursor|continue|windsurf|roo|cline|codex|gemini|ollama|tabby|agents?)/'
        '(^|/)\.github/(copilot-instructions\.md$|instructions/|prompts/|chatmodes/|agents/)'
        '(^|/)\.?mcp([-_]config)?\.json$'
        '(^|/)\.vscode/mcp\.json$'
        '(^|/)modelfile(\.[^/]*)?$'
        '(^|/)llms(-full)?\.txt$'
        '(^|/)prompts?/'
        '\.(prompt|prompty)(\.md|\.txt|\.ya?ml)?$'
        '\.mdc$'
        '(^|/)skills/[^/]+/SKILL\.md$'
    )
    $aiNoise = '\.aider\.(chat\.history|input\.history|tags\.cache)'   # aider's own scratch files: never "AI config"
    function Test-AiPath([string]$p) {
        $q = ($p -replace '\\', '/').TrimStart('/')
        if ($q -match $aiNoise) { return $false }
        foreach ($rx in $aiRx) { if ($q -match $rx) { return $true } }
        $leaf = [System.IO.Path]::GetFileName($q.TrimEnd('/'))
        foreach ($gl in $aiGlobs) { if ($q -like $gl -or $leaf -like $gl) { return $true } }
        $false
    }

    # gitmoji (-Emoji / "emoji": true): built from code points; U+FE0F forces emoji presentation of a text-style symbol
    $emap    = @{ feat = 0x2728; fix = 0x1F41B; refactor = 0x267B; perf = 0x26A1; docs = 0x1F4DD; style = 0x1F484; test = 0x2705; build = 0x1F4E6; ci = 0x1F477; chore = 0x1F527; revert = 0x23EA }
    $rxEmoji = '^(?:[\uD83C-\uD83E][\uDC00-\uDFFF]|[\u2300-\u23FF\u2600-\u27BF\u2B00-\u2BFF]\uFE0F?)+\s*'
    function Get-Emoji([string]$t) {
        if (-not $emap.ContainsKey($t)) { return '' }
        $e = [char]::ConvertFromUtf32($emap[$t])
        if ($t -eq 'refactor') { $e += [string][char]0xFE0F }
        $e
    }

    # builds the header; a leading emoji is added when gitmoji is on and stripped when it is off (so the x key can toggle it)
    function Join-Header([string]$t, [string]$sc, [bool]$bang, [string]$subj) {
        $em = if ($useEmoji) { Get-Emoji $t } else { '' }
        $clean = $subj -replace $rxEmoji, ''
        $subj = if ($em) { "$em $clean" } else { $clean }
        $t + $(if ($sc) { "($sc)" } else { '' }) + $(if ($bang) { '!' } else { '' }) + ': ' + $subj
    }
    function Get-Bang([string]$msg) { [regex]::Match((($msg -split '\r?\n')[0]), $rxParse).Groups['bang'].Success }
    function Get-Type([string]$msg) {
        $m = [regex]::Match((($msg -split '\r?\n')[0]), $rxParse)
        if ($m.Success) { $m.Groups['type'].Value.ToLower() } else { '' }
    }

    # rewrite type / scope / "!" of the header without touching the subject or body
    function Set-Prefix([string]$msg, [hashtable]$set) {
        $nl    = $msg.IndexOf("`n")
        $first = if ($nl -ge 0) { $msg.Substring(0, $nl) } else { $msg }
        $rest  = if ($nl -ge 0) { $msg.Substring($nl) } else { '' }
        $m     = [regex]::Match($first, $rxParse)
        $t  = if ($set.ContainsKey('Type'))  { $set.Type }  elseif ($m.Success) { $m.Groups['type'].Value.ToLower() } else { 'chore' }
        $sc = if ($set.ContainsKey('Scope')) { $set.Scope } elseif ($m.Success -and $m.Groups['scope'].Success) { $m.Groups['scope'].Value } else { '' }
        $b  = if ($set.ContainsKey('Bang'))  { [bool]$set.Bang } elseif ($m.Success) { $m.Groups['bang'].Success } else { $false }
        $s  = if ($m.Success) { $m.Groups['subj'].Value } else { $first }
        (Join-Header $t $sc $b $s) + $rest
    }

    # models love to add fences, <think> blocks, preambles, capitals and trailing dots: tidy all of it
    function Normalize-Message([string]$raw) {
        $m = $raw -replace '(?s)<think>.*?</think>', '' -replace '(?s)<think>.*$', ''
        $m = ($m.Trim() -replace '^\x60{3}[A-Za-z]*\s*', '' -replace '\s*\x60{3}\s*$', '').Trim()
        if (-not $m) { return '' }
        $lines = @($m -split '\r?\n')
        $start = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim($trimChars) -match '^[A-Za-z]+(\([^)]*\))?!?:\s*\S') { $start = $i; break }
        }
        $hdr = $lines[$start].Trim($trimChars)
        $pm  = [regex]::Match($hdr, $rxParse)
        if ($pm.Success) {
            $s = $pm.Groups['subj'].Value.Trim($trimChars).TrimEnd('.', ' ')
            if ($s -cmatch '^[A-Z][a-z]+(\s|$)') { $s = $s.Substring(0, 1).ToLower() + $s.Substring(1) }   # "Add x" -> "add x"
            $sc = if ($pm.Groups['scope'].Success) { $pm.Groups['scope'].Value.Trim() } else { '' }
            $hdr = Join-Header $pm.Groups['type'].Value.ToLower() $sc $pm.Groups['bang'].Success $s
        }
        $bul = [System.Collections.Generic.List[string]]::new()
        $foot = [System.Collections.Generic.List[string]]::new()
        $rest = if ($lines.Count -gt $start + 1) { $lines[($start + 1)..($lines.Count - 1)] } else { @() }
        foreach ($l in $rest) {
            $t = $l.Trim()
            if (-not $t) { continue }
            if ($t -match '^(BREAKING[ -]CHANGE|Refs?|Closes|Fixes|Co-authored-by|Signed-off-by)\b') { $foot.Add($t); continue }
            $t = $t -replace '^[\*\u2022]\s+', '- '
            if ($t -notmatch '^-\s') { $t = "- $t" }
            $bul.Add($t)
        }
        if ($Bullets -eq 0) { $bul.Clear() } elseif ($bul.Count -gt $Bullets) { $bul.RemoveRange($Bullets, $bul.Count - $Bullets) }
        if ($Ref -and -not ($foot | Where-Object { $_ -like "*$Ref*" })) { $foot.Add("Refs: $Ref") }
        $out = $hdr
        if ($bul.Count)  { $out += "`n`n" + ($bul -join "`n") }
        if ($foot.Count) { $out += "`n`n" + ($foot -join "`n") }
        # honour what the user forced (flags or menu), even if a small model ignored the prompt
        $set = @{}
        if ($st.Type)    { $set.Type  = $st.Type }
        if ($st.NoScope) { $set.Scope = '' } elseif ($st.Scope) { $set.Scope = $st.Scope }
        if ($st.Bang)    { $set.Bang  = $true }
        if ($set.Count -or $useEmoji) { $out = Set-Prefix $out $set }
        $out
    }

    function Test-Message([string]$msg) {
        $p = [System.Collections.Generic.List[string]]::new()
        $first = ($msg -split '\r?\n')[0]
        if ($first -cnotmatch $rxStrict) { $p.Add("header is not 'type(scope): subject'") }
        elseif ($first.Length -gt 72)    { $p.Add("subject line is $($first.Length) chars (max 72)") }
        $m = [regex]::Match($first, $rxParse)
        if ($cfgScopes.Count -and $m.Success -and $m.Groups['scope'].Value -and ($cfgScopes -notcontains $m.Groups['scope'].Value)) {
            $p.Add("scope '$($m.Groups['scope'].Value)' is not one of: $($cfgScopes -join ', ')")
        }
        return , $p.ToArray()
    }

    # a scope candidate from one path: "src/app/dashboard/page.tsx" -> dashboard ('' for files at the top level)
    function Get-ScopeCandidate([string]$path) {
        $generic = 'src', 'source', 'app', 'apps', 'lib', 'libs', 'packages', 'pkg', 'internal', 'cmd'
        $seg = @($path -split '/')
        $i = 0; while ($i -lt $seg.Count - 1 -and $generic -contains $seg[$i].ToLower()) { $i++ }
        if ($i -lt $seg.Count - 1) { ($seg[$i] -replace '[^A-Za-z0-9._-]', '').ToLower() } else { '' }
    }
    function Get-ScopeHint([string[]]$paths) {
        $u = @($paths | ForEach-Object { Get-ScopeCandidate $_ } | Select-Object -Unique)
        if ($u.Count -eq 1 -and $u[0]) { $u[0] } else { '' }
    }

    # keep the prompt inside MaxChars but give EVERY file a fair share (small files free budget for big ones)
    function Shrink-Diff([string]$diffText, [int]$budget) {
        if ($diffText.Length -le $budget) { return $diffText }
        $chunks = @($diffText -split '(?m)^(?=diff --git )' | Where-Object { $_ })
        if ($chunks.Count -eq 0) { return $diffText.Substring(0, $budget) + "`n[... diff truncated ...]" }
        $left = $budget; $n = $chunks.Count; $keep = @{}
        foreach ($ix in (0..($chunks.Count - 1) | Sort-Object { $chunks[$_].Length })) {
            $share = [int][Math]::Floor($left / $n); $n--
            $c = $chunks[$ix]
            if ($c.Length -gt $share) { $c = $c.Substring(0, $share) + "`n[... truncated ...]`n" }
            $left -= [Math]::Min($chunks[$ix].Length, $share)
            $keep[$ix] = $c
        }
        -join (0..($chunks.Count - 1) | ForEach-Object { $keep[$_] })
    }

    # warn (never send anywhere: everything stays local) about files / added lines that look like secrets
    $secretRules = [ordered]@{
        'AWS access key id'    = 'AKIA[0-9A-Z]{16}'
        'private key block'    = '-----BEGIN (?:RSA |EC |DSA |OPENSSH |PGP )?PRIVATE KEY'
        'GitHub token'         = 'gh[pousr]_[A-Za-z0-9]{36,}'
        'Slack token'          = 'xox[baprs]-[A-Za-z0-9-]{10,}'
        'Stripe live key'      = '[sr]k_live_[0-9A-Za-z]{20,}'
        'Google API key'       = 'AIza[0-9A-Za-z_-]{35}'
        'JWT'                  = 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
        'database URL with password' = '(?:mongodb(?:\+srv)?|postgres(?:ql)?|mysql|redis)://[^\s:/@''"]+:[^\s@/''"]{3,}@'
        'hard-coded secret'    = '(?i)(?:api[_-]?key|secret|token|passw(?:or)?d)["'']?\s*[:=]\s*["''][^"''\s]{12,}["'']'
    }
    function Find-Secrets([string[]]$paths, [string]$diffText) {
        $hits = [System.Collections.Generic.List[string]]::new()
        foreach ($p in $paths) {
            if ($p -match '(^|/)\.env(\.[^/]+)?$' -and $p -notmatch '\.(example|sample|template|dist)$') { $hits.Add("$p - environment file (usually holds secrets)") }
            elseif ($p -match '\.(pem|p12|pfx|jks|keystore)$|(^|/)id_(rsa|dsa|ecdsa|ed25519)$|service[-_]?account[^/]*\.json$') { $hits.Add("$p - key / credential file") }
        }
        $rxPlaceholder = '(?i)example|your[-_ ]|xxxx|placeholder|changeme|dummy|<.+>|\$\{|:(password|pass|secret|root|admin|postgres)@'
        $scan = if ($diffText.Length -gt 3MB) { $diffText.Substring(0, 3MB) } else { $diffText }      # keep the scan quick on huge diffs
        foreach ($rule in $secretRules.Keys) {
            try {
                $rx = [regex]::new('(?m)^\+(?!\+\+).*?(?:' + $secretRules[$rule] + ')', [System.Text.RegularExpressions.RegexOptions]::None, [TimeSpan]::FromSeconds(2))
                foreach ($m in $rx.Matches($scan)) {
                    if ($rule -in 'hard-coded secret', 'database URL with password' -and $m.Value -match $rxPlaceholder) { continue }
                    $h = $scan.LastIndexOf('diff --git ', $m.Index)
                    $file = if ($h -ge 0 -and $scan.Substring($h, [Math]::Min(300, $scan.Length - $h)) -match 'diff --git a/.+? b/(.+?)\r?\n') { $Matches[1] } else { 'staged diff' }
                    if ($file -match '\.(example|sample|template|dist)$') { continue }            # templates hold placeholders by design
                    $hit = "$file - $rule"
                    if (-not $hits.Contains($hit)) { $hits.Add($hit) }
                }
            } catch [System.Text.RegularExpressions.RegexMatchTimeoutException] { continue }
        }
        return , $hits.ToArray()
    }

    function Build-Messages([string]$note) {
        $repo = $ctx.Repo
        $sys = [System.Collections.Generic.List[string]]::new()
        $sys.Add('You are an expert developer who writes git commit messages.')
        $sys.Add('Use Conventional Commits: type(scope): subject')
        $sys.Add('type is one of: feat, fix, refactor, perf, docs, style, test, build, ci, chore.')
        $sys.Add('Subject: imperative mood, lowercase, no trailing period, max 72 characters.')
        if ($Bullets -gt 0) { $sys.Add(('For non-trivial changes add a blank line, then up to {0} bullets ("- ") explaining what changed and why.' -f $Bullets)) }
        else                { $sys.Add('Output the subject line only: no body, no bullets.') }
        $sys.Add('Describe only what is visible in the diff. Never invent details.')
        if ($Language -notmatch '^(en|english)$') { $sys.Add("Write the subject and bullets in $Language. Keep the type and scope in English.") }
        if ($st.Type)    { $sys.Add("The type MUST be: $($st.Type)") }
        if ($st.NoScope) { $sys.Add('Do not use a scope.') }
        elseif ($st.Scope) { $sys.Add("The scope MUST be: $($st.Scope)") }
        elseif ($cfgScopes.Count) { $sys.Add("Allowed scopes: $($cfgScopes -join ', '). Use exactly one of them, or omit the scope if none fits.") }
        if ($repo.AllAi -and -not $st.Type) { $sys.Add('Every changed file is AI tooling (prompts, agent rules, model or editor AI config). Prefer type chore (docs for pure documentation) and say what changes for the AI behaviour.') }
        $sys.Add('Output ONLY the commit message: no markdown fences, no quotes, no preamble.')
        $sys.Add('')
        $sys.Add('Example:')
        $sys.Add('fix(api): return 404 when the user does not exist')
        if ($Bullets -gt 0) { $sys.Add(''); $sys.Add('- throw NotFoundError instead of returning null'); $sys.Add('- add a test for the missing-user case') }

        $usr = [System.Collections.Generic.List[string]]::new()
        $usr.Add("Branch: $($repo.Branch)")
        if ($repo.Recent) { $usr.Add("Recent commits (style reference only, never copy them):`n$($repo.Recent)") }
        if ($repo.ScopeHint -and -not $st.Scope -and -not $st.NoScope -and (-not $cfgScopes.Count -or $cfgScopes -contains $repo.ScopeHint)) {
            $usr.Add("Likely scope (use it only if it fits): $($repo.ScopeHint)")
        }
        if ($repo.AiPaths.Count -and -not $repo.AllAi) {
            $usr.Add("Some changed files are AI tooling configs: $((@($repo.AiPaths) | Select-Object -First 5) -join ', '). Mention them only if they matter.")
        }
        if ($st.Hint) { $usr.Add("Note from the author (context only, do not quote): $($st.Hint)") }
        if ($note)    { $usr.Add($note) }
        $usr.Add("Files changed:`n$($repo.Stat)")
        $usr.Add("Diff:`n$($repo.Diff)")
        if ($st.Model -match 'qwen3') { $usr.Add('/no_think') }          # Qwen3 soft switch: covers Ollama versions that predate the `think` option
        return , @(
            @{ role = 'system'; content = ($sys -join "`n") }
            @{ role = 'user';   content = ($usr -join "`n`n") }
        )
    }

    # =========================================================================================
    # 4) Ollama: capabilities + streaming generation with spinner, live tail and Esc-to-cancel
    # =========================================================================================
    $capCache = @{}
    function Test-Cap([string]$name, [string]$cap) {
        if (-not $capCache.ContainsKey($name)) {
            $caps = @()
            try {
                $body = @{ model = $name; name = $name } | ConvertTo-Json
                $caps = @((Invoke-RestMethod -Uri "$base/api/show" -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 5).capabilities)
            } catch { }
            $capCache[$name] = $caps
        }
        [bool]($capCache[$name] -contains $cap)
    }

    function Invoke-Generate([string]$ModelName, $Messages, [double]$Temp) {
        $res = @{ Text = ''; Tokens = 0; Thought = 0; EvalCount = 0; EvalNs = 0; Seconds = 0.0; Cancelled = $false; Error = $null }
        [void]$used.Add($ModelName)
        # context window big enough for prompt + answer (code is roughly 2.8 chars per token)
        $chars   = ($Messages | ForEach-Object { $_.content.Length } | Measure-Object -Sum).Sum
        $ctxSize = [Math]::Max($NumCtx, [int]([Math]::Ceiling(($chars / 2.8 + $NumPredict + 64) / 1024) * 1024))
        $payload = [ordered]@{
            model = $ModelName; stream = $true; keep_alive = $KeepAlive; messages = $Messages
            options = @{ temperature = $Temp; num_ctx = $ctxSize; num_predict = $NumPredict }
        }
        # thinking models (qwen3, deepseek-r1 ...) would burn the whole token budget on reasoning: switch it off
        if (Test-Cap $ModelName 'thinking') { $payload['think'] = $false }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Depth 8 -Compress))

        $handler = [System.Net.Http.HttpClientHandler]::new()
        if ($uri.IsLoopback) { $handler.UseProxy = $false }
        $http   = [System.Net.Http.HttpClient]::new($handler)
        $http.Timeout = [TimeSpan]::FromSeconds($TimeoutSec)
        $sw     = [System.Diagnostics.Stopwatch]::StartNew()
        $resp   = $null; $reader = $null
        $text   = [System.Text.StringBuilder]::new()
        $frame  = 0; $lastDraw = -1000

        if ($ui.Anim) { Say "$esc[?25l" -NoNewline } else { Say (Paint "  Generating with $ModelName ..." 'dim') }
        try {
            $req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Post, "$base/api/chat")
            $req.Content = [System.Net.Http.ByteArrayContent]::new($bytes)
            $req.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
            $send = $http.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)

            # (a) waiting for the first byte = model load + prompt evaluation
            while (-not $send.IsCompleted) {
                if ($sw.ElapsedMilliseconds - $lastDraw -ge 80) {
                    $frame++
                    Draw-Spin $frame 'reading diff' $sw.Elapsed.TotalSeconds 0 ''
                    $lastDraw = $sw.ElapsedMilliseconds
                    if (Poll-Abort) { $res.Cancelled = $true; $http.CancelPendingRequests(); return $res }
                }
                if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) { $res.Error = "timed out after $TimeoutSec s"; $http.CancelPendingRequests(); return $res }
                Start-Sleep -Milliseconds 25
            }
            if ($send.IsFaulted -or $send.IsCanceled) {
                $inner = if ($send.Exception) { $send.Exception.GetBaseException().Message } else { 'request cancelled' }
                $res.Error = if ($inner -match 'refused|No connection|actively|unreachable|Name or service') { "can't reach Ollama at $base (is it running?)" } else { $inner }
                return $res
            }
            $resp = $send.Result
            if (-not $resp.IsSuccessStatusCode) {
                $raw = $resp.Content.ReadAsStringAsync().Result
                $em  = try { Get-Prop ($raw | ConvertFrom-Json) 'error' } catch { $null }
                $res.Error = if ($em) { [string]$em } else { "HTTP $([int]$resp.StatusCode)" }
                return $res
            }

            # (b) NDJSON stream: one JSON object per line, roughly one token each
            $reader   = [System.IO.StreamReader]::new($resp.Content.ReadAsStreamAsync().Result, [System.Text.Encoding]::UTF8)
            $lineTask = $reader.ReadLineAsync()
            while ($true) {
                if ($sw.ElapsedMilliseconds - $lastDraw -ge 80) {
                    $lbl = if ($res.Tokens -gt 0) { 'writing' } elseif ($res.Thought -gt 0) { 'thinking' } else { 'reading diff' }
                    $frame++
                    Draw-Spin $frame $lbl $sw.Elapsed.TotalSeconds ($res.Tokens + $res.Thought) $text.ToString()
                    $lastDraw = $sw.ElapsedMilliseconds
                    if (Poll-Abort) { $res.Cancelled = $true; $http.CancelPendingRequests(); return $res }
                }
                if ($sw.Elapsed.TotalSeconds -gt $TimeoutSec) { $res.Error = "timed out after $TimeoutSec s"; return $res }
                if (-not $lineTask.IsCompleted) { Start-Sleep -Milliseconds 20; continue }
                $line = $lineTask.Result
                if ($null -eq $line) { break }
                if ($line.Trim()) {
                    $o = $null
                    try { $o = $line | ConvertFrom-Json } catch { }
                    if ($o) {
                        $oErr = Get-Prop $o 'error'
                        if ($oErr) { $res.Error = [string]$oErr; return $res }
                        $oMsg = Get-Prop $o 'message'
                        $oTxt = Get-Prop $oMsg 'content'
                        if ($oTxt)                         { [void]$text.Append([string]$oTxt); $res.Tokens++ }
                        elseif (Get-Prop $oMsg 'thinking') { $res.Thought++ }
                        if (Get-Prop $o 'done') { $res.EvalCount = [int64](Get-Prop $o 'eval_count'); $res.EvalNs = [int64](Get-Prop $o 'eval_duration') }
                    }
                }
                $lineTask = $reader.ReadLineAsync()
            }
            $res.Text = $text.ToString()
            if (-not $res.Text.Trim() -and $res.Thought -gt 0) { $res.Error = 'the model spent its whole token budget thinking (raise -NumPredict or pick a non-reasoning model)' }
            return $res
        } finally {
            $res.Seconds = $sw.Elapsed.TotalSeconds
            Clear-Line
            if ($ui.Anim) { Say "$esc[?25h" -NoNewline }
            if ($reader) { $reader.Dispose() }
            if ($resp)   { $resp.Dispose() }
            $http.Dispose()
        }
    }

    # generate (+ automatic format retries). Fills $st.Msg / $st.Problems / $st.Meta, returns ok | cancelled | error
    function New-Message {
        $note = ''
        for ($try = 0; $try -le $Retries; $try++) {
            $temp = [Math]::Min(0.9, $Temperature + 0.2 * ($st.Regen + $try))    # a bit more creative on every retry
            $gen  = Invoke-Generate $st.Model (Build-Messages $note) $temp
            if ($gen.Cancelled) { return 'cancelled' }
            if ($gen.Error) {
                Fail 'Generation failed' $gen.Error
                if ($gen.Error -match 'not found') { Say ('    ' + (Paint "ollama pull $($st.Model)" 'accent')) }
                return 'error'
            }
            $msg = Normalize-Message $gen.Text
            if (-not $msg) { Fail 'The model returned an empty message' 'Press r to retry, or try another -Model.'; return 'error' }
            $prob = Test-Message $msg
            $tokN = if ($gen.EvalCount -gt 0) { $gen.EvalCount } else { $gen.Tokens }
            $rate = if ($gen.EvalNs -gt 0) { " $($g.mid) $(F1 ($gen.EvalCount / ($gen.EvalNs / 1e9))) tok/s" } else { '' }
            $st.Msg = $msg; $st.Problems = $prob
            $st.Meta = "$tokN tok $($g.mid) $(F1 $gen.Seconds)s$rate $($g.mid) $($st.Model)" + $(if ($try -gt 0) { " $($g.mid) attempt $($try + 1)" } else { '' })
            if ($prob.Count -eq 0) { break }
            if ($try -lt $Retries) {
                Warn "$($prob[0]) - retrying ($($try + 1)/$Retries)"
                $note = "Your previous answer was rejected: $($prob -join '; '). Follow the format exactly."
            }
        }
        'ok'
    }

    # several alternatives at rising temperature (the v key). Returns distinct, normalised messages.
    function Get-Variants {
        $found = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt $Variants; $i++) {
            $temp = [Math]::Min(0.95, $Temperature + 0.25 * ($i + 1))
            $gen  = Invoke-Generate $st.Model (Build-Messages '') $temp
            if ($gen.Cancelled) { break }
            if ($gen.Error) { Fail 'Generation failed' $gen.Error; break }
            $m = Normalize-Message $gen.Text
            if ($m -and -not $found.Contains($m)) { $found.Add($m) }
        }
        return , $found.ToArray()
    }

    # =========================================================================================
    # 5) screens
    # =========================================================================================
    function Format-Line([string]$l, [bool]$isFirst) {
        if ($isFirst) {
            $m = [regex]::Match($l, $rxParse)
            if (-not $m.Success) { return (Paint $l 'bold') }
            $t   = $m.Groups['type'].Value.ToLower()
            $col = if ($typeRgb.ContainsKey($t)) { "1;38;2;$($typeRgb[$t])" } else { '1;97' }
            $o   = Paint $t $col
            if ($m.Groups['scope'].Success) { $o += (Paint '(' 'dim') + (Paint $m.Groups['scope'].Value 'scope') + (Paint ')' 'dim') }
            if ($m.Groups['bang'].Success)  { $o += Paint '!' 'errb' }
            return $o + (Paint ': ' 'dim') + (Paint $m.Groups['subj'].Value '1;97')
        }
        if ($l -match '^-\s') { return (Paint '-' 'dim') + (Paint $l.Substring(1) 'mute') }
        if ($l.Trim())        { return Paint $l 'dim' }
        ''
    }

    function Show-Header {
        if ($Banner -eq 'none') { return }
        Say ''
        if ($Banner -eq 'big' -and -not $ui.Plain) {                      # two-row block logo with the theme gradient
            $up = U 0x2580; $lo = U 0x2584; $fb = U 0x2588
            $r1 = "$lo$up$fb  $fb  $fb$up$up"
            $r2 = "$fb$up$fb  $fb  $fb$lo$lo"
            Say ('  ' + (Gradient $r1 $th.g1 $th.g2) + '   ' + (Paint 'AI commit' 'bold'))
            Say ('  ' + (Gradient $r2 $th.g1 $th.g2) + '   ' + (Paint "Conventional Commits $($g.mid) local Ollama $($g.mid) private" 'mute'))
            return
        }
        Say ('  ' + (Gradient "$($g.star) aic" $th.g1 $th.g2) + '  ' + (Paint "AI commit $($g.mid) local & private" 'mute'))
    }

    function Show-Stat {
        $files = $ctx.Files
        $adds = [int](($files | Measure-Object Add -Sum).Sum); $dels = [int](($files | Measure-Object Del -Sum).Sum)
        CardTop $(if ($Amend) { 'Amending last commit' } else { 'Staged changes' }) (Paint $branch 'scope')
        $show = @($files | Sort-Object @{ Expression = { $_.Add + $_.Del }; Descending = $true }, Path | Select-Object -First 8)
        $maxT = [Math]::Max(1, [int](($show | ForEach-Object { $_.Add + $_.Del } | Measure-Object -Maximum).Maximum))
        $room = [Math]::Max(12, (RuleWidth) - 39)
        foreach ($f in $show) {
            $t = $f.Add + $f.Del
            if ($f.Bin) { $bar = Paint ($g.empty * 12) 'dim'; $nums = (Paint '  bin' 'mute') + (Paint '     ' 'dim') }
            else {
                $fill = if ($t -gt 0) { [Math]::Max(1, [int][Math]::Round(12 * $t / $maxT)) } else { 0 }
                $gr   = if ($t -gt 0) { [int][Math]::Round($fill * $f.Add / $t) } else { 0 }
                $bar  = (Paint ($g.full * $gr) 'ok') + (Paint ($g.full * ($fill - $gr)) 'err') + (Paint ($g.empty * (12 - $fill)) 'dim')
                $nums = (Paint ('+' + "$($f.Add)".PadLeft(4)) 'ok') + ' ' + (Paint ($g.del + "$($f.Del)".PadLeft(4)) 'err')
            }
            $p = $f.Path; if ($p.Length -gt $room) { $p = '~' + $p.Substring($p.Length - $room + 1) }
            $aiTag = if (Test-AiPath $f.Path) { (Paint 'AI' 'ai') + ' ' } else { '   ' }
            Rail ($nums + '  ' + $bar + '  ' + $aiTag + $p)
        }
        $more = if ($files.Count -gt $show.Count) { " $($g.mid) +$($files.Count - $show.Count) more" } else { '' }
        $aiN  = @($files | Where-Object { Test-AiPath $_.Path }).Count
        $aiTx = if ($aiN) { " $($g.mid) $aiN AI" } else { '' }
        CardBottom ("$($files.Count) file$(if ($files.Count -ne 1) { 's' }) $($g.mid) +$adds $($g.del)$dels$aiTx$more")
        foreach ($f in $st.Findings) { Warn "possible secret: $f" }
        $areas = @($files | ForEach-Object { Get-ScopeCandidate $_.Path } | Where-Object { $_ } | Select-Object -Unique).Count
        if ($files.Count -gt 15 -or $areas -ge 4) {
            Say ('  ' + (Paint "tip: $($files.Count) files across $areas areas - smaller commits read better (aic -Pick lets you choose)" 'dim'))
        }
        if ($ctx.PendingAi -gt 0) {
            Say ('  ' + (Paint "tip: $($ctx.PendingAi) more AI-related file$(if ($ctx.PendingAi -ne 1) { 's' }) not staged - press a (or run aic -AiFiles)" 'ai'))
        }
    }

    function Show-Message([switch]$Instant) {
        $n = $st.Problems.Count
        $badge = if ($n) { Paint "$($g.warn) $n note$(if ($n -ne 1) { 's' })" 'warn' } else { Paint "$($g.ok) valid" 'ok' }
        $ty    = Get-Type $st.Msg
        $pill  = if ($ty -and $typeRgb.ContainsKey($ty)) { (Pill $ty $typeRgb[$ty]) + ' ' } else { '' }
        Say ''
        CardTop 'Commit message' ($pill + $badge)
        $lines = @($st.Msg -split '\r?\n')
        for ($i = 0; $i -lt $lines.Count; $i++) {
            Say ('  ' + (Paint $g.v 'dim') + ' ') -NoNewline
            Reveal (Format-Line $lines[$i] ($i -eq 0)) -Instant:$Instant
        }
        foreach ($p in $st.Problems) { Rail (Paint "$($g.warn) $p" 'warn') }
        # subject-length gauge: green up to 50, amber up to 72, red beyond
        $len = $lines[0].Length
        $col = if ($len -le 50) { 'ok' } elseif ($len -le 72) { 'warn' } else { 'err' }
        $bul = @($lines | Where-Object { $_ -match '^-\s' }).Count
        Rail ((Paint 'subject ' 'dim') + (Paint (Bar $len 72 12) $col) + (Paint " $len/72" 'mute') + (Paint " $($g.mid) $bul bullet$(if ($bul -ne 1) { 's' })" 'dim'))
        CardBottom $st.Meta
    }

    function Show-Actions {
        $items = @(('Enter', 'commit'), ('e', 'edit'), ('r', 'retry'), ('v', 'variants'), ('h', 'hint'), ('m', 'model'), ('t', 'type'), ('s', 'scope'),
                   ('b', 'breaking'), ('x', 'emoji'), ('a', 'AI files'), ('f', 'files'), ('c', 'copy'), ('p', 'commit+push'), ('d', 'diff'), ('q', 'quit'))
        $w = (WinWidth) - 4; $line = ''; $len = 0; $out = @()
        foreach ($a in $items) {
            $plainLen = $a[0].Length + 2 + 1 + $a[1].Length + 2
            if ($len + $plainLen -gt $w -and $line) { $out += $line; $line = ''; $len = 0 }
            $line += (Cap $a[0]) + ' ' + (Paint $a[1] 'mute') + '  '
            $len  += $plainLen
        }
        $out += $line
        Say ''
        foreach ($l in $out) { Say "  $l" }
    }

    # ---- extra screens: themes, log, doctor ----------------------------------------------------------
    function Show-Themes {
        Say ''
        CardTop 'Themes' (Paint "current: $Theme" 'scope')
        foreach ($name in ($themes.Keys | Sort-Object)) {
            $t = $themes[$name]
            $swatch = Gradient ($g.full * 26) $t.g1 $t.g2
            $dot    = if ($ui.Color) { "$esc[38;2;$($t.a)m$($g.dot)$esc[0m" } else { $g.dot }
            $cur    = if ($name -eq $Theme) { Paint "  $($g.sel) current" 'dim' } else { '' }
            Rail ($dot + ' ' + (Paint $name.PadRight(8) 'text') + $swatch + $cur)
        }
        CardBottom "aic -Theme <name>   or   ""theme"": ""<name>"" in .aic.json"
    }

    function Show-Log([int]$n) {
        $rows = @(git @gitC log -n $n --no-merges '--format=%h%x09%ar%x09%s' 2>$null | Where-Object { $_ })
        if ($rows.Count -eq 0) { Warn 'No commits yet.'; return }
        $count = @{}; $conv = 0
        Say ''
        CardTop "Last $($rows.Count) commits" (Paint $branch 'scope')
        $room = [Math]::Max(16, (RuleWidth) - 36)
        foreach ($r in $rows) {
            $p = ([string]$r) -split "`t", 3
            $subj = if ($p.Count -ge 3) { $p[2] } else { '' }
            $age  = if ($p.Count -ge 2) { $p[1] } else { '' }
            $m = [regex]::Match($subj, $rxParse)
            $t = if ($m.Success) { $m.Groups['type'].Value.ToLower() } else { '' }
            if ($t -and $typeRgb.ContainsKey($t)) {
                $conv++
                $count[$t] = 1 + [int]$count[$t]
                $sc   = if ($m.Groups['scope'].Success -and $m.Groups['scope'].Value) { Paint "($($m.Groups['scope'].Value)) " 'scope' } else { '' }
                $text = $m.Groups['subj'].Value
                if ($text.Length -gt $room) { $text = $text.Substring(0, $room - 1) + '~' }
                Rail ((Paint $p[0] 'accent') + '  ' + (Pill $t.PadRight(8) $typeRgb[$t]) + ' ' + $sc + (Paint $text 'text') + (Paint "  $age" 'dim'))
            } else {
                $text = $subj
                if ($text.Length -gt $room + 12) { $text = $text.Substring(0, $room + 11) + '~' }
                Rail ((Paint $p[0] 'accent') + '  ' + (Paint $text 'mute') + (Paint "  $age" 'dim'))
            }
        }
        if ($count.Count) {
            $hist = (($count.Keys | Sort-Object { -$count[$_] }, { $_ }) | ForEach-Object { Paint "$_ $($count[$_])" "38;2;$($typeRgb[$_])" }) -join (Paint " $($g.mid) " 'dim')
            Rail ''
            Rail $hist
        }
        CardBottom "$conv of $($rows.Count) follow Conventional Commits"
    }

    function Doc-Row([string]$state, [string]$label, [string]$detail = '') {
        $mark = switch ($state) { 'ok' { Paint $g.ok 'ok' } 'warn' { Paint $g.warn 'warn' } default { Paint $g.bad 'err' } }
        Rail ($mark + ' ' + (Paint $label.PadRight(15) 'text') + (Paint $detail 'mute'))
    }
    function Show-Doctor {
        Say ''
        CardTop 'aic doctor'
        $v = $PSVersionTable.PSVersion
        Doc-Row $(if ($v.Major -ge 7) { 'ok' } else { 'warn' }) 'PowerShell' ("$v" + $(if ($v.Major -lt 7) { '  (7+ recommended)' } else { '' }))
        Doc-Row $(if ($ui.Color) { 'ok' } else { 'warn' }) 'Terminal' "colour $($ui.Color), animation $($ui.Anim), raw keys $($ui.Keys)"
        $gv = [string](git --version 2>$null)
        Doc-Row $(if ($gv) { 'ok' } else { 'bad' }) 'git' $(if ($gv) { $gv } else { 'not found in PATH' })
        if ($inRepo) {
            Doc-Row 'ok' 'Repository' "$root  ($branch)"
            $un = [string](git @gitC config user.name 2>$null); $ue = [string](git @gitC config user.email 2>$null)
            Doc-Row $(if ($un -and $ue) { 'ok' } else { 'warn' }) 'Identity' $(if ($un -and $ue) { "$un <$ue>" } else { 'user.name / user.email missing' })
        } else { Doc-Row 'warn' 'Repository' 'not inside a git repository' }
        $gp = Join-Path $HOME '.aic.json'
        Doc-Row 'ok' 'Settings' ("personal: $(if (Test-Path -LiteralPath $gp) { 'found' } else { 'none' }) $($g.mid) repo: $(if ($inRepo -and (Test-Path -LiteralPath (Join-Path $root '.aic.json'))) { 'found' } else { 'none (aic -Init)' })")
        if ($inRepo) {
            $pend = @(Get-Changes | Where-Object { $_.Ai })
            Doc-Row 'ok' 'AI files' "$($pend.Count) changed $($g.mid) $(@($pend | Where-Object { $_.Staged }).Count) staged $($g.mid) custom globs: $($aiGlobs.Count)"
        }
        $tg = $null
        try { $tg = Invoke-RestMethod -Uri "$base/api/tags" -TimeoutSec 3 } catch { }
        if ($tg) {
            $names = @(@(Get-Prop $tg 'models') | ForEach-Object { Get-Prop $_ 'name' } | Where-Object { $_ })
            Doc-Row 'ok' 'Ollama' "$($uri.Authority) $($g.mid) $($names.Count) model(s)"
            $wantM = if ($Model -match ':') { $Model } else { "${Model}:latest" }
            Doc-Row $(if ($names -contains $wantM) { 'ok' } else { 'bad' }) 'Model' $(if ($names -contains $wantM) { $Model } else { "$Model is not installed: ollama pull $Model" })
        } else { Doc-Row 'bad' 'Ollama' "not reachable at $base" }
        Doc-Row $(if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { 'ok' } else { 'warn' }) 'Clipboard' $(if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) { 'available' } else { 'Set-Clipboard missing (c key will not work)' })
        CardBottom "theme $Theme $($g.mid) border $Border $($g.mid) spinner $Spinner $($g.mid) banner $Banner"
    }

    # =========================================================================================
    # 6) git actions
    # =========================================================================================
    function Invoke-GitUi { if ($PassThru) { git @gitC @args | Out-Host } else { git @gitC @args } }

    function Do-Commit([string]$msg, [bool]$viaEditor) {              # sets $st.CommitOk, never writes to the pipeline
        $tmp = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmp, $msg, [System.Text.UTF8Encoding]::new($false))   # UTF-8 without BOM: safest for multi-line + Arabic
        try {
            $a = @('commit', '-F', $tmp)
            if ($viaEditor) { $a += '-e' }
            if ($Amend)     { $a += '--amend' }
            if ($NoVerify)  { $a += '--no-verify' }
            if ($Signoff)   { $a += '--signoff' }
            Invoke-GitUi @a
            $st.CommitOk = ($LASTEXITCODE -eq 0)
        } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        if (-not $st.CommitOk) { Fail 'git commit did not complete' 'A hook failed or the editor was closed empty. Your message is still here: fix it, then press Enter again.' }
    }

    function Do-Push {
        Say ('  ' + (Paint "pushing $($g.mid) $branch ..." 'mute'))
        git @gitC rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Invoke-GitUi push } else { Invoke-GitUi push -u origin HEAD }       # first push of a new branch
        if ($LASTEXITCODE -eq 0) { Say ('  ' + (Paint "$($g.ok) pushed" 'ok')) } else { Fail 'git push failed' 'See the git output above.' }
    }

    function Show-Done {
        $info = @(@(git @gitC log -1 --shortstat --format=%h) | Where-Object { $_.Trim() })       # always an array, even for a single line
        $stat = if ($info.Count -gt 1) { $info[1].Trim() } else { '' }
        $word = "$($g.ok) $(if ($Amend) { 'amended' } else { 'committed' })"
        Say ''
        Shimmer "$word $($info[0]) on $branch"
        Say ('  ' + (Paint $word 'okb') + ' ' + (Paint $info[0] 'accent') + ' on ' + (Paint $branch 'scope') + $(if ($stat) { '  ' + (Paint $stat 'dim') } else { '' }))
        Say ('  ' + (Paint (Get-Random -InputObject $quips) 'mute') + (Paint "  $($g.mid) $(F1 $sessionSw.Elapsed.TotalSeconds)s" 'dim'))
        if ($Bell) { Say "`a" -NoNewline }
    }

    # every changed file as objects: Path, Code (git status letter), Staged, Dirty (also modified after staging), Ai
    function Get-Changes {
        $raw   = (git @gitC status --porcelain=v1 -z -uall 2>$null) -join ''
        $parts = @($raw -split "`0" | Where-Object { $_ })
        if ($parts.Count -gt 400) {                                                  # e.g. node_modules not ignored: show folders, not 50k files
            $raw   = (git @gitC status --porcelain=v1 -z -unormal 2>$null) -join ''
            $parts = @($raw -split "`0" | Where-Object { $_ })
        }
        $items = [System.Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt $parts.Count; $i++) {
            $e = $parts[$i]
            if ($e.Length -lt 4) { continue }
            $x = [string]$e[0]; $y = [string]$e[1]
            if ($x -eq 'R' -or $x -eq 'C') { $i++ }                                  # the next entry is the old file name
            if ($x -eq '!') { continue }
            $staged = ($x -ne ' ' -and $x -ne '?')
            $code   = if ($x -eq '?') { '?' } elseif ($y -ne ' ') { $y } else { $x }
            $path   = $e.Substring(3)
            $items.Add([pscustomobject]@{ Path = $path; Code = $code; Staged = $staged; Dirty = ($y -ne ' '); Ai = (Test-AiPath $path) })
        }
        $items.ToArray()
    }

    # git add every changed AI-related file (new, modified, deleted). Returns how many were added.
    function Stage-AiFiles {
        $ai = @(Get-Changes | Where-Object { $_.Ai -and (-not $_.Staged -or $_.Dirty) })
        if ($ai.Count -eq 0) { Say ('  ' + (Paint 'no unstaged AI-related files found' 'mute')); return 0 }
        $paths = @($ai | ForEach-Object { $_.Path })
        git @gitC --literal-pathspecs add -A -- @paths 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { Fail 'git add failed for some AI files' 'Check .gitignore or file permissions.'; return 0 }
        Say ''
        CardTop 'AI files staged' (Pill 'AI' $aiRgb)
        foreach ($f in ($ai | Select-Object -First 8)) {
            $c = switch ($f.Code) { 'A' { 'ok' } '?' { 'ok' } 'D' { 'err' } default { 'warn' } }
            Rail ((Paint $(if ($f.Code -eq '?') { 'A' } else { $f.Code }) $c) + '  ' + (Paint $f.Path 'text'))
        }
        if ($ai.Count -gt 8) { Rail (Paint "... and $($ai.Count - 8) more" 'dim') }
        CardBottom "$($ai.Count) AI file$(if ($ai.Count -ne 1) { 's' }) added to the index"
        return $ai.Count
    }

    # -AiOnly: keep only AI files in the index (files stay untouched in the working tree)
    function Limit-ToAi {
        $staged = @(git @gitC diff --staged --name-only --no-ext-diff 2>$null | Where-Object { $_ })
        $drop   = @($staged | Where-Object { -not (Test-AiPath $_) })
        if ($drop.Count -eq 0) { return }
        if ($ui.Keys -and -not $Yes -and -not (Confirm-Key "Unstage $($drop.Count) non-AI file$(if ($drop.Count -ne 1) { 's' }) so this commit holds only AI files?" $true)) { return }
        git @gitC --literal-pathspecs reset -q -- @drop 2>$null | Out-Null
        Say ('  ' + (Paint "$($g.ok) unstaged $($drop.Count) non-AI file$(if ($drop.Count -ne 1) { 's' }) (still in your working tree)" 'ok'))
    }

    # checklist of changed files: ticked = in this commit. Stages the newly ticked, unstages the unticked.
    function Select-Files {
        $items = @(Get-Changes)
        if ($items.Count -eq 0) { return }
        $labels = @($items | ForEach-Object { "$($_.Code)  $($_.Path)" })
        $sel = Pick-Many "Choose what goes into this commit ($($items.Count) changed)" $labels @($items | ForEach-Object { [bool]$_.Staged }) @($items | ForEach-Object { [bool]$_.Ai })
        if ($null -eq $sel) { return }
        $add = @(); $drop = @()
        for ($i = 0; $i -lt $items.Count; $i++) {
            if ($sel[$i] -and (-not $items[$i].Staged -or $items[$i].Dirty)) { $add  += $items[$i].Path }
            if (-not $sel[$i] -and $items[$i].Staged)                        { $drop += $items[$i].Path }
        }
        if ($add.Count)  { git @gitC add -A -- @add  2>$null | Out-Null }
        if ($drop.Count) { git @gitC reset -q -- @drop 2>$null | Out-Null }
    }

    # (re)read the staged changes into $ctx (files, prompt material) and $st.Findings. Returns the file count.
    function Load-Changes {
        $numstat = @(git @gitC diff --staged --numstat --no-ext-diff @baseArgs @pathArgs 2>$null)
        $list = @(foreach ($l in $numstat) {
            $p = $l -split "`t", 3
            if ($p.Count -lt 3) { continue }
            $bin = ($p[0] -eq '-')
            [pscustomobject]@{ Add = $(if ($bin) { 0 } else { [int]$p[0] }); Del = $(if ($bin) { 0 } else { [int]$p[1] }); Path = $p[2]; Bin = $bin }
        })
        $ctx.Files = $list
        $ctx.PendingAi = 0
        if ($list.Count -eq 0) { return 0 }
        $diffText = (git @gitC diff --staged --unified=1 --no-color --no-ext-diff @baseArgs @pathArgs) -join "`n"
        $statText = (($list | Select-Object -First 40 | ForEach-Object { if ($_.Bin) { "$($_.Path) (binary)" } else { "$($_.Path) (+$($_.Add) -$($_.Del))" } }) -join "`n")
        if ($list.Count -gt 40) { $statText += "`n... and $($list.Count - 40) more files" }
        $recent = ''
        if ($History -gt 0) {
            $skipN = if ($Amend) { 1 } else { 0 }
            $recent = ((@(git @gitC log -n $History "--skip=$skipN" --no-merges --pretty=%s 2>$null) | Where-Object { $_ }) | ForEach-Object { "- $_" }) -join "`n"
        }
        $aiPaths = @($list | Where-Object { Test-AiPath $_.Path } | ForEach-Object { $_.Path })
        $allAi   = ($aiPaths.Count -gt 0 -and $aiPaths.Count -eq $list.Count)
        $scHint  = Get-ScopeHint @($list | ForEach-Object { $_.Path })
        if ($allAi -and (-not $cfgScopes.Count -or $cfgScopes -contains 'ai')) { $scHint = 'ai' }
        $ctx.Repo = @{
            Branch = $branch; Recent = $recent; ScopeHint = $scHint; Stat = $statText
            Diff = (Shrink-Diff $diffText $MaxChars); AiPaths = $aiPaths; AllAi = $allAi
        }
        $find = @()
        if (-not $NoScan) { $find = Find-Secrets @($list | ForEach-Object { $_.Path }) $diffText }
        $st.Findings = $find
        $ctx.PendingAi = @(Get-Changes | Where-Object { $_.Ai -and (-not $_.Staged -or $_.Dirty) }).Count
        return $list.Count
    }

    # =========================================================================================
    # 7) main
    # =========================================================================================
    $oldTitle = $null; $oldEnc = $null; $base = $null; $uri = $null
    $inRepo = $false; $root = ''; $branch = ''; $gitC = @(); $baseArgs = @(); $pathArgs = @()
    $used = [System.Collections.Generic.HashSet[string]]::new()
    $st   = @{ Findings = @(); CommitOk = $false }
    $ctx  = @{ Files = @(); Repo = @{ AiPaths = @(); AllAi = $false }; PendingAi = 0 }
    if ($ui.Fancy) { try { $oldTitle = $Host.UI.RawUI.WindowTitle } catch { } }
    try {
        Show-Header
        foreach ($w in $cfgWarn) { Warn $w }
        SetTitle 'aic - AI commit'
        if ($ListThemes) { Show-Themes; return }
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail 'git was not found in PATH.'; return }
        $oldEnc = [Console]::OutputEncoding
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8          # git speaks UTF-8: Arabic file names and diffs survive
        $root = git rev-parse --show-toplevel 2>$null
        $inRepo = ($LASTEXITCODE -eq 0 -and [bool]$root)
        if (-not $inRepo -and -not $Doctor) { Fail 'Not inside a git repository.'; return }
        if ($inRepo) {
            $gitC = '-C', $root, '-c', 'core.quotepath=false'
            $branch = git @gitC symbolic-ref --short -q HEAD 2>$null
            if (-not $branch) { $branch = 'detached HEAD' }
        }

        # Ollama address (OLLAMA_HOST may be ":11434", "0.0.0.0:11434", "host:port" ...)
        $base = if ($OllamaUrl) { $OllamaUrl } elseif ($env:OLLAMA_HOST) { $env:OLLAMA_HOST } else { 'http://localhost:11434' }
        if ($base -match '^:\d+$') { $base = "localhost$base" }
        if ($base -notmatch '^https?://') { $base = "http://$base" }
        $base = ($base -replace '//0\.0\.0\.0', '//127.0.0.1').TrimEnd('/')      # OLLAMA_HOST=0.0.0.0 is a bind address, not a destination
        try { $uri = [Uri]$base } catch { Fail "Invalid Ollama URL: $base"; return }

        if ($Doctor) { Show-Doctor; return }
        if ($Log -gt 0) { Show-Log $Log; return }

        # ---- write a starter .aic.json -------------------------------------------------------------------
        if ($Init) {
            $cfgPath = Join-Path $root '.aic.json'
            if (Test-Path -LiteralPath $cfgPath) { Warn ".aic.json already exists: $cfgPath"; return }
            $cand = @(git @gitC ls-files 2>$null | ForEach-Object { Get-ScopeCandidate $_ } | Where-Object { $_ } |
                      Group-Object | Sort-Object Count -Descending | Select-Object -First 12 | ForEach-Object { $_.Name })
            $starter = [ordered]@{
                model = $Model; language = 'English'; bullets = 3; history = 3; emoji = $false
                theme = $Theme; spinner = $Spinner; border = $Border; banner = $Banner; width = $Width
                scopes = $cand; exclude = @(); aiFiles = @('prompts/*', '*.prompt.md'); autoStageAi = $false
            }
            [System.IO.File]::WriteAllText($cfgPath, ($starter | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
            Say ''
            Say ('  ' + (Paint "$($g.ok) created $cfgPath" 'ok'))
            Say ('    ' + (Paint $(if ($cand.Count) { "scopes inferred from your layout: $($cand -join ', ')" } else { 'no scopes inferred - add your own' }) 'mute'))
            Say ('    ' + (Paint 'tip: the same keys work in ~/.aic.json as personal defaults for every repo' 'dim'))
            return
        }

        # ---- which changed files are AI-related? (no staging, no Ollama needed) -------------------------
        if ($ListAi) {
            $ai = @(Get-Changes | Where-Object { $_.Ai })
            Say ''
            if ($ai.Count -eq 0) { Say ('  ' + (Paint 'no changed AI-related files' 'mute')); return }
            CardTop 'AI-related changes' (Pill 'AI' $aiRgb)
            foreach ($f in $ai) {
                $stg = if ($f.Staged -and -not $f.Dirty) { Paint 'staged  ' 'ok' } elseif ($f.Staged) { Paint 'partial ' 'warn' } else { Paint 'unstaged' 'mute' }
                Rail ($stg + '  ' + (Paint $f.Code 'warn') + '  ' + $f.Path)
            }
            CardBottom "$($ai.Count) file$(if ($ai.Count -ne 1) { 's' }) $($g.mid) aic -AiFiles stages them $($g.mid) aic -AiOnly commits only them"
            return
        }

        # ---- undo the last commit (soft: everything stays staged) --------------------------------------
        if ($Undo) {
            $last = @(git @gitC log -1 '--format=%h%x09%s' 2>$null)
            if ($LASTEXITCODE -ne 0 -or -not $last) { Fail 'There is no commit to undo.'; return }
            git @gitC rev-parse --verify -q 'HEAD~1' 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail "The very first commit can't be soft-undone this way."; return }
            $h, $subj = ([string]$last[0]) -split "`t", 2
            Say ''
            Say ('  ' + (Paint "last commit $h" 'accent') + '  ' + $subj)
            git @gitC rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0 -and [int](git @gitC rev-list --count '@{u}..HEAD' 2>$null) -eq 0) {
                Warn 'It is already on the remote: undoing it locally means force-pushing later.'
            }
            if (-not $Yes -and -not (Confirm-Key 'Undo it? Your changes stay staged.' $false)) { Say ('  ' + (Paint 'cancelled' 'mute')); return }
            git @gitC reset --soft 'HEAD~1'
            if ($LASTEXITCODE -eq 0) { Say ('  ' + (Paint "$($g.ok) undone. Changes are staged, run aic again." 'ok')) } else { Fail 'git reset failed' }
            return
        }

        # ---- Ollama up? (offer to start it) model installed? --------------------------------------------
        $tags = $null
        try { $tags = Invoke-RestMethod -Uri "$base/api/tags" -TimeoutSec 3 } catch { }
        if (-not $tags) {
            $oc = Get-Command ollama -ErrorAction SilentlyContinue
            if ($oc -and $uri.IsLoopback -and ($StartOllama -or ($ui.Keys -and (Confirm-Key 'Ollama is not running. Start it now?' $true)))) {
                $sp = @{ FilePath = $oc.Source; ArgumentList = 'serve' }
                if ($env:OS -eq 'Windows_NT') { $sp.WindowStyle = 'Hidden' }
                else {                                                                      # macOS/Linux: server logs go to temp files, not your terminal
                    $sp.RedirectStandardOutput = Join-Path ([System.IO.Path]::GetTempPath()) 'aic-ollama.out.log'
                    $sp.RedirectStandardError  = Join-Path ([System.IO.Path]::GetTempPath()) 'aic-ollama.err.log'
                }
                try { Start-Process @sp | Out-Null } catch { Warn "could not start ollama: $($_.Exception.Message)" }
                $sw0 = [System.Diagnostics.Stopwatch]::StartNew(); $f0 = 0
                if (-not $ui.Anim) { Say (Paint '  starting ollama ...' 'dim') }
                while (-not $tags -and $sw0.Elapsed.TotalSeconds -lt 25) {
                    $f0++
                    Draw-Spin $f0 'starting ollama' $sw0.Elapsed.TotalSeconds -1 ''
                    try { $tags = Invoke-RestMethod -Uri "$base/api/tags" -TimeoutSec 1 } catch { Start-Sleep -Milliseconds 300 }
                }
                Clear-Line
            }
        }
        if (-not $tags) { Fail "Can't reach Ollama at $base" 'Start it (open the Ollama app or run: ollama serve), use -StartOllama, or pass -OllamaUrl.'; return }
        $tagModels = @(Get-Prop $tags 'models')
        $installed = @($tagModels | ForEach-Object { Get-Prop $_ 'name' } | Where-Object { $_ })
        $want = if ($Model -match ':') { $Model } else { "${Model}:latest" }      # Ollama resolves "name" to "name:latest"
        if ($installed -notcontains $want) {
            $alts = @($installed | Where-Object { $_ -notmatch 'embed' } | Sort-Object)
            if ($ui.Fancy -and $ui.Keys -and $alts.Count) {
                Warn "Model '$Model' is not installed."
                $ix = Pick-One 'Use one of your installed models' $alts 0
                if ($ix -ge 0) { $Model = $alts[$ix]; $want = $Model }
            }
        }
        if ($installed -notcontains $want) {
            Fail "Model '$Model' is not installed" ("Pull it with: ollama pull $Model    (installed: " + ($installed -join ', ') + ')')
            return
        }
        $Model = $want
        if ((Test-Cap $Model 'embedding') -and -not (Test-Cap $Model 'completion')) { Fail "'$Model' is an embedding model and cannot write text."; return }
        Say ('  ' + (Paint $g.dot 'ok') + ' ' + (Paint "ollama $($g.mid) $($uri.Authority) $($g.mid) $Model" 'mute'))

        # ---- which files? -All / AI files / checklist, then collect everything ---------------------------
        if ($All) { git @gitC add -A }
        if ($AiFiles -or $AiOnly -or $autoAi) { [void](Stage-AiFiles) }
        if ($AiOnly) { Limit-ToAi }
        elseif (-not $All -and -not $Amend -and $ui.Keys -and $ui.Fancy) {
            $pickNow = [bool]$Pick
            if (-not $pickNow) { git @gitC diff --staged --quiet --no-ext-diff 2>$null; $pickNow = ($LASTEXITCODE -eq 0) }
            if ($pickNow) { Select-Files }
        }

        # amend = compare the index with the PARENT of HEAD (4b825dc... is git's empty tree, for root commits)
        if ($Amend) {
            git @gitC rev-parse --verify -q HEAD 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { Fail 'Nothing to amend: this repository has no commits yet.'; return }
            git @gitC rev-parse --verify -q 'HEAD~1' 2>$null | Out-Null
            $baseArgs = @(if ($LASTEXITCODE -eq 0) { 'HEAD~1' } else { '4b825dc642cb6eb9a060e54bf8d69288fbee4904' })
        }
        # lockfiles / minified / generated files are noise for the model
        $skipNames = @('package-lock.json', 'npm-shrinkwrap.json', 'pnpm-lock.yaml', 'yarn.lock', 'bun.lock', 'bun.lockb', 'Cargo.lock',
                       'composer.lock', 'poetry.lock', 'Gemfile.lock', 'go.sum', '*.min.js', '*.min.css', '*.map') + @($Exclude)
        $pathArgs = @('--', '.') + @($skipNames | Where-Object { $_ } | ForEach-Object { ":(exclude)*$_" })

        # ---- state shared by the whole session -----------------------------------------------------------
        $st = @{
            Model = $Model; Hint = $Hint; Type = $Type; Scope = $Scope; NoScope = $false; Bang = [bool]$Breaking
            Regen = 0; Msg = ''; Problems = @(); Meta = ''; CommitOk = $false; Ack = $false; Findings = @()
        }
        if ((Load-Changes) -eq 0) {
            if ($AiOnly) { Warn 'No AI-related changes to commit (see aic -ListAi, or add globs with -AiPattern).' }
            else { Warn 'Nothing staged (or only lockfiles). Run "git add ...", use aic -All / -AiFiles, or run aic in a normal terminal for the file checklist.' }
            return
        }
        Say ''
        Show-Stat

        # ---- generate -> review -> commit ----------------------------------------------------------------
        $need = $true
        while ($true) {
            if ($need) {
                $need = $false
                $r = New-Message
                if ($r -eq 'error') { return }
                if ($r -eq 'cancelled') {
                    Say ('  ' + (Paint 'cancelled' 'warn'))
                    if (-not $st.Msg) { return }
                    Say ('  ' + (Paint 'keeping the previous message' 'mute'))
                } else { Show-Message }
            }
            if ($DryRun) { Say ''; Say ('  ' + (Paint "dry run $($g.mid) nothing was committed" 'mute')); if ($PassThru) { $st.Msg }; return }
            if ($Copy) {
                try { Set-Clipboard -Value $st.Msg; Say ('  ' + (Paint "$($g.ok) copied to clipboard" 'ok')) } catch { Fail 'Clipboard is not available here.' }
                if ($PassThru) { $st.Msg }
                return
            }
            if ($Yes) {
                if ($st.Findings.Count) { Fail 'Possible secrets are staged, so -Yes will not commit.' 'Review the warnings above, or re-run with -NoScan if they are false alarms.'; return }
                if ($st.Problems.Count -eq 0) {
                    Do-Commit $st.Msg $false
                    if ($st.CommitOk) { Show-Done; if ($Push) { Do-Push }; if ($PassThru) { $st.Msg } }
                    return
                }
                if (-not $ui.Keys) { Fail 'The message still fails the format check, so -Yes will not commit it.' $st.Problems[0]; return }
            }

            Show-Actions
            $k = Read-Action
            $key = if ($k.Key -eq 'Enter') { 'y' } elseif ($k.Key -eq 'Escape') { 'q' } else { "$($k.Char)" }
            switch ($key) {
                { $_ -in 'y', 'e', 'p' } {
                    if ($st.Findings.Count -and -not $st.Ack) {
                        if (-not (Confirm-Key 'Possible secrets are staged. Commit anyway?' $false)) { break }
                        $st.Ack = $true
                    }
                    Do-Commit $st.Msg ($key -eq 'e')
                    if ($st.CommitOk) {
                        Show-Done
                        if ($Push -or $key -eq 'p') { Do-Push }
                        if ($PassThru) { $st.Msg }
                        return
                    }
                }
                'r' { $st.Regen++; $need = $true }
                'v' {
                    $alt  = @(Get-Variants)
                    $opts = @(@($st.Msg) + $alt | Select-Object -Unique)
                    if ($opts.Count -lt 2) { Warn 'no different variants were produced'; break }
                    $labels = @(for ($i = 0; $i -lt $opts.Count; $i++) { (($opts[$i] -split '\r?\n')[0]) + $(if ($i -eq 0) { '   <- current' } else { '' }) })
                    $ix = Pick-One 'Pick a message' $labels 0
                    if ($ix -ge 0) { $st.Msg = $opts[$ix]; $st.Problems = Test-Message $st.Msg; Show-Message -Instant }
                }
                'h' {
                    $h = Read-Line 'hint for the model (Esc = cancel):'
                    if ($h -and $h.Trim()) { $st.Hint = $h.Trim(); $st.Regen++; $need = $true }
                }
                'm' {
                    $mods = @($tagModels | Where-Object { $_ -and $_.name -notmatch 'embed' } | Sort-Object name)
                    $labels = @($mods | ForEach-Object { '{0}  ({1} GB){2}' -f $_.name, ($_.size / 1GB).ToString('0.0', $inv), $(if ($_.name -eq $st.Model) { '   <- current' } else { '' }) })
                    $ix = Pick-One 'Pick a model' $labels ([Math]::Max(0, [array]::IndexOf(@($mods | ForEach-Object { $_.name }), $st.Model)))
                    if ($ix -ge 0 -and $mods[$ix].name -ne $st.Model) { $st.Model = $mods[$ix].name; $st.Regen = 0; $need = $true }
                }
                't' {
                    $ix = Pick-One 'Pick a type' $types ([Math]::Max(0, [array]::IndexOf($types, (Get-Type $st.Msg))))
                    if ($ix -ge 0) {
                        $st.Type = $types[$ix]
                        $st.Msg = Set-Prefix $st.Msg @{ Type = $st.Type }; $st.Problems = Test-Message $st.Msg
                        Show-Message -Instant
                    }
                }
                's' {
                    if ($cfgScopes.Count) {                                  # a fixed list from .aic.json: pick, don't type
                        $opts = @($cfgScopes) + '(no scope)'
                        $ix = Pick-One 'Pick a scope' $opts 0
                        if ($ix -lt 0) { break }
                        $s = if ($ix -lt $cfgScopes.Count) { $cfgScopes[$ix] } else { '' }
                    } else {
                        $s = Read-Line 'scope (blank = none, Esc = cancel):'
                        if ($null -eq $s) { break }
                        $s = $s.Trim()
                    }
                    $st.Scope = $s; $st.NoScope = (-not $s)
                    $st.Msg = Set-Prefix $st.Msg @{ Scope = $s }; $st.Problems = Test-Message $st.Msg
                    Show-Message -Instant
                }
                'b' {
                    $st.Bang = -not (Get-Bang $st.Msg)
                    $st.Msg = Set-Prefix $st.Msg @{ Bang = $st.Bang }; $st.Problems = Test-Message $st.Msg
                    Show-Message -Instant
                }
                'x' {                                                        # gitmoji on/off, applied to the current message instantly
                    $useEmoji = -not $useEmoji
                    $st.Msg = Set-Prefix $st.Msg @{}; $st.Problems = Test-Message $st.Msg
                    Show-Message -Instant
                }
                'a' {                                                        # stage AI files, reload the diff, write a fresh message
                    if ((Stage-AiFiles) -gt 0) {
                        [void](Load-Changes)
                        Say ''; Show-Stat
                        $st.Regen++; $need = $true
                    }
                }
                'f' {                                                        # re-pick files, reload the diff, write a fresh message
                    if (-not ($ui.Fancy -and $ui.Keys)) { Warn 'the file checklist needs an interactive terminal'; break }
                    Select-Files
                    if ((Load-Changes) -eq 0) { Warn 'Nothing staged any more.'; return }
                    Say ''; Show-Stat
                    $st.Regen++; $need = $true
                }
                'c' {
                    try { Set-Clipboard -Value $st.Msg; Say ('  ' + (Paint "$($g.ok) copied to clipboard" 'ok')) } catch { Fail 'Clipboard is not available here.' }
                }
                'd' { Invoke-GitUi diff --staged --no-ext-diff @baseArgs @pathArgs }
                'q' { Say ('  ' + (Paint 'cancelled' 'mute')); return }
                default { }
            }
        }
    } finally {
        if ($ui.Fancy) { Say "$esc[?25h" -NoNewline }
        if ($Unload -and $base -and $used.Count) {                       # give the VRAM back (documented: keep_alive 0 unloads a model)
            foreach ($m in $used) {
                try { Invoke-RestMethod -Uri "$base/api/generate" -Method Post -ContentType 'application/json' -Body (@{ model = $m; keep_alive = 0 } | ConvertTo-Json) -TimeoutSec 5 | Out-Null } catch { }
            }
            Say ('  ' + (Paint "model unloaded $($g.mid) VRAM is free again" 'dim'))
        }
        if ($oldEnc)   { try { [Console]::OutputEncoding = $oldEnc } catch { } }
        if ($oldTitle) { SetTitle $oldTitle }
    }
}

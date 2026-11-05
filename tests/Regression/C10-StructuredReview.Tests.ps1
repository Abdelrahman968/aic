# Structured -Review: severity, file, VERIFIED line numbers, evidence checked against the diff, JSON / Markdown output, severity filter,
# -ReviewDiff <ref>. The model is untrusted: aic verifies every finding against the diff and never prints an invented line.
BeforeAll { . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1'); $script:mock = Start-MockOllama }
AfterAll  { Stop-MockOllama $script:mock }

Describe 'C10: structured review' -Tag 'Regression', 'C10' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        $script:repo = New-TestRepo $script:sb @{ 'README.md' = "# demo`n" }
        Set-TestFile $script:repo 'src/auth.js' "function login(user, pass) {`n  const q = `"SELECT * FROM users WHERE name='`" + user + `"'`";`n  return db.query(q);`n}`n"
        [void](G $script:repo add -- src/auth.js)
        $script:q = "const q = `"SELECT * FROM users WHERE name='`" + user + `"'`";"
        function script:Reply($findings) { Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text (ConvertTo-Json -InputObject @($findings) -Depth 5 -Compress)) } }
        function script:F($sev, $file, $line, $ev, $title = 'Something') { @{ severity = $sev; file = $file; line = $line; evidence = $ev; title = $title; why = 'because it matters'; fix = 'do the right thing' } }
        function script:ReviewJson($extra = @{}) { $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params (@{ ReviewJson = $true } + $extra); $script:last = $e; ($e.Pipeline -join "`n") | ConvertFrom-Json }
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'a finding whose evidence is in the diff is verified, and its line number is derived from the diff' {
        Reply @(F 'high' 'src/auth.js' 2 $script:q 'SQL injection')
        $j = ReviewJson
        $j.advisory | Should -BeTrue; $j.structured | Should -BeTrue; $j.testsRun | Should -BeFalse
        @($j.findings).Count | Should -Be 1
        $j.findings[0].severity | Should -Be 'high'; $j.findings[0].file | Should -Be 'src/auth.js'
        $j.findings[0].verified | Should -BeTrue; $j.findings[0].line | Should -Be 2
        $j.findings[0].why | Should -Match 'matters'; $j.findings[0].fix | Should -Match 'right thing'
    }
    It 'a wrong line number from the model is replaced by the real one' {
        Reply @(F 'high' 'src/auth.js' 99 $script:q)
        (ReviewJson).findings[0].line | Should -Be 2
    }
    It 'quoted code that is not in the diff makes the finding unverified and removes its line number' {
        Reply @(F 'critical' 'src/auth.js' 3 'eval(userInput)')
        $f = (ReviewJson).findings[0]
        $f.verified | Should -BeFalse; $f.line | Should -BeNullOrEmpty
    }
    It 'a finding about a file that is not in the diff is dropped and counted' {
        Reply @((F 'high' 'src/other.js' 1 'x = 1'), (F 'low' 'src/auth.js' 3 'return db.query(q);'))
        $j = ReviewJson
        @($j.findings).Count | Should -Be 1; $j.droppedUnknownFile | Should -Be 1
    }
    It 'severities are normalised (Critical, LOW, anything else = info) and sorted most severe first' {
        Reply @((F 'LOW' 'src/auth.js' 3 'return db.query(q);' 'a'), (F 'Critical' 'src/auth.js' 2 $script:q 'b'), (F 'weird' 'src/auth.js' 1 'function login' 'c'))
        $j = ReviewJson
        @($j.findings | ForEach-Object severity) | Should -Be @('critical', 'low', 'info')
        $j.counts.critical | Should -Be 1; $j.counts.low | Should -Be 1; $j.counts.info | Should -Be 1
    }
    It '-ReviewSeverity high keeps only high and critical and says how many were filtered' {
        Reply @((F 'low' 'src/auth.js' 3 'return db.query(q);' 'a'), (F 'medium' 'src/auth.js' 1 'function login' 'b'), (F 'high' 'src/auth.js' 2 $script:q 'c'))
        $j = ReviewJson @{ ReviewSeverity = 'high' }
        @($j.findings).Count | Should -Be 1; $j.filtered | Should -Be 2
    }
    It 'an empty list means "no problems found", still marked advisory' {
        Reply @()
        $j = ReviewJson
        @($j.findings).Count | Should -Be 0; $j.structured | Should -BeTrue; $j.advisory | Should -BeTrue
    }
    It 'free-text bullets from a model that ignores the format are passed on as unverified notes, never as findings' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text '- src/auth.js: arr[0] looks wrong') }
        $j = ReviewJson
        $j.structured | Should -BeFalse; @($j.findings).Count | Should -Be 0; $j.rawNotes | Should -Match 'looks wrong'
    }
    It '-ReviewJson keeps stdout clean (the interface goes to stderr) and the pipeline holds exactly one JSON document' {
        Reply @(F 'high' 'src/auth.js' 2 $script:q)
        [void](ReviewJson)
        $script:last.Stdout | Should -BeNullOrEmpty -Because $script:last.Stdout
        @($script:last.Pipeline).Count | Should -Be 1
    }
    It 'reports how much of the diff was reviewed' {
        Set-TestFile $script:repo 'big.txt' ((1..400 | ForEach-Object { "line number $_ of a long file" }) -join "`n"); [void](G $script:repo add -- big.txt)
        Reply @()
        $j = ReviewJson @{ MaxChars = 500 }
        $j.coverage.truncated | Should -BeTrue; $j.coverage.totalChars | Should -BeGreaterThan 500
    }
    It '-ReviewMarkdown produces a document with severity, file:line, the advisory notice and the no-tests statement' {
        Reply @(F 'high' 'src/auth.js' 2 $script:q 'SQL injection')
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ ReviewMarkdown = $true }
        $md = $e.Pipeline -join "`n"
        $md | Should -Match '(?m)^# AI review'; $md | Should -Match 'SQL injection'; $md | Should -Match 'src/auth\.js:2'
        $md | Should -Match 'advisory'; $md | Should -Match 'did not run any tests'
        $e.Stdout | Should -BeNullOrEmpty
    }
    It 'the interactive card shows the severity and whether a finding is verified' {
        Reply @((F 'high' 'src/auth.js' 2 $script:q 'SQL injection'), (F 'low' 'src/auth.js' 3 'not in the diff at all' 'Guess'))
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true }
        $e.Stdout | Should -Match '\[HIGH\]'; $e.Stdout | Should -Match 'unverified'; $e.Stdout | Should -Match 'src/auth\.js:2'
    }
    It 'tells the model that the diff is untrusted data and asks for JSON' {
        Reply @()
        [void](ReviewJson)
        $body = (Get-MockRequests $script:mock '/api/chat' | Select-Object -Last 1).Body
        $body | Should -Match 'untrusted'; $body | Should -Match 'JSON'
    }
    It '-ReviewJson together with -ReviewMarkdown is a usage error (exit 2)' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ ReviewJson = $true; ReviewMarkdown = $true }
        $e.Code | Should -Be 2
    }
    It '-ReviewDiff <ref> reviews the branch against a ref and never touches the index' {
        [void](G $script:repo reset -q); [void](G $script:repo switch -q -c feat/x); [void](G $script:repo add -- src/auth.js); [void](G $script:repo commit -q -m 'feat: auth')
        Set-TestFile $script:repo 'notes.txt' "n`n"                                    # an unstaged leftover that must stay untouched
        $before = Get-IndexFingerprint $script:repo
        Reply @(F 'high' 'src/auth.js' 2 $script:q 'SQL injection')
        $j = ReviewJson @{ ReviewDiff = 'main' }
        $j.scope | Should -Match 'main'; $j.findings[0].verified | Should -BeTrue; $j.findings[0].line | Should -Be 2
        Get-IndexFingerprint $script:repo | Should -Be $before
    }
    It '-ReviewDiff with an unknown ref is reported' {
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ ReviewDiff = 'no-such-branch' }
        $e.Code | Should -Be 1; $e.Stdout | Should -Match 'no-such-branch'
    }
    It 'CONTROL: the old free-text review still works (bullets, "no problems found")' -Tag 'Control' {
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text '- no problems found') }
        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Review = $true }
        $e.Stdout | Should -Match 'no problems found'
    }
}

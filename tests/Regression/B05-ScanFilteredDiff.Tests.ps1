# B5 (High): the secret scan only sees the diff AFTER -Exclude / "exclude" / default lockfile filters are applied.
# Those filters are meant to keep noise away from the MODEL, yet the excluded files are still committed.
# NOTE: all "secrets" below are synthetic placeholders (AWS' documented example key, repeated letters), never real credentials.
BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Helpers' 'All.ps1')
    $script:mock = Start-MockOllama
    $script:fakeAws = 'AKIAIOSFODNN7EXAMPLE'
    $script:fakeGh  = 'ghp_' + ('a' * 36)
}
AfterAll { Stop-MockOllama $script:mock }

Describe 'B5: excluded files are still scanned for secrets' -Tag 'Regression', 'B05' {
    BeforeEach {
        $script:sb = New-AicSandbox; Enter-AicSandbox $script:sb
        Set-MockChat $script:mock @{ Lines = (New-ChatLines -Text 'feat: add thing') }
        $script:repo = New-TestRepo $script:sb @{ 'src/a.js' = "let a = 1;`n"; '.keep' = "k`n" }
        Set-TestFile $script:repo 'src/a.js' "let a = 2;`n"                       # an ordinary staged change so the commit has content
        [void](G $script:repo add -- src/a.js)
        $script:head = Get-HeadSha $script:repo
    }
    AfterEach { Exit-AicSandbox $script:sb; Remove-AicSandbox $script:sb }

    It 'refuses -Yes when a secret sits in a file hidden by -Exclude' {
        Set-TestFile $script:repo 'secrets/aws.txt' "aws_access_key_id = $($script:fakeAws)`n"
        [void](G $script:repo add -- secrets/aws.txt)

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Exclude = @('secrets/*') }

        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head -Because "secrets/aws.txt must still be scanned. Committed tree: $((GTry $script:repo ls-tree -r --name-only HEAD).Out -join ', ')"
    }

    It 'refuses -Yes when a secret sits in a file hidden by "exclude" in .aic.json' {
        Set-TestFile $script:repo '.aic.json' "{ `"exclude`": [`"secrets/*`"] }`n"
        [void](G $script:repo reset -q -- src/a.js)                      # keep the config commit free of the staged change
        [void](G $script:repo add -- .aic.json); [void](G $script:repo commit -q -m 'chore: add aic config')
        Set-TestFile $script:repo 'src/a.js' "let a = 3;`n"; [void](G $script:repo add -- src/a.js)
        $script:head = Get-HeadSha $script:repo
        Set-TestFile $script:repo 'secrets/aws.txt' "aws_access_key_id = $($script:fakeAws)`n"
        [void](G $script:repo add -- secrets/aws.txt)

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }

        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
    }

    It 'refuses -Yes for an excluded key file (private key header and .pem name)' {
        Set-TestFile $script:repo 'deploy.pem' "-----BEGIN RSA PRIVATE KEY-----`nMIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu`n-----END RSA PRIVATE KEY-----`n"
        [void](G $script:repo add -- deploy.pem)

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true; Exclude = @('*.pem') }

        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
    }

    It 'refuses -Yes when a token is inside a lockfile (lockfiles are hidden from the model by default)' {
        Set-TestFile $script:repo 'package-lock.json' "{ `"resolved`": `"https://x:$($script:fakeGh)@registry.example/pkg.tgz`" }`n"
        [void](G $script:repo add -- package-lock.json)

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }

        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
    }

    It 'CONTROL: the same secret in a NOT excluded file is already refused' -Tag 'Control' {
        Set-TestFile $script:repo 'config.txt' "aws_access_key_id = $($script:fakeAws)`n"
        [void](G $script:repo add -- config.txt)

        $e = Invoke-Aic -Sandbox $script:sb -Mock $script:mock -Params @{ Yes = $true }

        $e.TimedOut | Should -BeFalse
        Get-HeadSha $script:repo | Should -Be $script:head
        $e.Stdout | Should -Match 'secret'
    }
}

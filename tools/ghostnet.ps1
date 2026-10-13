Register-ArgumentCompleter -Native -CommandName ghostnet,ghostnet-ru -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $words = 'build run test doctor setup watch clean check inspect languages init recent update auto-update completion --help --version --target --mode --type --run-file --run --yes --no-animation'.Split(' ')
    $previous = $commandAst.ToString() -replace '\S*$', ''
    if ($previous -match '--target\s+$') { $words = 'native linux windows macos both'.Split(' ') }
    elseif ($previous -match '--mode\s+$') { $words = 'auto files project cmake make cargo python go node dotnet maven gradle swift zig'.Split(' ') }
    elseif ($previous -match '--type\s+$') { $words = 'c cpp cmake rust python go java javascript typescript csharp bash ruby php lua swift kotlin dart zig'.Split(' ') }
    elseif ($previous -match 'auto-update\s+$') { $words = 'enable disable status'.Split(' ') }
    elseif ($previous -match 'completion\s+$') { $words = 'bash zsh powershell'.Split(' ') }
    $words | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

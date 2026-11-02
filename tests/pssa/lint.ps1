# SPDX-FileCopyrightText: 2026 RiDDiX / Maximilian Hammerschmid
# SPDX-License-Identifier: FSL-1.1-ALv2

# Parses every file and runs PSScriptAnalyzer against the Windows PowerShell 5.1 profiles.
$failed = 0
foreach ($file in $args) {
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file), [ref]$tokens, [ref]$parseErrors)
    foreach ($e in $parseErrors) {
        Write-Output ("{0}:{1}: parse error: {2}" -f $file, $e.Extent.StartLineNumber, $e.Message)
        $failed++
    }
    # Text written with Write-Output just before exit is lost when the caller
    # captures the function's output. [Console]::Out.WriteLine always arrives.
    $seen = @{}
    foreach ($fn in $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        foreach ($exit in $fn.Body.FindAll({ $args[0] -is [System.Management.Automation.Language.ExitStatementAst] }, $true)) {
            $block = $exit.Parent
            if (-not $block.PSObject.Properties['Statements']) { continue }
            foreach ($statement in $block.Statements) {
                if ($statement.Extent.StartOffset -ge $exit.Extent.StartOffset) { break }
                $first = $null
                if ($statement -is [System.Management.Automation.Language.PipelineAst]) { $first = $statement.PipelineElements[0] }
                $isOutput = ($first -is [System.Management.Automation.Language.CommandAst] -and $first.GetCommandName() -eq 'Write-Output') -or
                    ($first -is [System.Management.Automation.Language.CommandExpressionAst] -and $first.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) -or
                    ($first -is [System.Management.Automation.Language.CommandExpressionAst] -and $first.Expression -is [System.Management.Automation.Language.ExpandableStringExpressionAst])
                if ($isOutput -and -not $seen.ContainsKey($statement.Extent.StartOffset)) {
                    $seen[$statement.Extent.StartOffset] = $true
                    Write-Output ("{0}:{1}: OutputBeforeExit: in function {2} write the message with [Console]::Out.WriteLine(...), Write-Output before exit is lost when the caller captures the output" -f $file, $statement.Extent.StartLineNumber, $fn.Name)
                    $failed++
                }
            }
        }
    }
    $findings = Invoke-ScriptAnalyzer -Path $file -Settings (Join-Path $PSScriptRoot 'settings.psd1')
    foreach ($f in $findings) {
        Write-Output ("{0}:{1}: {2}: {3}" -f $file, $f.Line, $f.RuleName, $f.Message)
        $failed++
    }
}
Write-Output ("{0} files, {1} findings" -f $args.Count, $failed)
if ($failed) { exit 1 }

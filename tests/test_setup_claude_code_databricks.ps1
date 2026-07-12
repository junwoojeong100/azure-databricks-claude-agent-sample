$ErrorActionPreference = 'Stop'

$ScriptPath = Resolve-Path (
    Join-Path $PSScriptRoot '..\scripts\setup_claude_code_databricks.ps1'
)
$Tokens = $null
$ParseErrors = $null
$Ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $ScriptPath,
    [ref]$Tokens,
    [ref]$ParseErrors
)
if ($ParseErrors.Count) {
    throw "PowerShell setup script has $($ParseErrors.Count) parse error(s)."
}

foreach ($FunctionName in 'Test-JsonObject', 'Test-AnthropicMessageResponse') {
    $FunctionAst = $Ast.Find(
        {
            param($Node)
            $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $Node.Name -eq $FunctionName
        },
        $true
    ) | Select-Object -First 1
    if (-not $FunctionAst) {
        throw "Could not find function '$FunctionName'."
    }
    . ([scriptblock]::Create($FunctionAst.Extent.Text))
}

$Message = [pscustomobject]@{ type = 'message' }
if (-not (Test-AnthropicMessageResponse $Message)) {
    throw 'A top-level Anthropic message object must be accepted.'
}

$MessageArray = @(
    [pscustomobject]@{ type = 'error' },
    [pscustomobject]@{ type = 'message' }
)
if (Test-AnthropicMessageResponse $MessageArray) {
    throw 'A top-level array must not be accepted as an Anthropic message.'
}

foreach ($InvalidResponse in @(
    [pscustomobject]@{ type = 'error' },
    [pscustomobject]@{ type = @('message') },
    [pscustomobject]@{ content = @() },
    @{ type = 'message' },
    $null
)) {
    if (Test-AnthropicMessageResponse $InvalidResponse) {
        throw "Invalid response was accepted: $($InvalidResponse | Out-String)"
    }
}

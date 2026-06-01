param(
    [switch]$Clean,
    [switch]$SkipCompile
)

$ErrorActionPreference = "Stop"

$ContractRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-InContract {
    param([scriptblock]$Command)
    Push-Location $ContractRoot
    try {
        & $Command
    } finally {
        Pop-Location
    }
}

Write-Step "Check Node.js and npm"
Require-Command "node"
Require-Command "npm"
Invoke-InContract {
    Write-Host ("node " + (node --version))
    Write-Host ("npm  " + (npm --version))
}

if (-not (Test-Path (Join-Path $ContractRoot "package-lock.json"))) {
    throw "package-lock.json was not found. This project should be initialized with npm ci."
}

if ($Clean -and (Test-Path (Join-Path $ContractRoot "node_modules"))) {
    Write-Step "Remove existing node_modules"
    Invoke-InContract { Remove-Item -Recurse -Force -LiteralPath "node_modules" }
}

Write-Step "Install locked dependencies"
Invoke-InContract { npm ci }

Write-Step "Verify local Hardhat"
Invoke-InContract {
    npx --no-install hardhat --version
}

if (-not $SkipCompile) {
    Write-Step "Compile contracts"
    Invoke-InContract { npm run compile }
}

Write-Step "Environment is ready"
Write-Host "Use 'npm run compile' or 'npx --no-install hardhat compile' from $ContractRoot."

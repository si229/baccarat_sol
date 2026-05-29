param(
    [ValidateSet("setup", "node", "deploy", "doctor", "web3", "game", "all")]
    [string]$Step = "all"
)

$ErrorActionPreference = "Stop"

$ContractRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$WorkspaceRoot = Resolve-Path (Join-Path $ContractRoot "..")
$Web3ApiRoot = Join-Path $WorkspaceRoot "web3-api"
$GameServerRoot = Join-Path $WorkspaceRoot "gameServer"

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

function Invoke-InDirectory {
    param(
        [string]$Path,
        [scriptblock]$Command
    )
    Push-Location $Path
    try {
        & $Command
    } finally {
        Pop-Location
    }
}

function Test-PortOpen {
    param(
        [string]$HostName,
        [int]$Port
    )
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $async = $client.BeginConnect($HostName, $Port, $null, $null)
        $connected = $async.AsyncWaitHandle.WaitOne(500)
        if ($connected) {
            $client.EndConnect($async)
        }
        $client.Close()
        return $connected
    } catch {
        return $false
    }
}

function Wait-Port {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutSeconds = 30
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-PortOpen -HostName $HostName -Port $Port) {
            return
        }
        Start-Sleep -Seconds 1
    }
    throw "Timed out waiting for ${HostName}:$Port."
}

function Start-PowerShellWindow {
    param(
        [string]$Title,
        [string]$WorkingDirectory,
        [string]$Command
    )
    $escapedTitle = $Title.Replace("'", "''")
    $escapedDir = $WorkingDirectory.Replace("'", "''")
    $escapedCommand = $Command.Replace("'", "''")
    $argument = "-NoExit -ExecutionPolicy Bypass -Command `"Set-Location '$escapedDir'; `$Host.UI.RawUI.WindowTitle = '$escapedTitle'; $escapedCommand`""
    Start-Process powershell -ArgumentList $argument -WorkingDirectory $WorkingDirectory
}

function Setup-Contracts {
    Require-Command "node"
    Require-Command "npm"
    Write-Step "Install contract dependencies"
    Invoke-InContract { npm ci }
    Write-Step "Compile contracts"
    Invoke-InContract { npm run compile }
}

function Start-HardhatNode {
    Write-Step "Start Hardhat local node in a new PowerShell window"
    Start-PowerShellWindow `
        -Title "baccarat hardhat node" `
        -WorkingDirectory $ContractRoot `
        -Command "npx hardhat node --hostname 0.0.0.0 --port 8545"
    Wait-Port -HostName "127.0.0.1" -Port 8545 -TimeoutSeconds 45
}

function Deploy-Contracts {
    Write-Step "Deploy local contracts and refresh dependent configs"
    Invoke-InContract { npm run deploy:localhost }
}

function Doctor-Contracts {
    Write-Step "Verify deployed Baccarat contract"
    Invoke-InContract { npm run doctor:localhost }
}

function Start-Web3Api {
    if (-not (Test-Path $Web3ApiRoot)) {
        throw "web3-api directory not found: $Web3ApiRoot"
    }
    Require-Command "go"
    Write-Step "Start web3-api in a new PowerShell window"
    Start-PowerShellWindow `
        -Title "baccarat web3-api" `
        -WorkingDirectory $Web3ApiRoot `
        -Command "go mod download; go run .\cmd\web3-api"
    Wait-Port -HostName "127.0.0.1" -Port 9090 -TimeoutSeconds 60
}

function Start-GameServer {
    if (-not (Test-Path $GameServerRoot)) {
        throw "gameServer directory not found: $GameServerRoot"
    }
    Require-Command "rebar3"
    Write-Step "Start gameServer in a new PowerShell window"
    Start-PowerShellWindow `
        -Title "baccarat gameServer" `
        -WorkingDirectory $GameServerRoot `
        -Command "rebar3 compile; rebar3 shell"
}

switch ($Step) {
    "setup" {
        Setup-Contracts
    }
    "node" {
        Start-HardhatNode
    }
    "deploy" {
        Deploy-Contracts
    }
    "doctor" {
        Doctor-Contracts
    }
    "web3" {
        Start-Web3Api
    }
    "game" {
        Start-GameServer
    }
    "all" {
        Setup-Contracts
        Start-HardhatNode
        Deploy-Contracts
        Doctor-Contracts
        Start-Web3Api
        Start-GameServer
        Write-Step "Local stack is starting"
        Write-Host "Open http://127.0.0.1:7000/ after gameServer finishes booting."
    }
}

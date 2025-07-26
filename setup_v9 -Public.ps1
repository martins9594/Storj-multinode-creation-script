<# 
    Storj Multi‑Node Setup Script
    Author: Martin.S 
	Discord: martin.s9594

    This script downloads Storj binaries, generates node identities,
    sets up multiple nodes on Windows, opens firewall ports,
    installs Windows services for each node, and starts them.

    Version: 9.0
    Last updated: 26‑Jul‑2025
#>

# === Configuration ===
$wallet        		= "yourwallet"
$email         		= "youremail"
$externalIP    		= "yourIP"
$portStart     		= 28970
$dashboardStart		= 14005
$privatePortStart	= 7780

$nodes = @(	@{Drive="S:"; Folder="StorjNode01"; Name="Node01"; Space=500; Auth="youremail@gmail.com:yourtoken"},
			@{Drive="M:"; Folder="StorjNode02"; Name="Node02"; Space=500; Auth="youremail@gmail.com:yourtoken"},
			@{Drive="N:"; Folder="StorjNode03"; Name="Node03"; Space=500; Auth="youremail@gmail.com:yourtoken"}
)

# Determine a local working directory for the Storj binaries (next to the script)
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$storjBinDir = Join-Path $scriptDir "storj-bin"
if (!(Test-Path $storjBinDir)) {
    New-Item -ItemType Directory -Path $storjBinDir | Out-Null
}

# Prepare download directory
$tempDir = Join-Path $scriptDir "storj-temp"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# === Download Storj Binaries ===
Invoke-WebRequest -Uri "https://github.com/storj/storj/releases/latest/download/identity_windows_amd64.zip"      -OutFile "$tempDir\identity.zip"
Invoke-WebRequest -Uri "https://github.com/storj/storj/releases/latest/download/storagenode_windows_amd64.zip"    -OutFile "$tempDir\storagenode.zip"
Invoke-WebRequest -Uri "https://github.com/storj/storj/releases/latest/download/storagenode-updater_windows_amd64.zip" -OutFile "$tempDir\storagenode-updater.zip"

Expand-Archive "$tempDir\identity.zip"            -DestinationPath $storjBinDir -Force
Expand-Archive "$tempDir\storagenode.zip"         -DestinationPath $storjBinDir -Force
Expand-Archive "$tempDir\storagenode-updater.zip" -DestinationPath $storjBinDir -Force

# Find the actual executables (they may be nested in a folder)
$storagenodeExePath     = Get-ChildItem -Path $storjBinDir -Recurse -Filter storagenode.exe        | Select-Object -First 1 -ExpandProperty FullName
$storagenodeUpdaterPath = Get-ChildItem -Path $storjBinDir -Recurse -Filter storagenode-updater.exe | Select-Object -First 1 -ExpandProperty FullName
$identityExePath        = Get-ChildItem -Path $storjBinDir -Recurse -Filter identity.exe            | Select-Object -First 1 -ExpandProperty FullName

if (-not $storagenodeExePath -or -not $storagenodeUpdaterPath -or -not $identityExePath) {
    throw "Could not locate one or more executables in $storjBinDir"
}

# === Identity Setup ===
foreach ($node in $nodes) {
    $nodePath = Join-Path $node.Drive $node.Folder
    if (!(Test-Path $nodePath)) {
        New-Item -ItemType Directory -Path $nodePath | Out-Null
    }

    $identityName     = $node.Name
    $destIdentityRoot = Join-Path $nodePath "Identity"
    $destIdentityDir  = Join-Path $destIdentityRoot $identityName

    # If the identity doesn’t already exist in the destination, create and authorize it.
    if (!(Test-Path $destIdentityDir)) {
        & $identityExePath create $identityName
        & $identityExePath authorize $identityName "$($node.Auth)"

        if (!(Test-Path $destIdentityRoot)) {
            New-Item -ItemType Directory -Path $destIdentityRoot | Out-Null
        }
        $sourceIdentityDir = Join-Path $env:APPDATA ("Storj\Identity\" + $identityName)
        Move-Item $sourceIdentityDir $destIdentityRoot -Force
    }
}

# === Node Setup and Service Installation ===
for ($i = 0; $i -lt $nodes.Count; $i++) {
    $node       		= $nodes[$i]
    $nodePath   		= Join-Path $node.Drive $node.Folder
    $identityDir		= Join-Path (Join-Path $nodePath "Identity") $node.Name
    $configDir  		= $nodePath
    $dashPort   		= $dashboardStart + $i
    $port       		= $portStart + $i
	$privatePort		= $privatePortStart + $i

    # Each node gets its own copy of the binaries in a 'bin' subfolder
    $nodeBinDir = Join-Path $nodePath "bin"
    if (!(Test-Path $nodeBinDir)) {
        New-Item -ItemType Directory -Path $nodeBinDir | Out-Null
    }
    Copy-Item -Path $storagenodeExePath     -Destination $nodeBinDir -Force
    Copy-Item -Path $storagenodeUpdaterPath -Destination $nodeBinDir -Force

    # Run setup for this node
    & (Join-Path $nodeBinDir "storagenode.exe") setup `
        --config-dir "$configDir" `
        --identity-dir "$identityDir" `
        --operator.email "$email" `
        --operator.wallet "$wallet" `
        --contact.external-address "$($externalIP):$port" `
        --storage.path "$nodePath" `
        --storage.allocated-disk-space "$($node.Space)GB" `
        --server.address ":$port" `
		--console.address ":$dashPort" `
		--server.private-address "127.0.0.1:$privatePort" `
        --log.output ("winfile:///" + $nodePath + "\storagenode.log")

    # Service names
    $serviceName = $node.Name
    $updaterName = "$serviceName-updater"

    # Service paths point to the node-specific copies
    $nodeStoragenodeExe     = Join-Path $nodeBinDir "storagenode.exe"
    $nodeStoragenodeUpdater = Join-Path $nodeBinDir "storagenode-updater.exe"
    $binaryPath  = '"' + $nodeStoragenodeExe     + '" run --config-dir "' + $configDir + '"'
    $updaterPath = '"' + $nodeStoragenodeUpdater + '" run --config-dir "' + $configDir + '" --binary-location "' + $nodeStoragenodeExe + '" --log.output "winfile:///' + $nodePath + '\storagenode-updater.log" --service-name "' + $serviceName + '"'

    # Create services
    New-Service -Name $serviceName -BinaryPathName $binaryPath
    New-Service -Name $updaterName -BinaryPathName $updaterPath

    # Firewall rules
    New-NetFirewallRule -DisplayName "Storj $serviceName TCP" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow
    New-NetFirewallRule -DisplayName "Storj $serviceName UDP" -Direction Inbound -LocalPort $port -Protocol UDP -Action Allow

    # Start services
    Start-Service $serviceName
    Start-Service $updaterName
}

Write-Host "`n✅ All nodes set up, firewall rules applied, and services installed & started."

# Optionally clean up temporary files and the shared storj-bin directory:
# Remove-Item $tempDir -Recurse -Force
# Remove-Item $storjBinDir -Recurse -Force

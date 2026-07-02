# Download proof artifacts from a cloud proving server to your Windows machine.
# Edit the variables below before running. Do not commit real IPs or keys.

$ServerIp = "CHANGE_ME"
$ServerUser = "root"
$RemoteRepoPath = "/root/zkaudit"
$LocalPath = "C:\Users\petre\Desktop\zkaudit\cloud-artifacts"

if ($ServerIp -eq "CHANGE_ME") {
    Write-Error "Set `$ServerIp in fetch_outputs.ps1 to your VPS public IP before running."
    exit 1
}

if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
    Write-Error "scp not found. Install OpenSSH client (Windows Settings -> Apps -> Optional features -> OpenSSH Client)."
    exit 1
}

New-Item -ItemType Directory -Force -Path $LocalPath | Out-Null

$remote = "${ServerUser}@${ServerIp}"
$paths = @(
    "${RemoteRepoPath}/artifacts/",
    "${RemoteRepoPath}/logs/cp2-dev-mode.log",
    "${RemoteRepoPath}/logs/cp3-real-groth16.log",
    "${RemoteRepoPath}/logs/cloud-bootstrap.log",
    "${RemoteRepoPath}/logs/rzup-show.txt",
    "${RemoteRepoPath}/rzup-show.txt"
)

Write-Host "Downloading from ${remote} ..."
Write-Host "Local destination: ${LocalPath}"
Write-Host ""

foreach ($path in $paths) {
    Write-Host "  scp -r ${remote}:${path} -> ${LocalPath}"
    scp -r "${remote}:${path}" $LocalPath 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Optional path missing or failed: ${path}"
    }
}

Write-Host ""
Write-Host "Done. Check: ${LocalPath}"

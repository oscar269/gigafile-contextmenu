$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "oscar269/gigafile-contextmenu"
$headers = @{ "User-Agent" = "gigafile-contextmenu-remote-install" }

# find the .zip asset of the latest GitHub release
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
$asset = @($rel.assets | Where-Object { $_.name -match "\.zip$" })[0]
if (-not $asset) { throw "no .zip asset in the latest release: $($rel.tag_name)" }

Write-Host "[remote-install] downloading $($asset.name) ..."
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("gfc_install_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $headers
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    # install.ps1 is file-path based, so run it as a separate process
    $installer = Join-Path $tmp "install.ps1"
    $exe = Join-Path $tmp "gfu.exe"
    if (-not (Test-Path $installer)) { throw "install.ps1 is missing in the zip" }
    & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $installer -ExePath $exe
    if ($LASTEXITCODE -ne 0) { throw "install.ps1 failed" }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[remote-install] done."

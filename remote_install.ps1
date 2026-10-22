$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$repo = "oscar269/gigafile-contextmenu"
$headers = @{ "User-Agent" = "gigafile-contextmenu-remote-install" }

# 最新リリースの zip アセットを探す
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
$asset = @($rel.assets | Where-Object { $_.name -match "\.zip$" })[0]
if (-not $asset) { throw "リリースに .zip アセットがありません: $($rel.tag_name)" }

Write-Host "[remote-install] downloading $($asset.name) ..."
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("gfc_install_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers $headers
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    # install.ps1 がファイルパス前提なので別プロセスで実行する
    $installer = Join-Path $tmp "install.ps1"
    $exe = Join-Path $tmp "gfu.exe"
    if (-not (Test-Path $installer)) { throw "install.ps1 が zip 内にありません" }
    & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $installer -ExePath $exe
    if ($LASTEXITCODE -ne 0) { throw "install.ps1 の実行に失敗しました" }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[remote-install] done."

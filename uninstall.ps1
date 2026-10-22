$ErrorActionPreference = "Continue"

$label2 = "ギガファイル便にまとめてアップロード"

# 右クリックメニュー解除
reg delete 'HKCU\Software\Classes\*\shell\GigaFileUpload' /f | Out-Null
if ($LASTEXITCODE -eq 0) { Write-Host "[uninstall] context menu: removed" }

# SendTo ショートカット削除
$sendTo  = [Environment]::GetFolderPath("SendTo")
$lnkPath = Join-Path $sendTo ($label2 + ".lnk")
if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force; Write-Host "[uninstall] SendTo shortcut: removed" }

# インストール先フォルダ削除
$dest = Join-Path $env:LOCALAPPDATA "GigaFileUploader"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force; Write-Host "[uninstall] install dir: removed" }

Write-Host "[uninstall] done."

$ErrorActionPreference = "Continue"

$label2 = "ギガファイル便にまとめてアップロード"   # 旧版 SendTo 清掃用

# 右クリックメニュー解除 (既定動作の1種 + 旧2択版, cmd 経由で静かに)
cmd /c 'reg delete "HKCU\Software\Classes\*\shell\GigaFileUpload" /f >nul 2>&1'
if ($LASTEXITCODE -eq 0) { Write-Host "[uninstall] context menu: removed" }
cmd /c 'reg delete "HKCU\Software\Classes\*\shell\GigaFileUploadZip" /f >nul 2>&1'
if ($LASTEXITCODE -eq 0) { Write-Host "[uninstall] context menu (legacy 2-choice): removed" }

# SendTo ショートカット削除 (旧構成の清掃)
$sendTo  = Join-Path $env:APPDATA "Microsoft\Windows\SendTo"
$lnkPath = Join-Path $sendTo ($label2 + ".lnk")
if (Test-Path $lnkPath) { Remove-Item $lnkPath -Force; Write-Host "[uninstall] SendTo shortcut: removed" }

# インストール先フォルダ削除
$dest = Join-Path $env:LOCALAPPDATA "GigaFileUploader"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force; Write-Host "[uninstall] install dir: removed" }

Write-Host "[uninstall] done."

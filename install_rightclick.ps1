$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA "GigaFileUploader"
$label1 = "ギガファイル便にアップロード(&U)"
$label2 = "ギガファイル便にまとめてアップロード"

Write-Host "[install] destination: $dest"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# --- exe 探索 (PyInstaller でビルド済みであること) ---
$exe = Join-Path $here "dist\gfu.exe"
if (-not (Test-Path $exe)) { throw "dist\gfu.exe が見つかりません。先に PyInstaller でビルドしてください" }
Write-Host "[install] binary: $exe"

# --- 本体コピー (旧 py 版があれば掃除) ---
Remove-Item (Join-Path $dest "gfu.cmd"), (Join-Path $dest "gigafile_poc.py") -Force -ErrorAction SilentlyContinue
Copy-Item -Force $exe (Join-Path $dest "gfu.exe")

# --- レジストリ: 全ファイルの右クリックメニュー (HKCU, 管理者不要) ---
# * はワイルドカード扱いされないよう reg.exe で登録する
$verbKey = 'HKCU\Software\Classes\*\shell\GigaFileUpload'
reg add $verbKey /ve /t REG_SZ /d $label1 /f | Out-Null
$cmdLine = '"'+(Join-Path $dest "gfu.exe")+'" "%1"'
reg add "$verbKey\command" /ve /t REG_SZ /d $cmdLine /f | Out-Null
Write-Host "[install] context menu: registered ($cmdLine)"

# --- SendTo: 複数選択 → まとめてアップロード ---
$ws = New-Object -ComObject WScript.Shell
$sendTo = [Environment]::GetFolderPath("SendTo")
$lnkPath = Join-Path $sendTo ($label2 + ".lnk")
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = (Join-Path $dest "gfu.exe")
$lnk.Description = "Upload selected files to gigafile.nu and get zip URL"
$lnk.Save()
Write-Host "[install] SendTo shortcut: $lnkPath"

Write-Host "[install] done."

$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path $env:LOCALAPPDATA "GigaFileUploader"
$label1 = "ギガファイル便にアップロード(&U)"
$label2 = "ギガファイル便にまとめてアップロード"

Write-Host "[install] destination: $dest"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# --- python.exe 探索 ---
$py = (Get-Command python.exe -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $py) { throw "python.exe not found in PATH" }
Write-Host "[install] python: $py"

# --- 本体コピー ---
Copy-Item -Force (Join-Path $here "gigafile_poc.py") (Join-Path $dest "gigafile_poc.py")

# --- ランチャ gfu.cmd (ASCII のみ。パスはインストール時に実パスへ) ---
$pyPath    = Join-Path $dest "gigafile_poc.py"
$gfuPath   = Join-Path $dest "gfu.cmd"
$gfuContent = "@echo off`r`n" +
              "rem == GigaFile Uploader launcher ==`r`n" +
              '"'+$py+'" "'+$pyPath+'" upload --clip %*' + "`r`n" +
              "echo.`r`n" +
              "pause`r`n"
[System.IO.File]::WriteAllText($gfuPath, $gfuContent, [System.Text.Encoding]::ASCII)

# --- レジストリ: 全ファイルの右クリックメニュー (HKCU, 管理者不要) ---
# * はワイルドカード扱いされないよう reg.exe で登録する
$verbKey = 'HKCU\Software\Classes\*\shell\GigaFileUpload'
reg add $verbKey /ve /t REG_SZ /d $label1 /f | Out-Null
$cmdLine = '"'+$gfuPath+'" "%1"'
reg add "$verbKey\command" /ve /t REG_SZ /d $cmdLine /f | Out-Null
Write-Host "[install] context menu: registered ($cmdLine)"

# --- SendTo: 複数選択 → まとめてアップロード ---
$ws = New-Object -ComObject WScript.Shell
$sendTo = [Environment]::GetFolderPath("SendTo")
$lnkPath = Join-Path $sendTo ($label2 + ".lnk")
$lnk = $ws.CreateShortcut($lnkPath)
$lnk.TargetPath = $gfuPath
$lnk.Description = "Upload selected files to gigafile.nu and get zip URL"
$lnk.Save()
Write-Host "[install] SendTo shortcut: $lnkPath"

Write-Host "[install] done."

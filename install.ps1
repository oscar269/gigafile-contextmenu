param(
    # exe のパスを明示指定できる。省略時は自動検出:
    #   開発: 本スクリプトと同じ場所の dist\gfu.exe
    #   zip: 本スクリプトと同じ場所の gfu.exe
    [string]$ExePath = ""
)
$ErrorActionPreference = "Stop"

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $here) { $here = (Get-Location).Path }
$dest = Join-Path $env:LOCALAPPDATA "GigaFileUploader"
$label1 = "ギガファイル便にアップロード(&U)"
$label2 = "ギガファイル便にまとめてアップロード"   # 旧版 SendTo 清掃用

if (-not $ExePath) {
    $cand1 = Join-Path $here "dist\gfu.exe"
    $cand2 = Join-Path $here "gfu.exe"
    if (Test-Path $cand1) { $ExePath = $cand1 }
    elseif (Test-Path $cand2) { $ExePath = $cand2 }
    else {
        throw "gfu.exe が見つかりません。zip を展開して install.bat を実行するか、`n" +
              "one-liner インストールしてください:`n irm https://raw.githubusercontent.com/oscar269/gigafile-contextmenu/main/remote_install.ps1 | iex"
    }
}

Write-Host "[install] binary: $ExePath"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# --- 本体コピー (旧 py 版残骸があれば掃除。実行中プロセスも停止) ---
Remove-Item (Join-Path $dest "gfu.cmd"), (Join-Path $dest "gigafile_poc.py") -Force -ErrorAction SilentlyContinue
Stop-Process -Name gfu -Force -ErrorAction SilentlyContinue
Start-Sleep 1
Copy-Item -Force $ExePath (Join-Path $dest "gfu.exe")

# --- レジストリ: 右クリックメニュー (HKCU, 管理者不要。1種のみ) ---
# * はワイルドカード扱いされないよう reg.exe で登録する
# 旧版に作った2択・SendTo が残っていれば清掃する
$exeInstalled = Join-Path $dest "gfu.exe"
# 旧2択版の残骸清掃 (cmd 経由で stderr も完全に握りつぶす)
cmd /c 'reg delete "HKCU\Software\Classes\*\shell\GigaFileUploadZip" /f >nul 2>&1'
reg add 'HKCU\Software\Classes\*\shell\GigaFileUpload' /ve /t REG_SZ /d $label1 /f | Out-Null
reg add 'HKCU\Software\Classes\*\shell\GigaFileUpload\command' /ve /t REG_SZ /d ('"'+$exeInstalled+'" "%1"') /f | Out-Null
Write-Host "[install] context menu: registered"
Write-Host "  $label1 -> $exeInstalled"

# 旧 SendTo ショートカット清掃
$sendTo = Join-Path $env:APPDATA "Microsoft\Windows\SendTo"
$oldLnk = Join-Path $sendTo ($label2 + ".lnk")
if (Test-Path $oldLnk) { Remove-Item $oldLnk -Force; Write-Host "[install] legacy SendTo shortcut: removed" }

Write-Host "[install] done."

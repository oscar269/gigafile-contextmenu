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
$label2 = "ギガファイル便にまとめてアップロード"

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

# --- 本体コピー (旧 py 版残骸があれば掃除) ---
Remove-Item (Join-Path $dest "gfu.cmd"), (Join-Path $dest "gigafile_poc.py") -Force -ErrorAction SilentlyContinue
Copy-Item -Force $ExePath (Join-Path $dest "gfu.exe")

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

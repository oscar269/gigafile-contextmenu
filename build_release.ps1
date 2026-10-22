$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $here) { $here = (Get-Location).Path }
Set-Location $here

# --- 1. ビルド ---
python -m PyInstaller --onefile --console --name gfu gigafile_poc.py
if ($LASTEXITCODE -ne 0) { throw "PyInstaller build failed" }
Write-Host "[release] build ok: $(Join-Path $here 'dist\gfu.exe')"

# --- 2. ステージング ---
$stage = Join-Path $here "release_stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item (Join-Path $here "dist\gfu.exe") $stage
Copy-Item (Join-Path $here "install.ps1"), (Join-Path $here "uninstall.ps1"), `
          (Join-Path $here "install.bat"), (Join-Path $here "uninstall.bat"), `
          (Join-Path $here "packaging\README.txt") $stage

# --- 3. zip 化 ---
$zip = Join-Path $here "gigafile-contextmenu.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -Force
Write-Host "[release] zip: $zip ($((Get-Item $zip).Length) bytes)"

# --- 4. GitHub Release 作成 ---
$tag = "v1.0.0"
$notes = @"
## gigafile-contextmenu v1.0.0

ギガファイル便 (gigafile.nu) に Windows の右クリックメニューから直接アップロードできるツール。**Python 不要** (単一 exe)。

### インストール

**方法A: zip** - 上の gigafile-contextmenu.zip をダウンロードして展開 → install.bat をダブルクリック

**方法B: 一行コピペ** (PowerShell に貼り付け)

``````powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/oscar269/gigafile-contextmenu/main/remote_install.ps1 | iex"
``````

### 使い方

- 単一ファイル: 右クリック → 「ギガファイル便にアップロード」
- 複数ファイル: 右クリック → 送る → 「ギガファイル便にまとめてアップロード」
完了後、URL が自動でクリップボードにコピーされます。

### 免責

非公式ツール。無保証・自己責任。内部 API 直叩きのためサイト仕様変更で動かなくなる可能性あり。SmartScreen/ウイルス対策ソフトに誤検知される可能性あり (署名なし exe)。

アンインストール: zip 内の uninstall.bat または https://github.com/oscar269/gigafile-contextmenu#readme
"@
$notesFile = Join-Path $here "release_notes.md"
[IO.File]::WriteAllText($notesFile, $notes, (New-Object System.Text.UTF8Encoding($true)))

gh release create $tag $zip --title "gigafile-contextmenu v1.0.0" --notes-file $notesFile
if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $notesFile -Force -ErrorAction SilentlyContinue
Write-Host "[release] done."

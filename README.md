# gigafile-contextmenu

ギガファイル便 (https://gigafile.nu/) に Windows の右クリックメニューから直接アップロードするツール。

Web UI が裏で利用している内部 API (`/upload_chunk.php` など) を直接叩く方式。公式 API は存在しないため、サイトの仕様変更で動かなくなる可能性がある。**本リポジトリは非公式ツールであり、ギガファイル便運営「株式会社ギガファイル」とは無関係です。**

## 機能

- チャンク分割アップロード (既定 100MB/チャンク, 1ファイル最大 300GB)
- 複数ファイル → 「まとめてダウンロード」zip URL 自動発行
- 個別 DL パスワード / zip パスワード設定
- 進捗表示 (チャンク単位 + リアルタイム送信バイト数)
- ネットワークエラー時は 30 回まで 10 秒間隔でリトライ (Web UI と同一仕様)
- URL 自動クリップボードコピー / 完了待ち (メニュー実行時)
- アップロード済み URL の削除 (`delete`)

## インストール (Python 不要)

**方法A: zip**
GitHub Releases から `gigafile-contextmenu.zip` をダウンロード → 展開 → `install.bat` をダブルクリック

**方法B: 一行コピペ** (PowerShell に貼り付け)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/oscar269/gigafile-contextmenu/main/remote_install.ps1 | iex"
```

どちらも:

- `%LOCALAPPDATA%\GigaFileUploader\` に `gfu.exe` を配置
- `HKCU` に「ギガファイル便にアップロード(&U)」コンテキストメニュー登録 (管理者不要)
- SendTo に「ギガファイル便にまとめてアップロード」ショートカット登録

### 開発者用ビルド

```bash
pip install pyinstaller requests
python -m PyInstaller --onefile --console --name gfu gigafile_poc.py
powershell -ExecutionPolicy Bypass -File install.ps1   # dist\gfu.exe を検出して登録
```

リリースの作成: `build_release.ps1` (ビルド → zip → GitHub Release 添付まで自動)

## 使い方

**右クリックメニュー**

| メニュー | 動作 |
|---|---|
| ギガファイル便にアップロード(&U) | そのままアップロード → URL をクリップボードへ |

- 複数ファイルを選択して実行した場合、Windows の仕様でファイルごとに個別起動され、ファイルごとのURLがクリップボードに返ります。
- CLI でまとめ URL を作る場合は `--zip` (1ファイル) や複数ファイル指定 (自動で zip) を使用します。
- メニュー実行時は**共有用 URL のみ**クリップボードにコピーされる（zip があれば zip URL のみ）。delkey 等はコンソールに表示されるので確認すること

CLI (exe / python どちらでも):

```bash
# アップロード (複数ファイル → zip URL も発行)
gfu.exe file1.bin file2.txt

# オプション
gfu.exe [ファイル...] [--lifetime 7] [--password abcd]
        [--zip-password abcd] [--zip-name 名前]
        [--no-matomete] [--chunk-size 100] [--clip/--no-clip] [--hold/--no-hold]

# 削除
gfu.exe delete <URL> <delkey>
```

- `--lifetime`: 保存期限日数 (既定 7)
- `--chunk-size`: チャンクサイズ MB (テスト用に小さくできる)
- `--clip` / `--hold`: 省略時はメニュー実行=ON / 明示 CLI 実行=OFF

## 更新

PyInstaller で再ビルド → `install.ps1` 再実行で `%LOCALAPPDATA%` に上書き。

## アンインストール

zip に入っている `uninstall.bat`（またはリポジトリの `uninstall.ps1`）を実行。

## 免責事項

- 本ツールは非公式かつ無保証。**自己責任**で使用すること
- 内部 API は逆引きによるもので、ギガファイル便側の仕様変更・レート制限により動作しなくなる可能性がある
- 利用規約で自動アクセスを制限している場合、本ツールの利用が規約違反と判断される可能性がある
- 逆引きは自作再実装であり、公式コードの複製は含まない

## 注意

- Windows 11 では右クリックメニューは「その他のオプション」(旧メニュー) 配下に表示される
- exe 化でウイルス対策ソフトに誤検知される可能性がある (PyInstaller 一般的挙動)

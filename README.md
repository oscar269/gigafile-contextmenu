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

## インストール

ビルド済み `dist/gfu.exe` がある状態で:

```powershell
powershell -ExecutionPolicy Bypass -File install_rightclick.ps1
```

- `%LOCALAPPDATA%\GigaFileUploader\` に `gfu.exe` を配置
- `HKCU` に「ギガファイル便にアップロード(&U)」コンテキストメニュー登録 (管理者不要)
- SendTo に「ギガファイル便にまとめてアップロード」ショートカット登録
- **Python 実行環境は不要** (単一exe)

### ビルド方法 (開発者用)

```bash
pip install pyinstaller requests
python -m PyInstaller --onefile --console --name gfu gigafile_poc.py
```

## 使い方

GUI (インストール後):

- 単一ファイル: 右クリック → 「ギガファイル便にアップロード」
- 複数ファイル: 右クリック → 送る → 「ギガファイル便にまとめてアップロード」
- メニュー実行時は URL が自動でクリップボードにコピーされ、Enter で終了

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

ソース変更後、PyInstaller で再ビルド → `install_rightclick.ps1` を再実行すれば `%LOCALAPPDATA%` に上書きされる。

## アンインストール

```powershell
powershell -ExecutionPolicy Bypass -File uninstall_rightclick.ps1
```

## 免責事項

- 本ツールは非公式かつ無保証。**自己責任**で使用すること
- 内部 API は逆引きによるもので、ギガファイル便側の仕様変更・レート制限により動作しなくなる可能性がある
- 利用規約で自動アクセスを制限している場合、本ツールの利用が規約違反と判断される可能性がある
- 逆引きは自作再実装であり、公式コードの複製は含まない

## 注意

- Windows 11 ではレジストリ登録型メニューは「その他のオプション」(旧メニュー) 配下に表示される
- exe 化でウイルス対策ソフトに誤検知される可能性がある (PyInstaller 一般的挙動)

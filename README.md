# gigafile-contextmenu

ギガファイル便 (https://gigafile.nu/) に Windows の右クリックメニューから直接アップロードする CLI + コンテキストメニュー統合ツール。

Web UI が裏で利用している内部 API (`/upload_chunk.php` など) を直接叩く方式。公式 API は存在しないため、サイトの仕様変更で動かなくなる可能性がある。

## 機能

- チャンク分割アップロード (既定 100MB/チャンク, 1ファイル最大 300GB)
- 複数ファイル → 「まとめてダウンロード」zip URL 自動発行
- 個別 DL パスワード / zip パスワード設定
- 進捗表示 (チャンク単位 + リアルタイム送信バイト数)
- ネットワークエラー時は 30 回まで 10 秒間隔でリトライ (Web UI と同一仕様)
- 完了 URL のクリップボード自動コピー (`--clip`)
- アップロード済み URL の削除 (`delete`)

## インストール

```powershell
powershell -ExecutionPolicy Bypass -File install_rightclick.ps1
```

- `%LOCALAPPDATA%\GigaFileUploader\` に本体とランチャを配置
- `HKCU` に「ギガファイル便にアップロード(&U)」コンテキストメニュー登録 (管理者不要)
- SendTo に「ギガファイル便にまとめてアップロード」ショートカット登録

## 使い方

GUI (インストール後):

- 単一ファイル: 右クリック → 「ギガファイル便にアップロード」
- 複数ファイル: 右クリック → 送る → 「ギガファイル便にまとめてアップロード」

CLI:

```bash
# アップロード (複数ファイル → zip URL も発行)
python gigafile_poc.py upload file1.bin file2.txt --clip

# 単体のみ / オプション
python gigafile_poc.py upload [ファイル...] [--lifetime 7] [--password abcd]
                            [--zip-password abcd] [--zip-name 名前]
                            [--no-matomete] [--chunk-size 100] [--clip]

# 削除
python gigafile_poc.py delete <URL> <delkey>
```

- `--lifetime`: 保存期限日数 (既定 7)
- `--chunk-size`: チャンクサイズ MB (テスト用に小さくできる)

## 更新

ソース変更後、`install_rightclick.ps1` を再実行すれば `%LOCALAPPDATA%` に上書きコピーされる。

## アンインストール

```powershell
powershell -ExecutionPolicy Bypass -File uninstall_rightclick.ps1
```

## 注意

- Windows 11 ではレジストリ登録型メニューは「その他のオプション」(旧メニュー) 配下に表示される
- 内部 API は非公式。レート制限や仕様変更のリスクあり

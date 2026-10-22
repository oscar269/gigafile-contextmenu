#!/usr/bin/env python3
"""
GigaFile(ギガファイル便) アップロード CLI (PoC→実用版)
https://gigafile.nu/

Web UI が叩いている内部APIを直接利用する。
  - トップページの var server = "xx.gigafile.nu"; からサブドメ取得
  - /upload_chunk.php    : 100MBごとのチャンク分割アップロード
  - /set_dlkey.php       : 個別 DL パスワード(半角英数1-4)
  - /matomete_get_url.php: 複数ファイルの「まとめてダウンロード」URL発行
  - /remove.php          : 個別ファイル削除
  - /matomete_delete_url.php : zip URL 削除

使い方:
  python gigafile_poc.py upload <ファイル...> [--lifetime 7] [--password abcd]
                              [--zip-password abcd] [--zip-name 名前]
                              [--no-matomete] [--chunk-size 100] [--clip]
  python gigafile_poc.py delete <URL> <delkey>
"""

import argparse
import ctypes
import ctypes.wintypes as wt
import json
import math
import os
import random
import re
import sys
import time

import requests

TOP_URL = "https://gigafile.nu/"
UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
DEFAULT_CHUNK = 100  # MB
MAX_RETRY = 30       # gfupload 同様: ネットワーク系は30回まで
RETRY_WAIT = 10      # 秒
DLKEY_MAX = 4        # パスワードは半角英数1〜4文字
ZIP_UNSAFE = '\\/:,;*?"<>|'


# ---------------------------------------------------------------- utils
def force_utf8_console() -> None:
    """Windows の cp932 コンソール/パイプでも文字化けしないように"""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


class HardFail(Exception):
    """リトライしても意味がない失敗(4xx/5xx, JSON不正, status!=0)"""


class ProgressBytes:
    """multipart 部品として requests に渡すための進捗付き bytes 風オブジェクト"""

    def __init__(self, data: bytes, base_sent: int, total: int, label: str):
        self._data = data
        self._pos = 0
        self._base = base_sent
        self._total = total
        self._label = label
        self._last_print = 0.0

    def __len__(self) -> int:
        return len(self._data)

    def read(self, size: int = -1) -> bytes:
        if self._pos >= len(self._data):
            return b""
        end = len(self._data) if size is None or size < 0 else min(self._pos + size, len(self._data))
        chunk = self._data[self._pos:end]
        self._pos = end
        self._print()
        return chunk

    def _print(self) -> None:
        now = time.time()
        if now - self._last_print < 0.5 and self._pos < len(self._data):
            return
        self._last_print = now
        sent = self._base + self._pos
        pct = 100.0 * sent / self._total if self._total else 100.0
        sys.stdout.write(f"\r  {self._label} 送信中 {sent / 1048576:.1f}MB / {self._total / 1048576:.1f}MB ({pct:5.1f}%) ")
        sys.stdout.flush()

    def finish(self) -> None:
        sys.stdout.write("\n")
        sys.stdout.flush()


def copy_to_clipboard(text: str) -> bool:
    """Windows 標準APIのみでクリップボードへコピー"""
    if os.name != "nt":
        return False
    CF_UNICODETEXT, GMEM_MOVEABLE = 13, 0x2000
    try:
        user32 = ctypes.WinDLL("user32")
        kernel32 = ctypes.WinDLL("kernel32")
        # 64bit プロセスでハンドルが切り詰められないよう型を明示
        for fn, argt, rest in [
            (kernel32.GlobalAlloc, [ctypes.c_uint, ctypes.c_size_t], ctypes.c_void_p),
            (kernel32.GlobalLock, [ctypes.c_void_p], ctypes.c_void_p),
            (kernel32.GlobalUnlock, [ctypes.c_void_p], ctypes.c_int),
            (kernel32.GlobalFree, [ctypes.c_void_p], ctypes.c_void_p),
            (user32.SetClipboardData, [ctypes.c_uint, ctypes.c_void_p], ctypes.c_void_p),
            (user32.EmptyClipboard, [], ctypes.c_int),
            (user32.CloseClipboard, [], ctypes.c_int),
            (user32.OpenClipboard, [wt.HWND], ctypes.c_int),
        ]:
            fn.argtypes, fn.restype = argt, rest

        buf = ctypes.create_unicode_buffer(text)  # 終端NUL込み
        size = ctypes.sizeof(buf)
        if not user32.OpenClipboard(None):
            return False
        try:
            user32.EmptyClipboard()
            h = kernel32.GlobalAlloc(GMEM_MOVEABLE, size)
            if not h:
                return False
            p = kernel32.GlobalLock(h)
            if not p:
                kernel32.GlobalFree(h)
                return False
            try:
                ctypes.memmove(p, buf, size)
            finally:
                kernel32.GlobalUnlock(h)
            if not user32.SetClipboardData(CF_UNICODETEXT, h):
                kernel32.GlobalFree(h)
                return False
            return True
        finally:
            user32.CloseClipboard()
    except Exception as exc:
        print(f"(クリップボード失敗: {exc})", file=sys.stderr)
        return False


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024.0:
            return f"{n:.1f}{unit}" if unit != "B" else f"{int(n)}B"
        n /= 1024.0
    return f"{n:.1f}TB"


# ---------------------------------------------------------------- session
def make_session() -> requests.Session:
    s = requests.Session()
    s.headers.update({"User-Agent": UA})
    return s


def get_server(session: requests.Session) -> str:
    html = session.get(TOP_URL, timeout=30).text
    m = re.search(r'var\s+server\s*=\s*"([^"]+)"', html)
    if not m:
        raise RuntimeError("server 変数が見つかりませんでした(ページ仕様が変わった可能性)")
    return m.group(1)


def gen_task_id() -> str:
    """common.js の uniqid(32) と同形式の32桁hex"""
    chars = []
    for i in range(32):
        if i == 12:
            chars.append("4")
        elif i == 16:
            chars.append(format(random.randint(0, 3) | 8, "x"))
        else:
            chars.append(format(random.randint(0, 15), "x"))
    return "".join(chars)


# ---------------------------------------------------------------- core API
def post_with_retry(session: requests.Session, url: str, prepare,
                    retries: int = MAX_RETRY, wait: float = RETRY_WAIT):
    """gfupload と同じ方針: ネットワーク系は30回/10秒待ちでリトライ,
    4xx/5xx・JSON不正は即失敗"""
    last_err = None
    for attempt in range(retries + 1):
        if attempt:
            print(f"  リトライ {attempt}/{retries} ({wait}秒待機)")
            time.sleep(wait)
        try:
            resp = session.post(url, **prepare())
            if resp.status_code >= 400:
                raise HardFail(f"HTTP {resp.status_code}")
            try:
                j = resp.json()
            except ValueError:
                raise HardFail(f"JSONでない応答: {resp.text[:200]!r}")
            if j.get("status") != 0:
                raise HardFail(f"status={j.get('status')} message={j.get('message')}")
            return j
        except HardFail as e:
            raise RuntimeError(str(e))
        except (requests.ConnectionError, requests.Timeout) as e:
            last_err = e
    raise RuntimeError(f"リトライ上限に達しました: {last_err}")


def upload_one(session: requests.Session, server: str, path: str,
               lifetime: int, chunk_mb: int) -> dict:
    """1ファイル分のチャンクアップロード。応答 JSON(url, filename, delkey)を返す"""
    task_id = gen_task_id()
    name = os.path.basename(path)
    size = os.path.getsize(path)
    chunk_size = chunk_mb * 1048576
    chunks = max(1, math.ceil(size / chunk_size))
    url = f"https://{server}/upload_chunk.php"
    base = 0
    result = None

    print(f"  id={task_id}")
    with open(path, "rb") as f:
        for idx in range(chunks):
            data = f.read(chunk_size)
            label = f"chunk {idx + 1}/{chunks} ({human(size)})"
            prog = ProgressBytes(data, base, size, label)

            def prepare(p=prog):
                return {
                    "files": {
                        "id": (None, task_id),
                        "name": (None, name),
                        "chunk": (None, str(idx)),
                        "chunks": (None, str(chunks)),
                        "file": (name, p, "application/octet-stream"),
                        "lifetime": (None, str(lifetime)),
                    },
                    "headers": {"Referer": TOP_URL},
                    "timeout": (30, 180),
                }

            try:
                result = post_with_retry(session, url, prepare)
            finally:
                prog.finish()
            base += len(data)
    return result


def set_dlkey(session: requests.Session, server: str, filename: str,
              delkey: str, dlkey: str) -> bool:
    resp = session.get(
        f"https://{server}/set_dlkey.php",
        params={"file": filename, "delkey": delkey, "dlkey": dlkey},
        headers={"Referer": TOP_URL},
        timeout=30,
    )
    try:
        return resp.json().get("status") == 0
    except ValueError:
        return False


def matomete_get_url(session: requests.Session, server: str,
                     urls, dlkeys, file_name: str, dlkey: str, lifetime: int) -> dict:
    """まとめてダウンロードURL発行。jQueryの $.ajax と同じく urls[] 形式で送る"""
    body = [("urls[]", u) for u in urls]
    body += [("dlkeys[]", k) for k in dlkeys]
    body += [("file_name", file_name), ("dlkey", dlkey), ("lifetime", str(lifetime))]
    resp = session.post(
        f"https://{server}/matomete_get_url.php",
        data=body,
        headers={"Referer": TOP_URL},
        timeout=60,
    )
    try:
        j = resp.json()
    except ValueError:
        raise RuntimeError(f"まとめURL発行失敗(非JSON): {resp.text[:200]!r}")
    if j.get("status") != 0:
        raise RuntimeError(f"まとめURL発行失敗: {j}")
    return j


def delete_file(session: requests.Session, server: str, key: str, delkey: str) -> dict:
    """個別ファイル削除 (remove.php, GET: file=<key>&delkey=)"""
    resp = session.get(
        f"https://{server}/remove.php",
        params={"file": key, "delkey": delkey},
        headers={"Referer": TOP_URL},
        timeout=30,
    )
    try:
        return resp.json()
    except ValueError:
        return {"status": -1, "raw": resp.text[:200]}


def key_from_url(url: str) -> str:
    m = re.search(r"gigafile\.nu/([0-9a-f\-]+)", url)
    if not m:
        raise ValueError(f"URLからkeyを抽出できません: {url}")
    return m.group(1)


# ---------------------------------------------------------------- commands
def cmd_upload(args) -> int:
    files = [os.path.abspath(p) for p in args.files]
    for p in files:
        if not os.path.isfile(p):
            print(f"ファイルが存在しません: {p}", file=sys.stderr)
            return 2
    if args.password and not re.fullmatch(r"[0-9a-zA-Z]{1,4}", args.password):
        print("--password は半角英数1〜4文字", file=sys.stderr)
        return 2
    if args.zip_password and not re.fullmatch(r"[0-9a-zA-Z]{0,4}", args.zip_password):
        print("--zip-password は半角英数0〜4文字", file=sys.stderr)
        return 2
    if args.zip_name and re.search("[" + re.escape(ZIP_UNSAFE) + "]", args.zip_name):
        print(f"zip名に使えない文字: {ZIP_UNSAFE}", file=sys.stderr)
        return 2
    # サイトと同じルール: 個別パスあり → zipにもパス必須
    if args.password and len(files) >= 2 and not args.no_matomete and not args.zip_password:
        print("個別パスワード設定時は --zip-password も必要です(--no-matomete 可)", file=sys.stderr)
        return 2

    session = make_session()
    server = get_server(session)
    print(f"[server] {server}")

    results = []
    for i, path in enumerate(files, 1):
        print(f"[一括upload {i}/{len(files)}] {os.path.basename(path)} ({human(os.path.getsize(path))})")
        j = upload_one(session, server, path, args.lifetime, args.chunk_size)
        if args.password:
            ok = set_dlkey(session, server, j["filename"], j["delkey"], args.password)
            print(f"  パスワード設定: {'OK' if ok else '失敗'}")
        results.append({"url": j["url"], "delkey": j["delkey"], "file": os.path.basename(path)})

    zip_result = None
    if len(results) >= 2 and not args.no_matomete:
        zfile = args.zip_name or ""
        print(f"[まとめてダウンロード] {len(results)}ファイル, zip名'{zfile or '(自動)'}'")
        zip_result = matomete_get_url(
            session, server,
            [r["url"] for r in results],
            [args.password or r["delkey"] for r in results],
            zfile, args.zip_password or "", args.lifetime,
        )

    print("\n=== 結果 ===")
    lines = []
    for i, r in enumerate(results, 1):
        line = f"{i}. {r['url']}  (delkey: {r['delkey']}, {r['file']})"
        print(line)
        lines.append(line)
    if zip_result:
        zline = f"zip: {zip_result['url']}  (zip名: {zip_result['file_name']}, delkey: {zip_result['delkey']})"
        print(zline)
        lines.append(zline)

    if args.clip:
        if copy_to_clipboard("\n".join(lines)):
            print("→ クリップボードにコピーしました")
    return 0


def cmd_delete(args) -> int:
    session = make_session()
    html = session.get(TOP_URL, timeout=30).text
    m = re.search(r'var\s+server\s*=\s*"([^"]+)"', html)
    if not m:
        raise RuntimeError("server 変数が見つかりません")
    server = m.group(1)
    key = key_from_url(args.url)
    j = delete_file(session, server, key, args.delkey)
    print(json.dumps(j, ensure_ascii=False))
    if j.get("status") == 0:
        print("削除成功")
        return 0
    # zip URL の場合は matomete_delete_url.php
    resp = session.post(
        f"https://{server}/matomete_delete_url.php",
        data={"url": args.url, "delkey": args.delkey},
        headers={"Referer": TOP_URL},
        timeout=30,
    )
    try:
        j2 = resp.json()
    except ValueError:
        j2 = {"status": -1}
    print(json.dumps(j2, ensure_ascii=False))
    return 0 if j2.get("status") == 0 else 1


def main() -> int:
    force_utf8_console()
    argv = sys.argv[1:]
    if argv and argv[0] == "delete":
        argv = argv[1:]
        ap = argparse.ArgumentParser(prog="gigafile delete")
        ap.add_argument("url")
        ap.add_argument("delkey")
        args = ap.parse_args(argv)
        return cmd_delete(args)

    ap = argparse.ArgumentParser(
        prog="gigafile_poc.py",
        description="ギガファイル便 CLI アップローダ (内部API直叩き)",
    )
    sub = ap.add_subparsers(dest="cmd")
    up = sub.add_parser("upload", help="アップロード")
    up.add_argument("files", nargs="+", help="アップロードするファイル(複数可)")
    up.add_argument("--lifetime", type=int, default=7, help="保存期限(日, 既定7)")
    up.add_argument("--password", default="", help="個別DLパスワード(半角英数1-4)")
    up.add_argument("--zip-password", default="", help="zipのDLパスワード(半角英数0-4)")
    up.add_argument("--zip-name", default="", help="まとめzipの表示名(使用不可: %s)" % ZIP_UNSAFE)
    up.add_argument("--no-matomete", action="store_true", help="まとめURLを発行しない")
    up.add_argument("--chunk-size", type=int, default=DEFAULT_CHUNK, help="チャンクMB(既定100, テスト用に小さく可)")
    up.add_argument("--clip", action="store_true", help="結果URLをクリップボードへコピー")
    args = ap.parse_args(argv)
    if not args.cmd:
        ap.print_help()
        return 2
    if args.cmd == "upload":
        if args.chunk_size < 1 or args.chunk_size > 100:
            print("--chunk-size は 1〜100MB で指定", file=sys.stderr)
            return 2
        return cmd_upload(args)
    return 2


if __name__ == "__main__":
    sys.exit(main())

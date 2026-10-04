"""Offline Godot/itch.io web package audit; does not replace browser execution."""
from __future__ import annotations

import argparse
from html.parser import HTMLParser
import json
from pathlib import Path, PurePosixPath
import re
import tempfile
from urllib.parse import unquote, urlsplit
import zipfile


class References(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.paths: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        key = "href" if tag == "link" else "src"
        if tag in {"script", "link", "img", "source"} and values.get(key):
            self.paths.append(values[key] or "")


def audit(path: Path) -> dict:
    issues: list[str] = []
    warnings: list[str] = []
    archive = zipfile.ZipFile(path) if path.is_file() else None
    try:
        if archive:
            entries = [entry for entry in archive.infolist() if not entry.is_dir()]
            sizes = {entry.filename: entry.file_size for entry in entries}
            if len(sizes) != len(entries):
                issues.append("ZIP contains duplicate filenames")

            def read(name: str, limit: int | None = None) -> bytes:
                with archive.open(name) as stream:
                    return stream.read() if limit is None else stream.read(limit)
        else:
            sizes = {entry.relative_to(path).as_posix(): entry.stat().st_size
                     for entry in path.rglob("*") if entry.is_file()}

            def read(name: str, limit: int | None = None) -> bytes:
                with (path / name).open("rb") as stream:
                    return stream.read() if limit is None else stream.read(limit)

        if len(sizes) > 1000:
            issues.append("More than 1,000 extracted files")
        if sum(sizes.values()) > 500_000_000:
            issues.append("Extracted content exceeds 500 MB")
        for name, size in sizes.items():
            parts = PurePosixPath(name).parts
            if name.startswith("/") or "\\" in name or ".." in parts or re.match(r"^[A-Za-z]:", name):
                issues.append(f"Unsafe/nonportable archive path: {name}")
            if len(name) > 240:
                issues.append(f"Path exceeds 240 characters: {name}")
            if size > 200_000_000:
                issues.append(f"File exceeds 200 MB: {name}")
            if name.lower().endswith((".exe", ".ps1", ".pdb", ".cmd")):
                issues.append(f"Desktop/build artifact included: {name}")

        def require(name: str) -> bool:
            if name in sizes:
                return True
            alternative = next((key for key in sizes if key.lower() == name.lower()), None)
            issues.append(f"Case mismatch: {name} != {alternative}" if alternative else f"Missing file: {name}")
            return False

        config: dict = {}
        if require("index.html"):
            html = read("index.html").decode("utf-8-sig")
            parser = References()
            parser.feed(html)
            for ref in parser.paths:
                parsed = urlsplit(ref)
                if parsed.scheme or parsed.netloc:
                    if parsed.scheme not in {"data", "blob"}:
                        warnings.append(f"External dependency: {ref}")
                    continue
                if parsed.path.startswith("/"):
                    issues.append(f"Absolute URL breaks itch.io subdirectory hosting: {ref}")
                elif parsed.path:
                    require(unquote(parsed.path).removeprefix("./"))
            match = re.search(r"(?:const|let|var)\s+GODOT_CONFIG\s*=\s*(\{.*?\})\s*;", html, re.S)
            if match:
                try:
                    config = json.loads(match.group(1))
                except json.JSONDecodeError as error:
                    issues.append(f"GODOT_CONFIG is not valid JSON: {error}")
            else:
                warnings.append("No standard GODOT_CONFIG found; custom loader must be reviewed manually")

        executable = str(config.get("executable", "index"))
        for suffix, magic in ((".wasm", b"\x00asm\x01\x00\x00\x00"), (".pck", b"GDPC")):
            name = executable + suffix
            if require(name) and read(name, len(magic)) != magic:
                issues.append(f"Invalid {suffix} header: {name}")
        require(executable + ".js")
        for name, expected in config.get("fileSizes", {}).items():
            if require(name) and sizes[name] != expected:
                issues.append(f"Loader size mismatch: {name}: {sizes[name]} != {expected}")
        if config.get("ensureCrossOriginIsolationHeaders"):
            warnings.append("Loader requests cross-origin isolation; verify intentional threaded/PWA configuration")
        return {"path": str(path.resolve()), "files": len(sizes), "uncompressed_bytes": sum(sizes.values()),
                "largest_file": max(sizes, key=sizes.get) if sizes else None, "executable": executable,
                "config": config, "issues": issues, "warnings": warnings,
                "scope": "Offline links, file sizes, headers and itch.io limits; no browser was launched."}
    finally:
        if archive:
            archive.close()


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="someside-web-audit-") as temp:
        root = Path(temp)
        wasm = b"\x00asm\x01\x00\x00\x00"
        (root / "index.wasm").write_bytes(wasm)
        (root / "index.pck").write_bytes(b"GDPC")
        (root / "index.js").write_text("// test fixture", encoding="utf-8")
        config = {"executable": "index", "fileSizes": {"index.wasm": len(wasm), "index.pck": 4}}
        html = '<script src="index.js"></script><script>const GODOT_CONFIG = ' + json.dumps(config) + ';</script>'
        (root / "index.html").write_text(html, encoding="utf-8")
        assert not audit(root)["issues"]
        (root / "index.html").write_text(html.replace('src="index.js"', 'src="Index.js"'), encoding="utf-8")
        assert any("Case mismatch" in issue for issue in audit(root)["issues"])
        (root / "index.html").write_text(html.replace('src="index.js"', 'src="/index.js"'), encoding="utf-8")
        assert any("Absolute URL" in issue for issue in audit(root)["issues"])
        (root / "index.html").write_text(html, encoding="utf-8")
        (root / "index.wasm").write_bytes(b"not wasm")
        assert any("Invalid .wasm" in issue for issue in audit(root)["issues"])
        (root / "index.wasm").write_bytes(wasm)
        with zipfile.ZipFile(root / "web.zip", "w") as archive:
            for name in ("index.html", "index.js", "index.pck", "index.wasm"):
                archive.write(root / name, name)
        assert not audit(root / "web.zip")["issues"]
    print("WEB_ARTIFACT_AUDIT_SELF_TEST passed=5 failed=0")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", nargs="?", type=Path, help="Export folder or itch.io ZIP")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    elif not args.path or not args.path.exists():
        parser.error("Provide an existing export folder or ZIP")
    else:
        result = audit(args.path)
        payload = json.dumps(result, indent=2, ensure_ascii=False)
        if args.output:
            args.output.write_text(payload + "\n", encoding="utf-8")
        print(payload)
        raise SystemExit(bool(result["issues"]))

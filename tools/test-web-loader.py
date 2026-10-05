"""Check exported Web loader failures on loopback and direct file origins.

Requests are intercepted only by Playwright: the export is never modified.
The WASM module never starts; no gameplay or account session is opened.
"""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from threading import Thread
import time

from playwright.sync_api import sync_playwright


class QuietServer(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export", type=Path)
    parser.add_argument("--browser", required=True, type=Path)
    parser.add_argument("--engine", choices=("chromium", "firefox"), default="chromium")
    parser.add_argument("--file-only", action="store_true", help="Only verify direct-file guards in both languages")
    parser.add_argument("--output", type=Path, default=Path("tools/results/web-loader"))
    args = parser.parse_args()
    export = args.export.resolve(strict=True)
    if not (export / "index.html").is_file():
        parser.error("The export must contain index.html")
    args.output.mkdir(parents=True, exist_ok=True)
    source_html = (export / "index.html").read_text(encoding="utf-8-sig")
    feature_marker = "const missing = Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED });"
    if feature_marker not in source_html:
        parser.error("Cannot find the exported loader feature check")
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietServer, directory=str(export)))
    Thread(target=server.serve_forever, daemon=True).start()
    origin = f"http://127.0.0.1:{server.server_port}/"
    report = {"browser": str(args.browser), "browser_engine": args.engine, "export": str(export), "origin": origin, "cases": [], "errors": []}
    try:
        with sync_playwright() as playwright:
            failures = ("local-file",) if args.file_only else ("missing-wasm", "missing-loader", "unsupported-webgl", "local-file")
            for language, locale in (("en", "en-US"), ("zh", "zh-CN")):
                for failure in failures:
                    started = time.monotonic()
                    case = {"language": language, "failure": failure, "checks": [], "console_errors": [], "page_errors": [], "requests": [], "intercepts": 0}
                    report["cases"].append(case)
                    # A fresh browser also isolates startup failures that leave a pending engine promise.
                    browser = getattr(playwright, args.engine).launch(executable_path=str(args.browser), headless=True)
                    report["browser_version"] = browser.version
                    context = browser.new_context(viewport={"width": 1280, "height": 720}, locale=locale)
                    page = context.new_page()
                    page.set_default_timeout(20_000)
                    page.on("pageerror", lambda error, case=case: case["page_errors"].append(str(error)))
                    page.on("console", lambda message, case=case: case["console_errors"].append(message.text) if message.type == "error" else None)
                    page.on("request", lambda request, case=case: case["requests"].append(request.url))
                    def check(condition, name):
                        case["checks"].append({"name": name, "passed": bool(condition)})
                        print(("PASS " if condition else "FAIL ") + language + "/" + failure + " " + name, flush=True)
                        if not condition:
                            raise AssertionError(name)
                    try:
                        if failure == "unsupported-webgl":
                            html = source_html.replace(feature_marker, "Engine.getMissingFeatures = () => ['WebGL 2.0']; " + feature_marker, 1)
                            def block_features(route):
                                case["intercepts"] += 1
                                route.fulfill(status=200, content_type="text/html", body=html)
                            page.route(origin, block_features)
                        elif failure != "local-file":
                            target = "index.wasm" if failure == "missing-wasm" else "index.js"
                            def missing_asset(route):
                                case["intercepts"] += 1
                                route.fulfill(status=404, content_type="application/wasm" if target.endswith(".wasm") else "application/javascript", body="")
                            page.route(origin + target, missing_asset)
                        page.goto((export / "index.html").as_uri() if failure == "local-file" else origin, wait_until="domcontentloaded")
                        page.locator("#fallback").wait_for(state="visible")
                        case["fallback_seconds"] = round(time.monotonic() - started, 3)
                        message = page.locator("#message").inner_text()
                        case["message"] = message
                        if failure == "local-file":
                            check(page.url.startswith("file:") and case["intercepts"] == 0, "The actual local HTML file is opened without relaxed browser security or routing")
                            expected = "请通过本地预览服务器或 itch.io 打开游戏；直接双击 HTML 无法加载游戏文件。" if language == "zh" else "Open this game through a local preview server or itch.io. Opening the HTML file directly cannot load the game files."
                            check(expected in message, "Direct-file failure explains the required local server or itch.io launch")
                            hint = "本地开发：双击项目根目录的 PlayWeb.cmd。" if language == "zh" else "Local development: run PlayWeb.cmd from the project folder."
                            check(hint in page.locator("#hint").inner_text(), "The local-file hint names the actual project preview launcher")
                            check(page.locator("#retry").is_hidden(), "Direct-file failure omits a pointless reload button")
                            check(not any(url.endswith((".wasm", ".pck")) for url in case["requests"]), "The file-origin guard stops before requesting restricted game payloads")
                        else:
                            check(case["intercepts"] > 0, "The intended missing asset or feature was exercised")
                            check(message.startswith("启动失败。" if language == "zh" else "Unable to start."), "Failure explanation is visible in the browser language")
                            check(page.locator("#retry").is_visible() and page.locator("#retry").is_enabled() and page.locator("#retry").inner_text() == ("重试" if language == "zh" else "Retry"), "A localized retry action is visible and enabled")
                        check(page.locator("#status").is_visible() and page.locator("#progress").is_hidden(), "Failure replaces the loading spinner instead of waiting endlessly")
                        download = page.locator("#download")
                        check(download.is_visible() and download.inner_text() == ("下载 Windows 版" if language == "zh" else "Windows download") and download.get_attribute("href") == "https://bitetheddddt.itch.io/someside" and download.get_attribute("target") == "_blank" and "noopener" in download.get_attribute("rel"), "The localized fallback links to the user's Windows download page")
                        if failure == "unsupported-webgl":
                            check(not any(url.endswith((".wasm", ".pck")) for url in case["requests"]), "Unsupported WebGL stops before requesting the game payload")
                        if failure != "local-file":
                            previous = case["intercepts"]
                            with page.expect_navigation(wait_until="domcontentloaded"):
                                page.locator("#retry").click()
                            page.locator("#fallback").wait_for(state="visible")
                            check(case["intercepts"] > previous and page.locator("#progress").is_hidden(), "Retry reloads and returns to a visible fallback if the fault persists")
                        check(not case["page_errors"], "The failure path has no uncaught JavaScript exception")
                        page.screenshot(path=str(args.output / f"{language}-{failure}.png"))
                    except Exception as error:
                        case["error"] = str(error)
                        report["errors"].append(f"{language}/{failure}: {error}")
                        page.screenshot(path=str(args.output / f"{language}-{failure}-failed.png"))
                    finally:
                        case["elapsed_seconds"] = round(time.monotonic() - started, 3)
                        browser.close()
    finally:
        server.shutdown()
        server.server_close()
        checks = [check for case in report["cases"] for check in case["checks"]]
        report["passed"] = sum(check["passed"] for check in checks)
        report["failed"] = sum(not check["passed"] for check in checks) + len([case for case in report["cases"] if case.get("error") and all(check["passed"] for check in case["checks"])])
        (args.output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"WEB_LOADER_TEST_RESULT passed={report['passed']} failed={report['failed']}")
    if report["errors"] or report["failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

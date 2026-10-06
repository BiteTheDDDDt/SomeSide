"""Exercise an exported Web game in fresh Playwright profiles; no account access.

Requires Python Playwright and a Chromium-family browser. Serves only the export
directory on loopback. Optional CLI injection happens in intercepted test HTML,
never in the distributable. Screenshots are retained for visual review.
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


AUDIO_PROBE = """(() => {
  window.__audio = {contexts: [], starts: 0, taps: []};
  const Original = window.AudioContext;
  window.AudioContext = new Proxy(Original, {construct(target, args) {
    const ctx = Reflect.construct(target, args); __audio.contexts.push(ctx); return ctx;
  }});
  const connect = AudioNode.prototype.connect;
  AudioNode.prototype.connect = function(destination, ...args) {
    const result = connect.call(this, destination, ...args);
    if (destination === this.context.destination) {
      const tap = this.context.createAnalyser();
      connect.call(this, tap); __audio.taps.push(tap);
    }
    return result;
  };
  const start = AudioBufferSourceNode.prototype.start;
  AudioBufferSourceNode.prototype.start = function(...args) {
    __audio.starts++; return start.apply(this, args);
  };
})();"""

READ_PROFILE = r"""async () => {
  const results = [];
  for (const entry of await indexedDB.databases()) {
    const db = await new Promise((resolve, reject) => {
      const req = indexedDB.open(entry.name); req.onsuccess = () => resolve(req.result); req.onerror = reject;
    });
    for (const name of db.objectStoreNames) {
      const rows = await new Promise((resolve, reject) => {
        const req = db.transaction(name).objectStore(name).getAll(); req.onsuccess = () => resolve(req.result); req.onerror = reject;
      });
      for (const row of rows) if (row.contents) results.push(new TextDecoder().decode(row.contents));
    }
    db.close();
  }
  return results.filter(text => text.includes('[profile]')).join('\n');
}"""


class QuietServer(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export', type=Path)
    parser.add_argument('--browser', required=True, type=Path)
    parser.add_argument('--output', type=Path, default=Path('tools/results/web-browser'))
    parser.add_argument('--demo-only', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    game_server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietServer, directory=str(args.export.resolve())))
    # A different origin embeds the game without COOP/COEP, like itch's iframe.
    game_url = f'http://127.0.0.1:{game_server.server_port}/'
    class EmbedServer(QuietServer):
        def do_GET(self):
            body = ('<!doctype html><style>body{margin:0;background:#08141b}iframe{border:0;display:block;width:100vw;height:100vh}</style>'
                    f'<iframe src="{game_url}" allow="autoplay; fullscreen" allowfullscreen></iframe>').encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(body)
    embed_server = ThreadingHTTPServer(('127.0.0.1', 0), EmbedServer)
    for server in (game_server, embed_server):
        Thread(target=server.serve_forever, daemon=True).start()
    report = {'browser': str(args.browser), 'checks': [], 'logs': [], 'errors': []}
    def check(condition, name):
        report['checks'].append({'name': name, 'passed': bool(condition)})
        print(('PASS ' if condition else 'FAIL ') + name, flush=True)
        if not condition:
            raise AssertionError(name)
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path=str(args.browser), headless=True)
            report['version'] = browser.version
            context = browser.new_context(viewport={'width': 1280, 'height': 720}, locale='en-US')
            context.add_init_script(AUDIO_PROBE)
            page = context.new_page()
            def log(message):
                report['logs'].append({'type': message.type, 'text': message.text})
                if message.type == 'error': report['errors'].append(message.text)
            page.on('console', log)
            page.on('pageerror', lambda error: report['errors'].append(str(error)))
            page.on('requestfailed', lambda request: report['errors'].append(request.url + ': ' + str(request.failure)))
            page.on('response', lambda response: report['errors'].append(f'HTTP {response.status} {response.url}') if response.status >= 400 else None)
            def ready(previous=0):
                limit = time.monotonic() + 60
                while sum('SOMESIDE_READY' in row['text'] for row in report['logs']) <= previous:
                    if time.monotonic() > limit: raise TimeoutError('Game did not become ready')
                    page.wait_for_timeout(100)
                page.wait_for_timeout(600)
            def shot(name): page.screenshot(path=str(args.output / (name + '.png')))
            started = time.monotonic()
            if not args.demo_only:
                page.goto(f'http://localhost:{embed_server.server_port}/', wait_until='domcontentloaded')
                ready()
                frame = page.frames[1]
                report['cold_ready_seconds'] = round(time.monotonic() - started, 2)
                check(not frame.evaluate('crossOriginIsolated'), 'Cross-origin iframe runs without isolation headers')
                check(frame.locator('#status').is_hidden(), 'Loading screen dismisses after startup')
                report['renderer'] = frame.evaluate("""() => {const gl=document.querySelector('canvas').getContext('webgl2'); const ext=gl.getExtension('WEBGL_debug_renderer_info'); return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)}""")
                shot('menu-en')
                page.mouse.click(427, 462)
                page.wait_for_timeout(400)
                page.mouse.click(312, 194)  # Chinese language; the setting must survive reload.
                page.wait_for_timeout(500)
                page.mouse.click(339, 483)
                page.wait_for_timeout(500)
                check(frame.evaluate('!!document.fullscreenElement'), 'Settings button enters fullscreen from a real click')
                shot('settings-fullscreen')
                frame.evaluate('document.exitFullscreen()')
                page.wait_for_timeout(500)
                page.keyboard.press('F3')
                page.wait_for_timeout(1800)
                profile = frame.evaluate(READ_PROFILE)
                report['profile_before_reload'] = profile
                check('language="zh"' in profile and 'show_fps=false' in profile, 'Language and FPS preference reach IndexedDB')
                shot('settings-zh')
                audio = frame.evaluate("""() => ({states:__audio.contexts.map(c=>c.state), starts:__audio.starts, peaks:__audio.taps.map(a=>{const b=new Float32Array(a.fftSize);a.getFloatTimeDomainData(b);return Math.max(...b.map(Math.abs));})})""")
                report['audio'] = audio
                check('running' in audio['states'] and audio['starts'] > 0 and any(x > 0 for x in audio['peaks']), 'Gesture unlocks Web Audio with a nonzero output signal')
                count = sum('SOMESIDE_READY' in row['text'] for row in report['logs'])
                page.reload(wait_until='domcontentloaded')
                ready(count)
                frame = page.frames[1]
                check(frame.evaluate(READ_PROFILE) == profile, 'Saved preferences survive page reload')
                check(not frame.evaluate('!!document.fullscreenElement'), 'Reload does not automatically enter fullscreen')
                shot('menu-zh-restored')
                page.mouse.click(300, 238)
                page.wait_for_timeout(800)
                check(any('SOMESIDE_RUN_STARTED' in row['text'] for row in report['logs']), 'Real Single Player click starts a run')
                page.keyboard.down('d')
                page.mouse.move(900, 390)
                page.mouse.down()
                page.wait_for_timeout(1200)
                page.keyboard.down('Space')
                page.wait_for_timeout(120)
                page.keyboard.up('Space')
                page.wait_for_timeout(500)
                page.keyboard.down('a')
                page.wait_for_timeout(300)
                page.keyboard.up('a')
                page.wait_for_timeout(300)
                page.keyboard.up('d')
                page.mouse.up()
                shot('combat')
                page.keyboard.press('Tab'); page.wait_for_timeout(250); shot('inventory')
                page.keyboard.press('Tab'); page.keyboard.press('m'); page.wait_for_timeout(250); shot('map')
                page.keyboard.press('m')
                # DOM focus leaves iframe while a key is held; GDScript must pause/reset.
                page.keyboard.down('d')
                page.evaluate("document.body.tabIndex=0;document.body.focus()")
                page.keyboard.up('d')
                page.wait_for_timeout(300)
                shot('focus-loss-pause')
                for width, height in [(960, 540), (1920, 1080)]:
                    page.set_viewport_size({'width': width, 'height': height})
                    page.wait_for_timeout(350)
                    box = frame.locator('#canvas').bounding_box()
                    check(box and abs(box['width'] - width) <= 1 and abs(box['height'] - height) <= 1, f'Canvas fits {width}x{height} embed')
                    shot(f'pause-{width}')
                context.close()
            # Existing game automation reports concrete simulation ticks and full actor cache.
            context = browser.new_context(viewport={'width': 1280, 'height': 720}, locale='zh-CN')
            page = context.new_page()
            page.on('console', log)
            page.on('pageerror', lambda error: report['errors'].append(str(error)))
            html = (args.export / 'index.html').read_text(encoding='utf-8')
            html = html.replace('const engine = new Engine(GODOT_CONFIG);', 'GODOT_CONFIG.args = ["--", "--demo", "--duration=9"]; const engine = new Engine(GODOT_CONFIG);')
            page.route(game_url, lambda route: route.fulfill(status=200, content_type='text/html', body=html))
            count = sum('SOMESIDE_READY' in row['text'] for row in report['logs'])
            page.goto(game_url, wait_until='domcontentloaded'); ready(count)
            page.mouse.click(750, 420)
            page.wait_for_timeout(2500); shot('demo-combat-zh')
            deadline = time.monotonic() + 50
            while not any('SOMESIDE_AUTOMATION ' in row['text'] for row in report['logs']):
                if time.monotonic() > deadline: raise TimeoutError('Demo report missing')
                page.wait_for_timeout(200)
            payload = next(row['text'].split('SOMESIDE_AUTOMATION ', 1)[1] for row in report['logs'] if 'SOMESIDE_AUTOMATION ' in row['text'])
            report['simulation'] = json.loads(payload)
            sim = report['simulation']
            check(sim['started'] and sim['tick'] > 300 and sim['screen'] == 'playing', 'Browser simulation advances beyond 300 ticks')
            check(sim['language'] == 'zh', 'First launch detects the browser Chinese locale')
            check(sim['pixel_actors']['actors'] == 14, 'All 14 pixel actor definitions load')
            check(sim.get('attack_fx', {}).get('textures') == 8 and sim['attack_fx']['families'] == 18 and sim['attack_fx']['bytes'] <= sim['attack_fx']['max_bytes'], 'All 18 attack families share 8 sheets within the texture budget')
            check(not report['errors'], 'No browser, network or Godot runtime errors')
            browser.close()
    finally:
        for server in (game_server, embed_server): server.shutdown(); server.server_close()
        (args.output / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')


if __name__ == '__main__':
    main()

"""Serve a SomeSide Web export on loopback and open the default browser."""
from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit
import webbrowser


class PreviewHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map,
                      '.wasm': 'application/wasm', '.pck': 'application/octet-stream',
                      '.js': 'text/javascript; charset=utf-8'}

    def log_message(self, *_args):
        pass

    def list_directory(self, _path):
        self.send_error(403, 'Directory listing is disabled')

    def send_head(self):
        root = Path(self.directory).resolve()
        relative = unquote(urlsplit(self.path).path).lstrip('/') or 'index.html'
        candidate = (root / relative).resolve()
        if not candidate.is_relative_to(root) or candidate.name.startswith('.'):
            self.send_error(403, 'Path is outside the Web export')
            return None
        return super().send_head()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--port', type=int, default=8765)
    parser.add_argument('--no-browser', action='store_true')
    parser.add_argument('--ready-file', type=Path, help='Optional automation readiness JSON')
    args = parser.parse_args()
    root = args.directory.resolve()
    if not (root / 'index.html').is_file():
        parser.error('The directory must contain an exported index.html')
    if not 0 <= args.port <= 65535:
        parser.error('Port must be between 0 and 65535')
    try:
        server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(PreviewHandler, directory=str(root)))
    except OSError as error:
        parser.error(f'Cannot start local preview on port {args.port}: {error}. Close the previous preview or use --port 0.')
    url = f'http://127.0.0.1:{server.server_port}/'
    print(f'SomeSide Web preview: {url}\nKeep this window open while playing. Press Ctrl+C to stop.', flush=True)
    if args.ready_file:
        args.ready_file.write_text(json.dumps({'url': url, 'directory': str(root)}), encoding='utf-8')
    if not args.no_browser:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()

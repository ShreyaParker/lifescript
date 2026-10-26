"""Local-only release web server; never logs OAuth query strings."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class Handler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()


def main():
    directory = Path(__file__).resolve().parents[2] / 'frontend' / 'build' / 'web'
    if not (directory / 'index.html').is_file():
        raise SystemExit('Build the Flutter web app first.')
    server = ThreadingHTTPServer(('127.0.0.1', 8080), partial(Handler, directory=str(directory)))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()

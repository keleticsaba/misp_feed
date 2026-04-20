#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
import threading
import os

MAX_SESSIONS = 5
SERVE_DIR = "/home/misp/feed"
semaphore = threading.Semaphore(MAX_SESSIONS)

class LimitedHandler(SimpleHTTPRequestHandler):
    def handle(self):
        acquired = semaphore.acquire(blocking=False)
        if not acquired:
            self.connection.sendall(
                b"HTTP/1.1 503 Service Unavailable\r\n"
                b"Content-Type: text/plain\r\n\r\n"
                b"Too many connections (max 2).\n"
            )
            return
        try:
            super().handle()
        finally:
            semaphore.release()

    def translate_path(self, path):
        # Override to serve from /home/misp/feed instead of cwd
        root = SERVE_DIR
        path = super().translate_path(path)
        relpath = os.path.relpath(path, os.getcwd())
        return os.path.join(root, relpath)

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

if __name__ == "__main__":
    server = ThreadedHTTPServer(("0.0.0.0", 40000), LimitedHandler)
    print(f"Serving {SERVE_DIR} on http://0.0.0.0:40000 — max 5 concurrent sessions")
    server.serve_forever()


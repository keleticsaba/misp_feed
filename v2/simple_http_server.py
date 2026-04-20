#!/usr/bin/env python3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from socketserver import ThreadingMixIn
import threading
import syslog
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
                b"Too many connections.\n"
            )
            return
        try:
            super().handle()
        finally:
            semaphore.release()

    def do_GET(self):
        if self.path == "/status":
            body = b"OK\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            super().do_GET()

    def translate_path(self, path):
        root = SERVE_DIR
        path = super().translate_path(path)
        relpath = os.path.relpath(path, os.getcwd())
        return os.path.join(root, relpath)

    def log_message(self, format, *args):
        syslog.syslog(syslog.LOG_INFO, f"misp-feed {self.client_address[0]} {format % args}")

class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True

if __name__ == "__main__":
    syslog.openlog("misp-feed-server", syslog.LOG_PID, syslog.LOG_DAEMON)
    server = ThreadedHTTPServer(("0.0.0.0", 40000), LimitedHandler)
    syslog.syslog(syslog.LOG_INFO, f"Serving {SERVE_DIR} on port 40000, max {MAX_SESSIONS} concurrent sessions")
    print(f"Serving {SERVE_DIR} on http://0.0.0.0:40000 — max {MAX_SESSIONS} concurrent sessions")
    server.serve_forever()

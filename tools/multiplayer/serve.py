"""Serve the local web build and relay its same-origin /duel WebSocket."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import selectors
import socket


class GameHandler(SimpleHTTPRequestHandler):
    backend_port: int

    def do_GET(self):
        if self.path != "/duel":
            return super().do_GET()
        port = self.server.server_port
        origins = {f"http://127.0.0.1:{port}", f"http://localhost:{port}"}
        if self.headers.get("Upgrade", "").lower() != "websocket" or self.headers.get("Origin") not in origins:
            self.send_error(403, "Open the duel from the local game page")
            return
        try:
            upstream = socket.create_connection(("127.0.0.1", self.backend_port), timeout=5)
        except OSError:
            self.send_error(503, "The local Godot duel server is unavailable")
            return
        self.close_connection = True
        try:
            with upstream, selectors.DefaultSelector() as sockets:
                lines = [
                    "GET /duel HTTP/1.1",
                    f"Host: 127.0.0.1:{self.backend_port}",
                    "Connection: Upgrade",
                    "Upgrade: websocket",
                ]
                for name in ("Origin", "Sec-WebSocket-Key", "Sec-WebSocket-Version"):
                    value = self.headers.get(name, "")
                    if "\r" in value or "\n" in value:
                        return
                    lines.append(f"{name}: {value}")
                upstream.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("ascii"))
                sockets.register(self.connection, selectors.EVENT_READ, upstream)
                sockets.register(upstream, selectors.EVENT_READ, self.connection)
                while True:
                    for key, _ in sockets.select():
                        data = key.fileobj.recv(65536)
                        if not data:
                            return
                        key.data.sendall(data)
        except OSError:
            return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--duel-port", type=int, default=9074)
    parser.add_argument("--directory", type=Path, default=Path("builds/web"))
    args = parser.parse_args()
    if not (args.directory / "index.html").is_file():
        parser.error("The web export is missing. Run bash tools/build_web.sh first.")
    GameHandler.backend_port = args.duel_port
    handler = partial(GameHandler, directory=str(args.directory))
    with ThreadingHTTPServer(("127.0.0.1", args.port), handler) as server:
        print(f"Local dogfight game at http://127.0.0.1:{args.port}", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()

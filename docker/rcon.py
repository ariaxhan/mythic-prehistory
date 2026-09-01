#!/usr/bin/env python3
"""Minimal Source RCON client (Minecraft flavour), Python stdlib only.

Used exclusively over 127.0.0.1 to ask the running server questions -- chiefly
"how many players are connected" -- and to issue save/stop commands during the
shutdown sequence.

Deliberately dependency-free so the runtime image needs no pip packages for the
critical shutdown path.

Exit codes:
  0  command executed, response on stdout
  1  usage / configuration error
  2  connection or authentication failure  (caller must treat as "unknown")
"""

from __future__ import annotations

import argparse
import os
import socket
import struct
import sys

SERVERDATA_AUTH = 3
SERVERDATA_AUTH_RESPONSE = 2
SERVERDATA_EXECCOMMAND = 2
SERVERDATA_RESPONSE_VALUE = 0


class RconError(Exception):
    pass


class RconClient:
    def __init__(self, host: str, port: int, password: str, timeout: float = 10.0):
        self.host = host
        self.port = port
        self.password = password
        self.timeout = timeout
        self.sock: socket.socket | None = None
        self._request_id = 0

    def __enter__(self) -> "RconClient":
        self.connect()
        return self

    def __exit__(self, *_exc) -> None:
        self.close()

    def connect(self) -> None:
        self.sock = socket.create_connection((self.host, self.port), timeout=self.timeout)
        self.sock.settimeout(self.timeout)
        req_id = self._send(SERVERDATA_AUTH, self.password)
        # The server replies to AUTH with an (often empty) RESPONSE_VALUE packet
        # followed by AUTH_RESPONSE. Skip ahead to the auth verdict.
        while True:
            resp_id, resp_type, _ = self._recv()
            if resp_type == SERVERDATA_AUTH_RESPONSE:
                # id of -1 is the documented authentication-failure signal
                if resp_id == -1 or resp_id != req_id:
                    raise RconError("RCON authentication failed")
                return
            if resp_type != SERVERDATA_RESPONSE_VALUE:
                raise RconError(f"unexpected packet type during auth: {resp_type}")

    def command(self, cmd: str) -> str:
        req_id = self._send(SERVERDATA_EXECCOMMAND, cmd)
        resp_id, _resp_type, body = self._recv()
        if resp_id != req_id:
            raise RconError("RCON response id mismatch")
        return body

    def close(self) -> None:
        if self.sock is not None:
            try:
                self.sock.close()
            finally:
                self.sock = None

    # -- wire format ---------------------------------------------------------
    def _send(self, packet_type: int, body: str) -> int:
        assert self.sock is not None
        self._request_id += 1
        payload = body.encode("utf-8") + b"\x00\x00"
        packet = struct.pack("<ii", self._request_id, packet_type) + payload
        self.sock.sendall(struct.pack("<i", len(packet)) + packet)
        return self._request_id

    def _recv(self) -> tuple[int, int, str]:
        length = struct.unpack("<i", self._read_exactly(4))[0]
        if length < 10 or length > 4_194_304:
            raise RconError(f"implausible RCON packet length: {length}")
        data = self._read_exactly(length)
        resp_id, resp_type = struct.unpack("<ii", data[:8])
        body = data[8:-2].decode("utf-8", errors="replace")
        return resp_id, resp_type, body

    def _read_exactly(self, n: int) -> bytes:
        assert self.sock is not None
        chunks = []
        remaining = n
        while remaining > 0:
            chunk = self.sock.recv(remaining)
            if not chunk:
                raise RconError("RCON connection closed mid-packet")
            chunks.append(chunk)
            remaining -= len(chunk)
        return b"".join(chunks)


def main() -> int:
    parser = argparse.ArgumentParser(description="Minecraft RCON client")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=25575)
    parser.add_argument("--timeout", type=float, default=10.0)
    parser.add_argument("command", nargs="+", help="command and arguments")
    args = parser.parse_args()

    password = os.environ.get("RCON_PASSWORD", "")
    if not password:
        print("RCON_PASSWORD is not set", file=sys.stderr)
        return 1

    try:
        with RconClient(args.host, args.port, password, args.timeout) as client:
            print(client.command(" ".join(args.command)))
    except (OSError, RconError) as exc:
        print(f"rcon: {exc}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

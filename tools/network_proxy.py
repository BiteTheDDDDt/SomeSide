"""Local UDP impairment proxy for exercising real ENet traffic.

Each client receives a separate upstream socket, preserving ENet peer identities.
No third-party Python packages are required. Both directions receive independent
delay, jitter and loss; reliable delivery is left entirely to ENet.
"""

from __future__ import annotations

import argparse
import heapq
import json
import random
import selectors
import socket
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-port", type=int, required=True)
    parser.add_argument("--server-port", type=int, required=True)
    parser.add_argument("--delay-ms", type=float, default=50.0)
    parser.add_argument("--jitter-ms", type=float, default=10.0)
    parser.add_argument("--loss", type=float, default=0.02)
    parser.add_argument("--seed", type=int, default=20261004)
    parser.add_argument("--duration", type=float, default=22.0)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--ready", type=Path, required=True)
    args = parser.parse_args()
    if not 0 <= args.loss < 1 or args.delay_ms < 0 or args.jitter_ms < 0:
        parser.error("loss must be in [0, 1), and delay/jitter must be nonnegative")

    rng = random.Random(args.seed)
    selector = selectors.DefaultSelector()
    listener = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    listener.bind(("127.0.0.1", args.listen_port))
    listener.setblocking(False)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)
    selector.register(listener, selectors.EVENT_READ, None)
    upstreams: dict[tuple[str, int], socket.socket] = {}
    pending = []
    serial = 0
    started = time.monotonic()
    errors: list[str] = []
    socket_resets = 0
    directions = {
        key: {"received": 0, "forwarded": 0, "dropped": 0, "bytes": 0,
              "max_datagram_bytes": 0, "delay_ms_total": 0.0, "max_delay_ms": 0.0}
        for key in ("client_to_host", "host_to_client")
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.ready.write_text("ready\n", encoding="utf-8")
    print(f"UDP_PROXY_READY 127.0.0.1:{args.listen_port} -> 127.0.0.1:{args.server_port}", flush=True)

    def queue_packet(data: bytes, output: socket.socket, destination: tuple[str, int], direction: str) -> None:
        nonlocal serial
        statistics = directions[direction]
        statistics["received"] += 1
        statistics["max_datagram_bytes"] = max(statistics["max_datagram_bytes"], len(data))
        if rng.random() < args.loss:
            statistics["dropped"] += 1
            return
        received = time.monotonic()
        delay = max(0.0, args.delay_ms + rng.uniform(-args.jitter_ms, args.jitter_ms)) / 1000.0
        serial += 1
        heapq.heappush(pending, (received + delay, serial, output, data, destination, direction, received))

    try:
        while time.monotonic() - started < args.duration:
            now = time.monotonic()
            while pending and pending[0][0] <= now:
                _, _, output, data, destination, direction, received = heapq.heappop(pending)
                try:
                    output.sendto(data, destination)
                    statistics = directions[direction]
                    statistics["forwarded"] += 1
                    statistics["bytes"] += len(data)
                    elapsed_ms = (time.monotonic() - received) * 1000.0
                    statistics["delay_ms_total"] += elapsed_ms
                    statistics["max_delay_ms"] = max(statistics["max_delay_ms"], elapsed_ms)
                except OSError as error:
                    if len(errors) < 20:
                        errors.append(f"send: {error}")
            timeout = min(0.01, max(0.0, pending[0][0] - time.monotonic())) if pending else 0.01
            for key, _ in selector.select(timeout):
                current = key.fileobj
                while True:
                    try:
                        data, origin = current.recvfrom(65535)
                    except BlockingIOError:
                        break
                    except ConnectionResetError:
                        # Windows reports ICMP port-unreachable here after a game exits.
                        socket_resets += 1
                        break
                    if current is listener:
                        if origin not in upstreams:
                            upstream = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                            upstream.bind(("127.0.0.1", 0))
                            upstream.setblocking(False)
                            upstreams[origin] = upstream
                            selector.register(upstream, selectors.EVENT_READ, origin)
                        queue_packet(data, upstreams[origin], ("127.0.0.1", args.server_port), "client_to_host")
                    else:
                        queue_packet(data, listener, key.data, "host_to_client")
    finally:
        for statistics in directions.values():
            statistics["mean_delay_ms"] = round(statistics.pop("delay_ms_total") / max(1, statistics["forwarded"]), 3)
            statistics["observed_loss_rate"] = round(statistics["dropped"] / max(1, statistics["received"]), 5)
        passed = not errors and bool(upstreams) and all(statistics["forwarded"] > 10 for statistics in directions.values())
        report = {
            "passed": passed, "clients": len(upstreams), "elapsed": time.monotonic() - started,
            "delay_ms_per_direction": args.delay_ms, "jitter_ms": args.jitter_ms,
            "configured_loss_rate": args.loss, "seed": args.seed,
            "directions": directions, "pending_at_shutdown": len(pending),
            "socket_resets_after_exit": socket_resets, "errors": errors,
        }
        args.report.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print("UDP_PROXY_RESULT " + json.dumps(report), flush=True)
        selector.close()
        listener.close()
        for upstream in upstreams.values():
            upstream.close()
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

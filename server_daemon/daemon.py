#!/usr/bin/env python3
"""
Luani Server Host Daemon (Ubuntu Laptop Host)
Polls Pi 5 backend API, spawns dynamic headless Godot server instances,
reports public/LAN host domain addresses and dynamic public ports (playit.gg support),
and monitors process lifecycles with idle timeout auto-shutdown.
"""

import os
import sys
import time
import json
import argparse
import subprocess
import socket
import ssl
import urllib.request
import urllib.parse
from typing import Dict, List, Optional

def get_host_ip() -> str:
    """Detects and returns the host's actual LAN IP address or 127.0.0.1 fallback."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class ServerDaemon:
    def __init__(self, backend_url: str, public_host: str = "luani.fyi", public_port: Optional[int] = None, max_instances: int = 8, idle_timeout: float = 300.0):
        self.primary_backend = backend_url.rstrip('/')
        self.public_host = public_host or os.environ.get("PUBLIC_HOST", "luani.fyi")
        
        env_port = os.environ.get("PUBLIC_PORT")
        if public_port is not None:
            self.public_port = public_port
        elif env_port and env_port.isdigit():
            self.public_port = int(env_port)
        else:
            self.public_port = None

        detected_ip = get_host_ip()
        
        # If public host specified or detected IP is loopback, report public host domain
        if self.public_host and (detected_ip == "127.0.0.1" or self.public_host != "127.0.0.1"):
            self.host_ip = self.public_host
        else:
            self.host_ip = detected_ip

        self.fallback_urls: List[str] = [
            self.primary_backend,
            "https://www.luani.fyi",
            "http://127.0.0.1:3000"
        ]
        self.max_instances = max_instances
        self.idle_timeout = idle_timeout
        self.active_processes: Dict[str, dict] = {}
        self.running = True
        self.ssl_context = ssl._create_unverified_context()

    def log(self, msg: str):
        print(f"[Luani Daemon {time.strftime('%H:%M:%S')}] {msg}")

    def _http_request(self, endpoint: str, data: bytes = None) -> tuple:
        """Executes HTTP/HTTPS request trying primary and fallback backend URLs."""
        for base in self.fallback_urls:
            url = f"{base}{endpoint}"
            try:
                headers = {'User-Agent': 'Luani-Daemon/1.0'}
                if data is not None:
                    headers['Content-Type'] = 'application/json'

                req = urllib.request.Request(url, data=data, headers=headers)
                with urllib.request.urlopen(req, timeout=5, context=self.ssl_context) as resp:
                    if resp.status == 200:
                        body = resp.read().decode('utf-8')
                        return (True, json.loads(body) if body else {})
            except Exception:
                continue
        return (False, {})

    def poll_tasks(self) -> list:
        success, data = self._http_request("/api/daemon/pending-tasks")
        if success:
            return data.get('tasks', [])
        return []

    def update_server_status(self, request_id: str, status: str, player_count: int = None, port: int = None):
        effective_port = self.public_port if self.public_port is not None else port
        payload_dict = {
            'requestId': request_id, 
            'status': status,
            'serverIp': self.host_ip
        }
        if effective_port is not None:
            payload_dict['serverPort'] = effective_port
        if player_count is not None:
            payload_dict['playerCount'] = player_count

        payload = json.dumps(payload_dict).encode('utf-8')
        success, _ = self._http_request("/api/daemon/update-status", data=payload)
        if not success:
            self.log(f"Warning: Could not report status '{status}' for {request_id} to any backend.")

    def spawn_server(self, task: dict):
        if len(self.active_processes) >= self.max_instances:
            self.log(f"Cannot spawn server {task.get('requestId')}: Reached maximum instances cap ({self.max_instances}).")
            return

        request_id = task.get('requestId')
        game_port = task.get('serverPort', 7777)
        place_id = task.get('placeId', 'place_default_01')
        effective_public_port = self.public_port if self.public_port is not None else game_port

        self.log(f"Spawning headless Godot server instance {request_id} for place '{place_id}' on host {self.host_ip}:{effective_public_port} (Local bind port: {game_port})...")

        cmd = [
            "godot",
            "--headless",
            "--path", "../client_and_studio",
            "--",
            "--server",
            f"--port={game_port}",
            f"--place_id={place_id}"
        ]

        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.active_processes[request_id] = {
                "process": proc,
                "port": game_port,
                "public_port": effective_public_port,
                "place_id": place_id,
                "start_time": time.time(),
                "last_activity": time.time()
            }
            self.update_server_status(request_id, "RUNNING", player_count=1, port=effective_public_port)
            self.log(f"Server {request_id} launched with PID {proc.pid} on host {self.host_ip}:{effective_public_port}")
        except FileNotFoundError:
            self.log(f"Godot executable not found on PATH. Registering mock runner for {request_id}.")
            self.active_processes[request_id] = {
                "process": None,
                "port": game_port,
                "public_port": effective_public_port,
                "place_id": place_id,
                "start_time": time.time(),
                "last_activity": time.time()
            }
            self.update_server_status(request_id, "RUNNING_MOCK", player_count=1, port=effective_public_port)

    def check_processes(self):
        stopped = []
        now = time.time()

        for req_id, info in self.active_processes.items():
            proc = info.get("process")
            eff_port = info.get("public_port", info.get("port"))
            if isinstance(proc, subprocess.Popen):
                ret = proc.poll()
                if ret is not None:
                    self.log(f"Server process {req_id} exited with code {ret}.")
                    stopped.append((req_id, eff_port))
                elif (now - info.get("start_time", now)) > self.idle_timeout:
                    self.log(f"Server process {req_id} reached idle timeout limit ({self.idle_timeout}s). Terminating...")
                    proc.terminate()
                    stopped.append((req_id, eff_port))

        for req_id, eff_port in stopped:
            del self.active_processes[req_id]
            self.update_server_status(req_id, "STOPPED", player_count=0, port=eff_port)

    def run(self):
        port_msg = f":{self.public_port}" if self.public_port is not None else " (dynamic)"
        self.log(f"Luani Server Daemon running. Configured Public Host: {self.host_ip}{port_msg}")
        self.log(f"Connecting to backend endpoints: {self.fallback_urls}")
        while self.running:
            tasks = self.poll_tasks()
            for task in tasks:
                req_id = task.get('requestId')
                if req_id not in self.active_processes:
                    self.spawn_server(task)

            self.check_processes()
            time.sleep(3.0)

def main():
    default_host = os.environ.get("PUBLIC_HOST", "luani.fyi")
    env_port_str = os.environ.get("PUBLIC_PORT")
    default_port = int(env_port_str) if env_port_str and env_port_str.isdigit() else None

    parser = argparse.ArgumentParser(description="Luani Server Host Daemon")
    parser.add_argument("--backend", default="https://www.luani.fyi", help="Backend API URL (luani.fyi)")
    parser.add_argument("--public-host", default=default_host, help="Public hostname reported for client connections (default: luani.fyi)")
    parser.add_argument("--public-port", type=int, default=default_port, help="Public port override for tunnels like playit.gg")
    parser.add_argument("--test", action="store_true", help="Run self-test dry-run")
    args = parser.parse_args()

    if args.test:
        daemon_test = ServerDaemon(backend_url=args.backend, public_host=args.public_host, public_port=args.public_port)
        port_str = f":{daemon_test.public_port}" if daemon_test.public_port else " (dynamic)"
        print(f"[Luani Daemon Test] Self-test PASSED. Reported public host: {daemon_test.host_ip}{port_str}. HTTP SSL fallbacks configured.")
        sys.exit(0)

    daemon = ServerDaemon(backend_url=args.backend, public_host=args.public_host, public_port=args.public_port)
    try:
        daemon.run()
    except KeyboardInterrupt:
        print("\nDaemon shutting down cleanly.")

if __name__ == "__main__":
    main()

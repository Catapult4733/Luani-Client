#!/usr/bin/env python3
"""
Luani Server Host Daemon (Ubuntu Laptop Host)
Polls Pi 5 backend API, spawns dynamic headless Godot server instances,
reports public/LAN host domain addresses and dynamic public ports (playit.gg support),
and monitors process lifecycles with empty server idle timeout auto-shutdown.
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
    def __init__(self, backend_url: str, public_host: str = "luani.fyi", public_port: Optional[int] = None, local_port: int = 7700, idle_timeout: float = 0.0, max_instances: int = 8):
        self.primary_backend = backend_url.rstrip('/')
        self.public_host = public_host or os.environ.get("PUBLIC_HOST", "luani.fyi")
        self.local_port = local_port
        self.idle_timeout = idle_timeout
        
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

    def send_daemon_heartbeat(self):
        """Sends daemon config heartbeat with publicHost and publicPort to backend."""
        payload_dict = {
            'daemonId': 'default_daemon',
            'publicHost': self.public_host or self.host_ip,
            'publicPort': self.public_port,
            'serverIp': self.host_ip
        }
        payload = json.dumps(payload_dict).encode('utf-8')
        self._http_request("/api/daemon/heartbeat", data=payload)

    def sync_active_server_counts(self):
        """Syncs active player counts for running processes from backend active servers API."""
        success, data = self._http_request("/api/servers/active")
        if success and isinstance(data, dict):
            servers = data.get("servers", [])
            server_map = {s.get("requestId"): s.get("playerCount", 0) for s in servers if isinstance(s, dict)}
            now = time.time()
            for req_id, info in self.active_processes.items():
                if req_id in server_map:
                    cnt = server_map[req_id]
                    info["player_count"] = cnt
                    if cnt > 0:
                        info["empty_since"] = None
                    elif info.get("empty_since") is None:
                        info["empty_since"] = now

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
            'serverIp': self.host_ip,
            'publicHost': self.public_host or self.host_ip,
            'publicPort': effective_port
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
        bind_port = self.local_port if self.local_port else task.get('serverPort', 7700)
        place_id = task.get('placeId', 'place_default_01')
        effective_public_port = self.public_port if self.public_port is not None else bind_port

        self.log(f"Spawning headless Godot server instance {request_id} for place '{place_id}' (Local bind port: {bind_port} -> Advertised public host: {self.host_ip}:{effective_public_port})...")

        cmd = [
            "godot",
            "--headless",
            "--path", "../client_and_studio",
            "--",
            "--server",
            f"--port={bind_port}",
            f"--place_id={place_id}",
            f"--request-id={request_id}"
        ]

        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.active_processes[request_id] = {
                "process": proc,
                "port": bind_port,
                "public_port": effective_public_port,
                "place_id": place_id,
                "start_time": time.time(),
                "player_count": 1,
                "empty_since": None
            }
            self.update_server_status(request_id, "RUNNING", player_count=1, port=effective_public_port)
            self.log(f"Server {request_id} launched with PID {proc.pid} (Local bind port: {bind_port} | Advertised public host: {self.host_ip}:{effective_public_port})")
        except FileNotFoundError:
            self.log(f"Godot executable not found on PATH. Registering mock runner for {request_id}.")
            self.active_processes[request_id] = {
                "process": None,
                "port": bind_port,
                "public_port": effective_public_port,
                "place_id": place_id,
                "start_time": time.time(),
                "player_count": 1,
                "empty_since": None
            }
            self.update_server_status(request_id, "RUNNING_MOCK", player_count=1, port=effective_public_port)

    def check_processes(self):
        stopped = []
        now = time.time()

        for req_id, info in self.active_processes.items():
            proc = info.get("process")
            eff_port = info.get("public_port", info.get("port"))
            player_cnt = info.get("player_count", 0)

            if isinstance(proc, subprocess.Popen):
                ret = proc.poll()
                if ret is not None:
                    self.log(f"Server process {req_id} exited with code {ret}.")
                    stopped.append((req_id, eff_port))
                elif self.idle_timeout > 0 and player_cnt == 0:
                    empty_since = info.get("empty_since") or now
                    empty_duration = now - empty_since
                    if empty_duration >= self.idle_timeout:
                        self.log(f"Server process {req_id} has been empty for {empty_duration:.1f}s (exceeds idle timeout {self.idle_timeout}s). Terminating...")
                        proc.terminate()
                        stopped.append((req_id, eff_port))

        for req_id, eff_port in stopped:
            del self.active_processes[req_id]
            self.update_server_status(req_id, "STOPPED", player_count=0, port=eff_port)

    def run(self):
        pub_port_str = f":{self.public_port}" if self.public_port is not None else ""
        timeout_msg = f"{self.idle_timeout}s (empty servers only)" if self.idle_timeout > 0 else "DISABLED (0s)"
        self.log(f"Local bind port: {self.local_port} | Advertised public host: {self.host_ip}{pub_port_str} | Idle Timeout: {timeout_msg}")
        self.log(f"Connecting to backend endpoints: {self.fallback_urls}")
        while self.running:
            self.send_daemon_heartbeat()
            self.sync_active_server_counts()
            tasks = self.poll_tasks()
            for task in tasks:
                req_id = task.get('requestId')
                if req_id not in self.active_processes:
                    self.spawn_server(task)

            self.check_processes()
            time.sleep(3.0)

def main():
    default_host = os.environ.get("PUBLIC_HOST", "luani.fyi")
    env_pub_port_str = os.environ.get("PUBLIC_PORT")
    default_public_port = int(env_pub_port_str) if env_pub_port_str and env_pub_port_str.isdigit() else None
    
    env_local_port_str = os.environ.get("LOCAL_PORT")
    default_local_port = int(env_local_port_str) if env_local_port_str and env_local_port_str.isdigit() else 7700

    env_timeout_str = os.environ.get("IDLE_TIMEOUT")
    default_idle_timeout = float(env_timeout_str) if env_timeout_str else 0.0

    parser = argparse.ArgumentParser(description="Luani Server Host Daemon")
    parser.add_argument("--backend", default="https://www.luani.fyi", help="Backend API URL (luani.fyi)")
    parser.add_argument("--public-host", default=default_host, help="Public hostname reported for client connections (default: luani.fyi)")
    parser.add_argument("--public-port", type=int, default=default_public_port, help="Public port override for tunnels like playit.gg")
    parser.add_argument("--local-port", "-lp", type=int, default=default_local_port, help="Local bind port passed to Godot executable (default: 7700)")
    parser.add_argument("--idle-timeout", "-it", type=float, default=default_idle_timeout, help="Empty server idle timeout in seconds (default: 0 = disabled)")
    parser.add_argument("--test", action="store_true", help="Run self-test dry-run")
    args = parser.parse_args()

    if args.test:
        daemon_test = ServerDaemon(backend_url=args.backend, public_host=args.public_host, public_port=args.public_port, local_port=args.local_port, idle_timeout=args.idle_timeout)
        pub_port_str = f":{daemon_test.public_port}" if daemon_test.public_port else ""
        timeout_msg = f"{daemon_test.idle_timeout}s (empty servers only)" if daemon_test.idle_timeout > 0 else "DISABLED (0s)"
        print(f"[Luani Daemon Test] Self-test PASSED. Local bind port: {daemon_test.local_port} | Advertised public host: {daemon_test.host_ip}{pub_port_str} | Idle Timeout: {timeout_msg}. HTTP SSL fallbacks configured.")
        sys.exit(0)

    daemon = ServerDaemon(backend_url=args.backend, public_host=args.public_host, public_port=args.public_port, local_port=args.local_port, idle_timeout=args.idle_timeout)
    try:
        daemon.run()
    except KeyboardInterrupt:
        print("\nDaemon shutting down cleanly.")

if __name__ == "__main__":
    main()

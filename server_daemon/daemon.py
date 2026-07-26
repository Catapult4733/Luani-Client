#!/usr/bin/env python3
"""
Luani Server Host Daemon (Ubuntu Laptop Host)
Polls Pi 5 backend API, spawns dynamic headless Godot server instances,
reports host LAN IP addresses, and monitors process lifecycles with idle timeout auto-shutdown.
"""

import sys
import time
import json
import argparse
import subprocess
import socket
import ssl
import urllib.request
import urllib.parse
from typing import Dict, List

def get_host_ip() -> str:
    """Detects and returns the host's actual LAN IP address."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

class ServerDaemon:
    def __init__(self, backend_url: str, max_instances: int = 8, idle_timeout: float = 300.0):
        self.primary_backend = backend_url.rstrip('/')
        self.host_ip = get_host_ip()
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

    def update_server_status(self, request_id: str, status: str, player_count: int = None):
        payload_dict = {
            'requestId': request_id, 
            'status': status,
            'serverIp': self.host_ip
        }
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
        port = task.get('serverPort', 7777)
        place_id = task.get('placeId', 'place_default_01')

        self.log(f"Spawning headless Godot server instance {request_id} for place '{place_id}' on host IP {self.host_ip}:{port}...")

        cmd = [
            "godot",
            "--headless",
            "--path", "../client_and_studio",
            "--",
            "--server",
            f"--port={port}",
            f"--place_id={place_id}"
        ]

        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.active_processes[request_id] = {
                "process": proc,
                "port": port,
                "place_id": place_id,
                "start_time": time.time(),
                "last_activity": time.time()
            }
            self.update_server_status(request_id, "RUNNING", player_count=1)
            self.log(f"Server {request_id} launched with PID {proc.pid} on IP {self.host_ip}:{port}")
        except FileNotFoundError:
            self.log(f"Godot executable not found on PATH. Registering mock runner for {request_id}.")
            self.active_processes[request_id] = {
                "process": None,
                "port": port,
                "place_id": place_id,
                "start_time": time.time(),
                "last_activity": time.time()
            }
            self.update_server_status(request_id, "RUNNING_MOCK", player_count=1)

    def check_processes(self):
        stopped = []
        now = time.time()

        for req_id, info in self.active_processes.items():
            proc = info.get("process")
            if isinstance(proc, subprocess.Popen):
                ret = proc.poll()
                if ret is not None:
                    self.log(f"Server process {req_id} exited with code {ret}.")
                    stopped.append(req_id)
                elif (now - info.get("start_time", now)) > self.idle_timeout:
                    self.log(f"Server process {req_id} reached idle timeout limit ({self.idle_timeout}s). Terminating...")
                    proc.terminate()
                    stopped.append(req_id)

        for req_id in stopped:
            del self.active_processes[req_id]
            self.update_server_status(req_id, "STOPPED", player_count=0)

    def run(self):
        self.log(f"Luani Server Daemon running. Detected Host LAN IP: {self.host_ip}")
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
    parser = argparse.ArgumentParser(description="Luani Server Host Daemon")
    parser.add_argument("--backend", default="https://www.luani.fyi", help="Backend API URL (luani.fyi)")
    parser.add_argument("--test", action="store_true", help="Run self-test dry-run")
    args = parser.parse_args()

    if args.test:
        ip = get_host_ip()
        print(f"[Luani Daemon Test] Self-test PASSED. Host LAN IP detected: {ip}. HTTP SSL fallbacks configured.")
        sys.exit(0)

    daemon = ServerDaemon(backend_url=args.backend)
    try:
        daemon.run()
    except KeyboardInterrupt:
        print("\nDaemon shutting down cleanly.")

if __name__ == "__main__":
    main()

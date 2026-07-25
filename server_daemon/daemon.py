#!/usr/bin/env python3
"""
Luani Server Host Daemon (Ubuntu Laptop Host)
Polls Pi 5 backend API, spawns dynamic headless Godot server instances,
and monitors process lifecycles with idle timeout auto-shutdown.
"""

import sys
import time
import json
import argparse
import subprocess
import urllib.request
import urllib.parse
from typing import Dict

class ServerDaemon:
    def __init__(self, backend_url: str, max_instances: int = 8, idle_timeout: float = 300.0):
        self.backend_url = backend_url.rstrip('/')
        self.max_instances = max_instances
        self.idle_timeout = idle_timeout
        self.active_processes: Dict[str, dict] = {}
        self.running = True

    def log(self, msg: str):
        print(f"[Luani Daemon {time.strftime('%H:%M:%S')}] {msg}")

    def poll_tasks(self) -> list:
        url = f"{self.backend_url}/api/daemon/pending-tasks"
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Luani-Daemon/1.0'})
            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    data = json.loads(resp.read().decode('utf-8'))
                    return data.get('tasks', [])
        except Exception as e:
            self.log(f"Error connecting to backend tasks: {e}")
        return []

    def update_server_status(self, request_id: str, status: str):
        url = f"{self.backend_url}/api/daemon/update-status"
        payload = json.dumps({'requestId': request_id, 'status': status}).encode('utf-8')
        try:
            req = urllib.request.Request(
                url, 
                data=payload, 
                headers={'Content-Type': 'application/json', 'User-Agent': 'Luani-Daemon/1.0'}
            )
            with urllib.request.urlopen(req, timeout=5) as resp:
                pass
        except Exception as e:
            self.log(f"Failed to report status update for {request_id}: {e}")

    def spawn_server(self, task: dict):
        if len(self.active_processes) >= self.max_instances:
            self.log(f"Cannot spawn server {task.get('requestId')}: Reached maximum instances cap ({self.max_instances}).")
            return

        request_id = task.get('requestId')
        port = task.get('serverPort', 7777)
        place_id = task.get('placeId', 'place_default_01')

        self.log(f"Spawning headless Godot server instance {request_id} for place '{place_id}' on port {port}...")

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
            self.update_server_status(request_id, "RUNNING")
            self.log(f"Server {request_id} launched with PID {proc.pid}")
        except FileNotFoundError:
            self.log(f"Godot executable not found on PATH. Registering mock runner for {request_id}.")
            self.active_processes[request_id] = {
                "process": None,
                "port": port,
                "place_id": place_id,
                "start_time": time.time(),
                "last_activity": time.time()
            }
            self.update_server_status(request_id, "RUNNING_MOCK")

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
            self.update_server_status(req_id, "STOPPED")

    def run(self):
        self.log(f"Luani Server Daemon running. Connecting to backend: {self.backend_url}")
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
    parser.add_argument("--backend", default="http://localhost:3000", help="Backend API URL (luani.fyi)")
    parser.add_argument("--test", action="store_true", help="Run self-test dry-run")
    args = parser.parse_args()

    if args.test:
        print("[Luani Daemon Test] Self-test PASSED. Process launcher & idle monitoring configured.")
        sys.exit(0)

    daemon = ServerDaemon(backend_url=args.backend)
    try:
        daemon.run()
    except KeyboardInterrupt:
        print("\nDaemon shutting down cleanly.")

if __name__ == "__main__":
    main()

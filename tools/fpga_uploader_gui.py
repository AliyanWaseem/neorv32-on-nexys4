#!/usr/bin/env python3
"""
NEORV32 Bootloader Uploader - GUI

A simple desktop app (tkinter) to:
  - pick a serial port (with refresh)
  - pick a .bin file to upload (on Windows, opens straight in the WSL build folder)
  - upload it over the UART bootloader protocol
  - trigger execution and stream live UART output back, logging to a file

Settings (port, binary, log file) are remembered between runs in
~/.neorv32_uploader.json, so after the first upload students only press
"Upload & Run".

Requires: pyserial   (bundled automatically when built with PyInstaller)
Run from source:
    python fpga_uploader_gui.py
"""

import sys
import os
import json
import time
import threading
import queue
import subprocess
from datetime import datetime

import tkinter as tk
from tkinter import ttk, filedialog, messagebox

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("pyserial is required. Install it with: pip install pyserial")
    sys.exit(1)


BAUD_RATE = 19200
IS_WINDOWS = sys.platform.startswith("win")
HOME = os.path.expanduser("~")
CONFIG_PATH = os.path.join(HOME, ".neorv32_uploader.json")
DEFAULT_LOG = os.path.join(HOME, "neorv32_uart_output.log")

# Linux-side folder where the workshop builds its programs (inside WSL on Windows,
# or the native folder on Linux).
LINUX_EXAMPLE_DIR = "~/projects/neorv32/sw/example"


# -------------------------------------------------------------------
# Settings and path helpers
# -------------------------------------------------------------------
def load_config():
    try:
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_config(cfg):
    try:
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception:
        pass


def find_wsl_example_dir():
    """On Windows, ask WSL for the Windows path of the example folder.

    Returns something like \\\\wsl.localhost\\Ubuntu\\home\\mango\\projects\\neorv32\\sw\\example,
    falls back to the WSL home folder, or None if WSL is not available.
    """
    if not IS_WINDOWS:
        return None
    script = f'cd {LINUX_EXAMPLE_DIR} 2>/dev/null || cd ~; wslpath -w "$PWD"'
    try:
        result = subprocess.run(
            ["wsl.exe", "-e", "sh", "-c", script],
            capture_output=True,
            timeout=20,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        path = result.stdout.decode("utf-8", errors="ignore").strip()
        if result.returncode == 0 and path.startswith("\\\\") and os.path.isdir(path):
            return path
    except Exception:
        pass
    return None


def native_example_dir():
    path = os.path.expanduser(LINUX_EXAMPLE_DIR)
    return path if os.path.isdir(path) else HOME


class UploaderApp:
    def __init__(self, root):
        self.root = root
        self.root.title("NEORV32 Bootloader Uploader")
        self.root.geometry("760x580")
        self.root.minsize(660, 480)

        self.ser = None
        self.worker_thread = None
        self.stop_monitor = threading.Event()
        self.msg_queue = queue.Queue()
        self.is_running = False
        self.port_map = {}  # combobox label -> device name
        self.cfg = load_config()
        self.wsl_dir = None

        self._build_ui()
        self._refresh_ports()
        self._poll_queue()

        if IS_WINDOWS:
            # Starting WSL can take a few seconds, so look the folder up in the background.
            threading.Thread(target=self._detect_wsl_dir, daemon=True).start()

    # ---------------------------------------------------------------
    # UI construction
    # ---------------------------------------------------------------
    def _build_ui(self):
        pad = {"padx": 8, "pady": 6}

        top = ttk.Frame(self.root)
        top.pack(fill="x", **pad)

        # Port selection
        ttk.Label(top, text="Serial Port:").grid(row=0, column=0, sticky="w")
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(top, textvariable=self.port_var, width=50, state="readonly")
        self.port_combo.grid(row=0, column=1, sticky="we", padx=(4, 4))
        ttk.Button(top, text="Refresh", command=self._refresh_ports).grid(row=0, column=2, padx=(0, 4))

        # Bin file selection
        ttk.Label(top, text="Binary File:").grid(row=1, column=0, sticky="w", pady=(8, 0))
        self.binfile_var = tk.StringVar(value=self.cfg.get("binfile", ""))
        ttk.Entry(top, textvariable=self.binfile_var, width=50).grid(
            row=1, column=1, sticky="we", padx=(4, 4), pady=(8, 0)
        )
        ttk.Button(top, text="Browse...", command=self._browse_bin).grid(row=1, column=2, pady=(8, 0))

        # Log file selection
        ttk.Label(top, text="Log File:").grid(row=2, column=0, sticky="w", pady=(8, 0))
        self.logfile_var = tk.StringVar(value=self.cfg.get("logfile", DEFAULT_LOG))
        ttk.Entry(top, textvariable=self.logfile_var, width=50).grid(
            row=2, column=1, sticky="we", padx=(4, 4), pady=(8, 0)
        )
        ttk.Button(top, text="Browse...", command=self._browse_log).grid(row=2, column=2, pady=(8, 0))

        top.columnconfigure(1, weight=1)

        # Action buttons
        btn_frame = ttk.Frame(self.root)
        btn_frame.pack(fill="x", **pad)

        self.upload_btn = ttk.Button(btn_frame, text="Upload && Run", command=self._start_upload)
        self.upload_btn.pack(side="left")

        self.stop_btn = ttk.Button(btn_frame, text="Stop Monitoring", command=self._stop_monitoring, state="disabled")
        self.stop_btn.pack(side="left", padx=(8, 0))

        ttk.Button(btn_frame, text="Clear Output", command=self._clear_output).pack(side="left", padx=(8, 0))

        self.status_var = tk.StringVar(value="Idle")
        ttk.Label(btn_frame, textvariable=self.status_var, foreground="#555").pack(side="right")

        hint = ttk.Label(
            self.root,
            text="Tip: press the board's CPU RESET button just before clicking Upload & Run.",
            foreground="#555",
        )
        hint.pack(anchor="w", padx=8)

        # Output console
        out_frame = ttk.Frame(self.root)
        out_frame.pack(fill="both", expand=True, **pad)

        ttk.Label(out_frame, text="Output:").pack(anchor="w")

        text_frame = ttk.Frame(out_frame)
        text_frame.pack(fill="both", expand=True)

        mono = "Consolas" if IS_WINDOWS else "DejaVu Sans Mono"
        self.output_text = tk.Text(text_frame, wrap="word", state="disabled", bg="#111", fg="#ddd",
                                   insertbackground="#ddd", font=(mono, 10))
        self.output_text.pack(side="left", fill="both", expand=True)

        scrollbar = ttk.Scrollbar(text_frame, command=self.output_text.yview)
        scrollbar.pack(side="right", fill="y")
        self.output_text.config(yscrollcommand=scrollbar.set)

    # ---------------------------------------------------------------
    # UI helpers
    # ---------------------------------------------------------------
    def _detect_wsl_dir(self):
        self.wsl_dir = find_wsl_example_dir()
        if self.wsl_dir:
            self._log(f"WSL build folder: {self.wsl_dir}")
        else:
            self._log("WSL not found; Browse will start in your Windows home folder.")

    def _refresh_ports(self):
        self.port_map = {}
        labels = []
        for p in sorted(serial.tools.list_ports.comports(), key=lambda p: p.device):
            desc = p.description if p.description and p.description != "n/a" else ""
            label = f"{p.device}  -  {desc}" if desc else p.device
            self.port_map[label] = p.device
            labels.append(label)
        self.port_combo["values"] = labels

        # Prefer the port used last time, then keep the current one, then the first.
        last = self.cfg.get("port")
        current = self.port_map.get(self.port_var.get())
        chosen = None
        for label, dev in self.port_map.items():
            if dev == current or (current is None and dev == last):
                chosen = label
                break
        if chosen is None and labels:
            chosen = labels[0]
        self.port_var.set(chosen or "")

        self._log(f"Found {len(labels)} port(s): {', '.join(self.port_map.values()) if labels else 'none'}")

    def _initial_bin_dir(self):
        current = self.binfile_var.get().strip()
        if current and os.path.isdir(os.path.dirname(current)):
            return os.path.dirname(current)
        if IS_WINDOWS:
            return self.wsl_dir or HOME
        return native_example_dir()

    def _browse_bin(self):
        path = filedialog.askopenfilename(
            title="Select neorv32_exe.bin",
            initialdir=self._initial_bin_dir(),
            filetypes=[("Binary files", "*.bin"), ("All files", "*.*")],
        )
        if path:
            self.binfile_var.set(os.path.normpath(path))

    def _browse_log(self):
        path = filedialog.asksaveasfilename(
            title="Select log file",
            initialdir=os.path.dirname(self.logfile_var.get()) or HOME,
            defaultextension=".log",
            filetypes=[("Log files", "*.log"), ("All files", "*.*")],
        )
        if path:
            self.logfile_var.set(os.path.normpath(path))

    def _clear_output(self):
        self.output_text.config(state="normal")
        self.output_text.delete("1.0", "end")
        self.output_text.config(state="disabled")

    def _log(self, msg):
        self.msg_queue.put(msg if msg.endswith("\n") else msg + "\n")

    def _log_raw(self, chunk):
        self.msg_queue.put(chunk)

    def _poll_queue(self):
        try:
            while True:
                chunk = self.msg_queue.get_nowait()
                self.output_text.config(state="normal")
                self.output_text.insert("end", chunk)
                self.output_text.see("end")
                self.output_text.config(state="disabled")
        except queue.Empty:
            pass
        self.root.after(50, self._poll_queue)

    def _set_status(self, text):
        self.status_var.set(text)

    # ---------------------------------------------------------------
    # Upload / monitor logic (same protocol as upload.py, run on a worker thread)
    # ---------------------------------------------------------------
    def _start_upload(self):
        if self.is_running:
            return

        port = self.port_map.get(self.port_var.get(), self.port_var.get()).strip()
        binfile = self.binfile_var.get().strip()
        logfile = self.logfile_var.get().strip() or DEFAULT_LOG

        if not port:
            messagebox.showerror("Missing port", "Please select a serial port.")
            return
        if not binfile or not os.path.isfile(binfile):
            messagebox.showerror("Missing file", "Please select a valid .bin file.")
            return

        self.cfg.update({"port": port, "binfile": binfile, "logfile": logfile})
        save_config(self.cfg)

        built = datetime.fromtimestamp(os.path.getmtime(binfile)).strftime("%Y-%m-%d %H:%M:%S")
        self._log(f"Binary: {binfile}")
        self._log(f"        {os.path.getsize(binfile)} bytes, built {built}")

        self.is_running = True
        self.stop_monitor.clear()
        self.upload_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self._set_status("Uploading...")

        self.worker_thread = threading.Thread(
            target=self._worker, args=(port, binfile, logfile), daemon=True
        )
        self.worker_thread.start()

    def _stop_monitoring(self):
        self.stop_monitor.set()
        self.stop_btn.config(state="disabled")
        self._set_status("Stopping...")

    def _finish(self, status_text):
        self.is_running = False
        self.upload_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self._set_status(status_text)
        if self.ser and self.ser.is_open:
            try:
                self.ser.close()
            except Exception:
                pass
        self.ser = None

    def _worker(self, port, binfile, logfile):
        try:
            self.ser = serial.Serial(port, BAUD_RATE, timeout=2)
            time.sleep(0.5)

            self._log("Waiting for bootloader...")
            self.ser.reset_input_buffer()

            self.ser.write(b' ')
            time.sleep(0.5)
            response = self.ser.read(100).decode(errors='ignore')
            self._log(f"Got: {response!r}")

            self._log("Sending upload command...")
            self.ser.write(b'u')
            time.sleep(0.5)
            response = self.ser.read(50).decode(errors='ignore')
            self._log(f"Got: {response!r}")

            self._log("Sending binary...")
            with open(binfile, 'rb') as f:
                data = f.read()
            self.ser.write(data)
            self._log(f"Sent {len(data)} bytes")

            time.sleep(3)
            response = self.ser.read(200).decode(errors='ignore')
            self._log(f"Response: {response!r}")

            if 'OK' in response:
                self._log("Upload successful! Executing...")
                self.ser.write(b'e')

                self._log(f"\n--- Streaming program output -- also logging to {logfile} ---\n")
                self.root.after(0, lambda: self._set_status("Monitoring output..."))

                with open(logfile, "ab") as log:
                    log.write(f"\n--- Session started {datetime.now().isoformat()} ---\n".encode())
                    while not self.stop_monitor.is_set():
                        chunk = self.ser.read(256)
                        if chunk:
                            text = chunk.decode(errors='ignore')
                            self._log_raw(text)
                            log.write(chunk)
                            log.flush()

                self._log("\n--- Stopped monitoring (FPGA program is still running) ---")
                self.root.after(0, lambda: self._finish("Stopped monitoring"))
            else:
                self._log("Upload failed or timed out")
                self._log(f"Full response: {response!r}")
                self._log("Did you press CPU RESET just before Upload & Run? "
                          "The bootloader only waits about 8 seconds.")
                self.root.after(0, lambda: self._finish("Upload failed"))

        except serial.SerialException as e:
            self._log(f"Serial error: {e}")
            if not IS_WINDOWS and "ermission" in str(e):
                self._log("Linux needs permission to use serial ports. Run once:\n"
                          "    sudo usermod -aG dialout $USER\n"
                          "then log out and back in.")
            elif IS_WINDOWS and ("Access is denied" in str(e) or "PermissionError" in str(e)):
                self._log("The port is open in another program (a terminal or Vivado?). Close it and retry.")
            self.root.after(0, lambda: self._finish("Serial error"))
        except Exception as e:
            self._log(f"Unexpected error: {e}")
            self.root.after(0, lambda: self._finish("Error"))


def main():
    root = tk.Tk()
    try:
        style = ttk.Style()
        if "clam" in style.theme_names():
            style.theme_use("clam")
    except Exception:
        pass
    UploaderApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()

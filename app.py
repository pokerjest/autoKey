#!/usr/bin/env python3
import random
import subprocess
import threading
import time
import tkinter as tk
from typing import Optional
from tkinter import messagebox, ttk


def applescript_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


class StopTyping(Exception):
    pass


class AutoTyperApp:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("AutoKey Writer")
        self.root.geometry("760x620")
        self.root.minsize(680, 520)

        self.worker: Optional[threading.Thread] = None
        self.stop_requested = threading.Event()

        self.start_delay_var = tk.StringVar(value="3")
        self.min_interval_var = tk.StringVar(value="0.08")
        self.max_interval_var = tk.StringVar(value="0.20")
        self.line_break_delay_var = tk.StringVar(value="0.35")
        self.status_var = tk.StringVar(value="等待开始")

        self._build_ui()

    def _build_ui(self) -> None:
        container = ttk.Frame(self.root, padding=18)
        container.pack(fill=tk.BOTH, expand=True)

        title = ttk.Label(
            container,
            text="模拟手动输入到当前激活窗口",
            font=("PingFang SC", 20, "bold"),
        )
        title.pack(anchor=tk.W)

        hint = ttk.Label(
            container,
            text="把焦点切到起点作家助手的输入框后，本工具会逐字输入。",
            foreground="#555555",
        )
        hint.pack(anchor=tk.W, pady=(6, 16))

        settings = ttk.LabelFrame(container, text="输入参数", padding=12)
        settings.pack(fill=tk.X)

        ttk.Label(settings, text="开始前倒计时(秒)").grid(row=0, column=0, sticky="w")
        ttk.Entry(settings, textvariable=self.start_delay_var, width=12).grid(
            row=0, column=1, sticky="w", padx=(8, 24)
        )

        ttk.Label(settings, text="字符最小间隔(秒)").grid(row=0, column=2, sticky="w")
        ttk.Entry(settings, textvariable=self.min_interval_var, width=12).grid(
            row=0, column=3, sticky="w", padx=(8, 24)
        )

        ttk.Label(settings, text="字符最大间隔(秒)").grid(row=1, column=0, sticky="w", pady=(10, 0))
        ttk.Entry(settings, textvariable=self.max_interval_var, width=12).grid(
            row=1, column=1, sticky="w", padx=(8, 24), pady=(10, 0)
        )

        ttk.Label(settings, text="换行附加停顿(秒)").grid(row=1, column=2, sticky="w", pady=(10, 0))
        ttk.Entry(settings, textvariable=self.line_break_delay_var, width=12).grid(
            row=1, column=3, sticky="w", padx=(8, 24), pady=(10, 0)
        )

        settings.columnconfigure(4, weight=1)

        editor_frame = ttk.LabelFrame(container, text="待输入内容", padding=12)
        editor_frame.pack(fill=tk.BOTH, expand=True, pady=(16, 0))

        self.text = tk.Text(
            editor_frame,
            wrap=tk.WORD,
            font=("PingFang SC", 14),
            undo=True,
            padx=12,
            pady=12,
        )
        self.text.pack(fill=tk.BOTH, expand=True)

        action_row = ttk.Frame(container)
        action_row.pack(fill=tk.X, pady=(14, 0))

        self.start_button = ttk.Button(action_row, text="开始输入", command=self.start_typing)
        self.start_button.pack(side=tk.LEFT)

        self.stop_button = ttk.Button(action_row, text="停止", command=self.stop_typing, state=tk.DISABLED)
        self.stop_button.pack(side=tk.LEFT, padx=(10, 0))

        ttk.Button(action_row, text="清空", command=self.clear_text).pack(side=tk.LEFT, padx=(10, 0))

        ttk.Label(action_row, textvariable=self.status_var, foreground="#0f766e").pack(
            side=tk.RIGHT
        )

        footer = ttk.Label(
            container,
            text="首次使用需要在 macOS 系统设置里给 Terminal 或 Python 授予辅助功能权限。",
            foreground="#666666",
        )
        footer.pack(anchor=tk.W, pady=(12, 0))

    def clear_text(self) -> None:
        self.text.delete("1.0", tk.END)
        self.status_var.set("内容已清空")

    def start_typing(self) -> None:
        if self.worker and self.worker.is_alive():
            messagebox.showinfo("提示", "当前已经在输入中。")
            return

        content = self.text.get("1.0", tk.END).rstrip("\n")
        if not content:
            messagebox.showwarning("提示", "请先输入要发送的内容。")
            return

        try:
            start_delay = float(self.start_delay_var.get())
            min_interval = float(self.min_interval_var.get())
            max_interval = float(self.max_interval_var.get())
            line_break_delay = float(self.line_break_delay_var.get())
        except ValueError:
            messagebox.showerror("参数错误", "请输入合法的数字参数。")
            return

        if start_delay < 0 or min_interval < 0 or max_interval < 0 or line_break_delay < 0:
            messagebox.showerror("参数错误", "所有参数都必须大于等于 0。")
            return

        if min_interval > max_interval:
            messagebox.showerror("参数错误", "最小间隔不能大于最大间隔。")
            return

        self.stop_requested.clear()
        self.start_button.config(state=tk.DISABLED)
        self.stop_button.config(state=tk.NORMAL)
        self.status_var.set(f"{start_delay:.1f} 秒后开始，请切到目标输入框")

        self.worker = threading.Thread(
            target=self._typing_worker,
            args=(content, start_delay, min_interval, max_interval, line_break_delay),
            daemon=True,
        )
        self.worker.start()

    def stop_typing(self) -> None:
        self.stop_requested.set()
        self.status_var.set("正在停止")

    def _typing_worker(
        self,
        content: str,
        start_delay: float,
        min_interval: float,
        max_interval: float,
        line_break_delay: float,
    ) -> None:
        try:
            self._sleep_with_cancel(start_delay)

            total = len(content)
            for index, char in enumerate(content, start=1):
                if self.stop_requested.is_set():
                    self._set_status("已停止")
                    return

                self._send_character(char)
                self._set_status(f"输入中 {index}/{total}")

                delay = random.uniform(min_interval, max_interval)
                if char == "\n":
                    delay += line_break_delay
                self._sleep_with_cancel(delay)

            self._set_status("输入完成")
        except subprocess.CalledProcessError as exc:
            self._show_error(
                "发送失败",
                "无法通过 macOS 辅助功能发送按键。请确认已授予辅助功能权限。\n\n"
                f"系统返回: {exc}",
            )
            self._set_status("发送失败")
        except StopTyping:
            self._set_status("已停止")
        except Exception as exc:  # noqa: BLE001
            self._show_error("发生异常", str(exc))
            self._set_status("发生异常")
        finally:
            self.root.after(0, self._reset_buttons)

    def _send_character(self, char: str) -> None:
        if char == "\n":
            script = 'tell application "System Events" to key code 36'
        elif char == "\t":
            script = 'tell application "System Events" to key code 48'
        else:
            escaped = applescript_escape(char)
            script = f'tell application "System Events" to keystroke "{escaped}"'

        subprocess.run(
            ["osascript", "-e", script],
            check=True,
            capture_output=True,
            text=True,
        )

    def _sleep_with_cancel(self, seconds: float) -> None:
        end_time = time.time() + seconds
        while time.time() < end_time:
            if self.stop_requested.is_set():
                raise StopTyping
            time.sleep(0.02)

    def _reset_buttons(self) -> None:
        self.start_button.config(state=tk.NORMAL)
        self.stop_button.config(state=tk.DISABLED)

    def _set_status(self, value: str) -> None:
        self.root.after(0, lambda: self.status_var.set(value))

    def _show_error(self, title: str, message: str) -> None:
        self.root.after(0, lambda: messagebox.showerror(title, message))


def main() -> None:
    root = tk.Tk()
    try:
        style = ttk.Style(root)
        if "clam" in style.theme_names():
            style.theme_use("clam")
    except tk.TclError:
        pass

    AutoTyperApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()

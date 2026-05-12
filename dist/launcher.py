"""BF Telemetry launcher.

Loads and executes emulator.py from disk so packaged builds and source runs both
pick up local emulator edits without rebuilding the launcher.
"""
import sys, os

def _base():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

def _find_emulator_path():
    base = _base()
    candidates = [
        os.path.join(base, 'emulator.py'),
        os.path.join(base, 'dist', 'emulator.py'),
    ]
    for path in candidates:
        if os.path.exists(path):
            return path
    return candidates[0]

emulator_path = _find_emulator_path()

if not os.path.exists(emulator_path):
    try:
        import tkinter as tk
        import tkinter.messagebox as mb
        tk.Tk().withdraw()
        mb.showerror("BFTelem", f"emulator.py not found in expected locations:\n{emulator_path}")
    except Exception:
        print(f"ERROR: emulator.py not found at {emulator_path}", file=sys.stderr)
    sys.exit(1)

with open(emulator_path, 'r', encoding='utf-8') as f:
    code = f.read()

# Execute emulator.py as if it were launched directly.
exec(compile(code, emulator_path, 'exec'), {'__file__': emulator_path, '__name__': '__main__'})

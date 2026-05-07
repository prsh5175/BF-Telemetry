"""
BFTelem Launcher
Loads emulator.py from disk next to the exe so you can edit it without rebuilding.
"""
import sys, os

def _base():
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

emulator_path = os.path.join(_base(), 'emulator.py')

if not os.path.exists(emulator_path):
    try:
        import tkinter as tk
        import tkinter.messagebox as mb
        tk.Tk().withdraw()
        mb.showerror("BFTelem", f"emulator.py not found next to the exe:\n{emulator_path}")
    except Exception:
        print(f"ERROR: emulator.py not found at {emulator_path}", file=sys.stderr)
    sys.exit(1)

with open(emulator_path, 'r', encoding='utf-8') as f:
    code = f.read()

exec(compile(code, emulator_path, 'exec'), {'__file__': emulator_path, '__name__': '__main__'})

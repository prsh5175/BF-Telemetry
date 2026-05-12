"""
Headless screenshot capture for the BF Telemetry emulator.
Renders all three display modes using the current UI (header clock included)
and saves PNGs to assets/screenshots/.

Usage:
    python dist/take_screenshots.py
"""

import os, sys, math, importlib, types

# ── Locate project root ───────────────────────────────────────────────────────
HERE     = os.path.dirname(os.path.abspath(__file__))
ROOT     = os.path.dirname(HERE)
LUA_PATH = os.path.join(ROOT, "main.lua")
OUT_DIR  = os.path.join(ROOT, "assets", "screenshots")
os.makedirs(OUT_DIR, exist_ok=True)

# ── Bootstrap emulator module ─────────────────────────────────────────────────
sys.path.insert(0, HERE)
os.environ.setdefault("SDL_VIDEODRIVER", "dummy")  # headless
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

import pygame
pygame.init()

# Import emulator as module (it runs no code at import time beyond defs)
import emulator as E

E.LUA_PATH = LUA_PATH
E.L = E.make_layout(E.parse_lua(LUA_PATH))
E.init_fonts()

W, H = 800, 480
surf = pygame.display.set_mode((W, H))

MODES = [
    (0, "num",   "BF Telem lua screenshot_num.png"),
    (1, "bar",   "BF Telem lua screenshot_bar.png"),
    (2, "gauge", "BF Telem lua screenshot_gauge.png"),
]

armed    = True
arm_ts   = "02:34"
fm_str   = "ANGLE"
tile_slots = list(range(12))

for mode, label, filename in MODES:
    surf.fill(E.L['C_BG'])
    E.draw_pit(surf)

    base_tiles = E.make_tiles(armed, fm_str, arm_ts)
    rects      = E.tile_positions(len(tile_slots))

    for i, (tx_pos, ty_pos, tw, th) in enumerate(rects):
        d = base_tiles[i]
        E.render_tile(surf, tx_pos, ty_pos, tw, th, d[0], d, mode)

    E.draw_frame(surf)
    E.draw_side_battery_bars(surf, E.SIM.get("tx-voltage"), E.SIM.get("RxBt"), rx_cells=4)
    E.draw_header(surf, mode, armed, fm_str)

    out_path = os.path.join(OUT_DIR, filename)
    pygame.image.save(surf, out_path)
    print(f"Saved: {out_path}")

pygame.quit()
print("Done.")

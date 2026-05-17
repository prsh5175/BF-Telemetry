"""
Headless screenshot capture for the BF Telemetry emulator.
Renders all three display modes for each screen size:
- 800x480 (TX16S MK III) - default
- 480x272 (TX16S MK II / Jumper T16)
Saves PNGs to assets/screenshots/.

Usage:
    python dist/take_screenshots.py
"""

import os, sys, math, importlib, types

# ── Locate project root ───────────────────────────────────────────────────────
HERE     = os.path.dirname(os.path.abspath(__file__))
ROOT     = os.path.dirname(HERE)
LUA_PATH = os.path.join(ROOT, "WIDGETS", "BFTelem", "main.lua")
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

# Screen configurations to capture
SCREENS = [
    (800, 480, "TX16S_MK3", ""),           # 800x480 - default (no suffix)
    (480, 272, "TX16S_MK2", "_480x272"),   # 480x272 TX16S MK II
    (480, 272, "JumperT16", "_480x272"),   # 480x272 Jumper T16 (same as MK2)
]

MODES = [
    (0, "num"),
    (1, "bar"),
    (2, "gauge"),
]

armed    = True
arm_ts   = "02:34"
fm_str   = "ANGLE"

for screen_w, screen_h, device_type, size_suffix in SCREENS:
    print(f"Rendering {screen_w}x{screen_h} ({device_type})...")
    
    # Set emulator screen size and device type
    E.set_screen_size(screen_w, screen_h, device_type)
    E.L = E.make_layout(E.parse_lua(LUA_PATH))
    E.init_fonts()
    
    # Determine tile count based on screen size
    tile_count = 8 if (screen_w == 480 and screen_h == 272) else 12
    tile_slots = list(range(tile_count))
    
    surf = pygame.display.set_mode((screen_w, screen_h))

    for mode, label in MODES:
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
        E.draw_gps_status(surf)

        filename = f"BF Telem lua screenshot_{label}{size_suffix}.png"
        out_path = os.path.join(OUT_DIR, filename)
        pygame.image.save(surf, out_path)
        print(f"  Saved: {filename}")

pygame.quit()
print("Done.")
print("Done.")

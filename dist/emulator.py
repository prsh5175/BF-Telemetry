#!/usr/bin/env python3
"""
BF Telemetry Widget Emulator
Reads layout constants and colors directly from main.lua.
Keys: N=NUM  B=BAR  G=GAUGE  A=arm/disarm  R=reload lua  Q=quit
Mouse: click a tile to open metric picker, click metric row to assign tile
Place BFTelemEmulator.exe next to main.lua, OR anywhere - it will show
a file-picker dialog on first launch and remember the path.
"""
import re, os, sys, math, json, pygame

W, H = 800, 480
FPS  = 15
MENU_W = 320
MENU_ROW_H = 22
MENU_TITLE_H = 28
MENU_PAD = 8
CLICK_DEBOUNCE_MS = 140

# ── Lua file discovery ────────────────────────────────────────────────────────
def get_base_dir():
    """Directory of the exe (when frozen) or script (when running raw)."""
    if getattr(sys, 'frozen', False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))

def load_remembered_path():
    try:
        cfg = os.path.join(get_base_dir(), 'bftelem_path.txt')
        raw = open(cfg).read().strip()
        # support both absolute and relative paths
        if os.path.isabs(raw):
            p = raw
        else:
            p = os.path.normpath(os.path.join(get_base_dir(), raw))
        return p if os.path.exists(p) else None
    except Exception:
        return None

def save_remembered_path(p):
    try:
        cfg = os.path.join(get_base_dir(), 'bftelem_path.txt')
        # store as relative path so the folder is portable
        try:
            rel = os.path.relpath(p, get_base_dir())
        except ValueError:
            rel = p  # fallback to absolute if on different drive
        with open(cfg, 'w') as f:
            f.write(rel)
    except Exception:
        pass

def ask_file_dialog():
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        p = filedialog.askopenfilename(
            title="Select BF Telemetry main.lua",
            filetypes=[("Lua files", "*.lua"), ("All files", "*.*")])
        root.destroy()
        return p or None
    except Exception:
        return None

def find_lua():
    # 1. drag-drop / CLI arg
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        return sys.argv[1]
    # 2. remembered path from previous launch
    p = load_remembered_path()
    if p:
        return p
    # 3. look next to exe/script
    base = get_base_dir()
    for rel in ['main.lua',
                os.path.join('BF Telemetry', 'main.lua'),
                os.path.join('BFTelem', 'main.lua')]:
        p = os.path.join(base, rel)
        if os.path.exists(p):
            return p
    # 4. file picker dialog
    p = ask_file_dialog()
    if p:
        save_remembered_path(p)
        return p
    return None

def find_cf_image(lua_path):
    """Search for carbonfiber.jpg/.bmp walking up from the lua file location.
    Mirrors the SD card layout where IMAGES/ sits at the SD root, two levels
    above WIDGETS/BFTelem/main.lua (i.e. two levels above lua_path's dir)."""
    candidates = []
    base = os.path.dirname(lua_path) if lua_path else get_base_dir()
    for _ in range(6):
        for folder in ('IMAGES', 'images'):
            for name in ('carbonfiber.jpg', 'carbonfiber.bmp'):
                candidates.append(os.path.join(base, folder, name))
        candidates.append(os.path.join(base, 'carbonfiber.jpg'))
        base = os.path.dirname(base)
    # also check next to exe / PyInstaller bundle
    for folder in ('IMAGES', 'images'):
        candidates.append(os.path.join(get_base_dir(), folder, 'carbonfiber.jpg'))
    if getattr(sys, 'frozen', False):
        candidates.append(os.path.join(sys._MEIPASS, 'IMAGES', 'carbonfiber.jpg'))
        candidates.append(os.path.join(sys._MEIPASS, 'images', 'carbonfiber.jpg'))
    for p in candidates:
        if os.path.exists(p):
            return p
    return None

def tile_map_cfg_path():
    return os.path.join(get_base_dir(), 'bftelem_tilemap.json')

def _tile_map_key(lua_path):
    return os.path.abspath(lua_path or "main.lua")

def load_tile_slots(lua_path, count):
    slots = list(range(count))
    try:
        with open(tile_map_cfg_path(), encoding='utf-8') as f:
            raw = json.load(f)
        arr = raw.get(_tile_map_key(lua_path)) if isinstance(raw, dict) else None
        if isinstance(arr, list):
            for i in range(min(count, len(arr))):
                v = arr[i]
                if isinstance(v, int):
                    slots[i] = max(0, min(count - 1, v))
    except Exception:
        pass
    return slots

def save_tile_slots(lua_path, slots, count):
    out = [max(0, min(count - 1, int(v))) for v in slots[:count]]
    while len(out) < count:
        out.append(len(out))

    path = tile_map_cfg_path()
    data = {}
    try:
        with open(path, encoding='utf-8') as f:
            raw = json.load(f)
        if isinstance(raw, dict):
            data = raw
    except Exception:
        pass

    key = _tile_map_key(lua_path)
    if data.get(key) == out:
        return
    data[key] = out
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

# ── Lua parser ────────────────────────────────────────────────────────────────
def parse_lua(path):
    """
    Extract from main.lua:
      - simple numeric locals:   local VARNAME = NUMBER
      - color assignments:       VARNAME = lcd.RGB(r, g, b)
    Returns dict of {name: value}.
    Derived constants (GX, GW, TW, etc.) are computed in make_layout().
    """
    text = open(path, encoding='utf-8', errors='ignore').read()
    c = {}
    # numeric: local VARNAME = NUMBER  (integer or float, optional comment)
    for m in re.finditer(
            r'local\s+(\w+)\s*=\s*(-?\d+(?:\.\d+)?)\s*(?:--[^\n]*)?\n',
            text, re.MULTILINE):
        c[m.group(1)] = float(m.group(2))
    # color: VARNAME = lcd.RGB(r, g, b)
    for m in re.finditer(
            r'(\w+)\s*=\s*lcd\.RGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)',
            text):
        c[m.group(1)] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
    return c

def make_layout(c):
    """Build complete layout dict from parsed Lua constants, with defaults."""
    def n(k, d):
        v = c.get(k, d)
        return int(v) if isinstance(v, float) else int(d)
    def col(k, d):
        v = c.get(k)
        return v if isinstance(v, tuple) else d

    # -- frame geometry --
    FRM_L    = n('FRM_L',    30)
    FRM_R    = n('FRM_R',    30)
    FRM_B    = n('FRM_B',    14)
    TOP_EDGE = n('TOP_EDGE', 22)
    TOP_MID  = n('TOP_MID',  82)
    RAMP_W   = n('RAMP_W',   80)
    PEAK_X1  = n('PEAK_X1', 200)
    PEAK_X2  = n('PEAK_X2', 600)
    # -- rectangular grid (legacy) --
    COLS = n('_COLS', 4)
    ROWS = n('_ROWS', 3)
    GAP  = n('_GAP',  4)
    # -- derived (mirrors main.lua computed locals) --
    RAMP_X1 = PEAK_X1 - RAMP_W
    RAMP_X2 = PEAK_X2 + RAMP_W
    GX = FRM_L
    GY = TOP_MID + 2
    GW = 800 - FRM_L - FRM_R
    GH = 480 - TOP_MID - FRM_B
    TW = (GW - GAP * (COLS + 1)) // COLS
    TH = (GH - GAP * (ROWS + 1)) // ROWS

    # -- honeycomb grid (new) --
    USE_HEX = ('HX_COLS' in c and 'HX_ROWS' in c)
    HX_COLS = n('HX_COLS', 6)
    HX_ROWS = n('HX_ROWS', 2)
    HX_GAP  = n('HX_GAP',  2)
    HEX_W = int((GW - HX_GAP * 2) / (0.25 + 0.75 * HX_COLS))
    HEX_H = int(HEX_W * 1.00)
    max_hex_h = int((GH - HX_GAP * 2) / (HX_ROWS + 0.5))
    if HEX_H > max_hex_h:
        HEX_H = max_hex_h
        HEX_W = int(HEX_H / 1.00)
    HX_STEP_X = int(HEX_W * 0.75)
    HX_STEP_Y = HEX_H
    HX_TOTAL_W = HX_STEP_X * (HX_COLS - 1) + HEX_W
    HX_TOTAL_H = HEX_H * HX_ROWS + (HEX_H // 2)
    HX_ORG_X = GX + (GW - HX_TOTAL_W) // 2
    HX_ORG_Y = GY + (GH - HX_TOTAL_H) // 2
    # -- tile text offsets --
    TY_LBL  = n('TY_LBL',   7)
    TY_VAL  = n('TY_VAL',  24)
    TY_UNIT = n('TY_UNIT', 62)
    TY_SUB  = n('TY_SUB',  76)

    return dict(
        FRM_L=FRM_L, FRM_R=FRM_R, FRM_B=FRM_B,
        TOP_EDGE=TOP_EDGE, TOP_MID=TOP_MID, RAMP_W=RAMP_W,
        PEAK_X1=PEAK_X1, PEAK_X2=PEAK_X2,
        RAMP_X1=RAMP_X1, RAMP_X2=RAMP_X2,
        COLS=COLS, ROWS=ROWS, GAP=GAP,
        GX=GX, GY=GY, GW=GW, GH=GH, TW=TW, TH=TH,
        USE_HEX=USE_HEX,
        HX_COLS=HX_COLS, HX_ROWS=HX_ROWS, HX_GAP=HX_GAP,
        HEX_W=HEX_W, HEX_H=HEX_H,
        HX_STEP_X=HX_STEP_X, HX_STEP_Y=HX_STEP_Y,
        HX_ORG_X=HX_ORG_X, HX_ORG_Y=HX_ORG_Y,
        TY_LBL=TY_LBL, TY_VAL=TY_VAL, TY_UNIT=TY_UNIT, TY_SUB=TY_SUB,
        # colors
        C_BG=      col('C_BG',      (  0,   0,   0)),
        C_TILE=    col('C_TILE',    (  8,  10,  20)),
        C_CF1=     col('C_CF1',     (  0,   0,   0)),
        C_CF2=     col('C_CF2',     ( 10,  14,  30)),
        C_CF3=     col('C_CF3',     ( 18,  24,  50)),
        C_PIT=     col('C_PIT',     (  0,   0,   0)),
        C_SIL_HI=  col('C_SIL_HI', (  0, 180, 255)),
        C_SIL_MID= col('C_SIL_MID',(  0,  90, 180)),
        C_SIL_LO=  col('C_SIL_LO', (  0,  40,  90)),
        C_SIL_DK=  col('C_SIL_DK', (  0,  15,  45)),
        C_CYAN=    col('C_CYAN',    (  0, 255, 255)),
        C_CYAN_DIM=col('C_CYAN_DIM',(  0,  60,  80)),
        C_SHADOW=  col('C_SHADOW',  (  0,   0,   0)),
        C_HILIGHT= col('C_HILIGHT', ( 20,  50, 130)),
        C_ORANGE=  col('C_ORANGE',  (255, 140,   0)),
        C_WHITE=   col('C_WHITE',   (255, 255, 255)),
        C_DIM=     col('C_DIM',     (100, 130, 180)),
        C_GREEN=   col('C_GREEN',   (  0, 255, 100)),
        C_YELLOW=  col('C_YELLOW',  (255, 230,   0)),
        C_RED=     col('C_RED',     (255,  40,  60)),
    )

# ── Globals (reloaded with R) ─────────────────────────────────────────────────
L        = {}   # live layout dict
LUA_PATH = None

def reload_lua():
    global L
    if LUA_PATH:
        L = make_layout(parse_lua(LUA_PATH))

# ── Fonts ─────────────────────────────────────────────────────────────────────
F_LBL = F_SML = F_MID = F_DBL = None

def init_fonts():
    global F_LBL, F_SML, F_MID, F_DBL
    # Futuristic + bold font preferences; falls back to system fonts
    _pref = ["Sprintura", "Orbitron", "Space Mono", "JetBrains Mono", 
             "IBM Plex Mono", "Roboto Mono", "Ubuntu Mono", "Cascadia Mono", 
             "Cascadia Code", "Share Tech Mono", "OCR A Extended", 
             "Lucida Console", "Consolas", "Courier New"]
    def _font(size, bold=False):
        for name in _pref:
            path = pygame.font.match_font(name, bold=bold)
            if path:
                try:    return pygame.font.Font(path, size)
                except: pass
        return pygame.font.SysFont("consolas", size, bold=bold)
    F_LBL = _font(12)
    F_SML = _font(13)
    F_MID = _font(20, bold=True)
    F_DBL = _font(28, bold=True)

# ── Draw primitives ───────────────────────────────────────────────────────────
def fr(surf, x, y, w, h, c):
    if w > 0 and h > 0:
        pygame.draw.rect(surf, c, (x, y, w, h))

def tx(surf, s, x, y, c, font, align="left"):
    img = font.render(str(s), True, c)
    if align == "right":   x -= img.get_width()
    elif align == "center": x -= img.get_width() // 2
    surf.blit(img, (x, y))

def tx_header(surf, s, x, y, c, align="left"):
    t = str(s).upper()
    # Header text: always bold MIDSIZE for consistency
    tx(surf, t, x + 2, y + 2, L['C_SIL_DK'], F_MID, align=align)
    tx(surf, t, x, y, c, F_MID, align=align)

# ── Scan lines overlay ───────────────────────────────────────────────────────
_sl_surf = None   # lazily created, reused every frame

def draw_scanlines(surf):
    global _sl_surf
    if _sl_surf is None:
        _sl_surf = pygame.Surface((W, H), pygame.SRCALPHA)
        _sl_surf.fill((0, 0, 0, 0))
        for y in range(0, H, 3):
            pygame.draw.line(_sl_surf, (0, 0, 0, 55), (0, y), (W - 1, y))
    surf.blit(_sl_surf, (0, 0))

# ── Pit ───────────────────────────────────────────────────────────────────────
def draw_pit(surf):
    GX, GY, GW, GH = L['GX'], L['GY'], L['GW'], L['GH']
    fr(surf, GX+2, GY+2, GW-4, GH-4, L['C_PIT'])
    fr(surf, GX+2, GY+2, GW-4, 1, L['C_SHADOW'])
    fr(surf, GX+2, GY+3, GW-4, 1, L['C_SIL_DK'])
    fr(surf, GX+2, GY+4, GW-4, 1, L['C_CF1'])
    fr(surf, GX+2, GY+2, 1, GH-4, L['C_SHADOW'])
    fr(surf, GX+3, GY+2, 1, GH-4, L['C_SIL_DK'])
    fr(surf, GX+4, GY+2, 1, GH-4, L['C_CF1'])
    fr(surf, GX+2, GY+GH-3, GW-4, 1, L['C_CF2'])
    fr(surf, GX+2, GY+GH-2, GW-4, 1, L['C_HILIGHT'])
    fr(surf, GX+GW-3, GY+2, 1, GH-4, L['C_CF2'])
    fr(surf, GX+GW-2, GY+2, 1, GH-4, L['C_HILIGHT'])

# ── Carbon frame ─────────────────────────────────────────────────────────────
def draw_frame(surf):
    FRM_L  = L['FRM_L'];  FRM_R  = L['FRM_R'];  FRM_B = L['FRM_B']
    TE     = L['TOP_EDGE']; TM = L['TOP_MID']; RW = L['RAMP_W']
    PX1    = L['PEAK_X1']; PX2 = L['PEAK_X2']
    RX1    = L['RAMP_X1']; RX2 = L['RAMP_X2']
    GX     = L['GX'];  GY = L['GY'];  GW = L['GW'];  GH = L['GH']
    cf     = L['C_CF1']

    # ── Solid fills ──
    fr(surf, 0,        0,   W,     TM,              cf)
    fr(surf, 0,        TM,  FRM_L, H - TM - FRM_B,  cf)
    fr(surf, W-FRM_R,  TM,  FRM_R, H - TM - FRM_B,  cf)
    fr(surf, 0,       H-FRM_B, W,  FRM_B,            cf)

    # inner bevel: full-width bottom edge of flat top bar
    fr(surf, 0, TM,   W, 1, L['C_SIL_HI'])
    fr(surf, 0, TM+1, W, 1, L['C_SIL_MID'])

    # cyan accent
    fr(surf, 0, TM+2, W, 2, L['C_CYAN'])

    # L/R inner bevels
    fr(surf, FRM_L,     GY, 1, GH, L['C_SIL_HI'])
    fr(surf, FRM_L+1,   GY, 1, GH, L['C_SIL_MID'])
    fr(surf, W-FRM_R-2, GY, 1, GH, L['C_SIL_MID'])
    fr(surf, W-FRM_R-1, GY, 1, GH, L['C_SIL_HI'])
    fr(surf, GX, H-FRM_B-2, GW, 1, L['C_SIL_MID'])
    fr(surf, GX, H-FRM_B-1, GW, 1, L['C_SIL_HI'])

    # outer border
    fr(surf, 0,   0, W,   1, L['C_SIL_MID'])
    fr(surf, 0,   0, 1,   H, L['C_SIL_MID'])
    fr(surf, W-1, 0, 1,   H, L['C_SIL_MID'])
    fr(surf, 0, H-1, W,   1, L['C_SIL_MID'])

    # cyan corner L-brackets
    fr(surf,   0,   0, 18, 2, L['C_CYAN']); fr(surf, W-18,   0, 18, 2, L['C_CYAN'])
    fr(surf,   0, H-2, 18, 2, L['C_CYAN']); fr(surf, W-18, H-2, 18, 2, L['C_CYAN'])
    fr(surf,   0,   0,  2, 18, L['C_CYAN']); fr(surf, W-2,   0,  2, 18, L['C_CYAN'])
    fr(surf,   0, H-18, 2, 18, L['C_CYAN']); fr(surf, W-2, H-18, 2, 18, L['C_CYAN'])

# ── Tile ─────────────────────────────────────────────────────────────────────
def draw_hex_tile(surf, X, Y, TW, TH):
    # Flat-top hexagon: flat edges at top and bottom, points at left and right.
    q   = max(8, TW // 4)
    hh  = TH // 2
    xL  = X;         xR  = X + TW - 1
    xLT = X + q;     xRT = X + TW - q - 1
    yM  = Y + hh
    y1  = Y;         y4  = Y + TH - 1

    poly = [(xLT, y1), (xRT, y1), (xR, yM), (xRT, y4), (xLT, y4), (xL, yM)]
    pygame.draw.polygon(surf, L['C_TILE'], poly)

    # outer bevel (essential edges)
    pygame.draw.line(surf, L['C_SIL_HI'], (xLT, y1),  (xRT, y1),  1)  # top flat
    pygame.draw.line(surf, L['C_SIL_HI'], (xRT, y1),  (xR,  yM),  1)  # top-right
    pygame.draw.line(surf, L['C_SIL_HI'], (xL,  yM),  (xLT, y1),  1)  # top-left
    pygame.draw.line(surf, L['C_SIL_DK'], (xR,  yM),  (xRT, y4),  1)  # bottom-right
    pygame.draw.line(surf, L['C_SIL_DK'], (xRT, y4),  (xLT, y4),  1)  # bottom flat
    pygame.draw.line(surf, L['C_SIL_DK'], (xLT, y4),  (xL,  yM),  1)  # bottom-left

def draw_tile(surf, X, Y, TW, TH):
    if L.get('USE_HEX'):
        draw_hex_tile(surf, X, Y, TW, TH)
        return

    fr(surf, X+4, Y+4, TW, TH, L['C_SHADOW'])
    fr(surf, X,   Y,   TW, TH, L['C_TILE'])
    fr(surf, X,       Y,      TW,  1, L['C_SIL_HI'])
    fr(surf, X,       Y,       1, TH, L['C_SIL_HI'])
    fr(surf, X,    Y+TH-1, TW,  1, L['C_SIL_DK'])
    fr(surf, X+TW-1, Y,     1, TH, L['C_SIL_DK'])
    fr(surf, X+1,    Y+1,   TW-2, 1, L['C_SIL_MID'])
    fr(surf, X+1,    Y+1,    1, TH-2, L['C_SIL_MID'])
    fr(surf, X+1,  Y+TH-2, TW-2, 1, L['C_SIL_LO'])
    fr(surf, X+TW-2, Y+1,   1, TH-2, L['C_SIL_LO'])
    fr(surf, X+2,    Y,     TW-4, 3, L['C_CYAN'])
    fr(surf, X+TW-8, Y+1,   6, 1, L['C_CYAN'])
    fr(surf, X+TW-2, Y+1,   1, 6, L['C_CYAN'])
    fr(surf, X+1,  Y+TH-2,  6, 1, L['C_CYAN'])
    fr(surf, X+1,  Y+TH-7,  1, 6, L['C_CYAN'])

def hit_flat_hex(px, py, X, Y, TW, TH):
    if px < X or px > (X + TW - 1) or py < Y or py > (Y + TH - 1):
        return False
    hh = TH / 2.0
    if hh <= 0:
        return False
    y_mid = Y + hh
    q = TW / 4.0
    dy = abs(py - y_mid) / hh
    if dy > 1.0:
        return False
    inset = q * dy
    x_l = X + inset
    x_r = X + TW - 1 - inset
    return x_l <= px <= x_r

def tile_positions(tile_count):
    out = []
    if L.get('USE_HEX'):
        for i in range(tile_count):
            c = i % L['HX_COLS']
            r = i // L['HX_COLS']
            tx_pos = L['HX_ORG_X'] + c * L['HX_STEP_X']
            ty_pos = L['HX_ORG_Y'] + r * L['HX_STEP_Y'] + ((c % 2) * (L['HEX_H'] // 2))
            out.append((tx_pos, ty_pos, L['HEX_W'], L['HEX_H']))
    else:
        cols = L['COLS']
        gap = L['GAP']
        tw = L['TW']
        th = L['TH']
        gx = L['GX']
        gy = L['GY']
        for i in range(tile_count):
            c = i % cols
            r = i // cols
            tx_pos = gx + gap + c * (tw + gap)
            ty_pos = gy + gap + r * (th + gap)
            out.append((tx_pos, ty_pos, tw, th))
    return out

def tile_at_point(px, py, rects):
    for i, (x, y, w, h) in enumerate(rects):
        if L.get('USE_HEX'):
            if hit_flat_hex(px, py, x, y, w, h):
                return i
        else:
            if x <= px <= x + w - 1 and y <= py <= y + h - 1:
                return i
    return None

def menu_bounds(metric_count):
    h = MENU_TITLE_H + MENU_PAD * 2 + metric_count * MENU_ROW_H
    x = (W - MENU_W) // 2
    y = (H - h) // 2
    return x, y, MENU_W, h

def menu_metric_at(px, py, metric_count):
    x, y, w, h = menu_bounds(metric_count)
    if px < x or px > (x + w - 1) or py < y or py > (y + h - 1):
        return None
    row_y = y + MENU_TITLE_H + MENU_PAD
    for i in range(metric_count):
        if row_y <= py < (row_y + MENU_ROW_H):
            return i
        row_y += MENU_ROW_H
    return None

def draw_metric_menu(surf, labels, selected_idx, tile_idx):
    x, y, w, h = menu_bounds(len(labels))
    fr(surf, x, y, w, h, L['C_CF1'])
    pygame.draw.rect(surf, L['C_SIL_HI'], (x, y, w, h), 1)
    fr(surf, x + 1, y + 1, w - 2, MENU_TITLE_H, L['C_SIL_DK'])
    tx(surf, f"Tile {tile_idx + 1}: Select Metric", x + 8, y + 6, L['C_WHITE'], F_SML)

    row_y = y + MENU_TITLE_H + MENU_PAD
    for i, label in enumerate(labels):
        bg = L['C_HILIGHT'] if i == selected_idx else L['C_TILE']
        fr(surf, x + MENU_PAD, row_y, w - MENU_PAD * 2, MENU_ROW_H - 2, bg)
        pygame.draw.rect(surf, L['C_SIL_LO'], (x + MENU_PAD, row_y, w - MENU_PAD * 2, MENU_ROW_H - 2), 1)
        tx(surf, label, x + MENU_PAD + 6, row_y + 4, L['C_WHITE'], F_SML)
        row_y += MENU_ROW_H

# ── Bar ───────────────────────────────────────────────────────────────────────
def draw_bar(surf, X, Y, TW, TH, pct, c):
    bx = X+6; by = Y+30; bw = TW-12; bh = TH-38
    fr(surf, bx, by, bw, bh, L['C_SIL_DK'])
    if pct is not None:
        fw = int(bw * max(0, min(1, pct/100)))
        if fw > 0:
            fr(surf, bx, by, fw, bh, c)
            fr(surf, bx+fw-2, by, 2, bh, L['C_SIL_HI'])
    pygame.draw.rect(surf, L['C_SIL_MID'], (bx, by, bw, bh), 1)
    if pct is not None:
        s = F_MID.render(f"{int(pct)}%", True, c)
        surf.blit(s, (bx+bw//2-s.get_width()//2, by+bh//2-s.get_height()//2))

# ── Arc gauge ─────────────────────────────────────────────────────────────────
def arc_seg(surf, cx, cy, r, a1, a2, c, steps=12):
    da = (a2-a1)/steps
    pts = [(cx+int(r*math.cos(a1+i*da)+.5), cy+int(r*math.sin(a1+i*da)+.5))
           for i in range(steps+1)]
    for i in range(len(pts)-1):
        pygame.draw.line(surf, c, pts[i], pts[i+1])

def draw_gauge(surf, X, Y, TW, TH, pct, c, val_s, unit_s):
    cx = X + TW//2;  cy = Y + TH - 14
    r  = int(min(TW*0.38, (TH-26)*0.76))
    aS = math.radians(210);  aE = math.radians(210-300)
    arc_seg(surf, cx, cy, r,   aS, aE, L['C_SIL_LO'])
    arc_seg(surf, cx, cy, r-3, aS, aE, L['C_SIL_DK'])
    if pct and pct > 0:
        aV = aS - (aS-aE)*min(pct,100)/100
        arc_seg(surf, cx, cy, r, aS, aV, c)
        nx = cx+int((r-1)*math.cos(aV)+.5);  ny = cy+int((r-1)*math.sin(aV)+.5)
        fr(surf, nx-3, ny-3, 7, 7, L['C_SIL_DK'])
        fr(surf, nx-2, ny-2, 5, 5, L['C_SIL_HI'])
        fr(surf, nx-1, ny-1, 3, 3, L['C_WHITE'])
    if val_s:
        s = F_MID.render(val_s, True, c)
        surf.blit(s, (cx-s.get_width()//2, cy-14))
    if unit_s:
        s = F_SML.render(unit_s, True, L['C_DIM'])
        surf.blit(s, (cx-s.get_width()//2, cy+2))

# ── Tile renderer ─────────────────────────────────────────────────────────────
def render_tile(surf, X, Y, TW, TH, label, d, mode):
    _name, val_s, unit_s, pct, c, sub_s = d
    draw_tile(surf, X, Y, TW, TH)

    if L.get('USE_HEX'):
        cx = X + TW // 2
        y_lbl  = Y + int(TH * 0.22)
        y_val  = Y + int(TH * 0.36)
        y_unit = Y + int(TH * 0.62)
        y_sub  = Y + int(TH * 0.77)

        short = {
            "LINK QUALITY": "LINK Q",
            "FLIGHT TIMER": "TIMER",
            "CELL VOLTAGE": "CELL V",
            "TX POWER": "TX PWR",
            "CAPACITY": "CAPA",
            "DISTANCE": "DIST",
            "ALTITUDE": "ALT",
        }
        label = short.get(label, label)

        tx(surf, label, cx, y_lbl, L['C_CYAN'], F_SML, align="center")
        if mode == 1:
            pad = max(8, int(TW * 0.14))
            draw_bar(surf, X + pad, Y + int(TH * 0.33), TW - 2*pad, int(TH * 0.50), pct, c)
            tx(surf, val_s, cx, y_lbl + 14, c, F_SML, align="center")
        elif mode == 2:
            pad = max(8, int(TW * 0.14))
            draw_gauge(surf, X + pad, Y + 6, TW - 2*pad, TH - 14, pct, c, val_s, unit_s)
        else:
            tx(surf, val_s, cx, y_val, c, F_MID, align="center")
            if unit_s:
                tx(surf, unit_s, cx, y_unit, L['C_DIM'], F_SML, align="center")
            if sub_s:
                tx(surf, sub_s, cx, y_sub, L['C_DIM'], F_SML, align="center")
    else:
        tx(surf, label, X+6, Y+L['TY_LBL'], L['C_CYAN'], F_LBL)
        if mode == 1:
            draw_bar(surf, X, Y, TW, TH, pct, c)
            tx(surf, val_s, X+6, Y+L['TY_LBL']+14, c, F_SML)
        elif mode == 2:
            draw_gauge(surf, X, Y, TW, TH, pct, c, val_s, unit_s)
        else:
            tx(surf, val_s,  X+6, Y+L['TY_VAL'],  c,        F_MID)
            tx(surf, unit_s, X+6, Y+L['TY_UNIT'], L['C_DIM'], F_SML)
            if sub_s:
                tx(surf, sub_s, X+6, Y+L['TY_SUB'], L['C_DIM'], F_SML)

# ── Header ────────────────────────────────────────────────────────────────────
def draw_header(surf, mode, armed, fm_str):
    link_active = isinstance(SIM.get("RQly"), (int, float)) and SIM.get("RQly", 0) > 0
    model_name = "Air65" if link_active else "CRAFT"
    tx_header(surf, model_name, 80, 10, L['C_CYAN'])
    fr(surf, 300, 8, 2, 58, L['C_SIL_LO'])
    fm_col = L['C_ORANGE'] if armed else L['C_DIM']
    tx_header(surf, fm_str if fm_str else "MODE", 400, 10, fm_col, align="center")
    fr(surf, 500, 8, 2, 58, L['C_SIL_LO'])
    if armed:
        tx_header(surf, "ARMED",    530, 10, L['C_RED'])
    else:
        tx_header(surf, "DISARMED", 530, 10, L['C_GREEN'])
    txv = SIM.get("tx-voltage", 0)
    if txv:
        col = L['C_GREEN'] if txv > 7.0 else L['C_RED']
        tx(surf, f"TX {txv:.1f}V", 785, 8, col, F_SML, align="right")
    lbl = ["[ NUM ]", "[ BAR ]", "[GAUGE]"][mode]
    tx(surf, lbl, 785, 56, L['C_SIL_MID'], F_SML, align="right")

# ── Simulated sensor values  (edit to preview different states) ───────────────
SIM = {
    "RQly": 98,
    "RxBt": 16.2,   # 4S battery voltage
    "Curr": 18.5,
    "1RSS": -62,
    "2RSS": -70,
    "Capa": 420,
    "Alt":  22.4,
    "TPWR": 250,
    "RFMD": 6,
    "Dist": 145.0,
    "thr":  35,
    "tx-voltage": 7.8,
    "FM":   "ANGLE",
}

# ── Tile color helpers ────────────────────────────────────────────────────────
def c_lq(v, warn=70):
    if v is None: return L['C_DIM']
    return L['C_GREEN'] if v >= warn else L['C_YELLOW'] if v >= 40 else L['C_RED']
def c_pct(p):
    if p is None: return L['C_DIM']
    return L['C_GREEN'] if p >= 40 else L['C_YELLOW'] if p >= 20 else L['C_RED']
def c_volt(cv, wv, kv):
    if cv is None: return L['C_DIM']
    return L['C_GREEN'] if cv > wv else L['C_YELLOW'] if cv > kv else L['C_RED']

# ── Tile data builder ─────────────────────────────────────────────────────────
def make_tiles(armed, fm_str, arm_timer):
    lq   = SIM["RQly"];  volt = SIM["RxBt"]; curr = SIM["Curr"]
    r1   = SIM["1RSS"];  r2   = SIM["2RSS"]; capa = SIM["Capa"]
    alt  = SIM["Alt"];   tpwr = SIM["TPWR"]; rfmd = SIM["RFMD"]
    dist = SIM["Dist"];  thr  = SIM["thr"]
    nc = 4; fV = 4.2; eV = 3.30; wV = 3.6; kV = 3.4
    cV   = volt / nc if volt else None
    pb   = max(0, min(100, (cV-eV)/(fV-eV)*100)) if cV else None
    pc   = max(0, min(100, (cV-kV)/(4.2-kV)*100)) if cV else None
    RFM  = {0:"4Hz",1:"25Hz",2:"50Hz",3:"100Hz",4:"150Hz",5:"200Hz",
            6:"250Hz",7:"500Hz",8:"F1000",9:"F500",10:"DVDA"}
    t_pct = max(0, min(100, int((thr+1024)/20.48))) if thr is not None else None
    distc = (L['C_RED'] if (dist or 0) >= 500 else
             L['C_ORANGE'] if (dist or 0) >= 200 else L['C_GREEN'])
    r1c   = (L['C_GREEN'] if r1 and r1>-65 else
             L['C_YELLOW'] if r1 and r1>-85 else L['C_RED'])
    tpc   = (L['C_GREEN'] if tpwr and tpwr<=100 else
             L['C_YELLOW'] if tpwr and tpwr<=500 else L['C_RED'])
    cc    = (L['C_GREEN'] if capa and capa<500 else
             L['C_YELLOW'] if capa and capa<800 else L['C_RED'])

    return [
        ("LINK QUALITY", f"{lq}",          "%",
            lq,    c_lq(lq),        f"warn<70%"),
        ("BATTERY",      f"{volt:.1f}V",    f"{cV:.2f}/cell" if cV else "",
            pb,    c_pct(pb),        f"{int(pb)}%" if pb else None),
        ("CURRENT",      f"{curr:.1f}",     "Amps",
            min(100,curr) if curr else None, L['C_WHITE'], None),
        ("FLIGHT TIMER", arm_timer,         "ARMED" if armed else "disarmed",
            None,  L['C_GREEN'] if armed else L['C_DIM'], None),
        ("RSSI",         str(r1),           "dBm",
            max(0,min(100,r1+130)) if r1 else None, r1c, f"a2:{r2}" if r2 else None),
        ("CELL VOLTAGE", f"{cV:.2f}" if cV else "---", f"V  {nc}S",
            pc,    c_volt(cV,wV,kV), None),
        ("CAPACITY",     str(capa),         "mAh",
            min(100,capa/10) if capa else None, cc, None),
        ("THROTTLE",     str(t_pct or 0),   "%",
            t_pct, L['C_ORANGE'],    None),
        ("TX POWER",     str(tpwr),         "mW",
            min(100,tpwr/20) if tpwr else None, tpc, None),
        ("ALTITUDE",     f"{alt:.1f}",      "metres",
            max(0,min(100,alt/5)) if alt else None, L['C_WHITE'], None),
        ("DISTANCE",     f"{dist:.0f}" if dist else "---", "metres",
            min(100,dist/10) if dist else None, distc, None),
        ("RF MODE",      RFM.get(int(rfmd or 0), "?"), "RF mode",
            None,  L['C_WHITE'],     None),
    ]

# ── Main loop ─────────────────────────────────────────────────────────────────
def main():
    global LUA_PATH, L

    # Find main.lua
    LUA_PATH = find_lua()

    # Bootstrap pygame for error display even if lua not found
    pygame.init()
    init_fonts()

    if not LUA_PATH:
        surf = pygame.display.set_mode((500, 80))
        pygame.display.set_caption("BF Telemetry Emulator - Error")
        surf.fill((30, 0, 0))
        s = F_SML.render("Could not find main.lua.  Place exe next to it or relaunch to pick file.", True, (255, 120, 80))
        surf.blit(s, (10, 28))
        pygame.display.flip()
        pygame.time.wait(5000)
        pygame.quit()
        return

    L = make_layout(parse_lua(LUA_PATH))

    surf = pygame.display.set_mode((W, H))
    pygame.display.set_caption(
        f"BF Telemetry Emulator  [{os.path.basename(LUA_PATH)}]"
        "   N=num  B=bar  G=gauge  A=arm  R=reload  Q=quit")
    clock = pygame.time.Clock()

    mode   = 0
    armed  = False
    arm_t0 = None
    fm_str = SIM.get("FM", "ANGLE")

    def arm_ts():
        if arm_t0 is None: return "--:--"
        s = int((pygame.time.get_ticks() - arm_t0) / 1000)
        return f"{s//60:02d}:{s%60:02d}"

    reloaded_msg  = 0    # ticks when last reload happened (for brief flash)
    _last_mtime   = os.path.getmtime(LUA_PATH)
    _mtime_check  = 0    # ticks of last mtime poll
    menu_open = False
    menu_tile_idx = None
    last_click_ms = 0
    tile_slots = load_tile_slots(LUA_PATH, 12)

    running = True
    while running:
        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                running = False
            elif ev.type == pygame.KEYDOWN:
                if   ev.key == pygame.K_q: running = False
                elif ev.key == pygame.K_n: mode = 0
                elif ev.key == pygame.K_b: mode = 1
                elif ev.key == pygame.K_g: mode = 2
                elif ev.key == pygame.K_a:
                    armed  = not armed
                    arm_t0 = pygame.time.get_ticks() if armed else None
                elif ev.key == pygame.K_r:
                    L = make_layout(parse_lua(LUA_PATH))
                    _last_mtime  = os.path.getmtime(LUA_PATH)
                    reloaded_msg = pygame.time.get_ticks()
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                now_ms = pygame.time.get_ticks()
                if now_ms - last_click_ms < CLICK_DEBOUNCE_MS:
                    continue
                last_click_ms = now_ms
                mx, my = ev.pos

                base_tiles = make_tiles(armed, fm_str, arm_ts())
                if len(tile_slots) != len(base_tiles):
                    tile_slots = load_tile_slots(LUA_PATH, len(base_tiles))

                if menu_open and menu_tile_idx is not None:
                    metric_idx = menu_metric_at(mx, my, len(base_tiles))
                    if metric_idx is not None:
                        tile_slots[menu_tile_idx] = metric_idx
                        save_tile_slots(LUA_PATH, tile_slots, len(base_tiles))
                    menu_open = False
                    menu_tile_idx = None
                    continue

                rects = tile_positions(len(tile_slots))
                hit_idx = tile_at_point(mx, my, rects)
                if hit_idx is not None:
                    menu_open = True
                    menu_tile_idx = hit_idx

        # ── Auto-reload when file changes (poll every ~1 s) ──
        now = pygame.time.get_ticks()
        if now - _mtime_check >= 1000:
            _mtime_check = now
            try:
                mtime = os.path.getmtime(LUA_PATH)
                if mtime != _last_mtime:
                    _last_mtime  = mtime
                    L = make_layout(parse_lua(LUA_PATH))
                    reloaded_msg = now
            except OSError:
                pass

        # ── Draw ──
        surf.fill(L['C_BG'])
        draw_pit(surf)

        base_tiles = make_tiles(armed, fm_str, arm_ts())
        if len(tile_slots) != len(base_tiles):
            tile_slots = load_tile_slots(LUA_PATH, len(base_tiles))
        rects = tile_positions(len(tile_slots))

        for i, (tx_pos, ty_pos, tw, th) in enumerate(rects):
            mapped = tile_slots[i] if i < len(tile_slots) else i
            mapped = max(0, min(len(base_tiles) - 1, mapped))
            d = base_tiles[mapped]
            render_tile(surf, tx_pos, ty_pos, tw, th, d[0], d, mode)

        if menu_open and menu_tile_idx is not None:
            if not (0 <= menu_tile_idx < len(tile_slots)):
                menu_open = False
                menu_tile_idx = None
            else:
                current_idx = max(0, min(len(base_tiles) - 1, tile_slots[menu_tile_idx]))
                labels = [t[0] for t in base_tiles]
                draw_metric_menu(surf, labels, current_idx, menu_tile_idx)

        draw_frame(surf)
        draw_header(surf, mode, armed, fm_str)

        # bottom HUD bar
        hy = H - 14
        tx(surf, f"lua: {LUA_PATH}", 4, hy, L['C_DIM'], F_LBL)
        tx(surf, "click tile: assign metric  |  N=num  B=bar  G=gauge  A=arm  Q=quit",
           W-4, hy, L['C_DIM'], F_LBL, align="right")

        # brief "RELOADED" flash
        if reloaded_msg and pygame.time.get_ticks() - reloaded_msg < 1500:
            s = F_MID.render("RELOADED", True, L['C_CYAN'])
            surf.blit(s, (W//2 - s.get_width()//2, H//2 - s.get_height()//2))

        pygame.display.flip()
        clock.tick(FPS)

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()

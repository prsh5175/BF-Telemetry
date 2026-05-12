-- BF Telemetry Widget v3 - Carbon Frame + Recessed Tile Layout
-- EdgeTX 2.12, Lua 5.3, TX16S MK III 800x480

local OPTIONS = {
  { "Cells",   VALUE,  4,  1,  8 },
  { "FullV",   VALUE, 42, 30, 50 },
  { "WarnV",   VALUE, 36, 30, 42 },
  { "CritV",   VALUE, 34, 30, 42 },
  { "LQWrn",   VALUE, 70, 10, 99 },
  { "Mode",    VALUE,  0,  0,  2 },
  { "Theme",   VALUE,  0,  0,  3 },
  { "ThrOn",   VALUE,  5,  0, 50 },
  { "ArmSrc", SOURCE,  0 },
  { "T1",      VALUE,  0,  0, 11 },
  { "T2",      VALUE,  1,  0, 11 },
  { "T3",      VALUE,  2,  0, 11 },
  { "T4",      VALUE,  3,  0, 11 },
  { "T5",      VALUE,  4,  0, 11 },
  { "T6",      VALUE,  5,  0, 11 },
  { "T7",      VALUE,  6,  0, 11 },
  { "T8",      VALUE,  7,  0, 11 },
  { "T9",      VALUE,  8,  0, 11 },
  { "T10",     VALUE,  9,  0, 11 },
  { "T11",     VALUE, 10,  0, 11 },
  { "T12",     VALUE, 11,  0, 11 },
}

local SN_LQ    = "RQly"
local SN_RSSI1 = "1RSS"
local SN_RSSI2 = "2RSS"
local SN_VOLT  = "RxBt"
local SN_CURR  = "Curr"
local SN_CAPA  = "Capa"
local SN_ALT   = "Alt"
local SN_FM    = "FM"
local SN_TPWR  = "TPWR"
local SN_RFMD  = "RFMD"
local SN_DIST  = "Dist"

-- =========================================================================
--  COLORS
-- =========================================================================
local C_BG, C_TILE, C_CF1, C_CF2, C_CF3
local C_SIL_HI, C_SIL_MID, C_SIL_LO, C_SIL_DK
local C_CYAN, C_CYAN_DIM, C_PIT
local C_ORANGE, C_WHITE, C_DIM, C_GREEN, C_YELLOW, C_RED
local C_SHADOW, C_HILIGHT
local _colorsReady = false
local _themeId = -1

local function initColors(theme)
  local t = math.floor(tonumber(theme) or 0)
  if t < 0 then t = 0 elseif t > 3 then t = 3 end
  if _colorsReady and _themeId == t then return end

  C_BG      = lcd.RGB(  0,   0,   0)  -- pitch black
  C_TILE    = lcd.RGB(  8,  10,  20)  -- very dark tile
  C_CF1     = lcd.RGB(  0,   0,   0)  -- frame body: pure black
  C_CF2     = lcd.RGB( 10,  14,  30)  -- subtle stripe
  C_CF3     = lcd.RGB( 18,  24,  50)
  C_PIT     = lcd.RGB(  0,   0,   0)  -- pit: pure black

  -- Accent theme (used by divider lines, borders and header highlights)
  if t == 1 then
    -- Cyan theme
    C_SIL_HI   = lcd.RGB(  0, 180, 255)
    C_SIL_MID  = lcd.RGB(  0,  90, 180)
    C_SIL_LO   = lcd.RGB(  0,  40,  90)
    C_SIL_DK   = lcd.RGB(  0,  15,  45)
    C_CYAN     = lcd.RGB(  0, 255, 255)
    C_CYAN_DIM = lcd.RGB(  0,  60,  80)
    C_HILIGHT  = lcd.RGB( 20,  50, 130)
  elseif t == 2 then
    -- Green theme
    C_SIL_HI   = lcd.RGB(110, 255, 120)
    C_SIL_MID  = lcd.RGB( 40, 180,  70)
    C_SIL_LO   = lcd.RGB( 15,  90,  35)
    C_SIL_DK   = lcd.RGB(  5,  45,  15)
    C_CYAN     = lcd.RGB( 50, 220,  90)
    C_CYAN_DIM = lcd.RGB( 15,  70,  30)
    C_HILIGHT  = lcd.RGB( 35, 120,  45)
  elseif t == 3 then
    -- Orange theme
    C_SIL_HI   = lcd.RGB(255, 170,  60)
    C_SIL_MID  = lcd.RGB(220, 110,  25)
    C_SIL_LO   = lcd.RGB(120,  55,   8)
    C_SIL_DK   = lcd.RGB( 55,  22,   0)
    C_CYAN     = lcd.RGB(255, 120,  15)
    C_CYAN_DIM = lcd.RGB( 90,  40,   6)
    C_HILIGHT  = lcd.RGB(165,  70,  10)
  else
    -- Betaflight-style yellow theme (default)
    C_SIL_HI   = lcd.RGB(255, 220,  70)
    C_SIL_MID  = lcd.RGB(210, 165,  35)
    C_SIL_LO   = lcd.RGB(110,  78,  12)
    C_SIL_DK   = lcd.RGB( 48,  30,   0)
    C_CYAN     = lcd.RGB(255, 190,  20)
    C_CYAN_DIM = lcd.RGB( 85,  55,   8)
    C_HILIGHT  = lcd.RGB(150, 105,  20)
  end

  C_SHADOW   = lcd.RGB(  0,   0,   0)
  C_ORANGE  = lcd.RGB(255, 140,   0)  -- bright orange
  C_WHITE   = lcd.RGB(255, 255, 255)  -- pure white
  C_DIM     = lcd.RGB(100, 130, 180)  -- visible but dim
  C_GREEN   = lcd.RGB(  0, 255, 100)  -- neon green
  C_YELLOW  = lcd.RGB(255, 230,   0)  -- bright yellow
  C_RED     = lcd.RGB(255,  40,  60)  -- neon red
  _themeId = t
  _colorsReady = true
end

-- =========================================================================
--  SENSOR CACHE
-- =========================================================================
local _sid = {}
local function getS(name)
  local c = _sid[name]
  if c == nil then
    local info = getFieldInfo(name)
    _sid[name] = info and info.id or false
    c = _sid[name]
  end
  if c then return getValue(c) end
  return nil
end

-- =========================================================================
--  FLIGHT MODE CLEANUP
-- =========================================================================
local _FM_MAP = {
  STAB="ANGLE", ANGL="ANGLE", HOR="HORIZON",
  AIR="AIRMODE", ACRO="ACRO", MANU="MANUAL",
  HOLD="POSHOLD", RTH="RTH", FAIL="FAILSAFE",
  NAV="NAV", LAND="LAND", BARO="BARO",
}
local function cleanFM(s)
  if s == nil or s == "" then return "" end
  local t = string.gsub(tostring(s), "[*!%s]", "")
  return _FM_MAP[t] or t
end

-- =========================================================================
--  ARM / FLIGHT TIMER
-- =========================================================================
local _armStart  = nil
local _lastArmed = false
local _fmStr     = ""
local _lastThrUp = false

-- EdgeTX returns string-type telemetry sensors (like FM) as a byte-array
-- table, not a Lua string.  Convert either form to a plain string.
local function fmToString(raw)
  if raw == nil then return "" end
  if type(raw) == "string" then return raw end
  if type(raw) == "table" then
    local chars = {}
    for _, b in ipairs(raw) do
      if b == 0 then break end        -- null terminator
      chars[#chars + 1] = string.char(b)
    end
    return table.concat(chars)
  end
  return ""
end

local function throttlePct()
  local raw = getValue("thr")
  if type(raw) ~= "number" then return nil end
  return math.max(0, math.min(100, math.floor((raw + 1024) / 20.48)))
end

-- ArmSrc option: if set, use that switch/channel directly.
-- Otherwise fall back to the Betaflight FM telemetry field:
--   BF sends "!DISARMED" when disarmed, bare mode name (e.g. "ACRO") when armed.
local function sourceIsArmed(src)
  if src == nil or src == 0 then return nil end
  local info = getFieldInfo(src)
  if not info then return nil end        -- source not found on this radio
  local v = getValue(src)
  if type(v) == "number" then return v > 0 end
  return nil
end

local function hasActiveTelemetry()
  -- RQly > 0 means we have a live ELRS/CRSF link right now.
  -- Without this guard, EdgeTX serves stale persisted sensor values
  -- (e.g. last-known FM = "ACRO") even when the model is not connected,
  -- causing a false ARMED reading on startup.
  local lq = getS(SN_LQ)
  return type(lq) == "number" and lq > 0
end

local function isArmed(fmStr, opts)
  -- 1. Explicit arm switch wins if configured (most reliable).
  local fromOpt = sourceIsArmed(opts and opts.ArmSrc)
  if fromOpt ~= nil then return fromOpt end

  -- 2. No live telemetry link → never armed.
  if not hasActiveTelemetry() then return false end

  -- 3. FM telemetry string from Betaflight.
  --    BF marks disarmed state in one of two ways depending on version:
  --      a) "!" prefix  → e.g. "!DISARMED", "!ACRO"   (BF 4.3+)
  --      b) "*" suffix  → e.g. "ACRO*", "ANGL*"       (older BF / some configs)
  --    Any non-empty string WITHOUT these markers = armed.
  if fmStr == nil or fmStr == "" then return false end
  if string.sub(fmStr, 1, 1) == "!" then return false end
  if string.sub(fmStr, -1)   == "*" then return false end
  return true
end

local function tickArmTimer(opts)
  local raw   = getS(SN_FM)
  local s     = fmToString(raw)   -- decode byte-table → plain string
  local armed = isArmed(s, opts)

  local thr    = throttlePct()
  local thrOn  = (opts and opts.ThrOn) or 5
  local thrUp  = thr ~= nil and thr > thrOn

  if not armed then
    -- Disarmed: reset everything so next arm+throttle starts fresh.
    _armStart  = nil
    _lastThrUp = false
  elseif _armStart == nil then
    -- Armed but timer not yet running.
    -- Start on any throttle-up event (rising edge OR already-raised at arm time).
    if thrUp then
      _armStart = getTime()
    end
    _lastThrUp = thrUp
  else
    _lastThrUp = thrUp
  end

  _lastArmed = armed
  _fmStr     = cleanFM(s)
end

local function armTimerStr()
  if _armStart == nil then return "--:--" end
  local sec = math.floor((getTime() - _armStart) / 100)
  return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

-- =========================================================================
--  RF MODE
-- =========================================================================
local _RFM = {
  -- ELRS 2.4GHz rate enum (matches ExpressLRS RATE_* firmware constants)
  [0]="4Hz",      [1]="25Hz",    [2]="50Hz",    [3]="100Hz",
  [4]="100Hz/8ch",[5]="150Hz",   [6]="200Hz",   [7]="250Hz",
  [8]="333Hz/8ch",[9]="500Hz",   [10]="D250Hz",
  [11]="D500Hz",  [12]="F500Hz", [13]="F1000",
}
local function rfModeStr(v)
  if v == nil then return "---" end
  return _RFM[math.floor(v)] or tostring(math.floor(v))
end

-- =========================================================================
--  STATUS COLORS
-- =========================================================================
local function cLQ(v, warn)
  if v == nil then return C_DIM end
  if v >= (warn or 70) then return C_GREEN end
  if v >= 40 then return C_YELLOW end
  return C_RED
end
local function cPct(p)
  if p == nil then return C_DIM end
  if p >= 40 then return C_GREEN end
  if p >= 20 then return C_YELLOW end
  return C_RED
end
local function cVolt(cV, wV, kV)
  if cV == nil then return C_DIM end
  if cV > (wV or 3.6) then return C_GREEN end
  if cV > (kV or 3.4) then return C_YELLOW end
  return C_RED
end

-- =========================================================================
--  LAYOUT CONSTANTS
--  Screen: 800 x 480
--  Carbon frame sides: 44px L/R, 22px bottom
--  Top bar: flat 22px at edges, ramps to 82px peak over 80px each side
--  Peak zone: x=200..600 (flat 82px high = header info zone)
--  Tile grid: x=44..756, y=84..458
-- =========================================================================
local FRM_L    = 30
local FRM_R    = 30
local FRM_B    = 14
local TOP_EDGE = 22
local TOP_MID  = 82
local RAMP_W   = 80
local PEAK_X1  = 200
local PEAK_X2  = 600
local RAMP_X1  = PEAK_X1 - RAMP_W
local RAMP_X2  = PEAK_X2 + RAMP_W

local GX = FRM_L
local GY = TOP_MID + 2
local GW = 800 - FRM_L - FRM_R
local GH = 480 - TOP_MID - FRM_B

-- Honeycomb layout (12 cells = 4 columns x 3 staggered rows)
local HX_COLS = 6
local HX_ROWS = 2
local HX_GAP  = 2

local HEX_W = math.floor((GW - HX_GAP * 2) / (0.25 + 0.75 * HX_COLS))
local HEX_H = math.floor(HEX_W * 1.00)
local _maxHexH = math.floor((GH - HX_GAP * 2) / (HX_ROWS + 0.5))
if HEX_H > _maxHexH then
  HEX_H = _maxHexH
  HEX_W = math.floor(HEX_H / 1.00)
end

local HX_STEP_X = math.floor(HEX_W * 0.75)
local HX_STEP_Y = HEX_H
local HX_TOTAL_W = HX_STEP_X * (HX_COLS - 1) + HEX_W
local HX_TOTAL_H = HEX_H * HX_ROWS + math.floor(HEX_H / 2)
local HX_ORG_X = GX + math.floor((GW - HX_TOTAL_W) / 2)
local HX_ORG_Y = GY + math.floor((GH - HX_TOTAL_H) / 2)

local MENU_W = 380
local MENU_X = math.floor((800 - MENU_W) / 2)
local MENU_ROW_H = 38
local MENU_TITLE_H = 28
local MENU_PAD = 8
local MENU_MAX_ROWS = 8
local MENU_SCROLL_THRESHOLD = 10

local _tileSlots = {}
local _touchUi = {
  open = false,
  tile = nil,
  lastTap = 0,
  isDown = false,
  downKind = nil,
  downIndex = nil,
  downX = nil,
  downY = nil,
  downMoved = false,
  scrollStart = 0,
  menuScroll = 0,
}

local function clampInt(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- =========================================================================
--  CARBON FIBER FRAME
--  Draw using Y-axis horizontal slices (cheap) instead of per-column loops.
--  Total draw calls: ~100 (was ~4000 with cfStripe column loops).
-- =========================================================================
local function drawCarbonFrame()
  local cfD = C_CF1   -- solid dark carbon fill color

  -- ---- Flat frame panels ----
  lcd.drawFilledRectangle(0, 0, 800, TOP_MID, cfD)
  lcd.drawFilledRectangle(0, TOP_MID, FRM_L, 480 - TOP_MID - FRM_B, cfD)
  lcd.drawFilledRectangle(800 - FRM_R, TOP_MID, FRM_R, 480 - TOP_MID - FRM_B, cfD)
  lcd.drawFilledRectangle(0, 480 - FRM_B, 800, FRM_B, cfD)

  -- ---- Inner edge bevel (bottom edge of flat top bar) ----
  lcd.drawFilledRectangle(0, TOP_MID,   800, 1, C_SIL_HI)
  lcd.drawFilledRectangle(0, TOP_MID+1, 800, 1, C_SIL_MID)

  -- cyan accent line across full bottom of top bar
  lcd.drawFilledRectangle(0, TOP_MID + 2, 800, 2, C_CYAN)

  -- left/right frame inner edge bevels
  lcd.drawFilledRectangle(FRM_L,   GY, 1, GH, C_SIL_HI)
  lcd.drawFilledRectangle(FRM_L+1, GY, 1, GH, C_SIL_MID)
  lcd.drawFilledRectangle(800-FRM_R-2, GY, 1, GH, C_SIL_MID)
  lcd.drawFilledRectangle(800-FRM_R-1, GY, 1, GH, C_SIL_HI)

  -- bottom frame top edge bevel
  lcd.drawFilledRectangle(GX, 480-FRM_B-2, GW, 1, C_SIL_MID)
  lcd.drawFilledRectangle(GX, 480-FRM_B-1, GW, 1, C_SIL_HI)

  -- outer silver border
  lcd.drawFilledRectangle(0,   0, 800,   1, C_SIL_MID)
  lcd.drawFilledRectangle(0,   0,   1, 480, C_SIL_MID)
  lcd.drawFilledRectangle(799, 0,   1, 480, C_SIL_MID)
  lcd.drawFilledRectangle(0, 479, 800,   1, C_SIL_MID)

  -- cyan corner L-brackets
  lcd.drawFilledRectangle(  0,   0,  18,   2, C_CYAN)
  lcd.drawFilledRectangle(  0,   0,   2,  18, C_CYAN)
  lcd.drawFilledRectangle(782,   0,  18,   2, C_CYAN)
  lcd.drawFilledRectangle(798,   0,   2,  18, C_CYAN)
  lcd.drawFilledRectangle(  0, 462,  18,   2, C_CYAN)
  lcd.drawFilledRectangle(  0, 462,   2,  18, C_CYAN)
  lcd.drawFilledRectangle(782, 462,  18,   2, C_CYAN)
  lcd.drawFilledRectangle(798, 462,   2,  18, C_CYAN)
end

-- =========================================================================
--  RECESSED PIT
-- =========================================================================
local function drawPit()
  lcd.drawFilledRectangle(GX+2, GY+2, GW-4, GH-4, C_PIT)
  -- top shadow
  lcd.drawFilledRectangle(GX+2, GY+2, GW-4, 1, C_SHADOW)
  lcd.drawFilledRectangle(GX+2, GY+3, GW-4, 1, C_SIL_DK)
  lcd.drawFilledRectangle(GX+2, GY+4, GW-4, 1, C_CF1)
  -- left shadow
  lcd.drawFilledRectangle(GX+2, GY+2, 1, GH-4, C_SHADOW)
  lcd.drawFilledRectangle(GX+3, GY+2, 1, GH-4, C_SIL_DK)
  lcd.drawFilledRectangle(GX+4, GY+2, 1, GH-4, C_CF1)
  -- bottom highlight
  lcd.drawFilledRectangle(GX+2, GY+GH-3, GW-4, 1, C_CF2)
  lcd.drawFilledRectangle(GX+2, GY+GH-2, GW-4, 1, C_HILIGHT)
  -- right highlight
  lcd.drawFilledRectangle(GX+GW-3, GY+2, 1, GH-4, C_CF2)
  lcd.drawFilledRectangle(GX+GW-2, GY+2, 1, GH-4, C_HILIGHT)
end

-- =========================================================================
--  TILE
-- =========================================================================
local function drawTile(tx, ty, tw, th)
  -- Flat-top hexagon: flat edges at top and bottom, points at left and right.
  local q  = math.max(8, math.floor(tw / 4))
  local hh = math.floor(th / 2)
  local xL  = tx
  local xR  = tx + tw - 1
  local xLT = tx + q
  local xRT = tx + tw - q - 1
  local yM  = ty + hh
  local y1  = ty
  local y4  = ty + th - 1

  -- Lightweight fill: one inner rectangle keeps tile contrast with minimal CPU cost.
  local pad = math.max(3, math.floor(th * 0.10))
  local fillY = ty + pad
  local fillH = th - (pad * 2)
  local fillW = tw - (q * 2)
  if fillH > 0 and fillW > 0 then
    lcd.drawFilledRectangle(tx + q, fillY, fillW, fillH, C_TILE)
  end

  -- Hex outline (6 edges) so the honeycomb remains clearly visible.
  lcd.drawLine(xLT, y1,  xRT, y1,  0xFF, C_SIL_HI)   -- top
  lcd.drawLine(xRT, y1,  xR,  yM,  0xFF, C_SIL_MID)  -- right-top
  lcd.drawLine(xR,  yM,  xRT, y4,  0xFF, C_SIL_DK)   -- right-bottom
  lcd.drawLine(xRT, y4,  xLT, y4,  0xFF, C_SIL_DK)   -- bottom
  lcd.drawLine(xLT, y4,  xL,  yM,  0xFF, C_SIL_MID)  -- left-bottom
  lcd.drawLine(xL,  yM,  xLT, y1,  0xFF, C_SIL_HI)   -- left-top
end

-- =========================================================================
--  TEXT HELPERS
-- =========================================================================
local function lbl(tx, ty, txt)
  lcd.drawText(tx, ty, txt, SMLSIZE + C_CYAN)
end
local function val(tx, ty, txt, col, sz)
  lcd.drawText(tx, ty, txt, (sz or MIDSIZE) + BOLD + (col or C_WHITE))
end
local function sub(tx, ty, txt, col)
  lcd.drawText(tx, ty, txt, SMLSIZE + (col or C_DIM))
end

local function drawHeaderText(x, y, txt, col)
  local s = string.upper(tostring(txt or ""))
  lcd.drawText(x + 2, y + 2, s, MIDSIZE + BOLD + C_SIL_DK)
  lcd.drawText(x, y, s, MIDSIZE + BOLD + (col or C_WHITE))
end

local function drawHeaderTextC(x, y, txt, col)
  local s = string.upper(tostring(txt or ""))
  lcd.drawText(x + 2, y + 2, s, MIDSIZE + BOLD + CENTER + C_SIL_DK)
  lcd.drawText(x, y, s, MIDSIZE + BOLD + CENTER + (col or C_WHITE))
end

-- =========================================================================
--  BAR MODE
-- =========================================================================
local function drawBar(tx, ty, tw, th, pct, col)
  local bx = tx + 6
  local by = ty + 30
  local bw = tw - 12
  local bh = th - 38
  lcd.drawFilledRectangle(bx, by, bw, bh, C_SIL_DK)
  local fw = math.floor(bw * math.max(0, math.min(1, (pct or 0)/100)))
  if fw > 0 then
    lcd.drawFilledRectangle(bx, by, fw, bh, col or C_GREEN)
    lcd.drawFilledRectangle(bx+fw-2, by, 2, bh, C_SIL_HI)
  end
  lcd.drawRectangle(bx, by, bw, bh, C_SIL_MID)
  if pct then
    lcd.drawText(tx + tw/2, by + bh/2 - 8,
      string.format("%d%%", math.floor(pct)), MIDSIZE+BOLD+CENTER+(col or C_WHITE))
  end
end

-- =========================================================================
--  ARC GAUGE MODE (Optimized for Performance)
-- =========================================================================
local _PI = 3.14159265
local GAUGE_ARC_THICK = 96

-- Cache system: store last rendered state per gauge instance
local _gaugeCache = {}  -- { "key" = { lastPct, cx, cy, r, thick, aS, aE } }
local _gaugeBgCache = {}  -- { "key" = true } - background rendered once

local function drawArcSeg(cx, cy, r, a1, a2, col, steps)
  steps = steps or 56
  local da = (a2 - a1) / steps
  local px, py
  for i = 0, steps do
    local a  = a1 + i * da
    local nx = cx + math.floor(r * math.cos(a) + 0.5)
    local ny = cy + math.floor(r * math.sin(a) + 0.5)
    if px then lcd.drawLine(px, py, nx, ny, 0xFF, col) end
    px = nx; py = ny
  end
end

local function drawArcBand(cx, cy, r, a1, a2, coreCol, midCol, edgeCol, thick)
  local half = math.max(1, math.floor((thick or 10) / 2))
  local steps = math.max(56, math.floor(r * 2.2))
  for off = -half, half do
    local rr = r + off
    if rr > 0 then
      local d = math.abs(off)
      if d >= half then
        drawArcSeg(cx, cy, rr, a1, a2, edgeCol, steps)
      elseif d >= (half - 1) then
        drawArcSeg(cx, cy, rr, a1, a2, midCol, steps)
      else
        drawArcSeg(cx, cy, rr, a1, a2, coreCol, steps)
      end
    end
  end
end

-- Faster needle: draw triangle + center dot instead of 3 rectangles
local function drawNeedleTriangle(cx, cy, r, angleRad, col)
  local nx = cx + math.floor((r - 1) * math.cos(angleRad) + 0.5)
  local ny = cy + math.floor((r - 1) * math.sin(angleRad) + 0.5)
  
  -- Perpendicular direction for needle width
  local perpAngle = angleRad + _PI / 2
  local w = 4
  local wx = math.floor(w * math.cos(perpAngle))
  local wy = math.floor(w * math.sin(perpAngle))
  
  -- Triangle: needle point + two base corners
  local x1, y1 = nx, ny
  local x2, y2 = cx + wx, cy + wy
  local x3, y3 = cx - wx, cy - wy
  
  -- Draw filled triangle (using three lines as filled polygon)
  lcd.drawFilledRectangle(math.min(x1,x2,x3)-1, math.min(y1,y2,y3)-1, 
                          math.max(x1,x2,x3)-math.min(x1,x2,x3)+2,
                          math.max(y1,y2,y3)-math.min(y1,y2,y3)+2, C_SIL_DK)
  
  -- Draw bright needle
  lcd.drawLine(x1, y1, x2, y2, 0xFF, col)
  lcd.drawLine(x1, y1, x3, y3, 0xFF, col)
  lcd.drawLine(x2, y2, x3, y3, 0xFF, col)
  
  -- Center dot
  lcd.drawFilledRectangle(cx-2, cy-2, 5, 5, C_SIL_HI)
  lcd.drawFilledRectangle(cx-1, cy-1, 3, 3, C_WHITE)
end

local function drawGauge(tx, ty, tw, th, pct, col, val_str, unit_str)
  local cx = math.floor(tx + tw / 2)

  -- Keep gauge thick but always bounded inside the tile.
  local thick = math.max(8, math.min(GAUGE_ARC_THICK, math.floor(math.min(tw, th) * 0.18)))
  local halfT = math.floor(thick / 2)
  local r = math.floor(math.min(tw * 0.28, th * 0.28))
  local maxRByHeight = math.floor((th - 14 - (halfT * 2)) / 2)
  if maxRByHeight < 8 then maxRByHeight = 8 end
  if r > maxRByHeight then r = maxRByHeight end

  local cyMin = ty + 8 + r + halfT
  local cyMax = ty + th - 6 - r - halfT
  local cy = math.floor(ty + th * 0.62)
  if cy < cyMin then cy = cyMin end
  if cy > cyMax then cy = cyMax end

  local aS = 210 * _PI / 180
  local aE = (210 - 300) * _PI / 180

  -- Create cache key based on gauge geometry
  local cacheKey = string.format("%.0f_%.0f_%.0f_%.0f", cx, cy, r, thick)
  
  -- Draw background arc ONCE and cache it
  if not _gaugeBgCache[cacheKey] then
    drawArcBand(cx, cy, r, aS, aE, C_SIL_LO, C_SIL_DK, C_CF1, thick)
    _gaugeBgCache[cacheKey] = true
  end

  -- Only redraw needle + filled arc if percentage changed by >1%
  local lastPct = _gaugeCache[cacheKey] or -999
  local pctFloor = math.floor((pct or 0) + 0.5)
  local lastPctFloor = math.floor(lastPct + 0.5)
  
  if math.abs(pctFloor - lastPctFloor) > 1 then
    if pct and pct > 0 then
      local aV = aS - (aS - aE) * math.min(pct, 100) / 100

      -- Active track: bright center with faded edges
      drawArcBand(cx, cy, r, aS, aV, col or C_GREEN, C_SIL_MID, C_SIL_DK, thick)

      -- Draw optimized needle (triangle is faster than 3 rectangles)
      drawNeedleTriangle(cx, cy, r, aV, col or C_GREEN)
    else
      -- Draw center dot only when pct is 0
      lcd.drawFilledRectangle(cx-2, cy-2, 5, 5, C_SIL_HI)
      lcd.drawFilledRectangle(cx-1, cy-1, 3, 3, C_WHITE)
    end
    _gaugeCache[cacheKey] = pct or 0
  end
  
  -- Text is cheap, always draw for responsiveness
  if val_str then
    lcd.drawText(cx, cy - 12, val_str, MIDSIZE+BOLD+CENTER+(col or C_WHITE))
  end
  if unit_str then
    lcd.drawText(cx, cy + 2, unit_str, SMLSIZE+CENTER+C_DIM)
  end
end

local function hitFlatTopHex(px, py, tx, ty, tw, th)
  if px < tx or px > (tx + tw - 1) or py < ty or py > (ty + th - 1) then
    return false
  end
  local hh = th / 2
  if hh <= 0 then return false end
  local yMid = ty + hh
  local q = tw / 4
  local dyNorm = math.abs(py - yMid) / hh
  if dyNorm > 1 then return false end
  local inset = q * dyNorm
  local xL = tx + inset
  local xR = tx + tw - 1 - inset
  return px >= xL and px <= xR
end

local function tileRect(i)
  local c = (i - 1) % HX_COLS
  local r = math.floor((i - 1) / HX_COLS)
  local tx = HX_ORG_X + c * HX_STEP_X
  local ty = HX_ORG_Y + r * HX_STEP_Y + ((c % 2) * math.floor(HEX_H / 2))
  return tx, ty, HEX_W, HEX_H
end

local function tileAtPoint(px, py, tileCount)
  for i = 1, tileCount do
    local tx, ty, tw, th = tileRect(i)
    if hitFlatTopHex(px, py, tx, ty, tw, th) then
      return i
    end
  end
  return nil
end

local function touchXY(touchState)
  if type(touchState) ~= "table" then return nil, nil end
  local x = touchState.x or touchState.X or touchState[1]
  local y = touchState.y or touchState.Y or touchState[2]
  if type(x) ~= "number" or type(y) ~= "number" then return nil, nil end
  return x, y
end

local function canTapNow()
  local now = getTime() or 0
  if (now - (_touchUi.lastTap or 0)) < 18 then
    return false
  end
  _touchUi.lastTap = now
  return true
end

-- =========================================================================
--  TILE DATA
-- =========================================================================
local function tdLQ(o)
  local v = getS(SN_LQ)
  return { val=v and string.format("%d",v) or "---", unit="%",
           pct=v, col=cLQ(v,o.LQWrn),
           sub=v and string.format("warn<%d%%",o.LQWrn) or nil }
end
local function tdBatt(o)
  local volt=getS(SN_VOLT); local nc=o.Cells
  local fV=o.FullV/10.0; local eV=3.30
  local cV=volt and (volt/nc) or nil
  local pct=cV and math.max(0,math.min(100,(cV-eV)/(fV-eV)*100)) or nil
  return { val=volt and string.format("%.1fV",volt) or "---",
           unit=cV and string.format("%.2f/cell",cV) or "",
           pct=pct, col=cPct(pct),
           sub=pct and string.format("%d%%",math.floor(pct)) or nil }
end
local function tdCurrent(o)
  local v=getS(SN_CURR)
  return { val=v and string.format("%.1f",v) or "---", unit="Amps",
           pct=v and math.min(100,v) or nil, col=C_WHITE }
end
local function tdTimer(o)
  return { val=armTimerStr(), unit=_lastArmed and "ARMED" or "disarmed",
           pct=nil, col=_lastArmed and C_GREEN or C_DIM }
end
local function tdRSSI(o)
  local v1=getS(SN_RSSI1); local v2=getS(SN_RSSI2)
  local col=v1 and (v1>-65 and C_GREEN or (v1>-85 and C_YELLOW or C_RED)) or C_DIM
  return { val=v1 and tostring(v1) or "---", unit="dBm",
           pct=v1 and math.max(0,math.min(100,v1+130)) or nil,
           col=col, sub=v2 and string.format("a2:%d",v2) or nil }
end
local function tdCellV(o)
  local volt=getS(SN_VOLT); local nc=o.Cells
  local wV=o.WarnV/10.0; local kV=o.CritV/10.0
  local cV=volt and (volt/nc) or nil
  return { val=cV and string.format("%.2f",cV) or "---",
           unit=string.format("V  %dS",nc),
           pct=cV and math.max(0,math.min(100,(cV-kV)/(4.2-kV)*100)) or nil,
           col=cVolt(cV,wV,kV) }
end
local function tdMah(o)
  local v=getS(SN_CAPA)
  local col=v and (v<500 and C_GREEN or (v<800 and C_YELLOW or C_RED)) or C_DIM
  return { val=v and string.format("%d",v) or "---", unit="mAh",
           pct=v and math.min(100,v/10) or nil, col=col }
end
local function tdThrottle(o)
  local v = throttlePct()
  return { val=v and string.format("%d",v) or "---", unit="%",
           pct=v, col=C_ORANGE }
end
local function tdTXPwr(o)
  local v=getS(SN_TPWR)
  local col=v and (v<=100 and C_GREEN or (v<=500 and C_YELLOW or C_RED)) or C_DIM
  return { val=v and tostring(v) or "---", unit="mW",
           pct=v and math.min(100,v/20) or nil, col=col }
end
local function tdAlt(o)
  local v=getS(SN_ALT)
  return { val=v and string.format("%.1f",v) or "---", unit="metres",
           pct=v and math.max(0,math.min(100,v/5)) or nil, col=C_WHITE }
end
local function tdDist(o)
  local v=getS(SN_DIST)
  local col=v and (v>=500 and C_RED or (v>=200 and C_ORANGE or C_GREEN)) or C_DIM
  return { val=v and string.format("%.0f",v) or "---", unit="metres",
           pct=v and math.min(100,v/10) or nil, col=col }
end
local function tdRFMode(o)
  local v=getS(SN_RFMD)
  return { val=rfModeStr(v), unit="RF mode", pct=nil, col=C_WHITE }
end

local METRICS = {
  { "LINK QUALITY", tdLQ       },
  { "BATTERY",      tdBatt     },
  { "CURRENT",      tdCurrent  },
  { "FLIGHT TIMER", tdTimer    },
  { "RSSI",         tdRSSI     },
  { "CELL VOLTAGE", tdCellV    },
  { "CAPACITY",     tdMah      },
  { "THROTTLE",     tdThrottle },
  { "TX POWER",     tdTXPwr    },
  { "ALTITUDE",     tdAlt      },
  { "DISTANCE",      tdDist     },
  { "RF MODE",      tdRFMode   },
}

local function syncTileSlotsFromOptions(options)
  _tileSlots = _tileSlots or {}
  for i = 1, #METRICS do
    local key = "T" .. i
    local raw = options and options[key]
    local idx0 = (type(raw) == "number") and math.floor(raw) or (i - 1)
    _tileSlots[i] = clampInt(idx0, 0, #METRICS - 1) + 1
  end
end

local function setSequentialTileDefaults(options)
  _tileSlots = _tileSlots or {}
  for i = 1, #METRICS do
    _tileSlots[i] = i
    if options then
      options["T" .. i] = i - 1
    end
  end
end

local function optionsAllLinkQ(options)
  if type(options) ~= "table" then return false end
  for i = 1, #METRICS do
    if options["T" .. i] ~= 0 then
      return false
    end
  end
  return true
end

local function tileStorageKey()
  local modelName = "default"
  if model and model.getInfo then
    local info = model.getInfo()
    if info and info.name and info.name ~= "" then
      modelName = tostring(info.name)
    end
  end
  return "BFTelem.TileMap." .. modelName
end

local function saveTileSlotsToStorage(options)
  if not storage or not storage.write then return end
  local out = {}
  local mode = clampInt(math.floor((options and options.Mode) or 0), 0, 2)
  for i = 1, #METRICS do
    out[i] = (_tileSlots[i] or i) - 1
  end
  out.mode = mode
  pcall(storage.write, tileStorageKey(), out)
end

local function loadTileSlotsFromStorage(options)
  if not storage or not storage.read then return end
  local ok, saved = pcall(storage.read, tileStorageKey())
  if not ok or type(saved) ~= "table" then return false end

  local loadedAny = false
  for i = 1, #METRICS do
    local raw = saved[i]
    if type(raw) == "number" then
      local idx1 = clampInt(math.floor(raw), 0, #METRICS - 1) + 1
      _tileSlots[i] = idx1
      if options then
        options["T" .. i] = idx1 - 1
      end
      loadedAny = true
    end
  end

  if options and type(saved.mode) == "number" then
    options.Mode = clampInt(math.floor(saved.mode), 0, 2)
  end

  return loadedAny
end

local function menuBounds()
  local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
  local h = MENU_TITLE_H + MENU_PAD * 2 + visibleRows * MENU_ROW_H + MENU_ROW_H
  local y = math.floor((480 - h) / 2)
  return MENU_X, y, MENU_W, h
end

local function drawMetricMenu()
  if not _touchUi.open or not _touchUi.tile then return end
  local mx, my, mw, mh = menuBounds()
  lcd.drawFilledRectangle(mx, my, mw, mh, C_CF1)
  lcd.drawRectangle(mx, my, mw, mh, C_SIL_HI)
  lcd.drawFilledRectangle(mx + 1, my + 1, mw - 2, MENU_TITLE_H, C_SIL_DK)

  local title = string.format("Tile %d: Select Metric", _touchUi.tile)
  lcd.drawText(mx + 8, my + 6, title, SMLSIZE + C_WHITE)

  local currentIdx = _tileSlots[_touchUi.tile] or _touchUi.tile
  local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
  local maxScroll = math.max(0, #METRICS - visibleRows)
  local scroll = clampInt(_touchUi.menuScroll or 0, 0, maxScroll)
  _touchUi.menuScroll = scroll
  local rowY = my + MENU_TITLE_H + MENU_PAD
  for row = 1, visibleRows do
    local i = scroll + row
    local metric = METRICS[i]
    if not metric then break end
    local bg = C_TILE
    if i == currentIdx then
      bg = C_HILIGHT
    end
    lcd.drawFilledRectangle(mx + MENU_PAD, rowY, mw - MENU_PAD * 2, MENU_ROW_H - 2, bg)
    lcd.drawRectangle(mx + MENU_PAD, rowY, mw - MENU_PAD * 2, MENU_ROW_H - 2, C_SIL_LO)
    lcd.drawText(mx + MENU_PAD + 8, rowY + 11, metric[1], SMLSIZE + C_WHITE)
    rowY = rowY + MENU_ROW_H
  end

  if scroll > 0 then
    lcd.drawText(mx + mw - 16, my + 4, "^", SMLSIZE + C_SIL_HI)
  end
  if scroll < maxScroll then
    lcd.drawText(mx + mw - 16, my + mh - 14, "v", SMLSIZE + C_SIL_HI)
  end

  local resetY = my + mh - MENU_ROW_H
  lcd.drawFilledRectangle(mx + MENU_PAD, resetY, mw - MENU_PAD * 2, MENU_ROW_H - 2, C_ORANGE)
  lcd.drawRectangle(mx + MENU_PAD, resetY, mw - MENU_PAD * 2, MENU_ROW_H - 2, C_SIL_HI)
  lcd.drawText(mx + MENU_PAD + 8, resetY + 11, "RESET LAYOUT", SMLSIZE + C_WHITE)
end

local function menuMetricAt(mx, my)
  local x, y, w, h = menuBounds()
  if mx < x or mx > (x + w - 1) or my < y or my > (y + h - 1) then return nil end
  local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
  local maxScroll = math.max(0, #METRICS - visibleRows)
  local scroll = clampInt(_touchUi.menuScroll or 0, 0, maxScroll)
  local rowY = y + MENU_TITLE_H + MENU_PAD
  for row = 1, visibleRows do
    if my >= rowY and my < (rowY + MENU_ROW_H) then
      return scroll + row
    end
    rowY = rowY + MENU_ROW_H
  end
  local resetY = y + h - MENU_ROW_H
  if my >= resetY and my < (resetY + MENU_ROW_H) then
    return "RESET"
  end
  return nil
end

local function resetTouchDownState()
  _touchUi.downKind = nil
  _touchUi.downIndex = nil
  _touchUi.downX = nil
  _touchUi.downY = nil
  _touchUi.downMoved = false
  _touchUi.scrollStart = _touchUi.menuScroll or 0
end

local function handleTouch(widget, touchState)
  local x, y = touchXY(touchState)
  local isDown = (x ~= nil and y ~= nil)

  if isDown then
    if not _touchUi.isDown then
      if _touchUi.open and _touchUi.tile then
        local x0, y0, w0, h0 = menuBounds()
        if x >= x0 and x <= (x0 + w0 - 1) and y >= y0 and y <= (y0 + h0 - 1) then
          _touchUi.downKind = "menu"
          _touchUi.downIndex = menuMetricAt(x, y)
          _touchUi.downX = x
          _touchUi.downY = y
          _touchUi.downMoved = false
          _touchUi.scrollStart = _touchUi.menuScroll or 0
        else
          resetTouchDownState()
        end
      else
        local tile = tileAtPoint(x, y, #_tileSlots)
        if tile then
          _touchUi.downKind = "tile"
          _touchUi.downIndex = tile
          _touchUi.downX = x
          _touchUi.downY = y
          _touchUi.downMoved = false
        else
          resetTouchDownState()
        end
      end
    else
      if _touchUi.downKind == "menu" and _touchUi.downY then
        local dy = y - _touchUi.downY
        if math.abs(dy) >= MENU_SCROLL_THRESHOLD then
          _touchUi.downMoved = true
          local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
            local maxScroll = math.max(0, #METRICS - visibleRows)
            local rawRows = (_touchUi.downY - y) / MENU_ROW_H
            local deltaRows
            if rawRows >= 0 then
              deltaRows = math.floor(rawRows + 0.5)
            else
              deltaRows = math.ceil(rawRows - 0.5)
            end
          _touchUi.menuScroll = clampInt((_touchUi.scrollStart or 0) + deltaRows, 0, maxScroll)
        end
      end
    end
    _touchUi.isDown = true
    return
  end

  if not _touchUi.isDown then return end
  _touchUi.isDown = false

  local downKind = _touchUi.downKind
  local downIndex = _touchUi.downIndex
  local downMoved = _touchUi.downMoved
  resetTouchDownState()

  if downKind == "tile" and downIndex and not downMoved then
    if not canTapNow() then return end
    _touchUi.open = true
    _touchUi.tile = downIndex
    _touchUi.menuScroll = 0
    return
  end

  if downKind == "menu" and downIndex and not downMoved and _touchUi.open and _touchUi.tile then
    if not canTapNow() then return end
    if downIndex == "RESET" then
      setSequentialTileDefaults(widget and widget.options)
      saveTileSlotsToStorage(widget and widget.options)
    else
      _tileSlots[_touchUi.tile] = downIndex
      if widget and widget.options then
        widget.options["T" .. _touchUi.tile] = downIndex - 1
      end
      saveTileSlotsToStorage(widget and widget.options)
    end
    _touchUi.open = false
    _touchUi.tile = nil
  end
end

-- =========================================================================
--  TILE RENDERER
-- =========================================================================
local function renderTile(tx, ty, tw, th, lbl_str, d, mode)
  drawTile(tx, ty, tw, th)
  local cx = tx + math.floor(tw / 2)

  -- Slightly denser layout so text occupies more of each tile.
  local yLbl  = ty + math.floor(th * 0.22)
  local yVal  = ty + math.floor(th * 0.36)
  local yUnit = ty + math.floor(th * 0.62)
  local ySub  = ty + math.floor(th * 0.77)

  local shortLbl = lbl_str
  if lbl_str == "LINK QUALITY" then shortLbl = "LINK Q" end
  if lbl_str == "FLIGHT TIMER" then shortLbl = "TIMER" end
  if lbl_str == "CELL VOLTAGE" then shortLbl = "CELL V" end
  if lbl_str == "TX POWER"     then shortLbl = "TX PWR" end
  if lbl_str == "CAPACITY"     then shortLbl = "CAPA" end
  if lbl_str == "DISTANCE"     then shortLbl = "DIST" end
  if lbl_str == "ALTITUDE"     then shortLbl = "ALT" end

  -- label: small, cyan, centered
  lcd.drawText(cx, yLbl, shortLbl, SMLSIZE + CENTER + C_CYAN)

  if mode == 1 then
    local pad = math.max(8, math.floor(tw * 0.14))
    drawBar(tx + pad, ty + math.floor(th * 0.33), tw - 2 * pad, math.floor(th * 0.54), d.pct, d.col)
    lcd.drawText(cx, yLbl + 14, d.val, SMLSIZE + CENTER + BOLD + (d.col or C_WHITE))
  elseif mode == 2 then
    local pad = math.max(8, math.floor(tw * 0.14))
    drawGauge(tx + pad, ty + 6, tw - 2 * pad, th - 14, d.pct, d.col, d.val, d.unit)
  else
    lcd.drawText(cx, yVal, d.val, MIDSIZE + BOLD + CENTER + (d.col or C_WHITE))
    if d.unit and d.unit ~= "" then
      lcd.drawText(cx, yUnit, d.unit, SMLSIZE + CENTER + C_DIM)
    end
    if d.sub then
      lcd.drawText(cx, ySub, d.sub, SMLSIZE + CENTER + C_DIM)
    end
  end
end

-- =========================================================================
--  HEADER  (drawn inside the carbon top bar center bulge)
-- =========================================================================
local function drawHeader(o)
  local mname = "CRAFT"
  -- Show default label before bind; swap to model name only when telemetry is live.
  if hasActiveTelemetry() then
    local info = model.getInfo()
    if info and info.name and info.name ~= "" then mname = info.name end
  end
  -- model name (safe x=80 avoids EdgeTX logo, y=12 centers in 82px bar)
  drawHeaderText(80, 10, mname, C_SIL_HI)
  -- vertical separators (symmetric around x=400)
  lcd.drawFilledRectangle(300, 8, 2, 58, C_SIL_LO)
  -- flight mode
  local fmDisp = "MODE"
  if hasActiveTelemetry() then
    fmDisp = (_fmStr ~= "") and _fmStr or "MODE"
  end
  local fmCol = C_SIL_MID
  if hasActiveTelemetry() then
    fmCol = _lastArmed and C_ORANGE or C_SIL_HI
  end
  drawHeaderTextC(400, 10, fmDisp, fmCol)
  -- armed/disarmed indicator (replaces timer - timer is in FLIGHT TIMER tile)
  lcd.drawFilledRectangle(500, 8, 2, 58, C_SIL_LO)
  if _lastArmed then
    drawHeaderText(530, 10, "ARMED", C_RED)
  else
    drawHeaderText(530, 10, "DISARMED", C_GREEN)
  end
  -- TX voltage top-right
  local txv = getValue("tx-voltage")
  if type(txv) == "number" and txv > 0 then
    lcd.drawText(785, 8, string.format("TX %.1fV", txv),
      SMLSIZE+RIGHT+(txv > 7.0 and C_GREEN or C_RED))
  end
  -- mode label bottom-right
  local mLbl = (o.Mode==1) and "[ BAR ]" or (o.Mode==2) and "[GAUGE]" or "[ NUM ]"
  lcd.drawText(785, 56, mLbl, SMLSIZE+RIGHT+C_SIL_MID)
end

-- =========================================================================
--  GRID
-- =========================================================================
local function drawGrid(opts)
  local mode = opts.Mode or 0
  for i = 1, #_tileSlots do
    local metricIdx = _tileSlots[i] or i
    local metric = METRICS[metricIdx] or METRICS[i]
    local tx, ty, tw, th = tileRect(i)
    renderTile(tx, ty, tw, th, metric[1], metric[2](opts), mode)
  end
end

-- =========================================================================
--  LIFECYCLE
-- =========================================================================
local function create(zone, options)
  initColors(options and options.Theme)
  _sid = {}
  _armStart = nil
  _lastArmed = false
  _lastThrUp = false
  syncTileSlotsFromOptions(options)
  local loaded = loadTileSlotsFromStorage(options)
  if not loaded and optionsAllLinkQ(options) then
    setSequentialTileDefaults(options)
    saveTileSlotsToStorage(options)
  end
  _touchUi.open = false
  _touchUi.tile = nil
  _touchUi.lastTap = 0
  _touchUi.isDown = false
  _touchUi.downKind = nil
  _touchUi.downIndex = nil
  _touchUi.downX = nil
  _touchUi.downY = nil
  _touchUi.downMoved = false
  _touchUi.scrollStart = 0
  _touchUi.menuScroll = 0
  return { zone = zone, options = options }
end
local function update(widget, options)
  widget.options = options

  -- Some radios provide all-zero tile options after reboot; if we detect that
  -- shape, restore persisted tiles/mode before syncing back into runtime state.
  if optionsAllLinkQ(options) then
    local loaded = loadTileSlotsFromStorage(options)
    if not loaded then
      setSequentialTileDefaults(options)
    end
  end

  initColors(options and options.Theme)
  syncTileSlotsFromOptions(options)
  saveTileSlotsToStorage(options)
end
local function background(widget)      tickArmTimer(widget.options) end

local function refresh(widget, event, touchState)
  initColors(widget.options and widget.options.Theme)
  if #_tileSlots ~= #METRICS then
    syncTileSlotsFromOptions(widget.options)
  end
  handleTouch(widget, touchState)
  tickArmTimer(widget.options)
  lcd.drawFilledRectangle(0, 0, 800, 480, C_BG)
  drawPit()
  drawGrid(widget.options)
  drawMetricMenu()
  drawCarbonFrame()
  drawHeader(widget.options)
end

return {
  name       = "BF Telemetry",
  options    = OPTIONS,
  create     = create,
  update     = update,
  background = background,
  refresh    = refresh,
}
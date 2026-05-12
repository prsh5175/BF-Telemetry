-- BF Telemetry Widget (Square Tiles theme)
-- EdgeTX 2.12+, Lua 5.3, TX16S MK III 800x480.
-- This is the square-grid alternative to the default hex main.lua.

local OPTIONS = {
  { "Cells",   VALUE,  4,  1,  8 },
  { "FullV",   VALUE, 42, 30, 50 },
  { "WarnV",   VALUE, 36, 30, 42 },
  { "CritV",   VALUE, 34, 30, 42 },
  { "LQWrn",   VALUE, 70, 10, 99 },
  { "Mode",    VALUE,  0,  0,  2 },
  { "ThrOn",   VALUE,  5,  0, 50 },
  { "ArmSrc", SOURCE,  0 },
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

local function initColors()
  if _colorsReady then return end
  C_BG      = lcd.RGB(  0,   0,   0)  -- pitch black
  C_TILE    = lcd.RGB(  8,  10,  20)  -- very dark tile
  C_CF1     = lcd.RGB(  0,   0,   0)  -- frame body: pure black
  C_CF2     = lcd.RGB( 10,  14,  30)  -- subtle stripe
  C_CF3     = lcd.RGB( 18,  24,  50)
  C_PIT     = lcd.RGB(  0,   0,   0)  -- pit: pure black
  C_SIL_HI  = lcd.RGB(  0, 180, 255)  -- bright electric blue
  C_SIL_MID = lcd.RGB(  0,  90, 180)
  C_SIL_LO  = lcd.RGB(  0,  40,  90)
  C_SIL_DK  = lcd.RGB(  0,  15,  45)
  C_CYAN     = lcd.RGB(  0, 255, 255)  -- pure cyan
  C_CYAN_DIM = lcd.RGB(  0,  60,  80)
  C_SHADOW   = lcd.RGB(  0,   0,   0)
  C_HILIGHT  = lcd.RGB( 20,  50, 130)
  C_ORANGE  = lcd.RGB(255, 140,   0)  -- bright orange
  C_WHITE   = lcd.RGB(255, 255, 255)  -- pure white
  C_DIM     = lcd.RGB(100, 130, 180)  -- visible but dim
  C_GREEN   = lcd.RGB(  0, 255, 100)  -- neon green
  C_YELLOW  = lcd.RGB(255, 230,   0)  -- bright yellow
  C_RED     = lcd.RGB(255,  40,  60)  -- neon red
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
local FRM_L    = 44
local FRM_R    = 44
local FRM_B    = 22
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

local _COLS = 4
local _ROWS = 3
local _GAP  = 4

local TW = math.floor((GW - _GAP * (_COLS + 1)) / _COLS)
local TH = math.floor((GH - _GAP * (_ROWS + 1)) / _ROWS)

local TY_LBL  = 7
local TY_VAL  = 24
local TY_UNIT = 62
local TY_SUB  = 76

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
  -- drop shadow
  lcd.drawFilledRectangle(tx+4, ty+4, tw, th, C_SHADOW)
  -- fill
  lcd.drawFilledRectangle(tx, ty, tw, th, C_TILE)
  -- outer bevel
  lcd.drawFilledRectangle(tx,      ty, tw,  1, C_SIL_HI)
  lcd.drawFilledRectangle(tx,      ty,  1, th, C_SIL_HI)
  lcd.drawFilledRectangle(tx, ty+th-1, tw,  1, C_SIL_DK)
  lcd.drawFilledRectangle(tx+tw-1, ty,  1, th, C_SIL_DK)
  -- inner bevel
  lcd.drawFilledRectangle(tx+1,    ty+1, tw-2,  1, C_SIL_MID)
  lcd.drawFilledRectangle(tx+1,    ty+1,  1, th-2, C_SIL_MID)
  lcd.drawFilledRectangle(tx+1, ty+th-2, tw-2,  1, C_SIL_LO)
  lcd.drawFilledRectangle(tx+tw-2, ty+1,  1, th-2, C_SIL_LO)
  -- cyan top accent bar
  lcd.drawFilledRectangle(tx+2, ty, tw-4, 3, C_CYAN)
  -- cyan top-right L
  lcd.drawFilledRectangle(tx+tw-8, ty+1,  6, 1, C_CYAN)
  lcd.drawFilledRectangle(tx+tw-2, ty+1,  1, 6, C_CYAN)
  -- cyan bottom-left L
  lcd.drawFilledRectangle(tx+1, ty+th-2,  6, 1, C_CYAN)
  lcd.drawFilledRectangle(tx+1, ty+th-7,  1, 6, C_CYAN)
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

-- =========================================================================
--  BAR MODE
-- =========================================================================
local function drawBar(tx, ty, tw, th, pct, col)
  local bx = tx
  local by = ty
  local bw = tw
  local bh = th
  if bw < 8 or bh < 10 then return end
  lcd.drawFilledRectangle(bx, by, bw, bh, C_SIL_DK)
  local fw = math.floor(bw * math.max(0, math.min(1, (pct or 0)/100)))
  if fw > 0 then
    lcd.drawFilledRectangle(bx, by, fw, bh, col or C_GREEN)
    lcd.drawFilledRectangle(bx+fw-2, by, 2, bh, C_SIL_HI)
  end
  lcd.drawRectangle(bx, by, bw, bh, C_SIL_MID)
end

-- =========================================================================
--  ARC GAUGE MODE (Optimized for Performance)
-- =========================================================================
local _PI = 3.14159265

-- Cache system
local _gaugeCache = {}
local _gaugeBgCache = {}

local function drawArcSeg(cx, cy, r, a1, a2, col, steps)
  steps = steps or 12
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

-- Faster needle: triangle instead of 3 rectangles
local function drawNeedleTriangle(cx, cy, r, angleRad, col)
  local nx = cx + math.floor((r - 1) * math.cos(angleRad) + 0.5)
  local ny = cy + math.floor((r - 1) * math.sin(angleRad) + 0.5)
  
  -- Perpendicular direction for needle width
  local perpAngle = angleRad + _PI / 2
  local w = 3
  local wx = math.floor(w * math.cos(perpAngle))
  local wy = math.floor(w * math.sin(perpAngle))
  
  -- Draw needle lines
  lcd.drawLine(nx, ny, cx + wx, cy + wy, 0xFF, col)
  lcd.drawLine(nx, ny, cx - wx, cy - wy, 0xFF, col)
  lcd.drawLine(cx + wx, cy + wy, cx - wx, cy - wy, 0xFF, col)
  
  -- Center dot
  lcd.drawFilledRectangle(cx-2, cy-2, 5, 5, C_SIL_HI)
  lcd.drawFilledRectangle(cx-1, cy-1, 3, 3, C_WHITE)
end

local function drawGauge(tx, ty, tw, th, pct, col, val_str, unit_str)
  local cx = math.floor(tx + tw / 2)
  local cy = ty + th - 14
  local r  = math.floor(math.min(tw * 0.38, (th - 26) * 0.76))
  local aS = 210 * _PI / 180
  local aE = (210 - 300) * _PI / 180
  
  -- Create cache key based on gauge geometry
  local cacheKey = string.format("%.0f_%.0f_%.0f", cx, cy, r)
  
  -- Draw background arc ONCE and cache it
  if not _gaugeBgCache[cacheKey] then
    drawArcSeg(cx, cy, r, aS, aE, C_SIL_LO)
    drawArcSeg(cx, cy, r - 3, aS, aE, C_SIL_DK)
    _gaugeBgCache[cacheKey] = true
  end
  
  -- Only redraw needle if percentage changed by >1%
  local lastPct = _gaugeCache[cacheKey] or -999
  local pctFloor = math.floor((pct or 0) + 0.5)
  local lastPctFloor = math.floor(lastPct + 0.5)
  
  if math.abs(pctFloor - lastPctFloor) > 1 then
    if pct and pct > 0 then
      local aV = aS - (aS - aE) * math.min(pct, 100) / 100
      drawArcSeg(cx, cy, r, aS, aV, col or C_GREEN)
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

local TILES = {
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

-- =========================================================================
--  SIDE BATTERY BARS
-- =========================================================================
local function cBattPct(p)
  if p == nil then return C_DIM end
  if p >= 60 then return C_GREEN end
  if p >= 30 then return C_YELLOW end
  return C_RED
end

local function pctFromTxVoltage(v)
  if type(v) ~= "number" or v <= 0 then return nil end
  return math.max(0, math.min(100, (v - 6.4) / (8.4 - 6.4) * 100))
end

local function pctFromRxCellVoltage(volt, cells)
  if type(volt) ~= "number" or volt <= 0 then return nil end
  local nc = (type(cells) == "number" and cells > 0) and cells or 4
  local cV = volt / nc
  return math.max(0, math.min(100, (cV - 3.3) / (4.2 - 3.3) * 100))
end

local function drawSideBar(x, y, w, h, pct, label)
  local labelTop  = y + 2
  local barTop    = y + 40
  local pctY      = y + h - 10
  local barBottom = pctY - 4
  local textCx    = x + math.floor(w / 2)

  local labelStr = tostring(label or "")
  local line1, line2 = string.match(labelStr, "^(%S+)%s+(%S+)$")
  if line1 then
    lcd.drawText(textCx, labelTop,      line1, SMLSIZE + CENTER + C_SIL_HI)
    lcd.drawText(textCx, labelTop + 12, line2, SMLSIZE + CENTER + C_SIL_HI)
  else
    lcd.drawText(textCx, labelTop + 6,  labelStr, SMLSIZE + CENTER + C_SIL_HI)
    barTop = y + 36
  end

  local barH = barBottom - barTop
  if barH < 30 then return end

  local segCount = 10
  local gap      = 2
  local segH     = math.floor((barH - gap * (segCount - 1)) / segCount)
  if segH < 3 then segH = 3 end
  local lit = pct and math.floor((pct / 100) * segCount + 0.5) or 0
  lit = math.max(0, math.min(segCount, lit))

  lcd.drawRectangle(x - 2, barTop - 2, w + 4, barH + 4, C_SIL_LO)

  for i = 1, segCount do
    local idxFromBottom = segCount - i + 1
    local sy  = barTop + (i - 1) * (segH + gap)
    local on  = idxFromBottom <= lit
    local col = on and cBattPct((idxFromBottom / segCount) * 100) or C_SIL_DK
    lcd.drawFilledRectangle(x, sy, w, segH, col)
    lcd.drawRectangle(x, sy, w, segH, C_CF1)
  end

  local ptxt = pct and string.format("%d%%", math.floor(pct + 0.5)) or "---"
  lcd.drawText(textCx, pctY, ptxt, SMLSIZE + CENTER + (pct and cBattPct(pct) or C_DIM))
end

local function drawSideBatteryBars(o)
  local railW = FRM_L
  if railW < 12 then return end

  local y = TOP_MID + 16
  local h = 480 - TOP_MID - FRM_B - 34
  if h < 80 then return end

  local txv   = getValue("tx-voltage")
  local txPct = pctFromTxVoltage(txv)

  local rxv   = getS(SN_VOLT)
  local rxPct = pctFromRxCellVoltage(rxv, o and o.Cells)

  drawSideBar(0,           y, railW, h, rxPct, "RX batt")
  drawSideBar(800 - FRM_R, y, railW, h, txPct, "TX batt")
end


local function renderTile(tx, ty, tw, th, lbl_str, d, mode)
  drawTile(tx, ty, tw, th)
  lbl(tx+6, ty+TY_LBL, lbl_str)
  if mode == 1 then
    local pad = 8
    local valY = ty + TY_LBL + 14
    local unitY = ty + math.floor(th * 0.72)
    local barH = 10
      local barTop = ty + math.floor(th * 0.53)
    local maxBarTop = unitY - 8 - barH
    if barTop > maxBarTop then barTop = maxBarTop end
    if barTop < valY + 10 then barTop = valY + 10 end
    drawBar(tx + pad, barTop, tw - 2 * pad, barH, d.pct, d.col)
    sub(tx+6, valY, d.val, d.col)
    if d.unit and d.unit ~= "" then
      sub(tx+6, unitY, d.unit, C_DIM)
    end
  elseif mode == 2 then
    drawGauge(tx, ty, tw, th, d.pct, d.col, d.val, d.unit)
  else
    val(tx+6,  ty+TY_VAL,  d.val, d.col)
    sub(tx+6,  ty+TY_UNIT, d.unit)
    if d.sub then sub(tx+6, ty+TY_SUB, d.sub) end
  end
end

-- =========================================================================
--  HEADER  (drawn inside the carbon top bar center bulge)
-- =========================================================================
local function drawHeader(o)
  local mname = "CRAFT"
  local info = model.getInfo()
  if info and info.name and info.name ~= "" then mname = info.name end
  -- model name (safe x=80 avoids EdgeTX logo, y=12 centers in 82px bar)
  lcd.drawText(80, 12, mname, MIDSIZE+BOLD+C_CYAN)
  -- vertical separator
  lcd.drawFilledRectangle(262, 8, 2, 58, C_SIL_LO)
  -- flight mode
  local fmDisp = "MODE"
  if hasActiveTelemetry() then
    fmDisp = (_fmStr ~= "") and _fmStr or "MODE"
  end
  local fmCol  = _lastArmed and C_ORANGE or C_DIM
  lcd.drawText(272, 12, fmDisp, MIDSIZE+BOLD+fmCol)
  -- armed/disarmed indicator (replaces timer - timer is in FLIGHT TIMER tile)
  lcd.drawFilledRectangle(462, 8, 2, 58, C_SIL_LO)
  if _lastArmed then
    lcd.drawText(474, 12, "ARMED",    MIDSIZE+BOLD+C_RED)
  else
    lcd.drawText(474, 12, "DISARMED", MIDSIZE+BOLD+C_GREEN)
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
  for i, t in ipairs(TILES) do
    local c  = (i-1) % _COLS
    local r  = math.floor((i-1) / _COLS)
    local tx = GX + _GAP + c * (TW + _GAP)
    local ty = GY + _GAP + r * (TH + _GAP)
    renderTile(tx, ty, TW, TH, t[1], t[2](opts), mode)
  end
end

-- =========================================================================
--  LIFECYCLE
-- =========================================================================
local function create(zone, options)
  initColors()
  _sid = {}
  _armStart = nil
  _lastArmed = false
  _lastThrUp = false
  return { zone = zone, options = options }
end
local function update(widget, options) widget.options = options end
local function background(widget)      tickArmTimer(widget.options) end

local function refresh(widget, event, touchState)
  initColors()
  tickArmTimer(widget.options)
  lcd.drawFilledRectangle(0, 0, 800, 480, C_BG)
  drawPit()
  drawGrid(widget.options)
  drawCarbonFrame()
  drawSideBatteryBars(widget.options)
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
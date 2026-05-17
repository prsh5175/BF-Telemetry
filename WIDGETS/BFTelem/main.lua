-- BF Telemetry Widget (default Hex Honeycomb theme)
-- EdgeTX 2.12+, Lua 5.3, TX16S MK III 800x480.
-- Current UI details: flat hex borders (no bevel split), side battery rails,
-- and a time-of-day clock in the top-right pit gap.

local OPTIONS = {
  { "WarnV",      VALUE,  36,  30,   42 },
  { "LQWrn",      VALUE,  70,  10,   99 },
  { "Theme",      VALUE,   0,   0,    3 },  -- 0=Yellow  1=Cyan  2=Green  3=Orange
  { "ScreenType", VALUE,   0,   0,    2 },  -- 0=NUM  1=BAR  2=GAUGE
  { "FullV",      VALUE,  42,  30,   50 },
  { "CritV",      VALUE,  34,  30,   42 },
  { "SndEn",      VALUE,   1,   0,    1 },
  { "SndArmd",    VALUE,   0,   0,    1 },
  { "SndBatt",    VALUE,   1,   0,    1 },
  { "SndRSSI",    VALUE,   1,   0,    1 },
  { "RSSIWrn",    VALUE,  90,  60,  120 },
  { "SndRpt",     VALUE,  15,   5,  120 },
  { "SndLQ",      VALUE,   1,   0,    1 },
  { "SndDist",    VALUE,   1,   0,    1 },
  { "SndAlt",     VALUE,   1,   0,    1 },
  { "AltMax",     VALUE, 122,  10,  500 },
  { "ThrOn",      VALUE,   5,   0,   50 },
  { "TmrRed",     VALUE, 180,  30,  900 },
  { "DistRed",    VALUE, 100,  20, 2000 },
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
local SN_SATS  = "Sats"

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

local function armTimerSec()
  if _armStart == nil then return 0 end
  return math.floor((getTime() - _armStart) / 100)
end

local function armTimerStr()
  if _armStart == nil then return "--:--" end
  local sec = math.floor((getTime() - _armStart) / 100)
  return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

-- =========================================================================
--  AUDIO ALERTS
-- =========================================================================
local _soundPaths = {
  "/WIDGETS/BFTelem/sounds/",
  "/SOUNDS/en/",
}

local _telemetryPrev = false     -- Track previous telemetry state for system sound
local _nogpsOverlayUntil = 0     -- getTime() deadline while NO GPS banner is visible
local _screenTypeBannerUntil = 0 -- getTime() deadline while screen-type toast is visible

local _alerts = {
  lastRun = 0,
  armedPrev = false,
  battLevel = 0,   -- 0=normal, 1=warn, 2=critical
  rssiLow = false,
  lqLow = false,
  failsafe = false,
  distHigh = false,
  altHigh = false,
  armSwitchPrev = false,
  nextBatt = 0,
  nextRssi = 0,
  nextLq = 0,
  nextDist = 0,
  nextAlt = 0,
  nextNogps = 0,
}

-- Map alert types to existing EdgeTX system voice files.
-- Falls back to custom widget sounds if these don't exist.
local _alertVoices = {
  armed    = { custom = "armed",    system = "armed" },
  disarmed = { custom = "disarmed", system = "disarmed" },
  batlow   = { custom = "batlow",   system = "bat1" },
  batcrit  = { custom = "batcrit",  system = "bat0" },
  lowrssi  = { custom = "lowrssi",  system = "rssiloss" },
  lqlow    = { custom = "lqlow",    system = "siglow" },
  failsafe = { custom = "failsafe", system = "fsact" },
  distlmt  = { custom = "distlmt",  system = "warnng" },
  altmax   = { custom = "altmax",   system = "tohigh" },
  nogpsfix = { custom = "nogpsfix", system = nil },
}

local function playNamedSound(name)
  if type(name) ~= "string" or name == "" then return false end
  if not playFile then return false end
  for i = 1, #_soundPaths do
    local ok = pcall(playFile, _soundPaths[i] .. name .. ".wav")
    if ok then return true end
  end
  return false
end

local function playAlertVoice(alertType)
  if not _alertVoices[alertType] then return false end
  
  local voices = _alertVoices[alertType]
  
  -- First try custom widget-local sounds
  if playNamedSound(voices.custom) then return true end
  
  -- Then try EdgeTX system voice files
  if playNamedSound(voices.system) then return true end
  
  return false
end

local function fallbackBeep(freq)
  if type(playTone) ~= "function" then return end
  -- Keep fallback simple and synchronous so missing WAVs still produce an alert.
  pcall(playTone, freq or 1800, 120, 0)
end

local function playSystemSound(path)
  if type(playFile) == "function" then
    pcall(playFile, path)
  end
end

local function playAlert(alertType, fallbackFreq)
  if not playAlertVoice(alertType) then
    fallbackBeep(fallbackFreq)
  end
end

local function resetAlertState()
  _alerts.battLevel = 0
  _alerts.rssiLow   = false
  _alerts.lqLow     = false
  _alerts.failsafe  = false
  _alerts.distHigh  = false
  _alerts.altHigh   = false
  _alerts.nextBatt  = 0
  _alerts.nextRssi  = 0
  _alerts.nextLq    = 0
  _alerts.nextDist  = 0
  _alerts.nextAlt   = 0
  _alerts.nextNogps = 0
end

local function playNogpsFixBuzzer()
  -- No system voice exists for this; play a descending triple beep
  -- and also try the custom WAV in case the user has provided one.
  if not playAlertVoice("nogpsfix") then
    if type(playTone) == "function" then
      pcall(playTone, 1800, 80, 0)
      pcall(playTone, 1400, 80, 0)
      pcall(playTone, 1000, 120, 0)
    end
  end
  -- Show the NO GPS overlay for 1 second (100 ticks = 1s)
  _nogpsOverlayUntil = (getTime() or 0) + 100
end

local function getCellVoltage(opts)
  local pack = getS(SN_VOLT)
  if type(pack) ~= "number" then return nil end
  -- Auto-detect cell count from pack voltage using FullV per-cell reference
  local fullV = math.max(3.0, math.min(5.0, (tonumber(opts and opts.FullV) or 42) / 10.0))
  local cells = math.max(1, math.min(8, math.ceil((pack / fullV) - 0.0001)))
  return pack / cells
end

local function getWorstRssiDbm()
  local v1 = getS(SN_RSSI1)
  local v2 = getS(SN_RSSI2)
  if type(v1) ~= "number" then v1 = nil end
  if type(v2) ~= "number" then v2 = nil end
  if not v1 and not v2 then return nil end
  if not v1 then return v2 end
  if not v2 then return v1 end
  return math.min(v1, v2)
end

local function repeatCs(opts)
  local sec = math.max(5, math.floor(tonumber(opts and opts.SndRpt) or 15))
  return sec * 100
end

local function resolveBattLevel(cellV, warnV, critV, prev)
  local hys = 0.05
  if type(cellV) ~= "number" then return 0 end

  if prev == 2 then
    if cellV <= (critV + hys) then return 2 end
    if cellV <= warnV then return 1 end
    return 0
  end

  if prev == 1 then
    if cellV <= critV then return 2 end
    if cellV <= (warnV + hys) then return 1 end
    return 0
  end

  if cellV <= critV then return 2 end
  if cellV <= warnV then return 1 end
  return 0
end

local function resolveRssiLow(rssiDbm, thresholdAbs, prev)
  local hys = 3
  if type(rssiDbm) ~= "number" then return false end
  local absDbm = math.abs(rssiDbm)
  if prev then
    return absDbm >= (thresholdAbs - hys)
  end
  return absDbm >= thresholdAbs
end

local function tickAlerts(opts)
  local now = getTime() or 0
  if (now - (_alerts.lastRun or 0)) < 10 then
    return
  end
  _alerts.lastRun = now

  -- Play EdgeTX system 'Telemetry Connected' sound on rising edge
  local telemetryNow = hasActiveTelemetry()
  if telemetryNow and not _telemetryPrev then
    playSystemSound("/SOUNDS/en/telemetry.wav")
  end
  _telemetryPrev = telemetryNow

  if (opts and opts.SndEn or 0) == 0 then
    _alerts.armedPrev = _lastArmed
    resetAlertState()
    return
  end

  if not telemetryNow then
    _alerts.armedPrev = false
    resetAlertState()
    return
  end

  -- Arm-switch-high but GPS not fixed: alert on rising edge of arm switch
  do
    local switchHigh = sourceIsArmed(opts and opts.ArmSrc)
    local risingEdge = switchHigh and not _alerts.armSwitchPrev
    if risingEdge and not _lastArmed then
      local sats = getS(SN_SATS)
      local noFix = (type(sats) ~= "number") or (sats < 6)
      if noFix then
        local due = now >= (_alerts.nextNogps or 0)
        if due then
          playNogpsFixBuzzer()
          _alerts.nextNogps = now + 300  -- 3s cooldown between retries
        end
      end
    end
    _alerts.armSwitchPrev = switchHigh
  end

  if (opts and opts.SndArmd or 0) == 1 then
    if _lastArmed and not _alerts.armedPrev then
      playSystemSound("/SOUNDS/en/armed.wav")
    elseif (not _lastArmed) and _alerts.armedPrev then
      playAlert("disarmed", 1200)
    end
  end
  _alerts.armedPrev = _lastArmed

  if not _lastArmed then
    resetAlertState()
    return
  end

  if (opts and opts.SndBatt or 0) == 1 then
    local cellV = getCellVoltage(opts)
    local warnV = (tonumber(opts and opts.WarnV) or 36) / 10.0
    local critV = (tonumber(opts and opts.CritV) or 34) / 10.0
    local newLevel = resolveBattLevel(cellV, warnV, critV, _alerts.battLevel)
    local changed = (newLevel ~= _alerts.battLevel)

    if newLevel > 0 then
      local due = now >= (_alerts.nextBatt or 0)
      if changed or due then
        if newLevel >= 2 then
          playAlert("batcrit", 900)
        else
          playAlert("batlow", 1300)
        end
        _alerts.nextBatt = now + repeatCs(opts)
      end
    end
    _alerts.battLevel = newLevel
  else
    _alerts.battLevel = 0
    _alerts.nextBatt = 0
  end

  if (opts and opts.SndRSSI or 0) == 1 then
    local rssi = getWorstRssiDbm()
    local thr = math.max(60, math.floor(tonumber(opts and opts.RSSIWrn) or 90))
    local newLow = resolveRssiLow(rssi, thr, _alerts.rssiLow)
    local changed = (newLow ~= _alerts.rssiLow)

    if newLow then
      local due = now >= (_alerts.nextRssi or 0)
      if changed or due then
        playAlert("lowrssi", 1600)
        _alerts.nextRssi = now + repeatCs(opts)
      end
    end

    _alerts.rssiLow = newLow
  else
    _alerts.rssiLow = false
    _alerts.nextRssi = 0
  end

  -- Low Link Quality alert (reuses LQWrn display threshold)
  if (opts and opts.SndLQ or 0) == 1 then
    local lq = getS(SN_LQ)
    local thr = math.max(10, math.floor(tonumber(opts and opts.LQWrn) or 70))
    local newLow = type(lq) == "number" and lq < thr
    local changed = (newLow ~= _alerts.lqLow)
    if newLow then
      local due = now >= (_alerts.nextLq or 0)
      if changed or due then
        playAlert("lqlow", 1700)
        _alerts.nextLq = now + repeatCs(opts)
      end
    end
    _alerts.lqLow = newLow
  else
    _alerts.lqLow = false
    _alerts.nextLq = 0
  end

  -- Failsafe: edge-triggered from Betaflight FM string (no repeat suppression)
  local fsNow = type(_fmStr) == "string" and
                string.find(string.upper(_fmStr), "FAIL") ~= nil
  if fsNow and not _alerts.failsafe then
    playAlert("failsafe", 600)  -- deep urgent tone
  end
  _alerts.failsafe = fsNow

  -- Distance limit alert (reuses DistRed display threshold)
  if (opts and opts.SndDist or 0) == 1 then
    local dist = getS(SN_DIST)
    local thr = math.max(20, math.floor(tonumber(opts and opts.DistRed) or 100))
    local newHigh = type(dist) == "number" and dist >= thr
    local changed = (newHigh ~= _alerts.distHigh)
    if newHigh then
      local due = now >= (_alerts.nextDist or 0)
      if changed or due then
        playAlert("distlmt", 1500)
        _alerts.nextDist = now + repeatCs(opts)
      end
    end
    _alerts.distHigh = newHigh
  else
    _alerts.distHigh = false
    _alerts.nextDist = 0
  end

  -- Altitude warning (default 122m ≈ 400ft, configurable via AltMax in metres)
  if (opts and opts.SndAlt or 0) == 1 then
    local alt = getS(SN_ALT)
    local thr = math.max(10, math.floor(tonumber(opts and opts.AltMax) or 122))
    local newHigh = type(alt) == "number" and alt >= thr
    local changed = (newHigh ~= _alerts.altHigh)
    if newHigh then
      local due = now >= (_alerts.nextAlt or 0)
      if changed or due then
        playAlert("altmax", 1400)
        _alerts.nextAlt = now + repeatCs(opts)
      end
    end
    _alerts.altHigh = newHigh
  else
    _alerts.altHigh = false
    _alerts.nextAlt = 0
  end
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
local function cPctInv(p)
  if p == nil then return C_DIM end
  if p >= 70 then return C_RED end
  if p >= 40 then return C_YELLOW end
  return C_GREEN
end
local function cVolt(cV, wV, kV)
  if cV == nil then return C_DIM end
  if cV > (wV or 3.6) then return C_GREEN end
  if cV > (kV or 3.4) then return C_YELLOW end
  return C_RED
end

local function cBattPct(p)
  if p == nil then return C_DIM end
  if p > 50 then return C_GREEN end
  if p > 25 then return C_YELLOW end
  return C_RED
end

-- =========================================================================
--  LAYOUT CONSTANTS (Responsive)
--  Set by initLayoutConstants() based on screen size:
--  - 800x480: TX16S MK III (6 cols x 2 rows honeycomb)
--  - 480x272: TX16S MK II / Jumper T16 (4 cols x 2 rows honeycomb)
-- =========================================================================
-- All layout constants are now globals set by initLayoutConstants():
-- FRM_L, FRM_R, FRM_B, TOP_EDGE, TOP_MID, RAMP_W, PEAK_X1, PEAK_X2,
-- RAMP_X1, RAMP_X2, GX, GY, GW, GH,
-- HX_COLS, HX_ROWS, HX_GAP, HEX_W, HEX_H,
-- HX_STEP_X, HX_STEP_Y, HX_TOTAL_W, HX_TOTAL_H, HX_ORG_X, HX_ORG_Y,
-- MENU_W, MENU_X, MENU_ROW_H, MENU_TITLE_H, MENU_PAD, MENU_MAX_ROWS, MENU_SCROLL_THRESHOLD

-- Module-level screen state (populated by initLayoutConstants / detectDeviceType)
local _screenW    = 800
local _screenH    = 480
local _is480x272  = false
local _deviceType = "TX16S_MK3"

-- Cache the last initialised screen size to avoid redundant work on every refresh.
local _layoutInitW = 0
local _layoutInitH = 0

-- Set all layout constant globals based on the actual screen dimensions.
-- Accepts an optional zone table (from widget.zone) as the most reliable size source.
-- Safe to call on every refresh; skips work when the size has not changed.
local function initLayoutConstants(zone)
  local w, h
  -- zone.w/h is the most reliable source in a widget context
  if zone and type(zone.w) == "number" and zone.w > 0 then
    w = zone.w
    h = zone.h or _screenH
  else
    w = (lcd.getW and lcd.getW()) or _screenW
    h = (lcd.getH and lcd.getH()) or _screenH
  end
  if w == _layoutInitW and h == _layoutInitH then return end
  _layoutInitW = w
  _layoutInitH = h
  _screenW    = w
  _screenH    = h
  _is480x272  = (w <= 480)

  if _is480x272 then
    -- 480x272: TX16S MK II / Jumper T16 (6 cols x 2 rows honeycomb, same as MK3)
    FRM_L        = 20
    FRM_R        = 20
    FRM_B        = 10
    TOP_EDGE     = 14
    TOP_MID      = 48
    RAMP_W       = 48
    PEAK_X1      = 120
    PEAK_X2      = 360
    HX_COLS      = 6
    MENU_W       = 320
    MENU_ROW_H   = 26
    MENU_TITLE_H = 20
  else
    -- 800x480: TX16S MK III (6 cols x 2 rows honeycomb)
    FRM_L        = 30
    FRM_R        = 30
    FRM_B        = 14
    TOP_EDGE     = 22
    TOP_MID      = 82
    RAMP_W       = 80
    PEAK_X1      = 200
    PEAK_X2      = 600
    HX_COLS      = 6
    MENU_W       = 460
    MENU_ROW_H   = 38
    MENU_TITLE_H = 28
  end

  RAMP_X1 = PEAK_X1 - RAMP_W
  RAMP_X2 = PEAK_X2 + RAMP_W
  HX_ROWS = 2
  HX_GAP  = 2

  GX = FRM_L
  GY = TOP_MID + 2
  GW = _screenW - FRM_L - FRM_R
  GH = _screenH - TOP_MID - FRM_B

  -- Fit hexagon tiles into the available pit area
  HEX_W = math.floor((GW - HX_GAP * 2) / (0.25 + 0.75 * HX_COLS))
  HEX_H = math.floor(HEX_W * 1.00)
  local maxHexH = math.floor((GH - HX_GAP * 2) / (HX_ROWS + 0.5))
  if HEX_H > maxHexH then
    HEX_H = maxHexH
    HEX_W = math.floor(HEX_H / 1.00)
  end

  HX_STEP_X  = math.floor(HEX_W * 0.75)
  HX_STEP_Y  = HEX_H
  HX_TOTAL_W = HX_STEP_X * (HX_COLS - 1) + HEX_W
  HX_TOTAL_H = HEX_H * HX_ROWS + math.floor(HEX_H / 2)
  HX_ORG_X   = GX + math.floor((GW - HX_TOTAL_W) / 2)
  HX_ORG_Y   = GY + math.floor((GH - HX_TOTAL_H) / 2)

  MENU_X                = math.floor((_screenW - MENU_W) / 2)
  MENU_PAD              = 8
  MENU_MAX_ROWS         = 8
  MENU_SCROLL_THRESHOLD = 10
end

-- Detect the specific radio model to select appropriate input handling.
-- Accepts an optional zone table (from widget.zone) as the most reliable size source.
-- Returns "TX16S_MK3", "TX16S_MK2", or "T16".
local function detectDeviceType(options, zone)
  local w, h
  if zone and type(zone.w) == "number" and zone.w > 0 then
    w = zone.w
    h = zone.h or _screenH
  else
    w = (lcd.getW and lcd.getW()) or _screenW
    h = (lcd.getH and lcd.getH()) or _screenH
  end
  _screenW   = w
  _screenH   = h
  _is480x272 = (w <= 480)

  if not _is480x272 then
    return "TX16S_MK3"
  end

  -- Distinguish TX16S MK II (has touchscreen) from Jumper T16 (no touchscreen)
  -- by checking the radio model name reported by EdgeTX.
  if radio and radio.getInfo then
    local ok, info = pcall(radio.getInfo)
    if ok and type(info) == "table" and type(info.name) == "string" then
      local name = string.upper(info.name)
      if string.find(name, "TX16") or string.find(name, "RADIOMASTER") then
        return "TX16S_MK2"
      end
    end
  end

  -- Default for 480x272 without confirmed TX16S: Jumper T16 (scroll wheel only)
  return "T16"
end

local _tileSlots = {}
local _touchUi = {
  open = false,
  tile = nil,
  lastTap = 0,
  ignoreDismissUntil = 0,
  isDown = false,
  downKind = nil,
  downIndex = nil,
  downX = nil,
  downY = nil,
  downMoved = false,
  scrollStart = 0,
  menuScroll = 0,
}
local _scrollWheelUi = {
  focusedTile = 1,       -- currently focused tile (1-based)
  lastRotaryEvent = 0,   -- debounce timer
  debounceMs = 50,       -- debounce interval in milliseconds (100 ticks = 1 second)
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
  local cfD  = C_CF1   -- solid dark carbon fill color
  local sw   = _screenW
  local sh   = _screenH

  -- ---- Flat frame panels ----
  lcd.drawFilledRectangle(0, 0, sw, TOP_MID, cfD)
  lcd.drawFilledRectangle(0, TOP_MID, FRM_L, sh - TOP_MID - FRM_B, cfD)
  lcd.drawFilledRectangle(sw - FRM_R, TOP_MID, FRM_R, sh - TOP_MID - FRM_B, cfD)
  lcd.drawFilledRectangle(0, sh - FRM_B, sw, FRM_B, cfD)

  -- ---- Inner edge bevel (bottom edge of flat top bar) ----
  lcd.drawFilledRectangle(0, TOP_MID,   sw, 1, C_SIL_HI)
  lcd.drawFilledRectangle(0, TOP_MID+1, sw, 1, C_SIL_MID)

  -- cyan accent line across full bottom of top bar
  lcd.drawFilledRectangle(0, TOP_MID + 2, sw, 2, C_CYAN)

  -- left/right frame inner edge bevels
  lcd.drawFilledRectangle(FRM_L,      GY, 1, GH, C_SIL_HI)
  lcd.drawFilledRectangle(FRM_L+1,    GY, 1, GH, C_SIL_MID)
  lcd.drawFilledRectangle(sw-FRM_R-2, GY, 1, GH, C_SIL_MID)
  lcd.drawFilledRectangle(sw-FRM_R-1, GY, 1, GH, C_SIL_HI)

  -- bottom frame top edge bevel
  lcd.drawFilledRectangle(GX, sh-FRM_B-2, GW, 1, C_SIL_MID)
  lcd.drawFilledRectangle(GX, sh-FRM_B-1, GW, 1, C_SIL_HI)

  -- outer silver border
  lcd.drawFilledRectangle(0,    0,  sw,   1, C_SIL_MID)
  lcd.drawFilledRectangle(0,    0,   1,  sh, C_SIL_MID)
  lcd.drawFilledRectangle(sw-1, 0,   1,  sh, C_SIL_MID)
  lcd.drawFilledRectangle(0,  sh-1, sw,   1, C_SIL_MID)

  -- cyan corner L-brackets
  lcd.drawFilledRectangle(     0,     0, 18,  2, C_CYAN)
  lcd.drawFilledRectangle(     0,     0,  2, 18, C_CYAN)
  lcd.drawFilledRectangle(sw-18,     0, 18,  2, C_CYAN)
  lcd.drawFilledRectangle(sw- 2,     0,  2, 18, C_CYAN)
  lcd.drawFilledRectangle(     0, sh-18, 18,  2, C_CYAN)
  lcd.drawFilledRectangle(     0, sh-18,  2, 18, C_CYAN)
  lcd.drawFilledRectangle(sw-18, sh-18, 18,  2, C_CYAN)
  lcd.drawFilledRectangle(sw- 2, sh-18,  2, 18, C_CYAN)
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

  -- Hex outline (6 edges): flat style (no top/bottom shading split).
  local edgeCol = C_SIL_HI
  lcd.drawLine(xLT, y1,  xRT, y1,  0xFF, edgeCol)  -- top
  lcd.drawLine(xRT, y1,  xR,  yM,  0xFF, edgeCol)  -- right-top
  lcd.drawLine(xR,  yM,  xRT, y4,  0xFF, edgeCol)  -- right-bottom
  lcd.drawLine(xRT, y4,  xLT, y4,  0xFF, edgeCol)  -- bottom
  lcd.drawLine(xLT, y4,  xL,  yM,  0xFF, edgeCol)  -- left-bottom
  lcd.drawLine(xL,  yM,  xLT, y1,  0xFF, edgeCol)  -- left-top
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

local function fitHeaderText(txt, maxW, flags)
  local s = string.upper(tostring(txt or ""))
  if s == "" or type(maxW) ~= "number" or maxW <= 0 or not lcd.getTextSize then
    return s
  end
  local w = lcd.getTextSize(s, flags)
  if type(w) ~= "number" or w <= maxW then return s end

  local ell = "..."
  local n = string.len(s)
  while n > 1 do
    local t = string.sub(s, 1, n) .. ell
    local tw = lcd.getTextSize(t, flags)
    if type(tw) == "number" and tw <= maxW then return t end
    n = n - 1
  end
  return ell
end

local function drawHeaderTextFit(x, y, txt, col, maxW)
  local flags = SMLSIZE + BOLD
  local s = fitHeaderText(txt, maxW, flags)
  lcd.drawText(x + 1, y + 1, s, flags + C_SIL_DK)
  lcd.drawText(x, y, s, flags + (col or C_WHITE))
end

local function drawHeaderTextC(x, y, txt, col, sizeFlags)
  local s = string.upper(tostring(txt or ""))
  local sf = sizeFlags or (MIDSIZE + BOLD)
  lcd.drawText(x + 2, y + 2, s, sf + CENTER + C_SIL_DK)
  lcd.drawText(x, y, s, sf + CENTER + (col or C_WHITE))
end

-- =========================================================================
--  BAR MODE
-- =========================================================================
local function drawBar(tx, ty, tw, th, pct, col)
  local bx = tx
  local by = ty
  local bw = tw
  local bh = th
  if bw < 8 or bh < 4 then return end
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
local GAUGE_ARC_THICK = 96

-- Cache system: store last rendered state per gauge instance
local _gaugeCache = {}  -- { "key" = { lastPct, cx, cy, r, thick, aS, aE } }
local _gaugeBgCache = {}  -- { "key" = true } - background rendered once
local _gaugeBgBuildBudget = 2  -- max uncached gauge backgrounds to build per refresh
local _dialBmp = nil
local _dialBmpTried = false
local _dialBmpDrawSig = 0  -- 0 unknown, 1 drawBitmap(bmp,x,y), 2 drawBitmap(x,y,bmp), -1 unsupported
local _gaugeLiteScaleCache = {}

local DIAL_BMP_W = 88
local DIAL_BMP_H = 46
local DIAL_BMP_OFF_X = 0
local DIAL_BMP_OFF_Y = 0

-- Use a pre-rendered transparent PNG dial background to keep Mode 2 CPU low.
-- Recommended asset path: /WIDGETS/BFTelem/assets/dial_bg.png
-- Recommended size: 88x46 (or similar), no runtime scaling.
local function getDialBitmap()
  if _dialBmpTried then return _dialBmp end
  _dialBmpTried = true
  if not Bitmap or not Bitmap.open then return nil end

  local candidates = {
    "/WIDGETS/BFTelem/assets/dial_bg.png",
    "/WIDGETS/BFTelem/assets/dial_bg.bmp",
    "/WIDGETS/BFTelem/assets/gauge_bg.png",
    "/WIDGETS/BFTelem/assets/gauge_bg.bmp",
  }

  for i = 1, #candidates do
    local ok, bmp = pcall(Bitmap.open, candidates[i])
    if ok and bmp then
      _dialBmp = bmp
      break
    end
  end
  return _dialBmp
end

local function drawDialBitmap(bmp, x, y)
  if not bmp or not lcd or not lcd.drawBitmap then return false end
  if _dialBmpDrawSig == 1 then
    lcd.drawBitmap(bmp, x, y)
    return true
  elseif _dialBmpDrawSig == 2 then
    lcd.drawBitmap(x, y, bmp)
    return true
  elseif _dialBmpDrawSig == -1 then
    return false
  end

  local ok = pcall(lcd.drawBitmap, bmp, x, y)
  if ok then
    _dialBmpDrawSig = 1
    return true
  end
  ok = pcall(lcd.drawBitmap, x, y, bmp)
  if ok then
    _dialBmpDrawSig = 2
    return true
  end

  _dialBmpDrawSig = -1
  return false
end

local function gaugeLiteScaleColor(t)
  local r, g, b
  if t <= 0.5 then
    -- Green -> Yellow
    local k = t * 2
    r = math.floor(255 * k + 0.5)
    g = 255
    b = 20
  else
    -- Yellow -> Red
    local k = (t - 0.5) * 2
    r = 255
    g = math.floor(255 * (1 - k) + 40 * k + 0.5)
    b = math.floor(20 * (1 - k) + 60 * k + 0.5)
  end
  return lcd.RGB(r, g, b)
end

-- Cached dim full-semicircle track (background), keyed by radius.
-- Keep this deliberately coarse: line count matters more than geometry precision.
local function getGaugeLiteTrack(r)
  local key = tostring(r)
  local c = _gaugeLiteScaleCache[key]
  if c then return c end

  local steps = math.max(6, math.floor(r * 0.28))
  local lines = {}
  local da = _PI / steps
  local px, py
  for i = 0, steps do
    local a  = _PI - da * i
    local nx = math.floor(r * math.cos(a) + 0.5)
    local ny = math.floor(-r * math.sin(a) + 0.5)
    if px then lines[#lines + 1] = {x1=px, y1=py, x2=nx, y2=ny} end
    px = nx; py = ny
  end

  _gaugeLiteScaleCache[key] = lines
  return lines
end

-- Cached colored value arc, keyed by radius + pct snapped to 2% buckets.
local _gaugeLiteArcCache = {}
local function getGaugeLiteArc(r, pct_bucket)
  local key = r * 100 + pct_bucket
  local c = _gaugeLiteArcCache[key]
  if c then return c end

  local steps = math.max(1, math.floor(math.max(6, r * 0.28) * pct_bucket / 100))
  local aNeedle = _PI - (_PI * pct_bucket / 100)
  local lines = {}
  local da = (aNeedle - _PI) / math.max(1, steps)
  local px, py
  for i = 0, steps do
    local a  = _PI + da * i
    local nx = math.floor(r * math.cos(a) + 0.5)
    local ny = math.floor(-r * math.sin(a) + 0.5)
    if px then lines[#lines + 1] = {x1=px, y1=py, x2=nx, y2=ny} end
    px = nx; py = ny
  end

  _gaugeLiteArcCache[key] = lines
  return lines
end

local function drawArcSeg(cx, cy, r, a1, a2, col, steps)
  -- Reduce steps for smaller radii to save CPU
  if not steps then
    steps = math.max(24, math.floor(r * 1.4))
  end
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
  local t = thick or 10
  local steps = math.max(14, math.floor(r * 0.7))

  -- Lightweight 3-5 stroke arc band (instead of dozens of concentric strokes).
  drawArcSeg(cx, cy, r, a1, a2, coreCol, steps)
  drawArcSeg(cx, cy, r - 1, a1, a2, coreCol, steps)
  drawArcSeg(cx, cy, r + 1, a1, a2, coreCol, steps)

  if t >= 8 then
    drawArcSeg(cx, cy, r - 2, a1, a2, midCol, steps)
    drawArcSeg(cx, cy, r + 2, a1, a2, edgeCol, steps)
  end

  if t >= 12 then
    drawArcSeg(cx, cy, r - 3, a1, a2, edgeCol, steps)
  end
end

local function drawGaugeTicks(cx, cy, r, aS, aE)
  local major = 8
  local minorPerSeg = 0
  local totalMinor = major * (minorPerSeg + 1)
  local span = aS - aE

  for i = 0, totalMinor do
    local a = aS - span * (i / totalMinor)
    local isMajor = (i % (minorPerSeg + 1) == 0)
    local inR = isMajor and (r - 16) or (r - 11)
    local outR = r - 3
    local x1 = cx + math.floor(inR * math.cos(a) + 0.5)
    local y1 = cy + math.floor(inR * math.sin(a) + 0.5)
    local x2 = cx + math.floor(outR * math.cos(a) + 0.5)
    local y2 = cy + math.floor(outR * math.sin(a) + 0.5)
    lcd.drawLine(x1, y1, x2, y2, 0xFF, isMajor and C_SIL_HI or C_SIL_MID)
  end
end

local function drawNeedleMotorbike(cx, cy, r, angleRad, col)
  local tipR = r - 2
  local shaftR = r - 16
  local tailR = 8

  local tipX = cx + math.floor(tipR * math.cos(angleRad) + 0.5)
  local tipY = cy + math.floor(tipR * math.sin(angleRad) + 0.5)
  local shaftX = cx + math.floor(shaftR * math.cos(angleRad) + 0.5)
  local shaftY = cy + math.floor(shaftR * math.sin(angleRad) + 0.5)

  local tailA = angleRad + _PI
  local tailX = cx + math.floor(tailR * math.cos(tailA) + 0.5)
  local tailY = cy + math.floor(tailR * math.sin(tailA) + 0.5)

  local perpA = angleRad + _PI / 2
  local w = 2
  local wx = math.floor(w * math.cos(perpA) + 0.5)
  local wy = math.floor(w * math.sin(perpA) + 0.5)

  -- Lightweight needle: one shaft plus compact arrowhead.
  lcd.drawLine(tailX, tailY, tipX, tipY, 0xFF, col)
  lcd.drawLine(tipX, tipY, shaftX + wx, shaftY + wy, 0xFF, col)
  lcd.drawLine(tipX, tipY, shaftX - wx, shaftY - wy, 0xFF, col)

  -- Hub cap.
  lcd.drawFilledRectangle(cx - 4, cy - 4, 9, 9, C_SIL_DK)
  lcd.drawFilledRectangle(cx - 2, cy - 2, 5, 5, C_SIL_HI)
  lcd.drawFilledRectangle(cx - 1, cy - 1, 3, 3, C_WHITE)
end

local function drawGauge(tx, ty, tw, th, pct, col, val_str, unit_str)
  local cx = math.floor(tx + tw / 2)

  -- Keep gauge thick but always bounded inside the tile.
  local thick = math.max(6, math.min(GAUGE_ARC_THICK, math.floor(math.min(tw, th) * 0.13)))
  local halfT = math.floor(thick / 2)
  local r = math.floor(math.min(tw * 0.32, th * 0.32))
  local maxRByWidth = math.floor((tw - 10 - (halfT * 2)) / 2)
  local maxRByHeight = math.floor((th - 14 - (halfT * 2)) / 2)
  if maxRByWidth < 8 then maxRByWidth = 8 end
  if maxRByHeight < 8 then maxRByHeight = 8 end
  if r > maxRByWidth then r = maxRByWidth end
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
  
  -- Draw background arc ONCE and cache it (budgeted to avoid CPU spikes).
  if (not _gaugeBgCache[cacheKey]) and (_gaugeBgBuildBudget > 0) then
    drawArcBand(cx, cy, r, aS, aE, C_SIL_LO, C_SIL_DK, C_CF1, thick)

    -- Red zone near the top end for a sport-bike cluster feel.
    local aRed = aS - (aS - aE) * 0.84
    drawArcBand(cx, cy, r + math.floor(thick * 0.30), aRed, aE,
      C_RED, C_ORANGE, C_SIL_DK, math.max(3, math.floor(thick * 0.14)))

    drawGaugeTicks(cx, cy, r, aS, aE)
    _gaugeBgCache[cacheKey] = true
    _gaugeBgBuildBudget = _gaugeBgBuildBudget - 1
  end

  -- Only redraw needle + filled arc if percentage changed by >=4%
  local lastPct = _gaugeCache[cacheKey] or -999
  local pctFloor = math.floor((pct or 0) / 4 + 0.5)  -- Round to nearest 4%
  local lastPctFloor = math.floor(lastPct / 4 + 0.5)
  
  if pctFloor ~= lastPctFloor then
    if pct and pct > 0 then
      local aV = aS - (aS - aE) * math.min(pct, 100) / 100

      -- Active track: lightweight single arc sweep for CPU safety.
      drawArcSeg(cx, cy, r, aS, aV, col or C_GREEN, math.max(14, math.floor(r * 0.7)))

      -- Draw motorbike-style pointer needle.
      drawNeedleMotorbike(cx, cy, r, aV, col or C_GREEN)
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

local function drawGaugeLite(tx, ty, tw, th, pct, col, label_str, val_str, unit_str)
  local cx = math.floor(tx + tw / 2)

  -- Four fixed zones (top → bottom), nothing overlaps:
  --   label  (SMLSIZE, ~12px)  at top
  --   arc    (semicircle)       in the middle band
  --   value  (MIDSIZE, ~16px)  below arc
  --   unit   (SMLSIZE, ~12px)  at bottom
  local labelY = ty + 2
  local unitY  = ty + th - 12
  local valY   = unitY - 24

  -- Arc fills the band between label and value
  local arcTop   = labelY + 14          -- 14px reserved for label text
  local arcAreaH = math.max(4, valY - arcTop - 2)
  local arcR     = math.floor(math.min(math.min((tw - 14) / 2, arcAreaH), tw * 0.36))
  if arcR < 6 then arcR = 6 end

  local arcCx = cx
  local arcCy = arcTop + arcR           -- pivot at arcTop + radius

  local p = math.max(0, math.min(100, pct or 0))

  -- Dim background track (full semicircle)
  local track = getGaugeLiteTrack(arcR)
  for i = 1, #track do
    local ln = track[i]
    lcd.drawLine(arcCx + ln.x1, arcCy + ln.y1, arcCx + ln.x2, arcCy + ln.y2, 0xFF, C_SIL_DK)
  end

  -- Colored value arc
  if p > 0 then
    local bucket = math.floor(p / 5 + 0.5) * 5
    if bucket > 100 then bucket = 100 end
    local arc = getGaugeLiteArc(arcR, bucket)
    for i = 1, #arc do
      local ln = arc[i]
      lcd.drawLine(arcCx + ln.x1, arcCy + ln.y1, arcCx + ln.x2, arcCy + ln.y2, 0xFF, col or C_WHITE)
    end
  end

  -- Needle + pivot dot
  local aNeedle = _PI - (_PI * p / 100)
  local nx = math.floor(arcCx + arcR * math.cos(aNeedle) + 0.5)
  local ny = math.floor(arcCy - arcR * math.sin(aNeedle) + 0.5)
  lcd.drawLine(arcCx, arcCy, nx, ny, 0xFF, col or C_WHITE)
  lcd.drawFilledRectangle(arcCx - 1, arcCy - 1, 3, 3, C_WHITE)

  -- Label at top
  if label_str and label_str ~= "" then
    lcd.drawText(cx, labelY, label_str, SMLSIZE + CENTER + C_CYAN)
  end
  -- Value below arc
  if val_str then
    lcd.drawText(cx, valY, val_str, MIDSIZE + BOLD + CENTER + (col or C_WHITE))
  end
  -- Unit at bottom
  if unit_str then
    lcd.drawText(cx, unitY, unit_str, SMLSIZE + CENTER + C_DIM)
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
           pct=v, col=cLQ(v,o.LQWrn) }
end

local function inferCellCountFromPack(packV, fullCellV)
  if type(packV) ~= "number" then return nil end
  local full = math.max(3.0, math.min(5.0, tonumber(fullCellV) or 4.2))
  local inferred = math.ceil((packV / full) - 0.0001)
  return clampInt(inferred, 1, 8)
end

local function resolveRxCellCount(o, packV)
  local fullV = (tonumber(o and o.FullV) or 42) / 10.0
  local cfg = math.floor(tonumber(o and o.Cells) or 0)
  if cfg >= 1 then
    if type(packV) == "number" then
      local perCell = packV / cfg
      -- If configured cells produce an impossible per-cell voltage,
      -- auto-correct from pack voltage to avoid wrong 100% readings.
      if perCell > (fullV + 0.25) or perCell < 2.5 then
        return inferCellCountFromPack(packV, fullV) or cfg
      end
    end
    return cfg
  end
  return inferCellCountFromPack(packV, fullV) or 1
end

local function tdBatt(o)
  local volt=getS(SN_VOLT)
  local nc=resolveRxCellCount(o, volt)
  local fV=(tonumber(o and o.FullV) or 42)/10.0; local eV=3.30
  local cV=volt and (volt/nc) or nil
  local pct=cV and math.max(0,math.min(100,(cV-eV)/(fV-eV)*100)) or nil
  return { val=volt and string.format("%.1f",volt) or "---",
           unit=string.format("V %dS", nc),
           pct=pct, col=cPct(pct) }
end
local function tdCurrent(o)
  local v=getS(SN_CURR)
  local pct=v and math.min(100,v) or nil
  return { val=v and string.format("%.1f",v) or "---", unit="Amps",
           pct=pct, col=cPctInv(pct) }
end
local function tdTimer(o)
  local sec = armTimerSec()
  local redS = math.max(30, math.floor(tonumber(o and o.TmrRed) or 180))
  local yellowS = math.max(10, math.floor(redS * 0.70 + 0.5))
  local col = C_GREEN
  if _lastArmed then
    if sec >= redS then
      col = C_RED
    elseif sec >= yellowS then
      col = C_YELLOW
    else
      local t = sec / math.max(1, yellowS)
      col = lcd.RGB(math.floor(255 * t + 0.5), 255, math.floor(100 * (1 - t) + 0.5))
    end
  end
  local pct = _lastArmed and math.min(100, (sec / math.max(1, redS)) * 100) or 0
  return { val=armTimerStr(), unit=_lastArmed and "ARMED" or "disarmed",
           pct=pct, col=col }
end
local function tdRSSI(o)
  local v1=getS(SN_RSSI1); local v2=getS(SN_RSSI2)
  local col=v1 and (v1>-65 and C_GREEN or (v1>-85 and C_YELLOW or C_RED)) or C_DIM
  return { val=v1 and tostring(v1) or "---", unit="dBm",
           pct=v1 and math.max(0,math.min(100,v1+130)) or nil,
           col=col }
end
local function tdCellV(o)
  local volt=getS(SN_VOLT)
  local nc=resolveRxCellCount(o, volt)
  local wV=(tonumber(o and o.WarnV) or 36)/10.0; local kV=(tonumber(o and o.CritV) or 34)/10.0
  local cV=volt and (volt/nc) or nil
  return { val=cV and string.format("%.2f",cV) or "---",
           unit=string.format("V  %dS",nc),
           pct=cV and math.max(0,math.min(100,(cV-kV)/(4.2-kV)*100)) or nil,
           col=cVolt(cV,wV,kV) }
end
local function tdMah(o)
  local v=getS(SN_CAPA)
  local pct=v and math.min(100,v/10) or nil
  return { val=v and string.format("%d",v) or "---", unit="mAh",
           pct=pct, col=cPctInv(pct) }
end
local function tdThrottle(o)
  local v = throttlePct()
  return { val=v and string.format("%d",v) or "---", unit="%",
           pct=v, col=cPctInv(v) }
end
local function tdTXPwr(o)
  local v=getS(SN_TPWR)
  local col=v and (v<=100 and C_GREEN or (v<=500 and C_YELLOW or C_RED)) or C_DIM
  return { val=v and tostring(v) or "---", unit="mW",
           pct=v and math.min(100,v/20) or nil, col=col }
end
local function tdAlt(o)
  local v=getS(SN_ALT)
  local pct=v and math.max(0,math.min(100,v/5)) or nil
  return { val=v and string.format("%d", math.floor(v + 0.5)) or "---", unit="metres",
           pct=pct, col=cPctInv(pct) }
end
local function tdDist(o)
  local v=getS(SN_DIST)
  local redD = math.max(20, math.floor(tonumber(o and o.DistRed) or 100))
  local yellowD = math.max(5, math.floor(redD * 0.70 + 0.5))
  local col = C_DIM
  if type(v) == "number" then
    if v >= redD then
      col = C_RED
    elseif v >= yellowD then
      col = C_YELLOW
    else
      col = C_GREEN
    end
  end
  local pct=v and math.min(100, (v / math.max(1, redD)) * 100) or nil
  return { val=v and string.format("%.0f",v) or "---", unit="metres",
           pct=pct, col=col }
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

local function getScreenType(options)
  if type(options) ~= "table" then return 0 end
  local v = options.ScreenType
  if v == nil then v = options["Screen type"] end
  if v == nil then v = options.Mode end
  if type(v) ~= "number" then return 0 end
  return clampInt(math.floor(v), 0, 2)
end

local function setScreenType(options, v)
  if type(options) ~= "table" then return end
  local m = clampInt(math.floor(tonumber(v) or 0), 0, 2)
  options.ScreenType = m
  options["Screen type"] = m
  options.Mode = m
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
  local mode = getScreenType(options)
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
    setScreenType(options, saved.mode)
  end

  return loadedAny
end

local function menuBounds()
  local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
  local h = MENU_TITLE_H + MENU_PAD * 2 + visibleRows * MENU_ROW_H + MENU_ROW_H
  local y = math.floor((_screenH - h) / 2)
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

local function handleScrollWheel(widget, event)
  -- Scroll wheel + button navigation for Jumper T16 and TX16S MK II
  local now = getTime() or 0
  local debounceElapsed = (now - (_scrollWheelUi.lastRotaryEvent or 0)) * 10  -- convert to ms
  
  -- Handle rotary encoder (scroll wheel)
  if event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT then
    if debounceElapsed < _scrollWheelUi.debounceMs then
      return  -- debounce: ignore rapid rotations
    end
    _scrollWheelUi.lastRotaryEvent = now
    
    if _touchUi.open and _touchUi.tile then
      -- Menu is open: rotate through metrics
      local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
      local maxScroll = math.max(0, #METRICS - visibleRows)
      local direction = (event == EVT_ROT_RIGHT) and 1 or -1
      _touchUi.menuScroll = clampInt((_touchUi.menuScroll or 0) + direction, 0, maxScroll)
    else
      -- Menu closed: rotate through tiles
      local direction = (event == EVT_ROT_RIGHT) and 1 or -1
      _scrollWheelUi.focusedTile = clampInt(_scrollWheelUi.focusedTile + direction, 1, math.min(#_tileSlots, HX_COLS * HX_ROWS))
    end
    return
  end
  
  -- Long-press ENTER (no menu open): cycle ScreenType 0(NUM)→1(BAR)→2(GAUGE)→0
  if event == EVT_VIRTUAL_ENTER_LONG then
    if not (_touchUi.open and _touchUi.tile) then
      if widget and widget.options then
        local cur = getScreenType(widget.options)
        local nxt = (cur + 1) % 3
        setScreenType(widget.options, nxt)
        saveTileSlotsToStorage(widget.options)
        _screenTypeBannerUntil = (getTime() or 0) + 150  -- ~1.5 s
      end
    end
    return
  end

  -- Handle Enter/OK button
  if event == EVT_VIRTUAL_ENTER then
    local now = getTime() or 0
    if _touchUi.open and _touchUi.tile then
      -- Menu is open: select the current metric from scroll position
      local visibleRows = math.min(#METRICS, MENU_MAX_ROWS)
      local maxScroll = math.max(0, #METRICS - visibleRows)
      local scroll = clampInt(_touchUi.menuScroll or 0, 0, maxScroll)
      local selectedIdx = scroll + 1  -- first visible metric
      
      if selectedIdx <= #METRICS then
        _tileSlots[_touchUi.tile] = selectedIdx
        if widget and widget.options then
          widget.options["T" .. _touchUi.tile] = selectedIdx - 1
        end
        saveTileSlotsToStorage(widget and widget.options)
      end
      _touchUi.open = false
      _touchUi.tile = nil
      _touchUi.ignoreDismissUntil = 0
    else
      -- Menu closed: open metric picker for focused tile
      if not canTapNow() then return end
      _touchUi.open = true
      _touchUi.tile = _scrollWheelUi.focusedTile
      _touchUi.menuScroll = 0
      _touchUi.ignoreDismissUntil = (getTime() or 0) + 12
    end
    return
  end
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
          local now = getTime() or 0
          if now >= (_touchUi.ignoreDismissUntil or 0) then
            _touchUi.downKind = "menuDismiss"
            _touchUi.downIndex = nil
            _touchUi.downX = x
            _touchUi.downY = y
            _touchUi.downMoved = false
          else
            resetTouchDownState()
          end
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
    _touchUi.ignoreDismissUntil = (getTime() or 0) + 12
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
    _touchUi.ignoreDismissUntil = 0
  end

  if downKind == "menuDismiss" and _touchUi.open then
    _touchUi.open = false
    _touchUi.tile = nil
    _touchUi.ignoreDismissUntil = 0
  end
end

-- =========================================================================
--  TILE RENDERER
-- =========================================================================
local function renderTile(tx, ty, tw, th, lbl_str, d, mode)
  drawTile(tx, ty, tw, th)
  local cx = tx + math.floor(tw / 2)

  -- Slightly denser layout so text occupies more of each tile.
  -- On small screens push yUnit further down to avoid overlapping the big value.
  local yLbl  = ty + math.floor(th * 0.22)
  local yVal  = ty + math.floor(th * 0.36)
  local yUnit = ty + math.floor(th * (_is480x272 and 0.70 or 0.62)) + 4
  local ySub  = ty + math.floor(th * 0.77)

  local shortLbl = lbl_str
  if lbl_str == "LINK QUALITY" then shortLbl = "LINK Q" end
  if lbl_str == "FLIGHT TIMER" then shortLbl = "TIMER" end
  if lbl_str == "CELL VOLTAGE" then shortLbl = "CELL V" end
  if lbl_str == "TX POWER"     then shortLbl = "TX PWR" end
  if lbl_str == "CAPACITY"     then shortLbl = "CAPA" end
  if lbl_str == "DISTANCE"     then shortLbl = "DIST" end
  if lbl_str == "ALTITUDE"     then shortLbl = "ALT" end

  if mode == 1 then
    -- label: small, cyan, centered
    lcd.drawText(cx, yLbl, shortLbl, SMLSIZE + CENTER + C_CYAN)
    local mCol = d.col or ((d.pct ~= nil) and cPct(d.pct) or C_WHITE)
    local pad = math.max(8, math.floor(tw * 0.14))
    local valY = yLbl + 14
    local unitY = ty + math.floor(th * 0.72) + 4
    local barH = math.max(6, math.min(8, math.floor(th * 0.08)))
    local barTop = ty + math.floor(th * 0.65)
    local maxBarTop = unitY - 4 - barH
    if barTop > maxBarTop then barTop = maxBarTop end
    if barTop < valY + 12 then barTop = valY + 12 end

    drawBar(tx + pad, barTop, tw - 2 * pad, barH, d.pct, mCol)
    lcd.drawText(cx, valY, d.val, SMLSIZE + CENTER + BOLD + mCol)
    if d.unit and d.unit ~= "" then
      lcd.drawText(cx, unitY, d.unit, SMLSIZE + CENTER + C_DIM)
    end
  elseif mode == 2 then
    local mCol = d.col or ((d.pct ~= nil) and cPct(d.pct) or C_WHITE)
    local pad = math.max(8, math.floor(tw * 0.14))
    drawGaugeLite(tx + pad, ty + 6, tw - 2 * pad, th - 14, d.pct, mCol, shortLbl, d.val, d.unit)
  else
    -- label: small, cyan, centered
    lcd.drawText(cx, yLbl, shortLbl, SMLSIZE + CENTER + C_CYAN)
    -- RF MODE strings can be wide (e.g. "333Hz/8ch"); use SMLSIZE to stay inside the tile.
    local valFlags = (lbl_str == "RF MODE") and (SMLSIZE + BOLD + CENTER + (d.col or C_WHITE))
                                              or  (MIDSIZE + BOLD + CENTER + (d.col or C_WHITE))
    local yValAdj  = (lbl_str == "RF MODE") and (ty + math.floor(th * 0.42)) or yVal
    lcd.drawText(cx, yValAdj, d.val, valFlags)
    if d.unit and d.unit ~= "" then
      lcd.drawText(cx, yUnit, d.unit, SMLSIZE + CENTER + C_DIM)
    end
    if d.sub then
      lcd.drawText(cx, ySub, d.sub, SMLSIZE + CENTER + C_DIM)
    end
  end
end

-- =========================================================================
--  HEADER  (top bar model/mode/arm status + TX voltage + screen mode + clock)
-- =========================================================================
local function drawHeader(o)
  local mname = "CRAFT"
  -- Show default label before bind; swap to model name only when telemetry is live.
  if hasActiveTelemetry() then
    local info = model.getInfo()
    if info and info.name and info.name ~= "" then mname = info.name end
  end
  -- Layout helpers: proportional positions relative to screen width.
  local sep1X  = math.floor(_screenW * 0.350)   -- left separator (wider MODE bin)
  local cx     = math.floor(_screenW / 2)        -- screen center (~400 on 800, ~240 on 480)
  local sep2X  = math.floor(_screenW * 0.650)    -- right separator (wider MODE bin)
  local armedX = sep2X + 14                      -- armed/disarmed text start
  local rightX = _screenW - 15                   -- right-aligned text anchor
  local sepH   = TOP_MID - 16                    -- separator bar height (fits within header)
  local yTop   = 10                              -- top text row Y
  local yBot   = math.max(yTop + 14, TOP_MID - 22)  -- bottom text row Y

  -- Model name in compact font with width clamp so it never overlaps FM area.
  drawHeaderTextFit(FRM_L - 10, yTop, mname, C_SIL_HI, sep1X - 65)
  -- vertical separators (symmetric around screen center)
  lcd.drawFilledRectangle(sep1X, 8, 2, sepH, C_SIL_LO)
  -- flight mode
  local fmDisp = "MODE"
  if hasActiveTelemetry() then
    fmDisp = (_fmStr ~= "") and _fmStr or "MODE"
  end
  local fmCol = C_SIL_MID
  if hasActiveTelemetry() then
    fmCol = _lastArmed and C_ORANGE or C_SIL_HI
  end
  drawHeaderTextC(cx, yTop, fmDisp, fmCol, SMLSIZE + BOLD)
  -- armed/disarmed indicator (replaces timer - timer is in FLIGHT TIMER tile)
  lcd.drawFilledRectangle(sep2X, 8, 2, sepH, C_SIL_LO)
  if _nogpsOverlayUntil and (getTime() or 0) < _nogpsOverlayUntil then
    local s = "NO GPS"
    lcd.drawText(armedX + 2, yTop + 2, s, SMLSIZE + BOLD + C_SIL_DK)
    lcd.drawText(armedX,     yTop,     s, SMLSIZE + BOLD + C_RED)
  elseif _lastArmed then
    local s = "ARMED"
    if _is480x272 then
      lcd.drawText(armedX + 1, yTop + 1, s, TINSIZE + BOLD + C_SIL_DK)
      lcd.drawText(armedX,     yTop,     s, TINSIZE + BOLD + C_RED)
    else
      lcd.drawText(armedX + 2, yTop + 2, s, SMLSIZE + BOLD + C_SIL_DK)
      lcd.drawText(armedX,     yTop,     s, SMLSIZE + BOLD + C_RED)
    end
  else
    local s = "DISARMED"
    if _is480x272 then
      lcd.drawText(armedX + 1, yTop + 1, s, TINSIZE + BOLD + C_SIL_DK)
      lcd.drawText(armedX,     yTop,     s, TINSIZE + BOLD + C_GREEN)
    else
      lcd.drawText(armedX + 2, yTop + 2, s, SMLSIZE + BOLD + C_SIL_DK)
      lcd.drawText(armedX,     yTop,     s, SMLSIZE + BOLD + C_GREEN)
    end
  end
  -- TX voltage top-right
  local txv = getValue("tx-voltage")
  if type(txv) == "number" and txv > 0 then
    lcd.drawText(rightX, yTop - 2, string.format("TX %.1fV", txv),
      SMLSIZE+RIGHT+(txv > 7.0 and C_GREEN or C_RED))
  end
  -- screen type label bottom-right
  local st = getScreenType(o)
  local mLbl = (st==1) and "SCR: BAR" or (st==2) and "SCR: GAUGE" or "SCR: NUM"
  lcd.drawText(rightX, yBot, mLbl, SMLSIZE+RIGHT+C_SIL_MID)

  -- Clock in the top-right pit gap (outside the top-right hex tile).
  if getDateTime then
    local dt = getDateTime()
    if type(dt) == "table" then
      local hh = dt.hour or dt.hr or dt[4]
      local mm = dt.min or dt.minute or dt[5]
      if type(hh) == "number" and type(mm) == "number" then
        local t = string.format("%02d:%02d", hh, mm)
        local cx = GX + GW - 10
        local cy = GY + 10
        if _is480x272 then
          -- Small screen: "TIME" micro-label + SMLSIZE time below it
          lcd.drawText(cx, cy,      "TIME", SMLSIZE + RIGHT + C_SIL_MID)
          lcd.drawText(cx, cy + 12, t,      TINSIZE + BOLD + RIGHT + C_SIL_HI)
        else
          lcd.drawText(cx, cy, "TIME", SMLSIZE + RIGHT + C_SIL_MID)
          lcd.drawText(cx, cy + 12, t, MIDSIZE + BOLD + RIGHT + C_SIL_HI)
        end
      end
    end
  end
end

-- =========================================================================
--  SIDE BATTERY BARS (outside hex pit, inside frame side rails)
-- =========================================================================
local function pctFromTxVoltage(v)
  if type(v) ~= "number" then return nil end
  -- 2S TX packs are commonly around 8.4V full and 6.6V near empty.
  local p = (v - 6.6) / (8.4 - 6.6) * 100
  return math.max(0, math.min(100, p))
end

local function pctFromRxCellVoltage(v, o)
  if type(v) ~= "number" then return nil end
  local nc = resolveRxCellCount(o, v)
  local cv = v / nc
  local full = (tonumber(o and o.FullV) or 42) / 10.0
  local empty = 3.30
  local p = (cv - empty) / (full - empty) * 100
  return math.max(0, math.min(100, p))
end

local function drawSideBar(x, y, w, h, pct, label)
  local labelTop = y + 2
  local barTop = y + 40
  local pctY = y + h - 10
  local barBottom = pctY - 4
  local textCx = x + w/2

  -- Draw label on two lines if it contains a space.
  local labelStr = tostring(label or "")
  local line1, line2 = string.match(labelStr, "^(%S+)%s+(%S+)$")
  if line1 then
    lcd.drawText(textCx, labelTop, line1, SMLSIZE + CENTER + C_SIL_HI)
    lcd.drawText(textCx, labelTop + 12, line2, SMLSIZE + CENTER + C_SIL_HI)
  else
    lcd.drawText(textCx, labelTop + 6, labelStr, SMLSIZE + CENTER + C_SIL_HI)
    barTop = y + 36
  end

  local barH = barBottom - barTop
  if barH < 30 then return end

  local segCount = 10
  local gap = 2
  local segH = math.floor((barH - gap * (segCount - 1)) / segCount)
  if segH < 3 then segH = 3 end
  local lit = pct and math.floor((pct / 100) * segCount + 0.5) or 0
  lit = clampInt(lit, 0, segCount)

  lcd.drawRectangle(x - 2, barTop - 2, w + 4, barH + 4, C_SIL_LO)

  for i = 1, segCount do
    local idxFromBottom = segCount - i + 1
    local sy = barTop + (i - 1) * (segH + gap)
    local on = idxFromBottom <= lit
    local col = on and cBattPct((idxFromBottom / segCount) * 100) or C_SIL_DK
    lcd.drawFilledRectangle(x, sy, w, segH, col)
    lcd.drawRectangle(x, sy, w, segH, C_CF1)
  end

  local ptxt = pct and string.format("%d%%", math.floor(pct + 0.5)) or "---"
  lcd.drawText(textCx, pctY, ptxt, SMLSIZE + CENTER + (pct and cBattPct(pct) or C_DIM))
end

local function drawSideBatteryBars(o)
  local railPadX = 0
  local railW = FRM_L - (railPadX * 2)
  if railW < 12 then return end

  local y = TOP_MID + 16
  local h = _screenH - TOP_MID - FRM_B - 34
  if h < 80 then return end

  local txv = getValue("tx-voltage")
  local txPct = pctFromTxVoltage(txv)

  local rxv = getS(SN_VOLT)
  local rxPct = pctFromRxCellVoltage(rxv, o)

  drawSideBar(railPadX, y, railW, h, rxPct, "RX batt")
  drawSideBar(_screenW - FRM_R + railPadX, y, railW, h, txPct, "TX batt")
end

-- =========================================================================
--  GRID
-- =========================================================================
local function drawGrid(opts)
  local mode = getScreenType(opts)
  local maxTiles = HX_COLS * HX_ROWS
  for i = 1, math.min(#_tileSlots, maxTiles) do
    local metricIdx = _tileSlots[i] or i
    local metric = METRICS[metricIdx] or METRICS[i]
    local tx, ty, tw, th = tileRect(i)
    renderTile(tx, ty, tw, th, metric[1], metric[2](opts), mode)
  end
end

local function drawScrollWheelFocus()
  -- Draw focus ring around the focused tile when using scroll wheel (Jumper T16, or TX16S MK II/MK III with wheel)
  if _scrollWheelUi.focusedTile and not _touchUi.open then
    local tx, ty, tw, th = tileRect(_scrollWheelUi.focusedTile)
    -- Draw a bright cyan border to indicate focus
    local q = math.max(8, math.floor(tw / 4))
    local hh = math.floor(th / 2)
    local xL  = tx
    local xR  = tx + tw - 1
    local xLT = tx + q
    local xRT = tx + tw - q - 1
    local yM  = ty + hh
    local y1  = ty
    local y4  = ty + th - 1
    
    -- Draw focus outline (bright cyan)
    local focusCol = C_CYAN
    lcd.drawLine(xLT, y1,  xRT, y1,  0xFF, focusCol)   -- top
    lcd.drawLine(xRT, y1,  xR,  yM,  0xFF, focusCol)   -- right-top
    lcd.drawLine(xR,  yM,  xRT, y4,  0xFF, focusCol)   -- right-bottom
    lcd.drawLine(xRT, y4,  xLT, y4,  0xFF, focusCol)   -- bottom
    lcd.drawLine(xLT, y4,  xL,  yM,  0xFF, focusCol)   -- left-bottom
    lcd.drawLine(xL,  yM,  xLT, y1,  0xFF, focusCol)   -- left-top
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
  _alerts.lastRun = 0
  _alerts.armedPrev = false
  _nogpsOverlayUntil = 0
  _screenTypeBannerUntil = 0
  resetAlertState()
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
  _scrollWheelUi.focusedTile = 1
  _scrollWheelUi.lastRotaryEvent = 0
  _deviceType = detectDeviceType(options, zone)
  initLayoutConstants(zone)
  return { zone = zone, options = options }
end
local function update(widget, options)
  widget.options = options
  initLayoutConstants()
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
  _deviceType = detectDeviceType(options, widget.zone)
end

local function refresh(widget, event, touchState)
  _gaugeBgBuildBudget = 2
  initLayoutConstants(widget.zone)
  initColors(widget.options and widget.options.Theme)
  if #_tileSlots ~= #METRICS then
    syncTileSlotsFromOptions(widget.options)
  end

  -- Input handling: Touch for TX16S MK II, scroll wheel for Jumper T16
  if _is480x272 then
    if _deviceType == "TX16S_MK2" then
      handleTouch(widget, touchState)
      -- Also support scroll wheel as alternative on TX16S MK II
      handleScrollWheel(widget, event)
    else
      -- Jumper T16: scroll wheel + button only (no touchscreen)
      handleScrollWheel(widget, event)
    end
  else
    -- TX16S MK III: touch primary, scroll wheel as alternative
    handleTouch(widget, touchState)
    handleScrollWheel(widget, event)
  end

  -- Handle RTN button to dismiss the menu
  if event == EVT_VIRTUAL_EXIT and _touchUi.open then
    _touchUi.open = false
    _touchUi.tile = nil
    _touchUi.ignoreDismissUntil = 0
  end

  tickArmTimer(widget.options)
  tickAlerts(widget.options)

  -- Draw order: pit/grid first, then menu overlay, frame/rails, then header text.
  lcd.drawFilledRectangle(0, 0, _screenW, _screenH, C_BG)
  drawPit()
  drawGrid(widget.options)
  drawScrollWheelFocus()
  drawMetricMenu()
  drawCarbonFrame()
  drawSideBatteryBars(widget.options)
  drawHeader(widget.options)

  -- Screen-type toast: brief centered banner after long-press ENTER cycle
  if (getTime() or 0) < _screenTypeBannerUntil then
    local st = getScreenType(widget.options)
    local msg = (st == 1) and "SCR: BAR" or (st == 2) and "SCR: GAUGE" or "SCR: NUM"
    local flags = MIDSIZE + BOLD
    local tw, th = lcd.getTextSize and lcd.getTextSize(msg, flags) or 80, 20
    local bx = math.floor((_screenW - (tw or 80)) / 2)
    local by = math.floor((_screenH - (th or 20)) / 2)
    lcd.drawFilledRectangle(bx - 14, by - 10, (tw or 80) + 28, (th or 20) + 20, C_SIL_DK)
    lcd.drawRectangle(bx - 14, by - 10, (tw or 80) + 28, (th or 20) + 20, C_CYAN)
    lcd.drawText(bx + 1, by + 1, msg, flags + C_SIL_DK)
    lcd.drawText(bx, by, msg, flags + C_CYAN)
  end

  -- NO GPS overlay: big red banner, shown for ~1 second after alert fires
  if (getTime() or 0) < _nogpsOverlayUntil then
    local msg = "NO GPS"
    local flags = DBLSIZE + BOLD
    local tw, th = lcd.getTextSize and lcd.getTextSize(msg, flags) or 120, 28
    local tx = math.floor((_screenW - (tw or 120)) / 2)
    local ty = math.floor((_screenH - (th or 28)) / 2)
    -- Semi-transparent dark backdrop
    lcd.drawFilledRectangle(tx - 14, ty - 10, (tw or 120) + 28, (th or 28) + 20, lcd.RGB(20, 0, 0))
    lcd.drawRectangle(tx - 14, ty - 10, (tw or 120) + 28, (th or 28) + 20, C_RED)
    -- Shadow + text
    lcd.drawText(tx + 2, ty + 2, msg, flags + lcd.RGB(80, 0, 0))
    lcd.drawText(tx, ty, msg, flags + C_RED)
  end
end

-- =========================================================================
--  GPS STATUS (bottom left persistent display)
-- =========================================================================
local function drawGpsStatus()
  local sats = getS(SN_SATS)
  local hasFix = (type(sats) == "number") and (sats >= 6)
  -- Offset the GPS status lower on small screens so it doesn't crowd the tiles
  local yOffset = _is480x272 and 22 or 0
  local x = GX + 10
  local y = GY + GH - 60 + yOffset
  if hasFix then
    -- Top line: "GPS Locked" (green, smlsize, not bold, same as NO GPS LOCK)
    lcd.drawText(x + 1, y - 2, "GPS Locked", SMLSIZE + C_SIL_DK)
    lcd.drawText(x, y - 4, "GPS Locked", SMLSIZE + C_GREEN)
    -- Bottom line: "(Sats = xx)" (green, smlsize, moved further down)
    local satsStr = string.format("(Sats = %d)", sats)
    lcd.drawText(x + 2, y + 18, satsStr, SMLSIZE + C_SIL_DK)
    lcd.drawText(x, y + 16, satsStr, SMLSIZE + C_GREEN)
  else
    -- One line: "NO GPS LOCK" (red, smlsize, smaller font)
    lcd.drawText(x + 1, y + 1, "NO GPS LOCK", SMLSIZE + C_SIL_DK)
    lcd.drawText(x, y, "NO GPS LOCK", SMLSIZE + C_RED)
  end
end

return {
  name       = "BF Telemetry",
  options    = OPTIONS,
  create     = create,
  update     = update,
  background = background,
  refresh    = function(widget, event, touchState)
    refresh(widget, event, touchState)
    drawGpsStatus()
  end,
}
# BF Telemetry Widget

An EdgeTX full-screen telemetry widget for the **Radiomaster TX16S MK III**, designed specifically for its 800×480 color LCD touchscreen. It displays 12 live Betaflight/ELRS telemetry tiles in a 4×3 grid.

---

## Requirements

| Requirement | Version |
|---|---|
| EdgeTX | 2.12+ |
| Lua | 5.3 |
| Radio | Radiomaster TX16S MK III (800×480 screen) |
| Telemetry | Betaflight + ExpressLRS (ELRS) |

---

## Installation

1. Copy `main.lua` into a new folder on your radio's SD card:
   ```
   /WIDGETS/BFTelem/main.lua
   ```
2. On the radio, navigate to **Screen Setup → Add Widget** and select **BF Telemetry**.

---

## Telemetry Tiles

The widget shows the following 12 tiles (populated automatically from your ELRS/Betaflight telemetry stream):

| Tile | Sensor | Unit |
|---|---|---|
| Link Quality | `RQly` | % |
| Battery | `RxBt` | V (pack + per-cell) |
| Current | `Curr` | A |
| Flight Timer | arm/disarm event | mm:ss |
| RSSI | `1RSS` / `2RSS` | dBm |
| Cell Voltage | `RxBt` ÷ Cells | V/cell |
| Capacity Used | `Capa` | mAh |
| Throttle | `thr` (stick) | % |
| TX Power | `TPWR` | mW |
| Altitude | `Alt` | m |
| Distance | `Dist` | m |
| RF Mode | `RFMD` | — |

The header bar shows model name, flight mode, armed/disarmed status, TX battery voltage, and the active tile display mode.

Header behavior:

- With no active telemetry link, the flight mode area shows `MODE`.
- Once telemetry is active, the flight mode area shows the current flight mode reported by Betaflight.
- The armed/disarmed indicator uses either the configured arm source or the Betaflight `FM` telemetry state.

---

## Customization

Open the widget's **Options** menu on the radio (long-press the widget area) to adjust these parameters:

| Option | Default | Range | Description |
|---|---|---|---|
| `Cells` | 4 | 1 – 8 | Number of LiPo cells |
| `FullV` | 42 | 30 – 50 | Full cell voltage × 10 (42 = 4.2 V/cell) |
| `WarnV` | 36 | 30 – 42 | Warning cell voltage × 10 (36 = 3.6 V/cell) |
| `CritV` | 34 | 30 – 42 | Critical cell voltage × 10 (34 = 3.4 V/cell) |
| `LQWrn` | 70 | 10 – 99 | Link quality % below which the tile turns yellow/red |
| `Mode`  | 0  | 0 – 2  | Display style: `0` = numeric, `1` = bar, `2` = arc gauge |
| `Theme` | 0  | 0 – 3  | Accent color theme: `0` = Betaflight yellow, `1` = cyan, `2` = green, `3` = orange |
| `ThrOn` | 5  | 0 – 50 | Throttle % threshold used to start the flight timer |
| `ArmSrc` | — | source | Optional EdgeTX source for the arm switch/channel |

Mode values shown in the header:

- `0` = `[ NUM ]`
- `1` = `[ BAR ]`
- `2` = `[GAUGE]`

Flight timer behavior:

- The timer resets to `--:--` when disarmed.
- The timer starts only after the model is armed and throttle rises above `ThrOn`.
- If `ArmSrc` is configured, that source is used as the primary armed/disarmed signal.
- If `ArmSrc` is not configured, the widget falls back to Betaflight flight-mode telemetry.

RF mode behavior:

- `RFMD` is decoded using the ExpressLRS rate enum, so values such as `250Hz`, `500Hz`, `F500Hz`, and `F1000` match the ELRS Lua script.

To change which sensor feeds a tile, edit the sensor name constants near the top of `main.lua`:

```lua
local SN_LQ    = "RQly"   -- Link quality
local SN_RSSI1 = "1RSS"   -- RSSI antenna 1
local SN_RSSI2 = "2RSS"   -- RSSI antenna 2
local SN_VOLT  = "RxBt"   -- Battery voltage
local SN_CURR  = "Curr"   -- Current
local SN_CAPA  = "Capa"   -- Capacity used
local SN_ALT   = "Alt"    -- Altitude
local SN_FM    = "FM"     -- Flight mode
local SN_TPWR  = "TPWR"  -- TX power
local SN_RFMD  = "RFMD"  -- RF mode
local SN_DIST  = "Dist"   -- Distance
```

Replace any value with the sensor name reported by your flight controller. Sensor names can be found in EdgeTX under **Model → Telemetry → Discovered sensors**.

---

## Running the Emulator

A Python-based desktop emulator lets you preview and develop the widget without a physical radio.

### Prerequisites

- Python 3.8+
- `tkinter` (included with most Python distributions)
- `pygame`
- `lupa` (for Lua-driven mode that executes `main.lua` directly)
- `emulator.py` placed in the **same folder** as `launcher.py`

Install dependencies:

```bash
pip install pygame lupa
```

### Launch

```bash
python launcher.py
```

`launcher.py` locates `emulator.py` next to itself at runtime, so you can edit `emulator.py` freely without rebuilding anything. If `emulator.py` is missing, a dialog box will report the expected path.

Lua-driven mode:

- If `lupa` is installed, the emulator runs `main.lua` directly and hot-reloads visual/logic changes automatically.
- If `lupa` is not installed, it falls back to legacy Python-rendered emulation.

---

## Emulator Screenshots

The images below show the desktop emulator in all three display modes:

### Gauge Mode

![BF Telemetry Emulator - Gauge Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_gauge.png)

### Bar Mode

![BF Telemetry Emulator - Bar Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_bar.png)

### Numeric Mode

![BF Telemetry Emulator - Numeric Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_num.png)

---

## License

MIT — use freely, modify to suit your build.

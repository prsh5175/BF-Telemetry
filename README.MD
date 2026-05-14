# BF Telemetry Widget

An EdgeTX full-screen telemetry widget for the **Radiomaster TX16S MK III**, designed specifically for its 800×480 color LCD touchscreen. It displays 12 live Betaflight/ELRS telemetry tiles in a hex honeycomb layout, with TX and RX battery level bars on the side rails and a time-of-day clock in the top-right pit area.

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

### Recommended (Drag-and-Drop This Repo)

This repository now includes top-level EdgeTX SD folders:

```
WIDGETS/
SOUNDS/
SCRIPTS/
```

After downloading and unzipping, copy these folders directly to the root of your EdgeTX SD card.

Main widget path after copy:

```
/WIDGETS/BFTelem/main.lua
```

The repository also keeps a secondary prepacked mirror in `sdcard/` for release packaging workflows.

Square theme variant is also included at:

```
/WIDGETS/BFTelem/main.square.lua
```

If you want the square theme, replace `main.lua` with `main.square.lua`.

### Manual (Single File)

1. Copy `main.lua` into a new folder on your radio's SD card:
   ```
   /WIDGETS/BFTelem/main.lua
   ```
2. On the radio, navigate to **Screen Setup → Add Widget** and select **BF Telemetry**.

Only `main.lua` is needed on the radio for the default theme. The emulator files, screenshots, and launcher are development-only and do not need to be copied to the SD card.

---

## Layout Themes

Two layout variants are available. Choose the one you prefer by using the corresponding `main.lua`:

| Theme | File | Description |
|---|---|---|
| **Hex Honeycomb** *(default)* | `main.lua` | 12 flat-top hexagonal tiles in a staggered grid. Touchscreen tile reassignment, dropdown metric menu. |
| **Square Tiles** | `Other Themes/Square_tiles/main.lua` | Classic 4×3 recessed rectangular tile grid with cyan corner accents. |

Both themes support all three display modes (numeric / bar / gauge), TX and RX battery sidebar bars, and the same sensor/color logic.

To use the Square Tiles theme, copy `Other Themes/Square_tiles/main.lua` to your SD card instead:
```
/WIDGETS/BFTelem/main.lua
```

---

## Telemetry Tiles

The widget shows 12 tiles populated automatically from your ELRS/Betaflight telemetry stream:

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

The header bar shows model name, flight mode, armed/disarmed status, TX battery voltage, active display mode, and time of day.

---

## Widget Setup (Options Wizard)

When you first add the widget, open its **Options** panel on the radio (long-press the widget area while not in full-screen, or go to **Model → Screen Setup → Edit Widget**).

Set these values to match your aircraft and battery:

| Option | Default | Range | What to set |
|---|---|---|---|
| `Cells` | 4 | 1 – 8 | Number of LiPo cells (e.g. 4 for 4S) |
| `FullV` | 42 | 30 – 50 | Full cell voltage × 10 (42 = 4.2 V/cell; use 42 for standard LiPo) |
| `WarnV` | 36 | 30 – 42 | Warning voltage × 10 (36 = 3.6 V — tile turns yellow below this) |
| `CritV` | 34 | 30 – 42 | Critical voltage × 10 (34 = 3.4 V — tile turns red below this) |
| `LQWrn` | 70 | 10 – 99 | Link quality % below which LINK Q turns yellow/red |
| `SndEn` | 1 | 0 – 1 | Master sound alerts (`0` off, `1` on) |
| `SndArmd` | 1 | 0 – 1 | Play ARMED / DISARMED voice alerts |
| `SndBatt` | 1 | 0 – 1 | Play battery low/critical voice alerts |
| `SndRSSI` | 1 | 0 – 1 | Play low RSSI voice alerts |
| `RSSIWrn` | 90 | 60 – 120 | RSSI warning threshold in absolute dBm (e.g. 90 = -90 dBm) |
| `SndRpt` | 15 | 5 – 120 | Repeat period (seconds) while an alert condition persists |
| `TmrRed` | 180 | 30 – 900 | Flight timer (seconds) at which the timer tile turns red |
| `DistRed` | 100 | 20 – 2000 | Distance (metres) at which the DIST tile turns red |
| `ScreenType` | 0 | 0 – 2 | Display style: `0` = numeric, `1` = bar, `2` = arc gauge |
| `ThrOn` | 5 | 0 – 50 | Throttle % threshold to start the flight timer |
| `ArmSrc` | — | source | Optional: EdgeTX source for the arm switch/channel |

> **Tip:** If you fly 6S, set `Cells = 6`, `FullV = 42`, `WarnV = 36`, `CritV = 34`. All tile colours and percentages adjust automatically.

### Sound Files

**By default**, BF Telemetry uses existing **EdgeTX system voice files** for all announcements, so you get audio alerts automatically without any setup.

Voice file lookup order:

1. **Custom widget sounds** in `/WIDGETS/BFTelem/sounds/` (override EdgeTX system voices)
2. **EdgeTX system voices** in `/SOUNDS/en/` (default; built into EdgeTX)
3. **Tone beep fallback** (if neither above exists)

Default EdgeTX system voice mappings:

| Alert | System Voice | Fallback |
|-------|--------------|----------|
| ARMED | `armed.wav` | 2200 Hz tone |
| DISARMED | `disarmed.wav` | 1200 Hz tone |
| Battery Low | `bat1.wav` | 1300 Hz tone |
| Battery Critical | `bat0.wav` | 900 Hz tone |
| Low RSSI | `rssiloss.wav` | 1600 Hz tone |

**Optional:** To override with custom voices, place WAV files in `/WIDGETS/BFTelem/sounds/` with these names:
- `armed.wav`
- `disarmed.wav`
- `batlow.wav`
- `batcrit.wav`
- `lowrssi.wav`

The widget will use custom files in preference to EdgeTX system voices.

---

## Usage Instructions

### Switching Display Modes

The widget has three display modes, each showing the same 12 metrics in a different visual style:

- **`[ NUM ]`** — Numeric: large value text with label and unit.
- **`[ BAR ]`** — Bar graph: horizontal progress bar with compact value/unit text.
- **`[GAUGE]`** — Arc gauge: semicircular arc that grows with the value.

**On the radio (TX16S MK III):**
- Turn the scroll wheel to cycle through modes, **or**
- Long-press the scroll wheel (hold ~1 second) to open the tile assignment menu for the tile under the cursor.

**In the emulator:** Press `N`, `B`, or `G` on your keyboard.

---

### Reassigning Tiles (Touchscreen)

Each of the 12 hex tiles can be set to display any metric you want.

**On the radio:**
1. Touch and hold a hex tile on the touchscreen.
2. Wait until the **EdgeTX system logo in the top-left corner disappears** — this confirms the widget's touch UI has taken over (takes ~0.5 s).
3. A scrollable dropdown menu appears listing all available metrics.
4. **Scroll** by dragging your finger up or down inside the menu.
5. **Tap** any metric name to assign it to that tile. The menu closes immediately.
6. **Tap outside** the menu (anywhere on the hex grid) to dismiss without changing anything.

> The menu opens with the currently-assigned metric already highlighted so you can confirm what is assigned before changing it.

**In the emulator (legacy mode):** Click a tile to open the metric menu. Click a metric name to assign it, or click outside the menu to dismiss.

---

### Side Battery Bars

Two vertical bar graphs run along the left and right edges of the screen:

- **Left bar — RX batt:** Your drone's LiPo pack level, calculated from per-cell voltage using the `Cells` setting.
- **Right bar — TX batt:** Your radio's internal 2S LiPo level, estimated from the TX voltage.

Both bars use **10 color-coded segments**: green (top) → yellow (middle) → red (bottom). The percentage is shown below each bar. The bars update live during flight.

---

### Header Bar

| Region | Content |
|---|---|
| Far left | Model name (e.g. `AIR65`) |
| Center-left | Current Betaflight flight mode (e.g. `ANGLE`, `ACRO`) |
| Center-right | Armed / disarmed status |
| Far right | TX battery voltage · active display mode badge · time of day |

- **DISARMED** is shown in green. The flight timer shows `--:--`.
- **ARMED** turns red. The flight timer starts once throttle rises above `ThrOn`.

---

### Tile Color Semantics

| Color | Meaning |
|---|---|
| Green | Good / nominal |
| Yellow | Caution / approaching threshold |
| Orange | Warning |
| Red | Critical / threshold exceeded |

**High-is-good** (green at high values): Link Quality, Battery, RSSI, Cell Voltage, TX Power  
**High-is-bad** (red at high values): Current, Capacity Used, Throttle, Altitude, Distance  
**Timer**: green → turns yellow as it approaches `TmrRed` → red when it hits `TmrRed`

---

### Customizing Sensor Names

If your FC reports telemetry under different names, edit the constants near the top of `main.lua`:

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

Sensor names can be found in EdgeTX under **Model → Telemetry → Discovered sensors**.

---

## Running the Emulator

A Python-based desktop emulator lets you preview the widget without a physical radio.

### Prerequisites

- Python 3.8+
- `pygame` (required)
- `lupa` (optional — enables Lua-driven hot-reload mode)

```bash
pip install pygame lupa
```

### Launch

```bash
python dist/launcher.py
```

### Emulator Keyboard Controls

| Key | Action |
|---|---|
| `N` | Switch to Numeric mode |
| `B` | Switch to Bar mode |
| `G` | Switch to Gauge mode |
| `A` | Toggle armed / disarmed |
| `R` | Reload `main.lua` from disk (Lua-driven mode only) |
| `S` | Save a screenshot to `assets/screenshots/` |
| `Q` | Quit |

**Mouse:** Click any hex tile to open the metric assignment dropdown. Click a metric name to assign it. Click outside to dismiss.

### Lua-driven vs Legacy mode

- **Lua-driven** (requires `lupa`): runs `main.lua` directly; hot-reloads on every file save — edit and see changes immediately.
- **Legacy Python** (no `lupa` needed): Python-native renderer that mirrors the Lua layout and behavior.

### Generating Screenshots

To regenerate all three mode screenshots automatically (no window needed):

```bash
python dist/take_screenshots.py
```

Output is saved to `assets/screenshots/`.

---

## Screenshots

### Numeric Mode
Large value readout with label and unit. RX batt (left) and TX batt (right) bars are visible on the side rails, with the time shown in the top-right gap.

![Numeric Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_num.png)

### Bar Mode
Horizontal progress bars for at-a-glance percentage comparison across all tiles, while keeping value/unit text readable. RX batt (left) and TX batt (right) bars are visible on the side rails, with the time shown in the top-right gap.

![Bar Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_bar.png)

### Gauge Mode
Semicircular arc gauges that grow as the value increases. Arc color follows the metric's threshold semantics (green / yellow / red), with a consistent flat hex border style. RX batt (left) and TX batt (right) bars are visible on the side rails, with the time shown in the top-right gap.

![Gauge Mode](assets/screenshots/BF%20Telem%20lua%20screenshot_gauge.png)

> The **RX batt** (left) and **TX batt** (right) vertical bars are always visible on the side rails in all three modes.

---

## License

MIT — use freely, modify to suit your build.

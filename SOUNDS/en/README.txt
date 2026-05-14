This directory mirrors EdgeTX's /SOUNDS/en/ structure for custom voice overrides.

When you copy this SOUNDS folder to your SD card root, EdgeTX's built-in voices
in /SOUNDS/en/ will be used automatically by the BF Telemetry widget.

To override with custom voices, place WAV files here (optional):
- armed.wav
- disarmed.wav
- batlow.wav
- batcrit.wav
- lowrssi.wav
- lqlow.wav
- failsafe.wav
- distlmt.wav
- altmax.wav

If you don't provide custom WAVs, the widget will use EdgeTX system voices:
- armed, disarmed, bat0, bat1, rssiloss, siglow, fsact, warnng, tohigh

If no WAV is found, the widget falls back to tone beeps.

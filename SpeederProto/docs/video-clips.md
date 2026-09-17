# Video clips: capturing action shots for interludes and a splash (17 Sep 2026)

## What exists

The post pass already reads finished frames back from the GPU (`FrameCapture`, the P key,
`SPEEDER_CAPTURE_TIMES`), and demo mode advances the simulation by exactly 1/60 s per rendered
frame. `Rendering/VideoRecorder.swift` builds on both: while `PostProcessor.recorder` is set, every
composited frame is blitted to a CPU-visible copy and appended to an H.264 `.mov` through
`AVAssetWriter`, stamped with the game clock. In demo mode that clock is the fixed step, so the
clip is exact 60 fps even though the readback drops the app to maybe 20-30 rendered frames per
wall-clock second; in hand play it is wall-clock time, so the clip plays back at real speed with
whatever frame rate the Mac or phone managed.

Three ways in:

| Hook | Where the file goes | Use |
|---|---|---|
| `SPEEDER_RECORD=<start>,<end>` with `SPEEDER_DEMO=1` | `$SPEEDER_CAPTURE_DIR/clip.mov` (`SPEEDER_RECORD_NAME` renames) | scripted, repeatable shots; `Captures/video/record.sh <dir> <start> <end> ENV=...` |
| R key on the Mac | `~/Desktop/Speeder-<stamp>.mov` | hand-played shots with the pad |
| REC button in the HUD settings panel (both platforms) | phone: `Documents/` (visible in Files and in Finder) | shots played on the phone with the Backbone |

The HUD is SwiftUI and is not in the frame, which is what you want for an interlude: clean
footage, no meters. `SPEEDER_WINDOW=1920x1080` fixes the Mac window so the clip has a known size
(the ARView renders at the window's backing size; the `PostProcessor: source` log line prints it).
Bitrate is ~15 Mbit/s at 1080p60, so a 10 s clip is 15-20 MB; `.mov` files under `Captures/` are
git-ignored, keep the ones worth shipping somewhere deliberate.

## Shot list (all scripted, so they repeat exactly)

- **Neon City boost run**: `record.sh neon-boost 5 12` (the demo boosts from t = 6.5 to 11).
- **Conduit entry**: `record.sh conduit 3 9 SPEEDER_DEMO_BIAS=-0.45` takes the tunnel branch;
  the times from `docs/polish-log.md` (`p1/conduit`) still apply.
- **Sunset Canyon**: `record.sh canyon 4 12 SPEEDER_VARIANT=canyon`.
- **Fork from above**: `record.sh fork 3 8 SPEEDER_CAMERA=overview`.
- **The Grid, ramp chase**: `record.sh grid-ramp 4 12 SPEEDER_VARIANT=grid-snap SPEEDER_DEMO_SCRIPT=ramp SPEEDER_ARENA_START=-52,70,0 SPEEDER_ARENA_RIVAL=KADE`.
- **The Grid, crash**: `record.sh grid-crash 2 7 SPEEDER_VARIANT=grid-snap SPEEDER_DEMO_SCRIPT=crash`
  (derez burst and freeze-cam).
- **The Grid, overview of a box-in**: `record.sh grid-box 4 16 SPEEDER_VARIANT=grid SPEEDER_ARENA_RIVAL=ORIN SPEEDER_ARENA_START=-40,40,0 SPEEDER_ARENA_CAMERA=overview`.
- **Mission launch**: `record.sh launch 0 4 SPEEDER_MISSION=1 SPEEDER_RESET_PROGRESS=1` (the GO
  kick); with `SPEEDER_HOLD_BRIEFING=1` the avatar idles for a title card background.

## Where interludes would fit, and what they cannot cover

Load times in this game are short except one: the launch takes about 8 s of wall-clock before the
scene runs (procedural textures, the avatar). World and job changes rebuild behind the curtain in
well under a second. So:

1. **Splash / attract**: a looping clip behind the title while the launch work runs. Worth doing;
   it is the one real wait. It has to be a video the app plays, not the engine (the engine is what
   is loading).
2. **Job briefings**: the briefing card already holds the world; a 3-5 s establishing clip of the
   destination (conduit mouth, skyway, The Grid arena) before the avatar speaks gives context
   without any load to hide. Same for the result card (a replay-style clip of the derez).
3. **World transitions**: the curtain fade is enough functionally; a 1-2 s wipe clip is tone,
   not necessity.

Playback options in the app, cheapest first:

- SwiftUI `VideoPlayer` (AVKit) layered in `ContentView` above the `GameView`, shown while
  `curtain == 1` or during a briefing phase. Simplest; the HUD is already SwiftUI.
- `AVPlayerLayer` on the ARView's window for the splash, before the controller builds anything.
- RealityKit `VideoMaterial` on a quad in the scene (a billboard or the briefing hologram) if the
  clip should sit inside the world rather than over it.

Ship clips as HEVC (`hvc1`) to halve the size; the recorder writes H.264 for compatibility with
editors, and the export step (Compressor, `ffmpeg -c:v hevc_videotoolbox -tag:v hvc1`) is where to
downsize to 1280x720 for the phone.

## Not verified yet

This pass was written without a Mac: the code has not been compiled or run. Expected failure
modes if it misbehaves: an odd render height (the encoder needs even dimensions; the recorder
drops one row), or a target format other than BGRA8 (then the slow path through `FrameCapture`
tone-maps it; check that the colours match a PNG still from the same run).

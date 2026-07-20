# RetroPlugMac Build Plan: Native Apple Silicon Audio Unit for Logic Pro

**Fork**: https://github.com/fyne4247/RetroPlugMac  
**Upstream**: https://github.com/tommitytom/RetroPlug (original project; development resumed in 2026)
**Goal**: Native **arm64** AUv2 `.component` for Logic Pro — **no Rosetta**.

**Date**: July 2026  
**Status**: ✅ **AUv2 builds, installs, and passes `auval` on Apple Silicon**  
**Paid Apple Developer account**: **Not required** for local Logic use

---

## Resume here first

### What works right now

| Item | Status |
|------|--------|
| arm64 standalone APP | Builds (`build/xcode4/bin/x64/Debug/RetroPlug_app_x64.app`) — optional |
| arm64 **AUv2** | **BUILDS + `auval` PASS** |
| Installed path | `/Library/Audio/Plug-Ins/Components/RetroPlugMac.component` |
| Validate | `auval -v aumu 2wvF Tmtt` → **AU VALIDATION SUCCEEDED** |
| Arch | `Mach-O 64-bit bundle arm64` |
| Logic Pro | Installed; load as AU Instrument → fyne4247 → RetroPlugMac |

### AU identity (updated)

| Field | Value |
|-------|--------|
| Type | `aumu` |
| Subtype | `2wvF` |
| Manufacturer | **`Tmtt`** (was `tmtt`; auval requires ≥1 non-lowercase char) |
| Factory | `RetroPlug_Factory` |
| Entry | `RetroPlug_Entry` |
| Bundle ID | `com.fyne4247.audiounit.RetroPlugMac` |

### Rebuild + install (canonical)

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH="/opt/homebrew/bin:$PATH"
cd "/Users/fish4247/Claude Code Projects/RetroPlugMac-main"

# Use pinned premake 5.0.0-beta1 (./premake5-mac). Homebrew beta8 breaks iplug2.lua.
./premake5-mac xcode4
sed -i '' 's+/\* IGraphicsNanoVG_src.m \*/;+/\* IGraphicsNanoVG_src.m \*/; settings = {COMPILER_FLAGS = "-fobjc-arc"; };+g' \
  build/xcode4/RetroPlug-auv2.xcodeproj/project.pbxproj

# Host tool for embedded Lua (once, or when scripts change)
xcodebuild -workspace build/xcode4/RetroPlug.xcworkspace -scheme ScriptCompiler \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build
( cd build/xcode4 && ./bin/x64/Debug/ScriptCompiler ../../src/compiler.config.lua )

# Build AU
xcodebuild -workspace build/xcode4/RetroPlug.xcworkspace -scheme RetroPlug-auv2 \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build

# Package into real .component + install (premake emits a flat mh_bundle binary)
./scripts/package_au.sh Debug

# Validate
killall -9 AudioComponentRegistrar 2>/dev/null || true
auval -v aumu 2wvF Tmtt
```

Then **restart Logic Pro** → Software Instrument → AU Instruments → fyne4247 → RetroPlugMac.

If macOS blocks: System Settings → Privacy & Security → Open Anyway.

---

## Priority

**AU only.** Standalone APP is optional for debugging. Do not polish APP unless needed to debug AU.

---

## Phase log

### Phase 0 — Setup — DONE

Xcode 26.6, CLT switched via `xcode-select`, license accepted, first-launch components installed.

### Phase 1 — Native arm64 core — DONE

Key fixes retained for all targets:

1. No x86 SSE/AVX in `config/RetroPlug-mac.xcconfig`
2. `./premake5-mac` = premake **5.0.0-beta1**
3. `premake5.lua`: deps for xcode4; platforms `{ "x64" }`; `COMPILE_LUA_SCRIPTS=1`; **`iplug2.project.auv2`**
4. Boot ROMs in `src/generated/bootroms/` from SameBoy **v0.15.7** release (not rgbds 1.x)
5. `scripts/minizip.lua` — macOS system zlib only
6. sol2 + `optional<T&>::emplace` patch
7. SWELL: BOOL=bool on Apple; arm64 `objc_msgSend` not `_stret`
8. SameBoy/Core **not** in SYSTEM includes (NanoVG `<memory.h>` clash)
9. Renamed RetroPlug `AudioBuffer` → **`NodeAudioBuffer`** (CoreAudio name clash under AU)
10. Manufacturer OSType **`Tmtt`** for auval compliance
11. `scripts/package_au.sh` — wraps flat binary into `.component` + installs
12. `scripts/prepare_resources-mac.py` — Python 3 plist updater

### Phase 2 — AUv2 for Logic — DONE (validation)

- Implemented `iplug2.project.auv2` in `thirdparty/iPlug2/lua/iplug2.lua`
- Scheme: `RetroPlug-auv2`
- Product binary: `build/xcode4/bin/x64/Debug/RetroPlug` (mh_bundle arm64)
- Packaged: `build/xcode4/bin/x64/Debug/RetroPlugMac.component`
- Installed: `/Library/Audio/Plug-Ins/Components/RetroPlugMac.component`
- **`auval -v aumu 2wvF Tmtt` → AU VALIDATION SUCCEEDED**
  - Open/init, format, render (multi SR/buffer), MIDI: PASS
  - Plugin loads Lua (LSDj, Arduinoboy, RetroPlug components registered)

### Phase 3 — Logic Pro smoke test — NEXT (manual)

1. Open Logic Pro (Apple Silicon, no Rosetta).
2. New software instrument track → AU Instruments → fyne4247 → RetroPlugMac.
3. Load a legally obtained LSDJ ROM (dev-only copies may live under `LSDj/` — **do not redistribute**).
4. Confirm display + audio + MIDI clock / mGB notes as desired.
5. Save project; re-open; confirm state restore (ROM/.sav expectations per original README).

### Phase 4 — Polish (later)

- Metal graphics backend (still NanoVG+GL2)
- Fix premake postbuild product naming so packaging is automatic without path confusion
- Raise `MACOSX_DEPLOYMENT_TARGET` from 10.9 to something Xcode 26 supports cleanly (e.g. 10.13+)
- Universal binary (arm64 + x86_64) if desired
- Code signing + notarization (needs paid Developer ID for public distribution only)
- Feature parity checklist vs Windows VST2

---

## Test assets (read-only)

- `LSDj/` and `mGB-master/` — **test only**. Do not edit or ship ROMs.
- Final plugin must not bundle LSDJ/mGB binaries.

## License

Plugin code: MIT (upstream). Do not redistribute LSDJ (see license text in earlier plan revisions).

---

## Known caveats

1. Premake AU target still emits a **flat** mh_bundle named `RetroPlug`; always run `scripts/package_au.sh` after build.
2. Xcode may report **BUILD FAILED** if only the old postbuild copy path fails — check that `build/xcode4/bin/x64/Debug/RetroPlug` exists and re-run `package_au.sh`.
3. First open can take ~200–300 ms (Lua init); normal for this plugin.
4. Warning: “Preset name is not retained…” — non-fatal; state chunks are used (`PLUG_DOES_STATE_CHUNKS`).

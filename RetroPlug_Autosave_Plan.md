# RetroPlug Autosave and Recovery Plan

**Status:** Back burner — implement after the current Logic Pro save/reopen smoke test  
**Primary target:** Native arm64 AUv2 in Logic Pro  
**Guiding rule:** Never overwrite a user's original `.sav` or ROM without an explicit command.

## Goal

Give RetroPlug two complementary layers of persistence:

1. **Logic-managed project state** remains the canonical session save. Whenever Logic asks the Audio Unit to serialize, RetroPlug embeds the project, ROM data, SRAM, emulator state, and component state in the plugin state chunk.
2. **RetroPlug recovery autosaves** provide a separate crash-recovery safety net. They are stored outside the Logic project and can be restored explicitly from the plugin UI.

The recovery system should protect work if Logic, RetroPlug, or macOS crashes without silently modifying source ROM or `.sav` files.

## Before implementation

Verify the existing state path first:

- Load a ROM and make an obvious persistent change.
- Save the Logic project, close Logic, reopen it, and confirm restoration.
- Confirm the ROM, SRAM, emulator state, active instance, and Lua component state all return correctly.
- Repeat with two to four instances.
- Restore a Logic autosave or project backup and confirm its embedded RetroPlug state is usable.

If any of these fail, fix project serialization/restoration before building recovery autosave.

## User-facing behavior

### Default behavior

- Recovery autosave is enabled by default.
- RetroPlug takes a recovery snapshot only after meaningful state changes.
- Autosaving is debounced so continuous emulator activity does not write constantly.
- The original ROM and sibling `.sav` remain untouched.
- Normal Logic project saves continue to use the existing Audio Unit state-chunk mechanism.

### Suggested settings

Add a **Recovery Autosave** submenu containing:

- **Enabled** — on by default.
- **Save Recovery Now** — immediately creates a recovery snapshot.
- **Restore Recovery…** — lists compatible snapshots by time and ROM/project identity.
- **Open Recovery Folder…**
- **Retention** — 5, 10, 20, or 50 snapshots; default 10.
- **Autosave Delay** — 15 seconds, 30 seconds, 1 minute, or 5 minutes; default 30 seconds after the last detected change.
- **Delete Recoveries for This ROM…** — requires confirmation.

When RetroPlug detects a recovery newer than the state restored by Logic, show a non-blocking notice:

> A newer RetroPlug recovery is available.

Offer **Restore**, **Ignore**, and **Show Recoveries**. Never restore automatically over valid Logic project state.

## Storage location

Use the user's Application Support folder:

```text
~/Library/Application Support/RetroPlug/0.3/recovery/
```

Organize snapshots by a stable identity derived from the ROM contents rather than its filename:

```text
recovery/
  <rom-hash>/
    manifest.json
    2026-07-19T18-45-30Z.rpr
    2026-07-19T18-46-12Z.rpr
```

For multi-instance projects, use a project-set identity derived from the ordered ROM hashes and store all instances in one snapshot.

Do not place recovery data inside the `.component` bundle or beside the user's ROM automatically.

## Snapshot contents

Reuse the existing project serialization format where practical. Each recovery should contain:

- Format version and RetroPlug version
- UTC creation time
- ROM hash, display name, and model for each instance
- SRAM for each instance
- SameBoy save state for each instance
- RetroPlug project settings and selected instance
- Per-system Lua component state
- Audio and MIDI routing settings
- A checksum for every binary payload
- Optional source-ROM path as informational metadata only

Avoid duplicating copyrighted ROM data in routine recovery snapshots if restoration can safely use the ROM already embedded in Logic or selected by the user. If a complete self-contained recovery requires ROM bytes, make that behavior explicit and keep recovery files local-only.

## Change detection

Do not hash or serialize full SRAM on every audio block.

Preferred flow:

1. SameBoy or the audio-side model marks an instance dirty when cartridge RAM is written or when relevant project/component settings change.
2. The audio thread publishes only a lightweight dirty notification.
3. The UI/controller layer starts or resets a debounce timer.
4. Once the project has been quiet for the configured delay, the UI requests a consistent state snapshot through the existing message bus.
5. The completed snapshot is handed to a background file writer.

If SameBoy cannot cheaply signal cartridge-RAM writes, use a low-frequency SRAM hash outside the audio callback as a fallback.

## Threading model

No filesystem access, compression, JSON creation, logging, or heap-heavy serialization may occur in `ProcessBlock`.

```text
Audio thread
  marks dirty
      ↓ lock-free message
UI/controller thread
  debounce + request coherent state
      ↓ immutable snapshot
Background writer
  encode → checksum → temporary file → atomic rename → prune old versions
```

The state snapshot must represent one coherent point in time. Use the existing audio/UI message boundary rather than reading SameBoy memory concurrently.

The background writer should own its queued snapshot until writing finishes. Plugin destruction must either finish the current atomic write or cancel it before the final rename.

## Atomic-write and corruption safety

For every recovery:

1. Write to a unique temporary file in the destination directory.
2. Flush and close it.
3. Reopen or validate the container and checksums.
4. Atomically rename it to the final timestamped filename.
5. Update `manifest.json` using the same temporary-file-and-rename strategy.
6. Prune old snapshots only after the new one is confirmed valid.

Ignore incomplete temporary files during startup. Never delete the last known-good recovery while creating a new one.

## Logic project integration

Keep `SerializeState` and `UnserializeState` as the authoritative interface for Logic project saves, autosaves, and backups.

Add metadata to the serialized state when the format is next versioned:

- State format version
- Snapshot creation time
- Project-set/ROM identity
- Payload checksum

RetroPlug cannot force Logic to save or control Logic's backup schedule. It should simply return a complete, validated state whenever the host requests one.

Recovery autosave must remain independent of Logic's project package so it can help when the most recent host autosave is missing or corrupt.

## Restore rules

- Validate the container version, bounds, and checksums before changing the running project.
- Reject incompatible or truncated snapshots with a clear error.
- Restore into a temporary project/model first, then swap it into the audio thread through the message bus.
- If the required ROM is unavailable, prompt the user to locate it and verify its hash.
- Never partially restore one instance while silently failing another.
- Keep the pre-restore state in memory until the recovered state is confirmed running.
- Offer an immediate **Undo Recovery Restore** until another project-changing action occurs.

## Retention and cleanup

- Default: retain the ten newest valid snapshots per project-set identity.
- Optionally retain one daily snapshot for the previous seven days.
- Enforce a configurable global size ceiling, initially 500 MB.
- Prune oldest non-pinned snapshots first.
- Never perform pruning on the audio thread.
- Do not follow symbolic links while cleaning recovery directories.

## Privacy and distribution

- Recovery files stay local and are never included in plugin distributions.
- Do not upload recovery data or ROM hashes.
- Do not include anything under `LSDj/` or `mGB-master/` in the component or repository.
- Document that self-contained snapshots may contain copyrighted ROM data if that mode is ever supported.

## Implementation phases

### A. Prove existing host persistence

- Complete the Logic save/reopen and backup tests.
- Add malformed/truncated state-chunk tests.
- Version the project-state envelope if necessary.

### B. Recovery format and writer

- Define the versioned recovery container and manifest.
- Implement checksums and strict bounds validation.
- Implement background atomic writes and retention cleanup.
- Add standalone round-trip and interrupted-write tests.

### C. Dirty tracking and scheduling

- Add lightweight dirty notifications for SRAM and project/component changes.
- Add UI-side debouncing and snapshot requests.
- Ensure repeated changes coalesce into one pending write.
- Ensure shutdown safely handles an in-progress save.

### D. Recovery UI

- Add settings and manual save/restore actions.
- Add newer-recovery detection after Logic state restoration.
- Add restore confirmation, progress/error reporting, and undo.

### E. Stress testing

- One through four instances.
- Rapid SRAM changes during playback.
- Menus and ROM changes during a pending autosave.
- Logic project save while recovery writing is active.
- Forced termination during every write stage.
- Full disk, permission failure, and corrupt manifest.
- Moved/renamed ROMs and hash mismatch.
- Recovery created by an older RetroPlug version.
- Long sessions at multiple sample rates and buffer sizes.

## Acceptance criteria

The feature is ready when:

- Logic project save/reopen remains fully compatible.
- Recovery writes cause no measurable audio-thread blocking or dropouts.
- Killing the host during a write cannot destroy the previous recovery.
- A corrupt newest snapshot falls back cleanly to an older valid one.
- Retention limits work without touching unrelated files.
- Original ROM and `.sav` files never change without explicit user action.
- Recovery works for one through four instances.
- Release AU still passes `auval` after the feature is enabled.

## Deliberately deferred decisions

- Whether self-contained recoveries should include ROM bytes.
- Whether users may pin named recovery snapshots.
- Whether `.sav` export can optionally mirror to a user-selected folder.
- Whether a future standalone app shares the same recovery store.
- Whether recovery snapshots should be compressed or delta-encoded.

These decisions should wait until the basic Logic project persistence test and real-world recovery workflow are proven.

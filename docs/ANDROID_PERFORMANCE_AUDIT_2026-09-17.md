# Android intermittent freeze investigation — September 17, 2026

The strongest identified cause is synchronous build-library processing during
automatic private backup. A synthetic library reproduced 0.75-second stalls for
one saved build and 3.8-second stalls for five on macOS, without network requests.
The reported phone was probably a Galaxy S24, sound was off, pauses lasted 1–4
seconds, and the player was signed in with saved builds. Those conditions match
the affected path. This establishes a reproducible application bottleneck, not
yet a capture of the original Android incident.

## Trigger and blocking work

- `scripts/cloud/private_backups.gd:31`: automatic backup starts one second after
  detecting an account, is brought forward to at most three seconds after a
  queued save, and repeats 60 seconds after a successful sync. It has no active
  battle exclusion. Failed syncs retry with backoff starting at 15 seconds.
- `scripts/campaign/screen.gd`: level start, wave start, and nonfinal wave clear
  call `save_progress()`. `persist_slot()` writes the slot and queues backup.
- `private_backups.gd:121`, `:139`, and `:160` each call `cloud_entries()` during
  the same sync. Each scan rereads and decodes the library, even when nothing
  changed. The network `await` yields while waiting for a response; the local
  loops between responses still run synchronously on the game thread.
- `scripts/persistence/save_slots.gd:93` calls `shared_entry()` for every library
  file. `scripts/persistence/reusable_build.gd:124` parses the envelope, verifies
  its checksum, parses its payload, and deeply validates the entire build.
  Full Campaign builds include stats for 48 levels and their waves. The probe's
  normal all-Campaign rules export is 3,147,118 characters long.
- Incoming library entries are decoded again at `private_backups.gd:168`, before
  checking whether their content hash already exists locally. Large server
  response decoding also happens on the main thread in `cloud_service.gd`.

This explains the timing better than enemy deaths themselves: startup and wave
changes schedule backup work, while periodic sync and responses can land during
combat. A single sync can cause several separate pauses. Muting sound does not
prevent this work. Signed-out play would require another explanation.

## Measured evidence

Initial muted, headless run on macOS using Godot 4.7.2, current source, synthetic
files under `/private/tmp`, no live account and no network requests:

| Operation | Observed duration |
| --- | ---: |
| Rewrite default 48-level Campaign slot, five samples | 6.49–6.91 ms |
| Read and hash three default Campaign slots, five samples | 6.79–6.96 ms |
| Scan one all-Campaign rules build, five samples | 747.50–754.71 ms |
| Scan five all-Campaign rules builds, three samples | 3,793.76–3,807.48 ms |
| Early-level combat, 1,186 ticks and 24 kills | median 0.174 ms; p99 0.354 ms; max 0.877 ms |

These are CPU-side desktop measurements, not Android frame rates. The combat
sample does not cover late levels, every tower/gear combination, or rendering.
The fixture builds differ by title and contain normal complete Campaign rule
exports, with one tower damage override; they are not the player's actual files.

`tools/campaign_stall_probe.gd` makes isolated synthetic slots/library files and
uses the existing fake cloud boundary for full-sync diagnostics. Run muted:

```sh
/Users/kaiser/Downloads/Godot.app/Contents/MacOS/Godot \
  --headless --audio-driver Dummy --path . \
  --script tools/campaign_stall_probe.gd
```

## Suggested fix, in priority order

1. **Stop repeatedly decoding unchanged builds.** Give the shared library owner a
   validated index containing content hash, metadata, and backup status. Populate
   it on successful save/import and invalidate it on replacement/deletion. Scan
   once per sync and reuse the result. For immutable content already validated
   under the current format/catalog version, use its cached result; retain full
   validation for new, changed, migrated, or untrusted content. Do not use a
   filename alone as proof of valid content.
2. **Keep heavy backup preparation off the game thread.** Use an owned worker for
   file reading, JSON, checksums, and pure validation on independent snapshots.
   The current validators touch lazy shared catalog/schema caches; initialize
   and make those read-only, or provide worker-owned validation data first.
   Keep scene-tree access and completion delivery on the main thread. Preserve
   account generation checks, revision/conflict handling, deletion rules, and
   checksummed atomic saves. `call_deferred()` alone only moves the same stall
   to another frame; yielding between files still permits a 0.75-second file
   stall and is insufficient by itself.
3. **Gate automatic sync preparation during active battles.** As a short-term
   mitigation, retain pending work until a safe menu/planning point and also
   guard continuations of syncs already in flight. This does not replace local
   durability or the worker/cache fix, and must not silently discard backups.
4. **Avoid slot writes when durable content has not changed.** Mid-wave state is
   intentionally not persisted, yet wave boundaries still rewrite the complete
   slot and change sequence/timestamp, which changes its backup fingerprint.
   Track meaningful dirty state; persist victories, equipment, configuration,
   and relevant lifecycle changes. Keep errors/recovery behavior intact.
5. **Warm artwork before combat.** `actor_images.gd:67` loads missing textures
   synchronously from its draw path. Request the selected level's assets in
   advance and obtain them only once ready; hold references for the run. This is
   a separate first-use hitch candidate, not the measured multi-second cause.

Godot documents that ordinary resource loads block and that prematurely calling
`load_threaded_get()` also blocks. Its thread-safety guidance excludes active
scene-tree access and warns about shared resources and GPU synchronization:
[background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html)
and [thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html).

## Acceptance before calling it fixed

Capture frame timing on the affected Android build/device with sound off and
the player's typical library size. Exercise level entry, actual kills, wave
clear/start, victory, and at least two automatic backup intervals. Compare signed
in versus signed out using preserved local saves. Time local library decoding,
slot writes, response parsing, first-use texture loads, and combat separately.

Verify the optimized unchanged sync performs no full-library decoding, changed
builds validate once and still back up, and concurrent edits/account changes
cannot commit stale results. Exercise corrupt files, failed writes, recovery,
cloud conflicts, deletes, restore, and backgrounding. Check frame-time tails and
longest frame, not only average FPS. Test at upright portrait phone sizes.

This task supplies diagnosis, measurements, a reproducible probe, and a proposed
fix. It does not implement or release the runtime optimization.

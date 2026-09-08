# Player change log

Main menu → Settings → Change log (immediately below Bug report) reads the live Supabase `public.change_log` table. It needs no sign-in. Each card contains one short change in 18-unit text, without a visible date. Dates remain in the backend for newest-first ordering and publication. Refresh reads the latest rows; Load older changes retrieves the next page without losing existing rows after a connection error. Back returns to Settings.

## Adding changes

Open the Hollow Vigil project in Supabase → Table Editor → `change_log` → Insert row. Enter a short, non-technical sentence in `summary` and save. The date defaults to today in America/Chicago and `published` defaults to true. ID and creation time are automatic; leave `source_commit` empty for manual entries. Players see the row when they open or refresh Change log. Set `published` to false to hide an entry, or choose a future `change_date` to publish on that day. Keep each sentence within 300 characters.

Only backend administrators can write rows. Anonymous and signed-in players have read-only access to published entries whose date has arrived. `read_change_log` runs with the caller's permissions and returns at most 31 records (30 displayed plus a next-page check). Pagination uses date, creation time, and ID.

## September 8 import

All 69 commits reachable from main at request start (`4296367`) whose commit date falls on September 8, 2026 in America/Chicago were reviewed. `supabase/change_log_20260908.json` contains only the 46 commits with player-visible changes, each with its own row and unique source hash. The 23 testing, release-record, and upkeep commits are omitted entirely. Historical intermediate UI changes remain individual rows as requested. No earlier day's commits are imported.

`tools/seed_change_log_20260908.py` reproduces the reviewed seed, without uploading it. The unique `source_commit` prevents duplicate imports. This is a one-time reviewed import, not automatic publication of future Git commits.

Validation: `tests/rendered/change_log_runner.gd` covers navigation, three portrait sizes, pagination, empty/error/malformed responses, and refresh. Add `-- --live` to verify the actual production feed. Physical iOS/Android testing remains separate.

Verified September 8: 234 rendered checks passed, including the production feed through Godot at 360×640, 390×844, and 540×960 (live feed at 540×960). Screenshots were visually inspected. Database contract checks passed for anonymous and signed-in read access, hidden/future rows, and denied write permissions; Supabase security advisors returned no findings. The live table contains exactly 46 published rows, all dated September 8. The restricted run could not reach the backend; the network-enabled rerun passed.

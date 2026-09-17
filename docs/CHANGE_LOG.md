# Player change log

Main menu → Settings → Change log (immediately below Bug report) reads the live Supabase `public.change_log` table. It needs no sign-in. Changes are grouped under date headings such as September 8th, with one bullet per change in 18-unit text and no individual cards. Older years include the year in their heading. Dates also control newest-first ordering and publication. Refresh reads the latest rows; Load older changes retrieves the next page without losing existing rows after a connection error. Back returns to Settings.

## Adding changes

Open the Hollow Vigil project in Supabase → Table Editor → `change_log` → Insert row. Enter a short, non-technical sentence in `summary` and save. The date defaults to today in America/Chicago and `published` defaults to true. ID and creation time are automatic; leave `source_commit` empty for manual entries. Players see the row when they open or refresh Change log. Set `published` to false to hide an entry, or choose a future `change_date` to publish on that day. Keep each sentence within 300 characters.

Only backend administrators can write rows. Anonymous and signed-in players have read-only access to published entries whose date has arrived. `read_change_log` runs with the caller's permissions and returns at most 31 records (30 displayed plus a next-page check). Pagination uses date, creation time, and ID.

## September 8 import

All 69 commits reachable from main at request start (`4296367`) whose commit date falls on September 8, 2026 in America/Chicago were reviewed. `supabase/change_log_20260908.json` contains only the 46 commits with player-visible changes, each with its own row and unique source hash. The 23 testing, release-record, and upkeep commits are omitted entirely. Historical intermediate UI changes remain individual rows as requested. No earlier day's commits are imported.



Verified September 8: 282 rendered checks passed across 360×640, 390×844, and 540×960, including date grouping across pages and the production feed through Godot at 540×960. Screenshots were visually inspected. Database contract checks passed for anonymous and signed-in read access, hidden/future rows, and denied write permissions; Supabase security advisors returned no findings. The live table contains exactly 46 published rows, all dated September 8. The restricted run could not reach the backend; the network-enabled rerun passed.

## September 16 import

Reviewed all 20 commits dated September 16, 2026 in America/Chicago through `768487c`. `supabase/change_log_20260916.json` records 15 published player-facing entries, matching the live log's short, non-technical sentences and one source commit per row. Commit timestamps preserve newest-first ordering within the September 16 heading. Existing September 8 rows were left untouched.

The five omitted commits are documentation-only updates (`0948664`, `ace2d6c`), a test-only correction (`baeceda`), the removed temporary button-palette selector (`948a2ad`), and removal of the temporary Windows build (`63d353d`). Mixed commits describe their retained player-facing effects; draft story plans, temporary Windows support, and removed palette selection are not advertised as available features.

Verified the live table contains 15 unique, published September 16 entries and the original 46 September 8 entries. The anonymous `read_change_log` HTTP endpoint returned all 15 new summaries in the expected order, followed by older entries. Each new summary is within the 300-character limit. No game code or database schema changed.

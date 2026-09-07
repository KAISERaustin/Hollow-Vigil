# Repository instructions

## UI standard for all future work

- Before adding or changing UI, read [docs/UI_STYLE_GUIDE.md](docs/UI_STYLE_GUIDE.md). Version 2, **Parchment cards**, is the default for future UI requests unless the user explicitly changes the direction. Its visual reference is [docs/references/ui-waves-reference.png](docs/references/ui-waves-reference.png), supplied by the user on September 7, 2026.
- Preserve the reference's clean cards, compact spacing, bold values above clear labels, and actual game portraits beside identity information when applicable. Use its layout and information hierarchy across new screens, not only Waves.
- Every visible UI enclosure uses the same black border: `VigilInterface.OUTLINE` = **3 UI units**, color `#000000`. Panels, cards, stat cells, buttons, fields, badges and dividers must not introduce heavier local borders or thicken on interaction. Keep rectangular corners at 4 units (0 for edge-to-edge chrome). World artwork contours remain governed by `docs/ART_DIRECTION.md`.
- Compose shared helpers in `scripts/ui/shared/interface.gd` and reusable presentation components in `scripts/ui/shared/`; extend those owners before introducing local styles. Use 12-unit card padding, 8-unit inset padding and cell gaps, and 12-unit internal section/action gaps. Keep screen controls at least 48 units high and preserve responsive reflow, scrolling, and input ownership.
- The new guide supersedes older conflicting instructions about mixed border weights, borderless statistics, or flat UI backgrounds. Keep the guide, its HTML companion, shared tokens, and `docs/ART_DIRECTION.md` consistent. Validate UI work with the relevant rendered checks and visually inspect the result at phone sizes.

## Reusable node system for every addition

- This is the default architecture for **everything added to the game**, not just attributes: entities, mechanics, abilities, effects, gear, enemies, bosses, towers, levels, world features, progression and the systems connecting them. Integrate each addition into the reusable node/component structure, or introduce a reusable node family when needed. Do not build isolated, one-off implementations that future mechanics cannot reuse.
- Before implementing an addition, identify its reusable node/category, its shared rules and its composable parts. Reuse or extend existing nodes first; define new behavior in reusable objects, then assign or compose those objects where needed. Make future reassignment, combination and extension straightforward.
- Build future game content around the hierarchy in `scripts/content/` and the extension guide in `docs/NODE_SYSTEM.md`. Shared categories such as Tower, Enemy, Boss, Gear and Level define common identity and rules; specific types inherit those foundations. Boss is an Enemy subtype, and towers share their plus-sign placement rules.
- Implement new optional mechanics, abilities, modifiers and other reusable attributes as **attachable attribute/component objects**. Define a behavior once so the same object can be assigned to one content type or several different types. Prefer composition for these capabilities instead of adding type-specific conditionals to a common parent or copying behavior between subclasses.
- Attaching an attribute must affect only its assigned recipients. Do not mutate the shared parent, sibling types or unrelated game sessions. Keep shared attribute configuration separate from mutable per-instance state: timers, counters, cooldowns and effect progress belong to each spawned/placed instance, even when several types share the same attribute object.
- Support explicit attachment, replacement and removal through the owning system. Clean up removed effects and reset attribute state when instances are recycled. Apply this pattern across enemies, bosses, towers, gear, levels and future content families where a capability can be shared.
- Connect attributes to actual gameplay through the existing simulation/service boundaries. Keep transactions, save validation and rendering in their respective owners. Verify that an attribute works on multiple assigned types, leaves unassigned types unchanged, and does not share runtime state between instances; add persistence coverage when its configuration or state is meant to survive saves.
- Treat examples offered to explain this architecture as design context, not authorization to add that example mechanic or change game balance. The user's September 6, 2026 example of an enemy periodically walking faster describes the desired reuse model; it is not a request to add a speed-boost ability.

## Preferred TestFlight upload method

- Prefer Xcode Organizer for uploading iOS archives: open the current `.xcarchive` in Xcode, choose **Distribute App → App Store Connect → Distribute**, and use the existing signed-in developer account. The user explicitly requested this preference on September 6, 2026 after Organizer succeeded while `xcodebuild -exportArchive` failed with an App Store Connect credentials error.
- Command-line Godot export and `xcodebuild archive` are suitable for preparing the archive. After Organizer confirms **Uploaded to Apple**, verify processing in App Store Connect and assign the new build to the existing **Just for Testing** group. An upload alone does not complete a TestFlight release.

## Commit and push after every chat

- At the end of every chat/task in this repository, commit all pending repository changes and push all local commits to `origin/main` before the final response. This applies even when the chat itself made no file changes. This is standing user authorization; do not ask for routine commit/push confirmation. Follow an explicit instruction in the current chat not to commit or push.
- Include all staged, unstaged, and untracked non-ignored files, regardless of which chat created them, whether they are related to the current task, or whether they are finished. Do not leave changes out because of ownership, scope, or a preference for granular history. Blanket staging with `git add -A` is authorized. Do not force-add ignored files.
- Use a descriptive commit message covering the pending work. If there are no pending changes, no empty commit is needed; still push any unpushed commits.

## Concurrent chats and preservation

- Inspect the branch, working tree, and staged changes before editing and immediately before committing. Review the staged diff so the commit's contents are understood; existing staged changes are included under this policy.
- Preserve all work. Never discard, overwrite, reset, clean, stash, or amend another chat's changes to make delivery succeed. Do not delete an active Git lock or switch branches under another active chat.
- Include concurrent changes available at staging time. After pushing, recheck for additional pending changes and deliver them when possible. If ongoing edits or another concrete blocker prevent a clean final state, report exactly what remains rather than silently excluding it.

## Delivery to main

- Run appropriate validation and inspect the diff for errors. Validation failures or unfinished work must be reported honestly, but do not by themselves justify withholding the requested commit and push.
- Fetch and inspect `origin/main` before delivery. On `main`, push normally after inspecting outgoing commits. On another branch, safely integrate all pending changes and unpushed work onto current `origin/main`, using an isolated worktree when the shared checkout is busy. Do not exclude work merely because it came from another chat.
- If a push is rejected because remote main advanced, fetch again, safely integrate the new history while preserving all work, rerun affected checks, and retry. Never force-push or rewrite published main history. Resolve conflicts only when the intended result is clear; otherwise preserve the work and report the specific blocker.
- Verify that the delivered commit is present in remote `main` (newer commits may be above it). In the final response, state the commit hash, push status, relevant validation, and anything still pending or blocked.
- If permissions, authentication, network access, branch protection, active locks, or unresolved conflicts prevent delivery, preserve the work and explain exactly what remains. Never claim a commit or push succeeded without verification.

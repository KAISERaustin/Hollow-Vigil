# First-time field guide

The tutorial borrows the supplied reference's teaching structure: one idea, a
short explanation, native game illustrations, and one clear continuation. It
uses Pickard's existing dark UI theme, not the reference game's parchment art.

- First planning screen: drag a tower onto clear ground and protect the core.
- After placing a tower: starting waves, earning gold, wave information and pause.
- After clearing a wave: tower management and placement strategy.
- First visit to a tower/tier milestone: the unlocked tower's portrait, role and
  next action. All eight families, tiers 1–3 and tier-4 specialization are covered.
- Before starting a wave: unseen enemies and bosses, grouped into one card with
  native portraits and catalog descriptions. Start wave continues the requested
  action; Back dismisses the information without starting combat.

Tips only interrupt planning. A modal freezes simulation without changing the
player's pause setting. Automatic basics have a 12-second dismissal cooldown and
wait until placement and other dialogs finish. Discoveries are tied to entering
a milestone or requesting a wave, not an accumulating popup queue.

Got it, Back and Skip all tips save learning history in `user://tutorials.cfg`.
It is shared by the device's three save slots and both play styles, outside
Campaign saves, builds, backups and progress resets. Skip all also suppresses
future lessons. Reinstalling/removing local app data removes this history; it is
not synchronized between devices. A failed history write is reported and the
current session still remembers the dismissal.

`campaign/tutorial_catalog.gd` owns immutable lesson definitions and resolves
encounters from the current authored/custom wave. `tutorial_history.gd` owns
per-device persistence. `ui/shared/tutorial_popup.gd` owns the reusable modal,
native portraits, fixed actions and scrollable body. `campaign/screen.gd` supplies
context and keeps gameplay, pause and navigation ownership.

Automated app fixtures with `load_saved_progress=false` suppress tips by default;
the dedicated runner explicitly enables them with isolated history paths.
Run `./launch.ps1 -TestScript tests/rendered/tutorial_runner.gd` for persistence,
all unlock milestones, portrait layout, pause, dismissal and start-wave checks.
Screenshots are written under ignored `artifacts/tutorial-*.png`. These are
desktop rendered checks, not physical phone acceptance.

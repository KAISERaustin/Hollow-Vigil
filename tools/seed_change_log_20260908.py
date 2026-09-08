"""Build the reviewed September 8 (America/Chicago) seed; never upload implicitly."""
import datetime
import json
from pathlib import Path
import subprocess

# One short player-facing sentence per commit that actually changes the game.
SUMMARIES = {
    '4296367': 'Tower range circles disappear as soon as you close the tower menu.',
    '606e162': 'Tap anywhere to dismiss wave rewards.',
    '734919f': 'Tower upgrade choices now have neatly centered pictures and prices.',
    'b9e4a01': 'Preview a tower\'s new attack range before upgrading.',
    '45c1313': 'Tower upgrade choices take up less screen space.',
    '3e3ffe2': 'Other menu buttons respond on the first tap while a tower is selected.',
    'a085a81': 'Tower upgrade choices show clear pictures and prices without repeated cost text.',
    '42798aa': 'Tap the battlefield to close the tower menu.',
    '29f03a6': 'Tower portraits, levels, and action buttons line up more neatly.',
    'bca858d': 'Tower level bubbles fill from the bottom upward.',
    '7482a83': 'Tower build cards stay visible after a campaign victory.',
    '7590729': 'Tower controls use a smaller layout with illustrated level bubbles.',
    '4dc2451': 'The tower menu adjusts to fit its contents.',
    '5866d4a': 'Drag a new tower from the toolbar while another tower is selected.',
    '0853a88': 'Place towers closer to roads without blocking them.',
    '2490dde': 'Manage towers from a compact card at the bottom of the screen.',
    'bdcabbc': 'Campaign victory messages are shorter.',
    'bea44e1': 'Wave reward messages disappear sooner.',
    '411bb61': 'Tower placement markers line up with the tower preview.',
    '6f1ad76': 'See a tower\'s attack range while dragging it into place.',
    'ec31d6a': 'Leaving a campaign battle asks you to confirm discarding the attempt.',
    'c88cd47': 'Campaign saves correctly keep towers placed on open ground.',
    'cf1541c': 'Tower details stay open until you drag the tower portrait.',
    '8e690d9': 'Drag the tower portrait to start placing it.',
    'a928fc5': 'Tower and enemy artwork has been refreshed.',
    'ec34ab1': 'Tower build previews show less clutter.',
    '0e26fcc': 'Tower details slide above the compact build strip.',
    '22f36d0': 'The wave button keeps the same Start wave label.',
    'ec2b7e3': 'Creative campaign maps show completed levels and your current destination.',
    '8574c96': 'Creative campaigns remember which levels you have beaten.',
    'a236644': 'Tower build cards stay visible while battles run more efficiently.',
    'ecea0ac': 'Coin symbols sit neatly beside currency amounts.',
    '351ac93': 'Currency amounts fit more neatly in the battle display.',
    'a993eca': 'Coin symbols are easier to read beside prices.',
    '679f14e': 'Restarting a campaign level restores its original starting conditions.',
    'a8082a8': 'Customize the rules for individual Creative campaign levels.',
    '01e0ff3': 'Overlapping towers appear in the correct order.',
    '8a8554e': 'Tower placement scrolls the view near the screen edges.',
    '2a7576b': 'Choose towers from a sliding build menu.',
    '12b6f93': 'Drag towers onto open ground in Campaign and Infinite.',
    '41d232b': 'Four level markers show how far a tower has been upgraded.',
    'c5a0b28': 'Tower build choices show simpler previews.',
    '087ef1c': 'Campaign battles show the level number with a less crowded status display.',
    'a1e3d2e': 'Campaign maps feature refreshed scenery across all six regions.',
    '38e9bd5': 'Send a private bug report from the main menu settings.',
    '1dd6517': 'Back buttons return to the correct screen without skipping menus.',
}

def main():
    cutoff = '4296367'  # Complete main history at the start of this request.
    lines = subprocess.check_output(['git', 'log', cutoff, '--format=%H|%cI|%s'], text=True).splitlines()
    rows = []
    zone = datetime.timezone(datetime.timedelta(hours=-5))
    for line in lines:
        commit, timestamp, subject = line.split('|', 2)
        date = datetime.datetime.fromisoformat(timestamp).astimezone(zone).date()
        if date.isoformat() != '2026-09-08':
            continue
        summary = SUMMARIES.get(commit[:7])
        if summary is None:
            continue
        rows.append(dict(source_commit=commit, change_date=str(date), created_at=timestamp,
                         summary=summary, published=True))
    assert len(rows) == 46
    assert len({r['source_commit'] for r in rows}) == len(rows)
    assert all(len(r['summary']) <= 300 for r in rows)
    Path('supabase/change_log_20260908.json').write_text(json.dumps(rows, indent=2) + '\n', encoding='utf-8')
    print(f"Reviewed 69 commits: {len(rows)} player-facing rows; omitted 23 non-gameplay commits.")

if __name__ == '__main__':
    main()

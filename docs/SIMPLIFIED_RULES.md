# Simplified rules

Enemy and boss abilities and their four resistances are inactive, including assignments in older saves. Their editor exposes health, speed, rewards, and core damage. Tower stats remain editable; ability and attribute editing is unavailable. Built-in tower attacks and specializations remain active. Levels are unchanged. Portals are absent from Edit rules.

Gear cannot be acquired, equipped, or applied to tower stats or attacks. Gear buttons remain visible and disabled. Legacy gear definitions and save fields remain readable for compatibility. Source images are retained in `assets/retained_gear/`; procedural artwork remains under `scripts/rendering/actors/gear/`.

Run `tests/simplified_rules_runner.gd` for removed mechanics and legacy assignment coverage, and `tests/rendered/rules_navigation_runner.gd` for portrait editor navigation, saved edits, and level settings.

# Editing each tower's placement collider

All eight towers have separate, square placement colliders. Each starts at
36 x 36 world units and can be adjusted without changing another tower.
All tiers and both branches of a tower share that tower's collider.

## Adjust it in Godot

1. Open `scenes/tools/tower_placement_colliders.tscn` in the **2D** editor.
   This authoring sheet shows all eight towers with translucent green colliders;
   the white cross marks each tower's ground anchor.
2. Select the named tower node in the Scene tree. In the Inspector, expand its
   **Collider** resource, then expand **Shape**.
3. Change **Size → X** (width) and **Size → Y** (height). Use matching values
   for a square, such as **24 x 24** or **40 x 40**. Unequal values give a rectangle.
4. Adjust the collider resource's **Offset** to move the shape relative to the
   ground anchor: positive X is right, positive Y is down. **Rotation Degrees**
   rotates it around its center. Values use world units, independent of zoom.
5. Save the external `.tres` resource using the Inspector's resource Save action,
   then restart the running game. The green preview updates while you edit.
   Test building and moving near another tower, a road, a portal and a map edge.

You can also select the `.tres` file directly in the FileSystem dock and edit
the same properties. Change the **Collider resource**, not the preview Node2D's
position/scale/rotation; node transforms only arrange/enlarge the authoring sheet.
The overlay is for inspection; resizing is through the Inspector fields.
Keep each tower's existing external resource separate; assigning another tower's
resource would deliberately make those towers share their configuration.

| Tower | Resource |
| --- | --- |
| Gloamwatch | `assets/placement_colliders/gloamwatch.tres` |
| Pyre | `assets/placement_colliders/pyre.tres` |
| Obelisk | `assets/placement_colliders/obelisk.tres` |
| Stormspire | `assets/placement_colliders/stormspire.tres` |
| Ironspike | `assets/placement_colliders/ironspike.tres` |
| Moonwheel | `assets/placement_colliders/moonwheel.tres` |
| Hex Lantern | `assets/placement_colliders/hex_lantern.tres` |
| Caltrop Keep | `assets/placement_colliders/caltrop_keep.tres` |

## Placement behavior

- Tower-to-tower placement compares both actual shapes, including offsets and
  rotations. Enlarging one affects its spacing against every other tower.
- Road exclusion is a capsule along each road segment; portals use circles.
  The tower's shape must clear these exclusion shapes and fit inside map bounds.
- Defaults are separate 36 x 36 squares with zero offset/rotation. Shared road
  radius 8 and portal radius 30 retain the old 26/48-unit axial center clearances.
  Square corners now block diagonal overlaps that the former circles permitted.
- Colliders do not change artwork, attack range, targeting, or weapon rotation.
- The build preview and purchase use the same economy check. Moving uses the
  moving tower's collider and ignores its own previous position; it still checks
  every other tower. Invalid purchases/moves spend no gold.
- Missing/unsupported/invalid shapes reject placement. Circles and capsules are
  supported if explicitly selected using Shape's dropdown; all eight defaults
  remain square. Shape dimensions must be finite and positive.

Campaign checkpoints and imported builds validate ground placements against the
current resources. Enlarging a collider or switching from circles to squares can
make an older ground setup invalid. Test on a new setup before adjusting resources
used by an existing saved layout. Legacy authored socket saves retain their
existing compatibility exception. New purchases and moves, including legacy
socket destinations, use the colliders. Configuration lives in project resources,
not player saves.

## Ownership and checks

`placement_colliders.gd` registers resources on Tower content nodes through the
replaceable `placement_collider` rule, inherited by tiers and branches.
`placement_collider.gd` owns geometry; `ground_placement.gd` composes it with
territory, roads, portals and bounds. Economy owns transactions; persistence
calls the same geometry. No physics scene or frame delay is needed for checks.

```powershell
./launch.ps1 -TestScript tests/placement_collider_runner.gd -Headless
./launch.ps1 -TestScript tests/campaign_ground_save_runner.gd -Headless
./launch.ps1 -TestScript tests/rendered/placement_collider_preview_runner.gd
./launch.ps1 -TestScript tests/rendered/ground_build_retry_runner.gd
```

The wide collider sheet is an artwork authoring view, not a device orientation.
Gameplay remains upright portrait.

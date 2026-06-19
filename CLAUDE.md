# Commander — project context

A multiplayer-capable **Napoleonic-era battle & campaign simulator** in **Godot 4.6.3 / GDScript**.
You command a battalion as a **mounted officer in third person**; battles of up to ~140k men render
through a handful of MultiMeshes. The campaign world and the tactical battle are now **one scene**
(`game.tscn` / `game.gd`) — you ride a living province and battles inflate in place.

## Vision / goals
- **MP-first living-world campaign** (colonial North America), no time acceleration in multiplayer.
- **Third-person always**: the player is the mounted officer; ride the world in 3rd person, battles
  inflate in place; the overhead map (`M`) is a dev/read-out aid, not the main view.
- Operational depth (brigades garrison towns, march, give battle), tactical drama, musketry realism.

## Layout
- Main scene: `menu.tscn` → `game.tscn`. (`world.tscn`/`world.gd` is the **deprecated** old campaign
  scene — no longer used; everything is one scene in `game.gd` now.)
- Key scripts: **`scripts/game.gd`** (the whole sim — very large), `scripts/menu.gd` (menu +
  character creation), `scripts/game_config.gd` (autoload), `scripts/net.gd`, `scripts/battle_setup.gd`.
- `.godot/` import cache is gitignored (Godot regenerates it).

## THE AFFORDABILITY KEYSTONE — do not break
The army (≤70k men/side) renders through **one MultiMesh per team + a GPU shader that animates by
VERTEX POSITION BANDS** (legs `y < -0.05` swing about the hip; arms `|x| > 0.215` swing about the
shoulder `y = 0.45`) **and colours by position** (height bands + a crossbelt formula). **No skeletons
or skinned meshes** — they cannot run at that count. Per-instance data carries dress packed in
`COLOR.a`, facing in `COLOR.rgb`, and animation state in `INSTANCE_CUSTOM`. This constraint is why
detailed per-bone characters are impossible for the masses.

## Soldiers — PROCEDURAL (settled decision)
The infantry are a **fully procedural** detailed line-infantryman built in code:
- `_soldier_mesh()` — ~30 box/cylinder primitives: tapered shako + brass band + peak + plume, head,
  stand collar + faced plastron + cuffs, coat with tails, white crossbelts (shader-drawn), white
  overalls over dark gaiters, knapsack + blanket on the back.
- `_soldier_shader()` — colours every part **by vertex position**, animates legs/arms by band, and
  **morphs the headgear** (shako / round hat / bicorne) per battalion from the packed dress.
- **Blender-built soldier `.glb` models were tried hard and ABANDONED** — they rendered as solid blue
  cubes (a joined-mesh issue never fully explained; the position-based procedural path is the one that
  reliably renders). Do **not** reintroduce Blender meshes for the masses without a new idea.

## The player's mounted officer — PROCEDURAL (settled decision)
`_build_officer()` builds the hero **procedurally in code** (`_build_officer_colonel()` for the rider,
`_build_horse()` for the charger + tack) — primitive meshes, like the soldiers, not a Blender import.
(`models/officer_hero.glb` is the old Blender-built hero asset; it's no longer loaded and is kept on
disk only in case it's useful later.) The hero reads as a **Colonel**: gorget, crimson waist sash, gold
fringed epaulettes on both shoulders, an aiguillette, and a gold-piped, tall-plumed bicorne, over a coat
in the player's militia colour with facing-coloured collar/lapels/cuffs/cockade. The charger carries a
leather saddle and a gold-piped shabraque in the militia's facing colour. This is a **single instance**
(not a MultiMesh) so it can carry far more primitives/detail than a soldier — only the 70k masses are
constrained to the cheap shader path. (Blender pipeline notes for a possible future Blender hero live in
the assistant's memory under `blender-model-pipeline`; building/exporting a new `.glb` requires the
user's local live Blender MCP link, which is not available in every session this game is built in —
e.g. cloud/remote sessions — hence the move to procedural.)

Both rider and charger were originally built from flat `BoxMesh` blocks (the soldiers' idiom, where
boxes are cheap and the silhouette reads fine at mass scale). Because the hero is exempt from the
affordability keystone, the round body volumes — rider's chest/tails/head/arms/cuffs/hands/legs/boots/
bicorne/cockade/aiguillette, and the horse's body/chest/rump/neck/head/muzzle/ears/tail/legs/hooves —
were redone as `CapsuleMesh`/`SphereMesh`/`CylinderMesh` primitives (non-uniform `.scale` approximates
each part's original box proportions where the cross-section isn't circular) for a rounded, less
box-man silhouette; genuinely flat parts (collar, lapels, sash, gorget, epaulettes, hat piping, sabre,
pistol, tack) stayed as boxes since they're flat in real life too. Parts whose long axis wasn't already
Godot's default growth axis (+Y) needed a realignment rotation composed with any existing tilt the box
already had (same-axis rotations simply add: `θ_new = θ_old + π/2` for an axis that was local Z),
worked out per-part rather than via a shared helper.

## Company officers & NCOs — brought up to the soldiers' standard
`_officer_mesh()` (the company officers marching in the ranks, `officer_mm`) used to be a
crude 7-box figure with no collar/lapels/cuffs and a flat-black hat blob — less detailed
than the privates they lead. It's now built to the same position bands as `_soldier_mesh()`
(collar, lapels, faced cuffs, coat tails, hands) plus the marks of authority: a crimson
waist sash and gold lace at the collar/lapels/cuffs/shoulder boards. The single shared
`_officer_shader()` paints both this mesh AND the NCOs/file-closers (`nco_mm`, which already
used the full `soldier_mesh` but was rendering it with the same crude old shader — flat-black
hat, no facing colours) — so NCOs now show a properly banded hat (brass band/body/peak/plume)
and the same gold/crimson rank marks as the officers, no geometry changes needed for them.
The AI's mounted battalion colonels/brigade commanders/divisional generals are still plain
capsules (`colonel_horse_mm`/`colonel_rider_mm`, `cmd_horse_mm`/`cmd_rider_mm`,
`gen_horse_mm`/`gen_rider_mm`) — a much bigger gap against the player's hero, not yet tackled.

## AI mounted commanders — also brought off the bare capsules
The three tiers of AI leadership (`colonel_*_mm` per battalion, `cmd_*_mm` per brigade,
`gen_*_mm` per division) now ride one shared detailed horse mesh (`_mount_horse_mesh()` /
`_mount_horse_shader()`) and one shared detailed rider mesh (`_mount_rider_mesh()` /
`_mount_rider_shader(trim)`) instead of bare `CapsuleMesh` primitives — built the same way as
the soldiers/officers (`SurfaceTool` boxes + cylinders, painted by a position-banded shader),
just with no rotated parts so the bands stay axis-aligned. Because each tier is itself a
MultiMesh (one per battalion/brigade/division, not one instance), it's still one mesh + one
shader per tier, never per-instance nodes like the player's hero. Rank reads two ways:
**size** (`MOUNT_SCALE_COMMANDER` / `MOUNT_SCALE_GENERAL` scale the shared transform up from
the colonel's 1.0) and **coat/trim** — the colonel rides in his army's colour with gold lace
(`_render_commanders()` sets `colonel_rider_mm`'s instance colour to team blue/red each frame,
same as before); the brigadier in a fixed solid gold coat with dark trim; the general in fixed
white-and-silver. The horse's **shabraque always carries the army's colour** (`team_color()`)
on all three tiers, via `use_colors` on the horse MultiMeshes — ties every rank visually to its
side even when the rider's coat doesn't. Both horse and rider meshes are built **origin-at-the-
horse's-feet** (ground level), matching `_build_horse()`/`_build_officer_colonel()`'s frame, so
`_render_commanders()` now places both transforms at `(x, _gh(x,z), z)` directly — no more
manual capsule-center y-offsets. Colour-bearers (`bearer_mm`) were left as a plain capsule —
out of scope for this pass.

## The colour party — flag and bearer brought up to standard
`bearer_mm` was the last bare capsule among the command group; it now reuses the existing
`officer_mm` assets (`_officer_mesh()` + `_officer_shader()`, shared — no new mesh/shader
needed) with `use_colors`/`use_custom_data` on and `_cg_dress()` painting his coat each frame,
placed with the same `0.85`-style ground-origin offset as `officer_mm` (not `CAP_HALF`, which
is only for capsule-center origins). The two colour-party escorts (`nco_mm` + `spontoon_mm`)
were already at this standard from the officer/NCO pass and needed no change.
`_make_flag()` was a bare pole + one flat solid-colour box; since the flag is **one node per
battalion, not a MultiMesh**, it's free of the affordability keystone and can carry real detail
like the hero. It now builds a small stand-of-colours assembly: a gold spearhead finial atop
the staff, a hoist canton in the regiment's facing colour, a gold roundel badge at the centre,
and a gold fringe along the top/bottom/fly edges — all individual `MeshInstance3D` parts. The
cloth is now a `Node3D` wrapper (still assigned to `b.flag_cloth`) holding all these parts, so
`_place_flag()`'s existing sway/lean/drag-when-down animation (which rotates `b.flag_cloth` as
a whole) keeps working on the whole assembly unchanged.

## Artillery — guns, crew and the limber team brought up to standard
Each gun (`Gun`/`_make_gun()`) is **one persistent `Node3D` per piece** (~64 on the field at
full strength), not a MultiMesh — like the flag, it's free of the affordability keystone and
can carry real per-node detail. The carriage gained cheeks (the sidewalls that cradle the
trunnions), an axle, a trail spade, and an elevating-screw block under the breech; the wheels
got hub caps; the barrel (still its own recoiling `Node3D`, unchanged mechanically) gained
reinforcing rings, a muzzle swell, a cascabel knob and trunnions, all as children of the tube
so they recoil with it for free.

The **gun crew** (`g.crew`, 3 bare capsules before) are now detailed gunner figures —
`_gunner_mesh()` (the soldiers'/officers' box-and-cylinder idiom: short-skirted coat, collar,
lapel, cartridge pouch at the hip, a round forage cap instead of a shako — no crossbelts, no
gold lace) painted by `_gunner_shader(coat)`, a position-banded shader with brass/buff trim
(the artillery's own branch colour) instead of the infantry's gold. Because every gun's crew on
a side shares the SAME mesh and material (`_gunner_assets(team)` builds them once, lazily, and
hands back the cached resources to every gun after the first), this costs nothing extra per
piece despite the higher per-figure detail. Each crewman is still an individual `Node3D` (now
wrapping a `MeshInstance3D` instead of being one directly) so `_animate_gun_crew()`'s existing
per-node position/rotation animation (the rammer's stroke, the gunners' sway and recoil step)
and `_drop_crewman()`'s pop-and-`queue_free()` casualty handling keep working unchanged.

The **limber team and caisson team** (4 and 2 bare horse-capsules before) now use a shared
`_draft_horse_mesh()` — the same body plan as the cavalry's mount (`_mount_horse_mesh()`) but
stripped of saddle/shabraque/stirrups and given a collar, back band and breeching strap, since
it pulls in harness rather than carries a rider — painted by `_draft_horse_shader(coat)` in one
of two lazily-built coat-colour variants (bay / black, `_draft_horse_assets()`), reused the same
way as the gunner assets. No team colouring is needed on a draft horse, so there's no per-
instance colour plumbing — just the two shared materials.

## Ships — resized to ride properly IN the sea, and detailed
`_ship_node(team)` (one persistent `Node3D` per hull, ~6 on the field — free of the
affordability keystone like the gun/flag) had the right rough scale for a small frigate/
sloop-of-war (man = `CAP_HEIGHT` 1.7 m is the yardstick; hull was already ~42 m long) but a
real bug: the lowest hull box spanned `y = 0` to `5`, i.e. the *entire* keel sat **above** the
sea surface — the ship floated on top of the water like a raft, with zero draft. Fixed by
splitting that box into a coppered underbody that actually sits **below** the waterline
(`y = -4.2` to `0`, a dulled copper-tone material — historically accurate antifouling sheathing),
a thin black boot-topping stripe right at `y = 0`, and the original timber bilge bridging back
up to the main hull. Hull breadth/length and all three mast heights/sail spans were also bumped
~8–10% for a more imposing tall-ship presence. Added detail at the beak: a carved, gilt
figurehead, cathead beams, and a stowed anchor (shank/stock/fluke) each side; an inner jib
alongside the existing headsail for a fuller sail plan; and a ship's boat stowed amidships on
the weather deck. `_ship_broadside()`'s muzzle/report offsets were nudged to match the slightly
wider hull. `_update_ships()`'s sea-following transform code (rides the Gerstner wave normal,
sets `node.transform` fresh every frame) needed no change — it positions the hull's local origin
at the wave surface, and the origin **is** the waterline, so the new underwater/boot/bilge split
just works.

## Shipyards — two navy build-points, ahead of the actual navy
`field_towns` (the province's ten capturable market towns) now carries a `shipyard: bool` flag.
Two towns are marked true via `const SHIPYARD_TOWNS` — **Hartsfield** (Crown-held, the team-0
town with the highest `x`, i.e. nearest the coast at `COAST_X`) and **Oakford** (Continental-
held, same logic for team 1) — one build-point per side, since none of the ten towns sit
exactly on the shoreline. `_build_shipyard(c)` (called from `_build_field_settlements()` right
after `_build_church(c)`, same one-`Node3D`-per-part idiom, no MultiMesh needed for a couple of
yards) raises a visible dockyard at each: a slipway, a part-built hull on the stocks (keel +
ribs), an A-frame yard crane, stacked seasoning timber, and a sawpit shed — so a player riding
through can already see which two towns are the navy's future home before any spawn logic
exists. Actually designing and launching ships from these two points (and wiring losing one to
the war, presumably) is future work; this pass only stakes out *where*.

## Player controls
`WASD` move · `Shift` run · `R` autorun · mouse look · `RMB` spyglass · `E` hail · `Q` courier orders ·
`M` map · `C` camp. Self: `LMB` sabre/fire · `G` pistol · **`V` present** (muskets up) ·
**`F` fire** (volley to the front, enemy or not) / charge (cavalry) / give the battery the word
(artillery) · `T` bring up the guns · `1/2/3` choose your arm at the step-off.

## Dev workflow & rules (IMPORTANT)
- **Do NOT launch the game to playtest** — it costs too many tokens. **The user playtests and reports /
  screenshots.** Headless checks ARE fine and expected.
- Verify edits headless with the Godot 4.6.3 **console** binary (in the user's Downloads):
  - Parse + import: `Godot...console.exe --headless --editor --quit`
  - Smoke test (boots host + a battle, catches GDScript runtime errors):
    `Godot...console.exe --headless --quit-after 650 -- --auto-host`
- **GLSL is NOT compiled headless** (dummy renderer) — shaders and any visual result must be confirmed
  by the user's playtest, never assumed from a headless run.
- A live **Blender (5.1) MCP** link is available for building/exporting `.glb` (used for the officer).

## Recent progress (as of Jun 2026)
- Replaced the box-man / failed Blender LOD with the **procedural detailed soldier** above.
- Integrated the **mounted officer hero**; facings auto-match the chosen militia.
- Added **Present (`V`)** and **Fire (`F`)** battalion commands (Fire works with no enemy in front).
- **Denser musket smoke** (a burst per musket) using a Blender-baked puff sprite
  `images/smoke_puff.png`; tuned so it **hangs at the firing line** instead of lofting skyward.
- Fixed the **see-through rolling ground** (inverted triangle winding) and **lowered the colours**.
- Removed the facing-colour picker from character creation (uses the regimental default).
- Repo published: **github.com/Uncreatedlemon91/Commander**.

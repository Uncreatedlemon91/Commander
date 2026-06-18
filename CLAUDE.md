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
`_build_horse()` for the charger + tack) — low-poly box/cylinder primitives, like the soldiers, not a
Blender import. (`models/officer_hero.glb` is the old Blender-built hero asset; it's no longer loaded
and is kept on disk only in case it's useful later.) The hero reads as a **Colonel**: gorget, crimson
waist sash, gold fringed epaulettes on both shoulders, an aiguillette, and a gold-piped, tall-plumed
bicorne, over a coat in the player's militia colour with facing-coloured collar/lapels/cuffs/cockade.
The charger carries a leather saddle and a gold-piped shabraque in the militia's facing colour. This is
a **single instance** (not a MultiMesh) so it can carry far more primitives/detail than a soldier —
only the 70k masses are constrained to the cheap shader path. (Blender pipeline notes for a possible
future Blender hero live in the assistant's memory under `blender-model-pipeline`; building/exporting a
new `.glb` requires the user's local live Blender MCP link, which is not available in every session
this game is built in — e.g. cloud/remote sessions — hence the move to procedural.)

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

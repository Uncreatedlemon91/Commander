"""
native_warrior_build.py — builds a low-poly, stylized Native warrior and exports a .glb.

SETTING:  Eastern Woodlands warrior of colonial North America (~1750s-1780s) —
          the kind that fought through the French & Indian War and the Revolution
          in the same forests the rest of Commander is set in (Iroquois / Algonquian
          cultural cues). Deliberately NOT a Plains war-bonnet stereotype, which would
          be a century and a thousand miles out of place for this game.

LOOK:     low-poly box/cylinder primitives in the same idiom as the game's procedural
          soldiers, but as a proper multi-material Blender mesh:
            - scalplock + deer-hair ROACH crest (red/black) with a single upright feather
            - bare, war-painted torso (red brow/cheek stripes)
            - red trade-wool breechcloth, buckskin leggings, hide moccasins
            - silver trade armbands, a crescent gorget, shell-bead (wampum) necklace
            - a pipe-tomahawk carried in the right hand

HOW TO RUN:
  In Blender:  Scripting workspace -> Open -> this file -> Run Script (Alt+P).
  Headless:    blender --background --python native_warrior_build.py
  The .glb is written to OUT_PATH below (defaults to this file's folder = Commander/models).

NOTE on the game's "blue cube" history (see CLAUDE.md): that bug came from JOINED meshes.
  This script keeps the parts as separate objects under one parent and exports the whole
  hierarchy, which Godot imports reliably. If you *want* a single joined mesh, flip JOIN_ALL.
"""

import bpy
import os
import math
from mathutils import Euler

# ----------------------------------------------------------------------------- config
OUT_DIR  = os.path.dirname(bpy.data.filepath) or os.path.dirname(os.path.abspath(__file__))
OUT_PATH = os.path.join(OUT_DIR, "native_warrior.glb")
JOIN_ALL = False          # leave False to dodge the documented joined-mesh import bug
LOWPOLY_CYL_VERTS = 8     # 8-sided cylinders read as low-poly and stay cheap

# ----------------------------------------------------------------------------- palette
def mat(name, rgb, metallic=0.0, roughness=0.85):
    """Create (or reuse) a simple Principled material. Only version-safe inputs are set."""
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    return m

MAT = {
    "skin":     mat("warrior_skin",      (0.62, 0.40, 0.27), 0.0, 0.78),
    "paint":    mat("warrior_warpaint",  (0.66, 0.12, 0.10), 0.0, 0.80),  # red ochre stripes
    "black":    mat("warrior_black",     (0.05, 0.05, 0.06), 0.0, 0.75),  # scalplock / roach base
    "buckskin": mat("warrior_buckskin",  (0.78, 0.62, 0.42), 0.0, 0.88),  # leggings
    "cloth":    mat("warrior_redcloth",  (0.60, 0.10, 0.09), 0.0, 0.90),  # trade-wool breechcloth
    "hide":     mat("warrior_hide",      (0.45, 0.30, 0.18), 0.0, 0.85),  # moccasins / pouch
    "silver":   mat("warrior_silver",    (0.80, 0.82, 0.85), 1.0, 0.28),  # armbands, gorget
    "shell":    mat("warrior_shell",     (0.90, 0.88, 0.83), 0.0, 0.45),  # wampum beads
    "feather":  mat("warrior_feather",   (0.93, 0.92, 0.88), 0.0, 0.60),
    "wood":     mat("warrior_wood",      (0.42, 0.28, 0.16), 0.0, 0.80),  # tomahawk haft
    "iron":     mat("warrior_iron",      (0.30, 0.32, 0.35), 0.9, 0.40),  # tomahawk blade
}

# ----------------------------------------------------------------------------- primitives
_parts = []

def _finish(obj, material, rot):
    if rot:
        obj.rotation_euler = Euler((math.radians(rot[0]),
                                    math.radians(rot[1]),
                                    math.radians(rot[2])), 'XYZ')
    obj.data.materials.clear()
    obj.data.materials.append(material)
    for p in obj.data.polygons:
        p.use_smooth = False          # flat shading -> crisp low-poly facets
    _parts.append(obj)
    return obj

def box(name, size, loc, material, rot=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2.0, size[1] / 2.0, size[2] / 2.0)
    return _finish(o, material, rot)

def cyl(name, radius, depth, loc, material, rot=None, verts=LOWPOLY_CYL_VERTS):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    return _finish(o, material, rot)

# ----------------------------------------------------------------------------- clean slate
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for block in (bpy.data.meshes, bpy.data.objects):
    for d in list(block):
        if d.users == 0:
            block.remove(d)

# ----------------------------------------------------------------------------- build
# Yardstick: man ~1.75 m tall, feet at z = 0, Z-up (Blender). Faces +Y.

# --- legs (buckskin leggings) + moccasins ---
for side, x in (("L", -0.11), ("R", 0.11)):
    cyl(f"leg_{side}", 0.075, 0.82, (x, 0.0, 0.45), MAT["buckskin"])
    box(f"moccasin_{side}", (0.16, 0.30, 0.10), (x, 0.07, 0.05), MAT["hide"])

# --- breechcloth: front and back flaps of red trade wool over the hips ---
box("breech_front", (0.26, 0.04, 0.34), (0.0,  0.085, 0.74), MAT["cloth"])
box("breech_back",  (0.26, 0.04, 0.30), (0.0, -0.085, 0.76), MAT["cloth"])

# --- pelvis / hip block (skin) ---
box("pelvis", (0.30, 0.20, 0.16), (0.0, 0.0, 0.90), MAT["skin"])

# --- torso (bare, painted) tapering up to the chest ---
box("torso_low", (0.34, 0.20, 0.22), (0.0, 0.0, 1.06), MAT["skin"])
box("torso_up",  (0.38, 0.21, 0.20), (0.0, 0.0, 1.26), MAT["skin"])

# --- bandolier / shoulder pouch strap across the chest (hide) ---
box("baldric", (0.40, 0.05, 0.07), (0.0, 0.11, 1.18), MAT["hide"], rot=(0, 0, 28))
box("pouch",   (0.16, 0.07, 0.16), (-0.20, 0.10, 0.96), MAT["hide"])

# --- arms (skin) hanging at the sides, with silver trade armbands ---
for side, x, hand_swing in (("L", -0.24, 0), ("R", 0.24, 0)):
    cyl(f"arm_{side}", 0.058, 0.50, (x, 0.0, 1.10), MAT["skin"])
    box(f"hand_{side}", (0.09, 0.10, 0.10), (x, 0.02, 0.82), MAT["skin"])
    cyl(f"armband_{side}", 0.066, 0.04, (x, 0.0, 1.24), MAT["silver"])   # upper-arm band
    cyl(f"wristband_{side}", 0.060, 0.03, (x, 0.0, 0.92), MAT["silver"])  # wrist band

# --- neck + crescent silver gorget + wampum necklace ---
cyl("neck", 0.06, 0.10, (0.0, 0.0, 1.40), MAT["skin"])
box("gorget", (0.14, 0.04, 0.06), (0.0, 0.085, 1.39), MAT["silver"])
cyl("necklace", 0.085, 0.025, (0.0, 0.02, 1.44), MAT["shell"], rot=(90, 0, 0))

# --- head (skin) ---
box("head", (0.18, 0.19, 0.20), (0.0, 0.0, 1.56), MAT["skin"])

# --- war paint: a red brow band and two cheek stripes (thin painted boxes on the face) ---
box("paint_brow",  (0.185, 0.02, 0.035), (0.0,   0.10, 1.60), MAT["paint"])
box("paint_cheekL",(0.03,  0.02, 0.07),  (-0.055, 0.10, 1.52), MAT["paint"])
box("paint_cheekR",(0.03,  0.02, 0.07),  ( 0.055, 0.10, 1.52), MAT["paint"])

# --- silver ear ornaments ---
box("ear_L", (0.03, 0.04, 0.06), (-0.10, 0.0, 1.55), MAT["silver"])
box("ear_R", (0.03, 0.04, 0.06), ( 0.10, 0.0, 1.55), MAT["silver"])

# --- shaved scalp left dark, with a roach (deer-hair crest) running front-to-back ---
box("scalp", (0.175, 0.18, 0.05), (0.0, 0.0, 1.67), MAT["black"])
# roach: a black hair base topped by a red-dyed crest, tallest at the front
box("roach_base", (0.06, 0.20, 0.06), (0.0, -0.01, 1.71), MAT["black"])
box("roach_crest",(0.05, 0.20, 0.10), (0.0, -0.01, 1.77), MAT["paint"])
# scalplock braid trailing down the back
cyl("scalplock", 0.022, 0.22, (0.0, -0.10, 1.50), MAT["black"], rot=(18, 0, 0))

# --- a single upright eagle feather socketed in the roach (white with a dark tip) ---
box("feather", (0.035, 0.012, 0.22), (0.0, -0.05, 1.92), MAT["feather"], rot=(-12, 0, 0))
box("feather_tip", (0.037, 0.013, 0.05), (0.0, -0.075, 2.03), MAT["black"], rot=(-12, 0, 0))

# --- pipe-tomahawk in the right hand (haft angled across the body) ---
HAFT_LOC = (0.30, 0.05, 0.78)
cyl("tomahawk_haft", 0.018, 0.46, HAFT_LOC, MAT["wood"], rot=(20, 0, 18))
box("tomahawk_head", (0.05, 0.04, 0.13), (0.355, 0.10, 0.98), MAT["iron"], rot=(20, 0, 18))
box("tomahawk_blade",(0.02, 0.10, 0.13), (0.40,  0.13, 1.00), MAT["iron"], rot=(20, 0, 18))

# ----------------------------------------------------------------------------- parent / origin at feet
bpy.ops.object.select_all(action='DESELECT')
root = bpy.data.objects.new("NativeWarrior", None)   # empty as a clean root
bpy.context.collection.objects.link(root)
root.location = (0.0, 0.0, 0.0)
for p in _parts:
    p.parent = root

# ----------------------------------------------------------------------------- optional join
if JOIN_ALL and _parts:
    bpy.ops.object.select_all(action='DESELECT')
    for p in _parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = _parts[0]
    bpy.ops.object.join()
    bpy.context.active_object.name = "NativeWarrior_mesh"

# ----------------------------------------------------------------------------- export
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(
    filepath=OUT_PATH,
    export_format='GLB',
    use_selection=True,
    export_apply=True,            # apply the scale on the cubes so Godot gets clean geometry
    export_yup=True,              # Godot is Y-up
)
print(f"[native_warrior] exported -> {OUT_PATH}  ({len(_parts)} parts, joined={JOIN_ALL})")

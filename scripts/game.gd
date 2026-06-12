extends Node3D

# 3D EXPLORATION — a 5v5 of full-size battalions. You play one officer (3rd person);
# the other nine battalions are AI-led. Soldiers march to their dressed places as
# individuals (no rigid block rotation). PERFORMANCE: per-man work is culled — a
# battalion off-screen does no per-soldier work, and distant ones render at reduced
# density (every 2nd/3rd man). The cheap per-battalion sim always runs.
#
# Officer:  WASD move (Shift run) · mouse look · scroll zoom · Esc cursor
# Orders (your battalion):  F follow · H halt/form up · L line · C column · V volley

const SP := 0.55                  # tighter, elbow-to-elbow ranks
const SKIRM_SP := 0.85            # loose interval when deployed as skirmishers
const CAP_RADIUS := 0.22
const CAP_HEIGHT := 1.7           # a properly-proportioned man (with shako ~1.8)
const CAP_HALF := CAP_HEIGHT * 0.5
const MEN := 700                  # men per battalion, drawn 1:1
# --- the full order of battle: battalion -> brigade -> division -> corps -> army ---
const BATTS_PER_BRIGADE := 5      # 3,500 men to a brigade
const BRIGADES_PER_DIVISION := 5  # 17,500 men to a division
const DIVISIONS_PER_CORPS := 2    # 35,000 men to a corps (1st line + 2nd line)
const CORPS_PER_TEAM := 2         # 70,000 men to an army
const BRIGADES_PER_TEAM := CORPS_PER_TEAM * DIVISIONS_PER_CORPS * BRIGADES_PER_DIVISION
const BATT_PER_TEAM := BRIGADES_PER_TEAM * BATTS_PER_BRIGADE   # 100 battalions a side
const BRIG_BATT_SPACING := 138.0  # interval between battalions dressed in a brigade line
const BRIG_FRONT := 3             # battalions in the front line; the rest form a reserve
const RESERVE_DEPTH := 55.0       # how far the reserve line stands behind the front
const BRIG_DECIDE := 0.9          # a brigade re-reads the field this often (s)
const ARMY_DECIDE := 3.5          # the army commander re-plans this often (s)
const FLANK_REACH := 120.0        # how far around an enemy flank a turning brigade swings
const BRIG_ENGAGE_RANGE := 72.0   # halt & open fire when the enemy line is in musket range
const BRIG_ASSAULT_MORALE := 52.0 # press the bayonet home once the enemy is this shaken
# --- cavalry: the arm of decision ---
const CAV_PER_TEAM := 6           # regiments of horse a side (massed on the wings)
const CAV_MEN := 120              # troopers per regiment
const CAV_SP := 1.5               # knee-to-knee interval (m)
const CAV_TROT := 3.2             # manoeuvre pace
const CAV_GALLOP := 6.5           # the charge home
const CAV_CHARGE_RANGE := 280.0   # will launch at a target within this
const CAV_CONTACT := 10.0         # the moment of impact
const CAV_RALLY_TIME := 32.0      # blown horses must rally before charging again
const CAV_DECIDE := 2.0           # how often a regiment looks for an opportunity
const SQUARE_ALERT := 150.0       # infantry forms square when enemy horse is this close
const SQUARE_RELAX := 230.0       # ...and re-forms line once it is well clear
# --- command depth: detachments, rallying, resupply ---
const SKIRM_SCREEN := 42.0        # how far ahead of the battalion its skirmish screen works
const RALLY_RANGE := 32.0         # ride this close to broken men to steady them
const RALLY_RATE := 7.0           # morale per second your presence restores
const CAISSON_SPEED := 2.0        # an ammunition waggon's plod
const CAISSON_UNLOAD := 9.0       # seconds to pass the cartridges down the line
const BRIG_SUPPORT_COOL := 18.0   # min seconds between a brigade's calls for help
const ARTY_MOVE_SPEED := 0.9      # limbered guns are the slowest thing on the field
const LIMBER_TIME := 5.0          # seconds to hook up the team / unhook and deploy
const ARTY_MOVE_THRESHOLD := 45.0 # the battery only re-limbers if the order shifts this far
# --- the command group under fire ---
const COLOURS_SHOCK := 18.0       # morale blow the moment the colours fall
const COLOURS_RALLY := 9.0        # morale lift when they are raised again
const OFFICER_SHOCK := 9.0        # morale blow when the commanding officer falls
const CMD_HIT_CHANCE := 0.05      # per second under fire, chance a command figure is hit
const BRIGADIER_HIT := 0.01       # per decision (~1 s) while engaged, chance the brigadier is shot
const CMD_CONFUSE := 14.0         # seconds a brigade is leaderless after its general falls
const TALK_RANGE := 55.0          # how close you must be to a unit to hail its sergeant

const BATT_SPEED := 1.7          # the measured pace of a line of battle
const MAN_SPEED := 2.0
const OFF_WALK := 2.1             # your horse at a walk
const OFF_RUN := 4.8              # ...and at a canter (Shift)
const FORMUP_DIST := 7.0
const MOUSE_SENS := 0.0035
# --- musketry (historical, tuned: long range almost useless, point-blank murderous) ---
const RELOAD_TIME := 30.0         # ~2 rounds/min sustained — bite, pour, ram, prime, present
const START_ROUNDS := 50.0        # cartridges a man carries into the fight
const AMMO_PER_SHOT := 0.004      # how fast a firing line eats through its supply
const FIRE_RANGE := 82.0          # smoothbore musket: in range at ~90 yards
const DEPLOY_RANGE := 78.0        # AI halts & deploys to a firing line within this
const HIT_POINT_BLANK := 0.24     # fraction of muskets that go off effectively at the muzzle
const HIT_FALLOFF := 1.0          # effectiveness ~ (1 - d/range)^this (effective ~55 yds)
# --- every ball is now a real ray with a cone of dispersion (cannon = none; the
#     smoothbore musket spreads, the pistol spreads more over its tiny range) ---
const BULLET_R := 0.34            # how near a ball must pass a man to strike him (m)
const MUSKET_YAW_SD := 0.022      # musket horizontal scatter (rad) — spreads the dead across the front
const MUSKET_PITCH_SD := 0.015    # musket vertical scatter (rad) — balls fly high/short at range
const PISTOL_RANGE := 15.0        # a horse-pistol is deadly only point-blank
const PISTOL_YAW_SD := 0.03
const PISTOL_PITCH_SD := 0.022
const PISTOL_RELOAD := 14.0       # one shot, then a long reload
# --- the player's sabre & his own mortality ---
const SWORD_REACH := 2.9          # cutting down from the saddle
const SWORD_ARC := 0.55           # cos of the half-arc the cut sweeps (~57 deg)
const SWORD_CD := 0.55
const OFF_HP := 100.0
const OFF_MELEE_DPS := 26.0       # hp lost per second per enemy at sword's length
const OFF_FIRE_DPS := 9.0         # hp lost per second standing in a close enemy's fire
const OFF_REGEN := 7.0            # hp recovered per second when not under threat
const OFF_DOWN_TIME := 6.5        # seconds carried to the rear before you are back
const ROUT_THRESHOLD := 30.0      # morale below this and the unit breaks
const SHAKEN_THRESHOLD := 55.0
const MORALE_PER_CASUALTY := 0.7
# fire discipline: a massed volley SHOCKS far beyond its casualties; independent
# fire is quicker but barely dents morale (men just trickle down).
const VOLLEY_SHOCK := 0.045       # morale shock per musket in a simultaneous volley
const VOLLEY_CASUALTY_MULT := 1.3 # massed-volley casualties also bite morale harder
const INDEP_MULT := 0.4           # independent fire: casualties, little moral effect
const MORALE_RECOVER := 3.0       # per second once out of the fight
const ROUT_SPEED := 3.4           # broken men run
const AIM_LEAD := 0.7             # a man levels his musket this long before he's loaded
# --- bayonet charge & melee ---
const CHARGE_SPEED := 3.6         # the pas de charge (m/s)
const CHARGE_RANGE := 65.0        # you may order a charge within this
const MELEE_RANGE := 6.0          # contact distance
const CHARGE_SHOCK := 34.0        # morale blow the defender takes at the moment of impact
const MELEE_RATE := 18.0          # men lost per second in the press (scaled by morale)
const MELEE_MORALE := 16.0        # morale bled per second locked in melee
const CHARGE_COOL := 8.0          # seconds before a unit can charge again
# companies are per-nation (French 6, British/Allied 10); see Batt.companies
const COMPANY_GAP := 1.1         # visible lateral gap between companies (m)
const COMPANY_ROLL := 0.45       # delay between companies in fire-by-company (s)
const LEVEL_TIME := 1.4           # men raise muskets to the level this long before firing
const MUZZLE_LIGHTS := 28         # pooled flash lights that illuminate the field
const SHAKE_MAX := 0.55
const COURIER_SPEED := 9.0        # an aide's canter (m/s)
const COURIER_MAX := 16
const AUDIO_POOL := 128           # the whole front is audible now — more voices at once
const MAX_PER_TEAM := BATT_PER_TEAM * MEN
const CORPSE_MAX := 24000          # per team, rolling (the oldest dead are re-used)
# --- artillery (the great killer of the age) ---
const BATTERIES_PER_TEAM := 8      # two batteries to a division, massed not strung out
const GUNS_PER_BATTERY := 4
const GUN_SPACING := 9.0           # interval between pieces in a battery (m)
const ARTY_RANGE := 540.0          # roundshot reaches far beyond musketry
const ARTY_RELOAD := 28.0          # ~2 rounds/min: sponge, load, ram, prime, lay, fire
const CREW_HP := 5.0               # musket hits a gun crew can soak before a man drops
const CANISTER_RANGE := 110.0      # inside this the gun loads canister (a giant shotgun)
const CANISTER_BALLS := 18         # lethal balls in a canister round
const PLOUGH_DEPTH := 13.0         # how far a roundshot bowls a lane through a formation
const BALL_HALFWIDTH := 0.55       # corridor a flying ball sweeps men from
const SHOT_SPEED := 145.0          # roundshot flight, slowed so the eye can follow it
const GUN_GRAVITY := 24.0          # arc on the shot so it clears its own line
const SHOT_POOL := 48              # 32 guns a side keep more iron in the air
const SCAR_MAX := 512              # ground furrows torn by roundshot

# LOD distances (m) from the camera
const LOD_NEAR := 70.0
const LOD_MID := 160.0
const LOD_FAR := 340.0            # full per-man simulation out to here...
const LOD_VFAR := 1400.0          # ...then a static formation IMPRESSION to here

enum Order { IDLE, FOLLOW }

class Batt:
	var team: int
	var is_player: bool = false
	var pos: Vector3
	var facing: float = 0.0
	var formation: String = "line"
	var figs: Array = []           # { slot: Vector2, wpos: Vector3, ph: float, spd: float }
	var order: int = Order.IDLE
	var morale: float = 100.0
	var state: String = "steady"   # steady | shaken | routing
	var calm_t: float = 0.0        # seconds since last casualty taken
	var volley_fire: bool = false  # true = hold fire until the officer's command
	var auto_volley: bool = false  # volley fire: wait until all are loaded, then fire as one
	var volley_seq: float = 0.0    # the words of command run their course before the crash
	var fire_now: bool = false     # one-shot: the officer's "FIRE!" this frame
	var wheeling: bool = false     # pivoting to a new facing
	var wheel_to: float = 0.0      # the facing being wheeled to
	var has_goal: bool = false     # ordered to a measured point (Advance N yards / Fall back)
	var move_goal: Vector3         # that point
	var fall_back: bool = false    # fighting retreat: step backward, face the enemy, keep firing
	var cg: Dictionary = {}        # command group's smoothed world positions (no snapping)
	var parent: Batt = null        # set on a detached company (its battalion)
	var detachment: Batt = null    # the skirmish company this battalion has out
	var caisson_coming: bool = false   # an ammunition waggon is on its way
	var masked: bool = false       # friends stand in the lane of fire — muskets held
	var rolling: bool = false      # fire-by-company sweep active
	var roll_company: int = -1     # company whose turn is next (right -> left)
	var roll_cd: float = 0.0
	var companies: int = 6         # French 6, British/Allied 10
	var has_target: bool = false
	var kills_pending: int = 0     # casualties to apply this frame
	var cas_since_redress: int = 0
	var charging: bool = false     # pas de charge toward the enemy
	var advancing: bool = false    # ordered to march forward onto the enemy
	var skirmish: bool = false     # deployed in loose open order
	var spent: bool = false        # shot to pieces — a broken remnant, no reinforcement
	var ammo: float = 50.0         # average cartridges per man remaining
	var melee_foe: Batt = null     # locked in hand-to-hand with this unit
	var charge_cool: float = 0.0
	var dmg_acc: float = 0.0       # fractional melee casualties accumulator
	var flinch: float = 0.0        # visible recoil/shudder when shocked (decays)
	var shot_from: Vector3 = Vector3.ZERO   # where the incoming fire is coming from
	var off_pos: Vector3           # this battalion's officer
	var off_facing: float = 0.0
	var visible: bool = false      # in view last frame (for LOD snap)
	var spawn: Vector3
	var idx: int = 0               # global battalion index (shared across peers)
	var human: bool = false        # controlled by a player (host or a client)
	var melee_vis: bool = false    # client-side: this unit is locked in melee (from sync)
	var fx_firemode: int = 0       # synced: 0 at-will, 1 volley-hold, 2 rolling
	var fx_acc: float = 0.0        # client-side crackle accumulator
	var flag: Node3D               # the regimental colour (pole + cloth)
	var flag_cloth: Node3D
	var inst_col: Color = Color(1, 1, 1, 0)   # rgb = facing colour, a = coat variant index
	var rname: String = ""         # the regiment's NAME, carried in from the world (seam)
	var exp_mul: float = 1.0       # drill quality: veterans reload faster, recruits slower
	var march_player: AudioStreamPlayer3D   # the drummer's marching cadence while moving
	var last_pos: Vector3          # to detect whether the battalion is moving this frame
	var marching: bool = false
	# --- the command group can be shot away: officer, colours, drummer ---
	var colours_down: bool = false   # the colour-bearer is down, the colours on the ground
	var colours_t: float = 0.0       # until another man raises them
	var officer_down: bool = false   # the commanding officer is a casualty (AI units)
	var officer_t: float = 0.0
	var drummer_down: bool = false   # the drummer is down, the cadence silenced
	var drummer_t: float = 0.0
	var cmd_check: float = 0.0        # throttle on command-casualty rolls
	# --- brigade command: this battalion takes its orders from a brigade commander ---
	var brigade = null             # the Brigade it belongs to
	var ai_target: Vector3         # the spot in the brigade line the commander wants it
	var ai_facing: float = 0.0     # the facing the commander wants
	var ai_posture: String = "advance"  # advance | engage | assault | hold | withdraw | skirmish
	var order_cd: float = 0.0      # throttle on couriers sent to a human commander

# a single field piece served by a crew, lobbing roundshot / canister at the enemy
class Gun:
	var team: int
	var pos: Vector3
	var facing: float = 0.0
	var reload: float = 0.0
	var node: Node3D            # barrel + carriage + crew, rotated to aim
	var barrel: Node3D          # recoils on firing
	var recoil: float = 0.0
	var reload_max: float = ARTY_RELOAD   # the full cycle length, for crew timing
	var crew: Array = []        # crew MeshInstance3D nodes (last = rammer)
	var crew_base: Array = []   # their rest positions
	var crew_dmg: float = 0.0   # accumulated musket hits on the crew
	var dead: bool = false      # crew shot down / gun silenced
	var brigade = null          # the Brigade this battery answers to
	var fire_mission = null     # an enemy Batt the commander has ordered it to engage
	var move_to: Vector3        # where the commander wants the piece posted
	var limber_state: String = "deployed"   # deployed | limbering | moving | unlimbering
	var limber_t: float = 0.0   # timer for the current limber/unlimber transition
	var limber_group: Node3D    # the limber cart + horse team (shown only while limbered)

# A brigade: several battalions and a battery under one commander, manoeuvring as a
# body to 18th-century doctrine — advance in line, soften with artillery, assault a
# shaken enemy, support a hard-pressed neighbour, refuse a threatened flank.
class Brigade:
	var team: int
	var idx: int = 0
	var battalions: Array = []     # its Batt members
	var guns: Array = []           # its attached battery
	var posture: String = "advance"   # advance | engage | assault | hold | support | withdraw
	var anchor: Vector3            # centre of the brigade's intended line
	var facing: float = 0.0        # the direction it faces (toward the enemy)
	var enemy = null               # the enemy Brigade it is engaging
	var fire_mission = null        # an enemy Batt to point the battery at
	var decide_cd: float = 0.0     # throttle on re-deciding
	var support_cd: float = 0.0    # throttle on calling for help
	var support_pos: Vector3 = Vector3.ZERO   # a flank/point we've been asked to shore up
	var support_t: float = 0.0     # how long we keep honouring that task
	var is_player: bool = false    # contains the human-led battalion
	var commander_pos: Vector3     # where the brigadier rides (behind the centre)
	var commander_down: bool = false   # the brigadier is shot — the brigade is leaderless
	var confuse_t: float = 0.0     # how long it stays confused before a colonel takes over
	# --- place in the order of battle ---
	var division: int = 0          # which division this brigade belongs to
	var corps: int = 0             # which corps that division belongs to
	var line2: bool = false        # a second-line (reserve) division
	# --- the mission handed down by the army commander ---
	var mission: String = "advance"   # attack | fix | flank | reserve | refuse | hold
	var mission_target = null      # the enemy Brigade this mission concerns
	var flank_side: int = 0        # for a flank mission: which way to swing (-1 / +1)
	var objective: Vector3         # the ground the brigade is moving its line onto

# The army commander: reads the whole front each cycle, decides where the enemy is
# weakest and where his own strength lies, and hands each brigade a mission so the
# army fights to a single plan (concentration of force) instead of piecemeal duels.
class Army:
	var team: int
	var decide_cd: float = 0.0
	var aggression: float = 0.5    # personality: cautious (0) .. bold (1)
	var plan: String = "develop"   # develop | press | defend
	var main = null                # the brigade making the main effort
	# --- the appreciation: the goal this commander has DEDUCED for himself ---
	var goal: String = "develop"   # destroy | turn_left | turn_right | break_centre | bleed | delay | seize
	var goal_t: float = 0.0        # commitment: how long the present goal has stood
	var play: String = ""          # the doctrine play serving the goal (e.g. grand_battery)
	var gb_pos: Vector3            # where the grand battery masses
	var intel_cd: float = 0.0      # reports arrive by courier — the picture lags reality
	var intel_left: float = 0.0    # last-REPORTED enemy frontage (for overlap judgments)
	var intel_right: float = 0.0
	var intel_fresh: bool = false

var key_points: Array = []         # future terrain goals: { pos, value, owner } (step 5 hook)

# A regiment of horse: held in reserve, loosed at an opportunity — a wavering line, a
# routing mob, an exposed battery, or the enemy's own cavalry — then blown, and must
# retire to rally before it can charge again. It breaks on a formed square.
class Cav:
	var team: int
	var idx: int = 0
	var pos: Vector3
	var facing: float = 0.0
	var troopers: Array = []       # { slot: Vector2, wpos: Vector3, ph: float }
	var state: String = "reserve"  # reserve | charging | retiring | rallying | fled
	var target = null              # Batt, Gun or Cav being charged
	var target_kind: String = ""
	var rally_t: float = 0.0
	var decide_cd: float = 0.0
	var reserve_pos: Vector3
	var spent: bool = false
	var hoof_player: AudioStreamPlayer3D   # the thunder of the gallop

var cavalry: Array[Cav] = []
var cav_horse_mm: Array = [null, null]    # per-team mounts
var cav_rider_mm: Array = [null, null]    # per-team riders
var _cav_warn_cd := 0.0                   # throttle on "form square!" warnings to you
var caissons: Array = []                  # ammunition waggons on the road: {node,pos,target,state,t,origin}
var _caisson_scan := 0.0                  # AI quartermasters check the line this often
var _rally_cd := 0.0                      # throttle on the rallying despatch

var armies: Array = []
var guns: Array[Gun] = []
var brigades: Array = []                  # the command formations both sides fight as
var _army_adv := [0.0, 0.0]               # each army's average advance (for dressing the line)
const DRESS_MARGIN := 70.0                # a brigade won't outrun the army by more than this
var brigade_couriers: Array = []          # aides riding support requests between brigades
var _shots: Array = []                    # flying roundshot: {active,pos,vel,from,dist,team}
var shot_mm: MultiMesh
var scar_mm: MultiMesh                     # furrows gouged in the ground by roundshot
var scar_idx := 0

# regimental dress: facing colours cycle per BRIGADE (a brigade was usually one
# regiment's battalions); coat variants pick from each team's small uniform table
const FACINGS_0 := [Color(0.95, 0.92, 0.85), Color(0.85, 0.15, 0.15), Color(0.92, 0.80, 0.15),
	Color(0.65, 0.10, 0.35), Color(0.95, 0.50, 0.12), Color(0.45, 0.70, 0.90)]
const FACINGS_1 := [Color(0.92, 0.85, 0.30), Color(0.20, 0.45, 0.20), Color(0.10, 0.15, 0.40),
	Color(0.95, 0.95, 0.92), Color(0.55, 0.12, 0.45), Color(0.05, 0.05, 0.06)]
const COATS_0 := [Color(0.30, 0.38, 0.78), Color(0.19, 0.25, 0.52), Color(0.15, 0.19, 0.42)]
const COATS_1 := [Color(0.74, 0.30, 0.30), Color(0.24, 0.42, 0.27), Color(0.52, 0.20, 0.20)]

var battalions: Array[Batt] = []
var player: Batt
var team_mm: Array = [null, null]
var team_prev: Array[int] = [0, 0]
var musket_mm: Array = [null, null]      # a placeholder musket per rendered soldier
var musket_prev: Array[int] = [0, 0]
var bearer_mm: MultiMesh                  # colour-bearer per battalion
var nco_mm: MultiMesh                     # company sergeants + rear file-closers
const MAX_NCO := 14
var _lights: Array = []                   # pooled muzzle-flash OmniLights
var _light_i := 0
var _shake := 0.0
var _flash_rect: ColorRect                # screen flash on a near volley
var _flash_amt := 0.0
var _suppress_rect: TextureRect           # smoky vignette that pulses on nearby fire
var _suppress := 0.0
var corpse_mm: Array = [null, null]       # per-team fallen (kept in team colour)
var corpse_idx: Array[int] = [0, 0]
# not every man hit is killed outright — some drag themselves toward the rear
var wounded: Array = []                   # { pos, dir, t, team, ph }
var wounded_mm: Array = [null, null]
const WOUNDED_MAX := 110                  # crawling at once, per team
const WOUNDED_FRAC := 0.3                 # fraction of the fallen who are wounded, not killed
const WOUNDED_TIME := 26.0                # how long a man crawls before he is still
const CRAWL_SPEED := 0.35
var _floor: StaticBody3D
var _ragdolls: Array = []                 # pool of tumbling rigid-body deaths
const RAGDOLL_POOL := 64
const RAGDOLL_TIME := 3.0
var officer_mm: MultiMesh        # AI officer markers
var cmd_rider_mm: MultiMesh      # mounted brigade commanders (the rider)
var cmd_horse_mm: MultiMesh      # their horses
var dead_horse_mm: MultiMesh     # fallen horses (generals' chargers, troopers' mounts)
var dead_horse_idx := 0
const DEAD_HORSE_MAX := 420

# player officer (3rd person)
var officer: Node3D
var off_pos := Vector3.ZERO
var off_facing := 0.0
var off_vis := 0.0
# the player's weapons & mortality
var sabre: MeshInstance3D
var pistol_mesh: MeshInstance3D
var _swing := 0.0                 # sabre swing animation timer
var _sword_cd := 0.0
var _pistol_loaded := true
var _pistol_reload := 0.0
var _off_hp := 100.0
var _off_down := false
var _off_respawn := 0.0
# prestige — the player's renown as a commander: +1 for every enemy felled by men
# under your command (or your own hand), -1 for every man of yours lost. Later the
# currency for upgrades: items, skills, better officers.
var prestige := 0
var _player_figs_prev := -1        # last known strength, for counting losses centrally

# --- battle flow: deployment, army collapse, victory & the butcher's bill ---
const DEPLOY_TIME := 75.0          # quiet minutes to read the ground before the step-off
var _deploy_t := DEPLOY_TIME
var _battle_begun := false
var battle_over := false
var _army_broken := [false, false]
var _start_strength := [0, 0]      # men each army brought to the field
var _bill_t := -1.0                # countdown from the collapse to the final despatch
var _bill_panel: PanelContainer
var _bill_label: RichTextLabel
var _dmg_flash := 0.0             # red screen pulse when you take a hit
var _dmg_rect: ColorRect

var cam: Camera3D
# --- HOST MODE (seam merge, staged): the tactical sim running INSIDE world.gd,
# sharing its province terrain, chase camera and day/night instead of building
# its own. Defaults off, so the standalone 70k battle is byte-for-byte unchanged.
var hosted := false
var host_origin := Vector3.ZERO    # where on the province this battle is fought (set as node pos)
var host_done := false             # set true when an embedded battle is resolved & dismissed
var _cam_yaw := PI                 # start looking from behind you toward the enemy
var _cam_pitch := deg_to_rad(28.0) # 3rd-person orbit elevation (camera height)
var _scope_pitch := 0.0            # spyglass look elevation (0 = level, + = up)
var _cam_dist := 26.0
var _mouse_captured := true

var smoke_p: GPUParticles3D                # cannon smoke: jets hard, then hangs
var musket_smoke_p: GPUParticles3D         # musket smoke: rolls forward, thins downrange
var flash_p: GPUParticles3D
var fire_p: GPUParticles3D
var blood_p: GPUParticles3D                # red spray when a man is hit
var blood_mm: MultiMesh                    # ground blood pools under the fallen
var blood_idx := 0
const BLOOD_MAX := 16000
const EMIT_FLAGS := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY | GPUParticles3D.EMIT_FLAG_COLOR

var snd_volley: Array = []
var snd_shots: Array = []                 # individual musket-shot recordings (for variety)
var snd_cannon_shots: Array = []          # cannon-shot recordings (for variety)
var snd_marchdrum: Array = []             # marching-cadence drum loops
var snd_melee: AudioStream
var snd_cannon: AudioStream
var snd_hooves: AudioStream               # the thunder of a charge (optional file)
var snd_cheer: AudioStream                # the charge goes in with a shout (optional)
var snd_v_ready: AudioStream              # officer: "Make ready!"  (optional)
var snd_v_present: AudioStream            # officer: "Present!"
var snd_v_fire: AudioStream               # officer: "FIRE!"
var snd_v_charge: AudioStream             # officer: "Charge!"
var _audio_pool: Array = []
var _audio_i := 0

var couriers: Array = []          # each: { pos: Vector3, order: Dictionary }
var courier_mm: MultiMesh
var courier_horse_mm: MultiMesh           # the aides' mounts

var help_panel: PanelContainer
var cmd_panel: PanelContainer             # the courier order menu (Scourge-style)
var _cmd_on := false
# incoming despatches from your brigade commander / neighbouring units
var msg_panel: PanelContainer
var msg_label: RichTextLabel
var _msg_text := ""
var _msg_t := 0.0
var _pending_player_order: Dictionary = {}   # the order a courier just brought you
var _player_order_cd := 6.0                  # throttle on brigade despatches to you
var _player_order_last := ""
# the order menu: [keycode, hotkey label, menu label, order kind]
# The order book, Scourge-of-War style: Q opens the despatch pad, pick a category,
# pick the order, and an aide rides it out. Measured advances and the fighting
# withdrawal give fine control of the line's ground.
const CMD_PAGES := {
	"": [
		[KEY_1, "1", "Movement …", "page:move"],
		[KEY_2, "2", "Formation …", "page:form"],
		[KEY_3, "3", "Fire discipline …", "page:fire"],
		[KEY_4, "4", "Charge!", "charge"],
	],
	"move": [
		[KEY_1, "1", "Advance 5 yards", "adv:5"],
		[KEY_2, "2", "Advance 10 yards", "adv:10"],
		[KEY_3, "3", "Advance 25 yards", "adv:25"],
		[KEY_4, "4", "Advance 50 yards", "adv:50"],
		[KEY_5, "5", "Fall back 50 yards (fighting)", "fallback:50"],
		[KEY_6, "6", "Move to my position", "move_to_me"],
		[KEY_7, "7", "Hold position", "halt"],
		[KEY_8, "8", "Wheel left", "wheel_left"],
		[KEY_9, "9", "Wheel right", "wheel_right"],
	],
	"form": [
		[KEY_1, "1", "Form line", "line"],
		[KEY_2, "2", "Form column", "column"],
		[KEY_3, "3", "Form square", "square"],
		[KEY_4, "4", "Deploy skirmishers (a company)", "skirmish"],
		[KEY_5, "5", "Recall skirmishers", "recall"],
	],
	"fire": [
		[KEY_1, "1", "Volley fire (as one)", "volley"],
		[KEY_2, "2", "Independent fire", "fire_at_will"],
		[KEY_3, "3", "Hold fire", "hold_fire"],
		[KEY_4, "4", "Send for cartridges", "resupply"],
	],
}
const PAGE_TITLES := { "": "DESPATCH ORDER", "move": "MOVEMENT", "form": "FORMATION", "fire": "FIRE DISCIPLINE" }
var _cmd_page := ""
var cmd_roster: RichTextLabel
var cmd_orders: RichTextLabel
var sun: DirectionalLight3D
var env: Environment                      # kept so the sky/fog can be driven each frame
var psm: ProceduralSkyMaterial
var ground_mat: StandardMaterial3D
# --- time of day & weather ---
var _time_of_day := 8.5                   # hours, 0..24
var _weather := "clear"                   # clear | overcast | rain | fog
var _weather_timer := 75.0                # seconds until the weather shifts on its own
var _night := 0.0                         # 0 broad day .. 1 deep night (muzzle flashes glow)
var _cloud := 0.0                         # smoothed cloud cover 0..1
var _fogw := 0.0                          # smoothed extra fog 0..1
var _rainw := 0.0                         # smoothed rain intensity 0..1
var _wind := Vector3.ZERO                 # gentle wind (drifts smoke, stirs the colours)
var _wet := 0.0                           # how damp the powder is (misfires in rain)
var rain_p: GPUParticles3D
var _grad_skytop: Gradient
var _grad_skyhorizon: Gradient
var _grad_sun: Gradient
var _grad_fog: Gradient
const DAY_RATE := 24.0 / 3600.0           # a full day cycles in ~60 minutes (N to skip ahead)
const WEATHERS := ["clear", "overcast", "rain", "fog"]
var _t := 0.0

# multiplayer
var authoritative := true         # host or single-player runs the sim
var _net_cd := 0.0                 # state-broadcast / input-send throttle
var _pending_net_order: Dictionary = {}   # client: order to forward to the host
var _got_state := false
var _got_fx := false
var _fx: Array = []                        # host: fx events buffered for clients
const NET_HZ := 15.0
const FX_VOLLEY := 0
const FX_MELEE := 1

# diegetic-UI bits: a toggleable help overlay, a raise-able spyglass, drummers
var _help_on := false
var _scoped := false
var _scope_amt := 0.0
var _scope_rect: TextureRect
var drummer_mm: MultiMesh
var snd_drum: AudioStream
var _drum_cd := 0.0
const FOV_NORMAL := 60.0
const FOV_SCOPE := 16.0

var _setup: BattleSetup            # the seam: the world this battle was handed
var _inflated: bool = false        # this battle was inflated from a campaign engagement

func _ready() -> void:
	authoritative = GameConfig.mode != "client"
	Net.game = self
	# THE SEAM: consume the BattleSetup (or build the default field)
	if GameConfig.setup == null:
		GameConfig.setup = BattleSetup.default_field()
	_setup = GameConfig.setup
	_inflated = _setup.units.size() > 0    # a campaign engagement, not the 70k set-piece
	_weather = _setup.weather
	_time_of_day = _setup.time_of_day
	_build_world()
	if not hosted:
		_build_scenery()            # host uses the province's own woods & fields
	_build_officer()
	_build_wounded_layer()
	_spawn_armies()
	_build_guns()
	_spawn_cavalry()
	_assign_brigades()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # the battle owns the mouse once joined

# ------------------------------------------------------------------ world

func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL   # spread the day/night sky re-render
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	psm = ProceduralSkyMaterial.new()
	psm.sky_horizon_color = Color(0.7, 0.72, 0.78)
	psm.ground_horizon_color = Color(0.6, 0.6, 0.62)
	psm.sun_curve = 0.12
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.25
	env.glow_strength = 1.1
	env.glow_hdr_threshold = 1.0          # only bright (HDR) muzzle fire blooms
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_density = 0.0008
	env.fog_sky_affect = 0.4
	# a gentle filmic grade so the field reads richer
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.14
	we.environment = env
	if not hosted:                  # the province supplies sky, fog and grade
		add_child(we)
	_build_tod_palette()

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 240.0   # bound shadow cost over the huge field
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = 1.1
	sun.light_angular_distance = 0.6              # soft penumbra
	if not hosted:                  # the province supplies the sun
		add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	ground_mat = _make_ground_material()
	ground.material_override = ground_mat
	if not hosted:                  # the province supplies the ground
		add_child(ground)

	rain_p = _build_rain()

	for team in [0, 1]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cap := CapsuleMesh.new()
		cap.radius = CAP_RADIUS
		cap.height = CAP_HEIGHT
		cap.radial_segments = 6          # 70,000 men a side — every vertex counts
		cap.rings = 2
		mm.mesh = cap
		mm.use_colors = true              # per-instance: rgb = facings, a = coat variant
		mm.instance_count = MAX_PER_TEAM
		mmi.multimesh = mm
		mmi.material_override = _soldier_shader(team)
		add_child(mmi)
		team_mm[team] = mm
		var def := Color(COATS_0[0], 0.0) if team == 0 else Color(COATS_1[0], 0.0)
		for i in range(MAX_PER_TEAM):
			mm.set_instance_transform(i, _zero_xf())
			mm.set_instance_color(i, def)

	# a placeholder musket (thin box) per soldier — shouldered, levelled to fire
	for team in [0, 1]:
		var gmi := MultiMeshInstance3D.new()
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, 1.3)
		gmm.mesh = box
		gmm.instance_count = MAX_PER_TEAM
		gmi.multimesh = gmm
		var gunmat := StandardMaterial3D.new()
		gunmat.albedo_color = Color(0.16, 0.11, 0.07)
		gunmat.roughness = 0.7
		gunmat.metallic = 0.25
		gmi.material_override = gunmat
		add_child(gmi)
		musket_mm[team] = gmm
		for i in range(MAX_PER_TEAM):
			gmm.set_instance_transform(i, _zero_xf())

	# pooled muzzle-flash lights (light the men, ground and smoke when volleys crash)
	for i in range(MUZZLE_LIGHTS):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.72, 0.36)
		l.omni_range = 18.0
		l.light_energy = 0.0
		l.shadow_enabled = false
		add_child(l)
		_lights.append(l)

	# fallen men, one MultiMesh per team so corpses keep their unit's colour
	for team in [0, 1]:
		var cmi := MultiMeshInstance3D.new()
		var cmm := MultiMesh.new()
		cmm.transform_format = MultiMesh.TRANSFORM_3D
		var ccap := CapsuleMesh.new()
		ccap.radius = CAP_RADIUS
		ccap.height = CAP_HEIGHT
		ccap.radial_segments = 6
		ccap.rings = 2
		cmm.mesh = ccap
		cmm.instance_count = CORPSE_MAX
		cmi.multimesh = cmm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = team_color(team).darkened(0.12)   # same colour, a touch muddied
		cmat.roughness = 1.0
		cmi.material_override = cmat
		add_child(cmi)
		corpse_mm[team] = cmm
		for i in range(CORPSE_MAX):
			cmm.set_instance_transform(i, _zero_xf())

	# an invisible ground plane so ragdolls have something to fall onto
	_floor = StaticBody3D.new()
	_floor.collision_layer = 1
	_floor.collision_mask = 0
	var fcol := CollisionShape3D.new()
	fcol.shape = WorldBoundaryShape3D.new()
	_floor.add_child(fcol)
	add_child(_floor)

	# pool of physics ragdolls (recycled): a man tumbles, settles, then bakes into
	# the static corpse layer. Only floor collisions — they pass through each other.
	for i in range(RAGDOLL_POOL):
		var rb := RigidBody3D.new()
		rb.collision_layer = 0
		rb.collision_mask = 1                 # collide with the floor only
		rb.freeze = true
		rb.continuous_cd = false
		var rcs := CollisionShape3D.new()
		var rcap := CapsuleShape3D.new()
		rcap.radius = CAP_RADIUS
		rcap.height = CAP_HEIGHT
		rcs.shape = rcap
		rb.add_child(rcs)
		var rmi := MeshInstance3D.new()
		var rmesh := CapsuleMesh.new()
		rmesh.radius = CAP_RADIUS
		rmesh.height = CAP_HEIGHT
		rmi.mesh = rmesh
		var rmat := StandardMaterial3D.new()
		rmi.material_override = rmat
		rb.add_child(rmi)
		rb.position = Vector3(0, -200, 0)
		add_child(rb)
		_ragdolls.append({ "body": rb, "mat": rmat, "active": false, "t": 0.0, "team": 0 })

	var omi := MultiMeshInstance3D.new()
	officer_mm = MultiMesh.new()
	officer_mm.transform_format = MultiMesh.TRANSFORM_3D
	var ocap := CapsuleMesh.new()
	ocap.radius = 0.3
	ocap.height = 1.7
	officer_mm.mesh = ocap
	officer_mm.instance_count = BATT_PER_TEAM * 2
	omi.multimesh = officer_mm
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(0.85, 0.7, 0.3)
	omi.material_override = omat
	add_child(omi)
	for i in range(BATT_PER_TEAM * 2):
		officer_mm.set_instance_transform(i, _zero_xf())

	# brigade commanders — mounted generals riding behind the centre of their brigade.
	# A dark horse (a capsule laid along the facing) under a bright gold rider.
	var bn := BRIGADES_PER_TEAM * 2
	var hmi := MultiMeshInstance3D.new()
	cmd_horse_mm = MultiMesh.new()
	cmd_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	var hcap := CapsuleMesh.new()
	hcap.radius = 0.34
	hcap.height = 1.9
	cmd_horse_mm.mesh = hcap
	cmd_horse_mm.instance_count = bn
	hmi.multimesh = cmd_horse_mm
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.20, 0.13, 0.08)
	hmat.roughness = 0.9
	hmi.material_override = hmat
	add_child(hmi)
	var rmi := MultiMeshInstance3D.new()
	cmd_rider_mm = MultiMesh.new()
	cmd_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	var rcap := CapsuleMesh.new()
	rcap.radius = 0.26
	rcap.height = 1.5
	cmd_rider_mm.mesh = rcap
	cmd_rider_mm.instance_count = bn
	rmi.multimesh = cmd_rider_mm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.82, 0.30)   # gold — stands out as the brigadier
	rmat.metallic = 0.2
	rmi.material_override = rmat
	add_child(rmi)
	for i in range(bn):
		cmd_horse_mm.set_instance_transform(i, _zero_xf())
		cmd_rider_mm.set_instance_transform(i, _zero_xf())

	# colour-bearers (one per battalion, dark coat — the cloth carries the colour)
	var bmi := MultiMeshInstance3D.new()
	bearer_mm = MultiMesh.new()
	bearer_mm.transform_format = MultiMesh.TRANSFORM_3D
	var bcap := CapsuleMesh.new()
	bcap.radius = 0.22
	bcap.height = 1.7
	bearer_mm.mesh = bcap
	bearer_mm.instance_count = BATT_PER_TEAM * 2
	bmi.multimesh = bearer_mm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.16, 0.16, 0.20)
	bmi.material_override = bmat
	add_child(bmi)
	for i in range(BATT_PER_TEAM * 2):
		bearer_mm.set_instance_transform(i, _zero_xf())

	# NCOs / file-closers (grey, posted on the ends and rear)
	var nmi := MultiMeshInstance3D.new()
	nco_mm = MultiMesh.new()
	nco_mm.transform_format = MultiMesh.TRANSFORM_3D
	var ncap := CapsuleMesh.new()
	ncap.radius = 0.22
	ncap.height = 1.72
	ncap.radial_segments = 6
	ncap.rings = 2
	nco_mm.mesh = ncap
	nco_mm.instance_count = BATT_PER_TEAM * 2 * MAX_NCO
	nmi.multimesh = nco_mm
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.42, 0.42, 0.46)
	nmi.material_override = nmat
	add_child(nmi)
	for i in range(BATT_PER_TEAM * 2 * MAX_NCO):
		nco_mm.set_instance_transform(i, _zero_xf())

	# drummers — one per battalion, at the colours (white coats)
	var dmi := MultiMeshInstance3D.new()
	drummer_mm = MultiMesh.new()
	drummer_mm.transform_format = MultiMesh.TRANSFORM_3D
	var dcap := CapsuleMesh.new()
	dcap.radius = 0.22
	dcap.height = 1.6
	drummer_mm.mesh = dcap
	drummer_mm.instance_count = BATT_PER_TEAM * 2
	dmi.multimesh = drummer_mm
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.86, 0.84, 0.78)
	dmi.material_override = dmat
	add_child(dmi)
	for i in range(BATT_PER_TEAM * 2):
		drummer_mm.set_instance_transform(i, _zero_xf())

	smoke_p = _make_emitter(24.0, 60000, _smoke_material(), Vector2(2.2, 2.2), 0)
	musket_smoke_p = _make_emitter(20.0, 60000, _smoke_material(), Vector2(2.0, 2.0), 5)
	flash_p = _make_emitter(0.16, 20000, _flash_material(), Vector2(1.0, 1.0), 1)
	fire_p = _make_emitter(0.4, 20000, _flash_material(), Vector2(0.8, 0.8), 2)
	blood_p = _make_emitter(0.85, 24000, _blood_material(), Vector2(0.5, 0.5), 4)
	add_child(smoke_p)
	add_child(musket_smoke_p)
	add_child(flash_p)
	add_child(fire_p)
	add_child(blood_p)

	# ground blood pools, baked under the fallen (paired with the corpse layer)
	var blmi := MultiMeshInstance3D.new()
	blood_mm = MultiMesh.new()
	blood_mm.transform_format = MultiMesh.TRANSFORM_3D
	var blpl := PlaneMesh.new()
	blpl.size = Vector2(1.1, 1.1)
	blood_mm.mesh = blpl
	blood_mm.instance_count = BLOOD_MAX
	blmi.multimesh = blood_mm
	var blmat := StandardMaterial3D.new()
	blmat.albedo_color = Color(0.32, 0.02, 0.02)
	blmat.albedo_texture = _radial_tex()             # soft-edged splotch
	blmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blmat.roughness = 0.7
	blmi.material_override = blmat
	add_child(blmi)
	for i in range(BLOOD_MAX):
		blood_mm.set_instance_transform(i, _zero_xf())

	# courier markers — mounted aides: a rider on a horse
	var crm := MultiMeshInstance3D.new()
	courier_mm = MultiMesh.new()
	courier_mm.transform_format = MultiMesh.TRANSFORM_3D
	var crcap := CapsuleMesh.new()
	crcap.radius = 0.24
	crcap.height = 1.4
	courier_mm.mesh = crcap
	courier_mm.instance_count = COURIER_MAX
	crm.multimesh = courier_mm
	var crmat := StandardMaterial3D.new()
	crmat.albedo_color = Color(0.88, 0.80, 0.52)
	crm.material_override = crmat
	add_child(crm)
	var chm := MultiMeshInstance3D.new()
	courier_horse_mm = MultiMesh.new()
	courier_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	var crhcap := CapsuleMesh.new()
	crhcap.radius = 0.32
	crhcap.height = 1.8
	courier_horse_mm.mesh = crhcap
	courier_horse_mm.instance_count = COURIER_MAX
	chm.multimesh = courier_horse_mm
	var chmat := StandardMaterial3D.new()
	chmat.albedo_color = Color(0.22, 0.15, 0.09)
	chm.material_override = chmat
	add_child(chm)
	for i in range(COURIER_MAX):
		courier_mm.set_instance_transform(i, _zero_xf())
		courier_horse_mm.set_instance_transform(i, _zero_xf())

	# load whatever sounds are present in res://sounds/ (missing files are skipped, so
	# the game never breaks if the audio set changes)
	snd_shots = _load_sound_set(["MusketShot1.wav", "MusketShot2.wav", "MusketShot3.wav"])
	snd_cannon_shots = _load_sound_set(["CannonShot1.wav", "CannonShot2.wav", "CannonShot3.wav"])
	snd_marchdrum = _load_sound_set(["MarchingDrum1.mp3", "MarchingDrum2.wav", "MarchingDrum3.wav"])
	snd_volley = _load_sound_set(["MusketVolley.wav", "Musket Volley.mp3", "MusketVolley2.mp3"])
	if snd_volley.is_empty():
		snd_volley = snd_shots          # no dedicated volley recording — mass the shot sounds
	snd_melee = _load_first(["MeleeCombat.wav", "Melee Combat.mp3", "MeleeCombat.mp3"])
	snd_cannon = _load_first(["CannonFire.mp3", "CannonFire.wav"])
	snd_drum = _load_first(["Drum.mp3", "Drum.wav"])     # optional morale-cadence drum
	# optional atmosphere — drop any of these into sounds/ and they come alive:
	snd_hooves = _load_first(["Hooves.wav", "Hooves.mp3", "CavalryCharge.wav"])
	snd_cheer = _load_first(["Cheer.wav", "Cheer.mp3"])
	snd_v_ready = _load_first(["VoiceMakeReady.wav", "VoiceMakeReady.mp3"])
	snd_v_present = _load_first(["VoicePresent.wav", "VoicePresent.mp3"])
	snd_v_fire = _load_first(["VoiceFire.wav", "VoiceFire.mp3"])
	snd_v_charge = _load_first(["VoiceCharge.wav", "VoiceCharge.mp3"])
	for i in range(AUDIO_POOL):
		var ap := AudioStreamPlayer3D.new()
		ap.max_distance = 1000.0
		ap.unit_size = 24.0          # carries much further before attenuating
		ap.volume_db = 11.0          # much louder
		add_child(ap)
		_audio_pool.append(ap)

	# the battle builds its own camera even when hosted — as a child of this node it
	# rides in local space, and the node's world position drops it on the province
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 8000.0                  # see the distant hills on the horizon
	cam.current = true
	add_child(cam)

	var cl := CanvasLayer.new()
	add_child(cl)

	# cinematic post: a static vignette + a volley flash that washes the screen
	var vig := TextureRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.texture = _vignette_tex()
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.modulate = Color(1, 1, 1, 0.85)
	cl.add_child(vig)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1.0, 0.86, 0.6, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_flash_rect)

	# suppression vignette — a smoky grey tunnel that closes in briefly when fire
	# crashes out nearby (a felt "suppress", not a jarring flash)
	_suppress_rect = TextureRect.new()
	_suppress_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_suppress_rect.texture = _vignette_tex()
	_suppress_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_suppress_rect.modulate = Color(0.10, 0.11, 0.13, 0.0)   # cold grey, alpha pulsed
	cl.add_child(_suppress_rect)

	# a red wash when YOU are hit
	_dmg_rect = ColorRect.new()
	_dmg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dmg_rect.color = Color(0.6, 0.0, 0.0, 0.0)
	_dmg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_dmg_rect)

	# spyglass tube — a circular mask that fades in when you raise the glass
	_scope_rect = TextureRect.new()
	_scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_rect.texture = _scope_tex()
	_scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_rect.modulate = Color(1, 1, 1, 0.0)
	cl.add_child(_scope_rect)

	_build_help(cl)
	_build_command_menu(cl)
	_build_despatch_panel(cl)
	_build_bill_panel(cl)

	_update_environment(0.0)   # apply the opening sky/light before the first frame

# The butcher's bill — the end-of-battle despatch, centred and final.
func _build_bill_panel(cl: CanvasLayer) -> void:
	_bill_panel = PanelContainer.new()
	_bill_panel.anchor_left = 0.5
	_bill_panel.anchor_right = 0.5
	_bill_panel.anchor_top = 0.5
	_bill_panel.anchor_bottom = 0.5
	_bill_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bill_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bill_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.94)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(22)
	_bill_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(_bill_panel)
	_bill_label = RichTextLabel.new()
	_bill_label.bbcode_enabled = true
	_bill_label.fit_content = true
	_bill_label.scroll_active = false
	_bill_label.custom_minimum_size = Vector2(380, 0)
	_bill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bill_label.add_theme_font_size_override("normal_font_size", 16)
	_bill_label.add_theme_font_size_override("bold_font_size", 22)
	_bill_panel.add_child(_bill_label)
	_bill_panel.visible = false

# ---------------------------------------------------------------- sky, light, weather

# The uniform, painted in bands by height: shako, FACING-coloured collar, coat,
# a facing cuff-line at the hands, campaign trousers. One draw call per army —
# the facing colour rides per-instance in COLOR.rgb, the coat variant in COLOR.a.
func _soldier_shader(team: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coats[3];
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	int ci = clamp(int(round(COLOR.a * 3.0)), 0, 2);
	vec3 col = coats[ci];
	if (vy > 0.70) { col = vec3(0.07, 0.07, 0.08); }              // the shako
	else if (vy > 0.45) { col = COLOR.rgb; }                      // collar: the facings
	else if (vy > -0.22 && vy < -0.10) { col = COLOR.rgb; }       // the cuff line
	else if (vy < -0.52) { col = vec3(0.60, 0.58, 0.53); }        // campaign trousers
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var coats := PackedVector3Array()
	for c in (COATS_0 if team == 0 else COATS_1):
		coats.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("coats", coats)
	return m

func _make_ground_material() -> StandardMaterial3D:
	# a tiling noise gives the turf colour variation; a finer noise gives micro-relief
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.013
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = n
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 0.72, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.20, 0.25, 0.14), Color(0.29, 0.35, 0.20),
		Color(0.37, 0.42, 0.25), Color(0.45, 0.48, 0.31)])
	tex.color_ramp = ramp
	var nn := FastNoiseLite.new()
	nn.noise_type = FastNoiseLite.TYPE_SIMPLEX
	nn.frequency = 0.06
	var ntex := NoiseTexture2D.new()
	ntex.width = 512
	ntex.height = 512
	ntex.seamless = true
	ntex.noise = nn
	ntex.as_normal_map = true
	ntex.bump_strength = 1.4
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.uv1_scale = Vector3(280, 280, 1)       # ~21 m per tile across the 6 km field
	m.normal_enabled = true
	m.normal_texture = ntex
	m.normal_scale = 0.6
	m.roughness = 1.0
	return m

func _build_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 9000
	p.lifetime = 1.2
	p.preprocess = 1.0
	p.local_coords = false
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-60, -45, -60), Vector3(120, 120, 120))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(55, 0.5, 55)
	pm.direction = Vector3(0.12, -1.0, 0.0)
	pm.spread = 2.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3(0, -12.0, 0)
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.55)         # a thin streak
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.72, 0.80, 0.92, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mesh.material = mat
	p.draw_pass_1 = mesh
	add_child(p)
	return p

func _grad(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

# Keyed colour ramps across the 24-hour day (offset = hour / 24).
func _build_tod_palette() -> void:
	_grad_skytop = _grad(
		[0.0, 0.21, 0.30, 0.5, 0.70, 0.80, 1.0],
		[Color(0.02, 0.03, 0.08), Color(0.10, 0.13, 0.24), Color(0.33, 0.45, 0.66),
		 Color(0.34, 0.54, 0.86), Color(0.36, 0.44, 0.70), Color(0.18, 0.15, 0.30), Color(0.02, 0.03, 0.08)])
	_grad_skyhorizon = _grad(
		[0.0, 0.24, 0.31, 0.5, 0.70, 0.79, 0.88, 1.0],
		[Color(0.05, 0.06, 0.11), Color(0.80, 0.55, 0.40), Color(0.86, 0.72, 0.56), Color(0.70, 0.75, 0.82),
		 Color(0.82, 0.66, 0.50), Color(0.78, 0.42, 0.30), Color(0.13, 0.11, 0.18), Color(0.05, 0.06, 0.11)])
	_grad_sun = _grad(
		[0.0, 0.26, 0.34, 0.5, 0.66, 0.77, 0.84, 1.0],
		[Color(0.35, 0.45, 0.70), Color(1.0, 0.66, 0.42), Color(1.0, 0.86, 0.72), Color(1.0, 0.97, 0.92),
		 Color(1.0, 0.88, 0.76), Color(1.0, 0.60, 0.38), Color(0.40, 0.42, 0.62), Color(0.35, 0.45, 0.70)])
	_grad_fog = _grad(
		[0.0, 0.28, 0.5, 0.77, 0.86, 1.0],
		[Color(0.06, 0.07, 0.12), Color(0.72, 0.62, 0.56), Color(0.74, 0.77, 0.82),
		 Color(0.74, 0.50, 0.40), Color(0.12, 0.11, 0.16), Color(0.06, 0.07, 0.12)])

# Drive the sun, sky, ambient, fog and weather from the time of day, every frame.
func _update_environment(delta: float) -> void:
	_time_of_day = fposmod(_time_of_day + delta * DAY_RATE, 24.0)
	var t := _time_of_day
	var u := t / 24.0
	var h := sin((t - 6.0) / 12.0 * PI)          # sun height: -1..1 (0 at 6 & 18)
	var day := clampf(h, 0.0, 1.0)
	_night = clampf(-h * 2.2 + 0.25, 0.0, 1.0)   # deep dark after dusk -> muzzle flashes blaze
	# the weather drifts on its own — fronts roll in and clear over the day
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_weather_timer = randf_range(60.0, 200.0)
		var roll := randf()
		_weather = "clear" if roll < 0.45 else ("overcast" if roll < 0.78 else ("rain" if roll < 0.92 else "fog"))
	# ease the weather toward the chosen state
	var tc := 0.0
	var tf := 0.0
	var tr := 0.0
	match _weather:
		"overcast": tc = 0.85; tf = 0.22
		"rain": tc = 1.0; tf = 0.45; tr = 1.0
		"fog": tc = 0.55; tf = 1.0
	var k := clampf(delta * 0.5, 0.0, 1.0)
	_cloud = lerpf(_cloud, tc, k)
	_fogw = lerpf(_fogw, tf, k)
	_rainw = lerpf(_rainw, tr, k)
	_wet = _rainw
	# the sun arcs across the sky; stays just above the horizon so shadows always cast
	var pitch := -clampf(h * 70.0, 4.0, 76.0)
	sun.rotation_degrees = Vector3(pitch, lerpf(-110.0, -250.0, u), 0.0)
	var sun_col: Color = _grad_sun.sample(u)
	sun.light_color = sun_col.lerp(Color(0.55, 0.57, 0.60), _cloud * 0.7)
	sun.light_energy = lerpf(0.06, 1.5, day) * lerpf(1.0, 0.38, _cloud)
	env.ambient_light_energy = lerpf(0.14, 0.55, day) * lerpf(1.0, 1.45, _cloud)
	# at night the powder-flashes bloom far harder against the dark
	env.glow_intensity = lerpf(0.9, 1.7, _night)
	env.glow_hdr_threshold = lerpf(1.0, 0.7, _night)
	psm.sky_top_color = _grad_skytop.sample(u).lerp(Color(0.50, 0.52, 0.55), _cloud * 0.6)
	psm.sky_horizon_color = _grad_skyhorizon.sample(u).lerp(Color(0.56, 0.57, 0.59), _cloud * 0.6)
	var fog_col: Color = _grad_fog.sample(u).lerp(Color(0.56, 0.57, 0.60), _cloud * 0.5)
	env.fog_light_color = fog_col
	env.fog_density = lerpf(0.0006, 0.0011, 1.0 - day) + _fogw * 0.004
	env.volumetric_fog_enabled = _fogw > 0.04 or _cloud > 0.5
	env.volumetric_fog_density = _fogw * 0.05 + _cloud * 0.008
	env.volumetric_fog_albedo = fog_col
	if rain_p and cam:
		rain_p.global_position = cam.global_position + Vector3(0, 32, 0)
		rain_p.emitting = _rainw > 0.04
		rain_p.amount_ratio = clampf(_rainw, 0.0, 1.0)
	if ground_mat:
		ground_mat.roughness = lerpf(1.0, 0.5, _rainw)             # wet sheen
		ground_mat.albedo_color = Color(1, 1, 1).lerp(Color(0.66, 0.69, 0.72), _rainw)
	# a slowly veering wind that drifts the smoke and stirs the colours
	_wind = Vector3(cos(_t * 0.05), 0.0, sin(_t * 0.05)) * (0.4 + _rainw * 2.2 + _cloud * 0.7)

func _cycle_weather() -> void:
	var i := WEATHERS.find(_weather)
	_weather = WEATHERS[(i + 1) % WEATHERS.size()]
	_weather_timer = randf_range(90.0, 220.0)        # hold the chosen weather a while
	_send_player_despatch("[color=#bcd] Weather: %s.[/color]" % _weather, {})

# ---------------------------------------------------------------- terrain & scenery

# The battlefield floor stays flat (the whole sim is on the plane); the terrain,
# woods and villages frame it as scenery so the field reads as a real valley.
func _build_scenery() -> void:
	_build_hills()
	_build_forests()
	_build_villages()

# A ring of rolling hills around the field — half-sunk domes that fade into the fog,
# giving the battlefield a sense of being fought in a valley.
func _build_hills() -> void:
	var count := 30
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 20
	sph.rings = 10
	mm.mesh = sph
	mm.instance_count = count
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.33, 0.23)
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU + randf_range(-0.12, 0.12)
		var rad := randf_range(1900.0, 3300.0)
		var w := randf_range(300.0, 750.0)
		var hgt := randf_range(70.0, 230.0)
		var pos := Vector3(cos(ang) * rad, -w * 0.55, sin(ang) * rad)
		var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(w, hgt + w * 0.55, w))
		mm.set_instance_transform(i, Transform3D(basis, pos))

# Woods: clusters of trees (trunk + foliage), placed on the flanks and rear so the
# battle lines don't march through them.
func _build_forests() -> void:
	var defs := [
		[Vector3(-1550, 0, -340), 300.0, 80],
		[Vector3(1480, 0, 360), 320.0, 90],
		[Vector3(-860, 0, -560), 200.0, 46],
		[Vector3(980, 0, -500), 220.0, 52],
		[Vector3(1820, 0, -120), 250.0, 64],
		[Vector3(-1780, 0, 220), 250.0, 64],
		[Vector3(120, 0, -760), 300.0, 80],
	]
	var total := 0
	for d in defs:
		total += int(d[2])
	var trunk_mm := _make_scenery_mm(_cylinder(0.32, 4.0), Color(0.26, 0.18, 0.10), total)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 2.6
	leaf_mesh.height = 5.6
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 7
	var foliage_mm := _make_scenery_mm(leaf_mesh, Color(0.18, 0.30, 0.15), total)
	var ti := 0
	for d in defs:
		var c: Vector3 = d[0]
		var r: float = d[1]
		var n: int = int(d[2])
		for j in range(n):
			var a := randf() * TAU
			var rr := sqrt(randf()) * r
			var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
			var s := randf_range(0.7, 1.5)
			var yaw := randf() * TAU
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
			trunk_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 2.0 * s, p.z)))
			foliage_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 5.6 * s, p.z)))
			ti += 1

# Hamlets: clusters of cottages (walls + a gable roof), set back from the fighting.
func _build_villages() -> void:
	var defs := [
		[Vector3(-320, 0, -440), 130.0, 13],
		[Vector3(440, 0, 450), 130.0, 15],
		[Vector3(1680, 0, 40), 110.0, 10],
		[Vector3(-1500, 0, -40), 120.0, 11],
	]
	var total := 0
	for d in defs:
		total += int(d[2])
	var wall_mm := _make_scenery_mm(_box(1, 1, 1), Color(0.72, 0.67, 0.57), total)
	var roof_mm := _make_scenery_mm(_prism(1, 1, 1), Color(0.42, 0.22, 0.16), total)
	var ti := 0
	for d in defs:
		var c: Vector3 = d[0]
		var r: float = d[1]
		var n: int = int(d[2])
		for j in range(n):
			var a := randf() * TAU
			var rr := sqrt(randf()) * r
			var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
			var wx := randf_range(5.0, 9.0)
			var wy := randf_range(4.0, 6.0)
			var wz := randf_range(4.5, 8.0)
			var roofh := randf_range(2.6, 4.2)
			var yaw := randf() * TAU
			var rot := Basis(Vector3.UP, yaw)
			wall_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx, wy, wz)), Vector3(p.x, wy * 0.5, p.z)))
			roof_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx * 1.06, roofh, wz * 1.06)), Vector3(p.x, wy + roofh * 0.5, p.z)))
			ti += 1

func _make_scenery_mm(mesh: Mesh, col: Color, count: int) -> MultiMesh:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
	for i in range(count):
		mm.set_instance_transform(i, _zero_xf())
	return mm

func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	return m

func _box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m

func _prism(x: float, y: float, z: float) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(x, y, z)
	return m

# A despatch from your commander or a neighbour — shown top-centre, obeyed with Y.
func _build_despatch_panel(cl: CanvasLayer) -> void:
	msg_panel = PanelContainer.new()
	msg_panel.anchor_left = 0.5
	msg_panel.anchor_right = 0.5
	msg_panel.anchor_top = 0.0
	msg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	msg_panel.offset_top = 24.0
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.05, 0.92)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	msg_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(msg_panel)
	msg_label = RichTextLabel.new()
	msg_label.bbcode_enabled = true
	msg_label.fit_content = true
	msg_label.scroll_active = false
	msg_label.custom_minimum_size = Vector2(440, 0)
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_label.add_theme_font_size_override("normal_font_size", 16)
	msg_panel.add_child(msg_label)
	msg_panel.visible = false

# The courier order menu: press Q to open, a number to dispatch that order.
func _build_command_menu(cl: CanvasLayer) -> void:
	cmd_panel = PanelContainer.new()
	cmd_panel.anchor_left = 0.0
	cmd_panel.anchor_top = 0.5
	cmd_panel.anchor_bottom = 0.5
	cmd_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	cmd_panel.offset_left = 18.0
	cmd_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.10, 0.90)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.65)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	cmd_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(cmd_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmd_panel.add_child(col)
	# your command — a live roster of the units that answer to you
	cmd_roster = RichTextLabel.new()
	cmd_roster.bbcode_enabled = true
	cmd_roster.fit_content = true
	cmd_roster.scroll_active = false
	cmd_roster.custom_minimum_size = Vector2(290, 0)
	cmd_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmd_roster.add_theme_font_size_override("normal_font_size", 14)
	cmd_roster.add_theme_font_size_override("bold_font_size", 15)
	col.add_child(cmd_roster)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(1.0, 0.84, 0.42, 0.35)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(rule)
	# the order book (paged)
	cmd_orders = RichTextLabel.new()
	cmd_orders.bbcode_enabled = true
	cmd_orders.fit_content = true
	cmd_orders.scroll_active = false
	cmd_orders.custom_minimum_size = Vector2(290, 0)
	cmd_orders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cmd_orders.add_theme_font_size_override("normal_font_size", 15)
	cmd_orders.add_theme_font_size_override("bold_font_size", 16)
	col.add_child(cmd_orders)
	cmd_panel.visible = false

# Live status of every unit answering to you (your battalion today; built to list
# more as your command grows). Strength, nerve, powder, formation, current task.
func _refresh_cmd_panel() -> void:
	if player == null:
		return
	var b := player
	var morale_word := "steady"
	var mcol := "9fe0a0"
	if b.state == "routing":
		morale_word = "breaking"; mcol = "ff7a6a"
	elif b.state == "shaken":
		morale_word = "shaken"; mcol = "ffcf6e"
	var task := "holding"
	if b.fall_back:
		task = "falling back, firing"
	elif b.has_goal:
		task = "advancing %d yds" % int(round(b.pos.distance_to(b.move_goal) / 0.9144))
	elif b.charging:
		task = "charging!"
	elif b.melee_foe != null:
		task = "in the melee"
	elif b.wheeling:
		task = "wheeling"
	elif b.order == Order.FOLLOW:
		task = "following you"
	var firemode := "volley on order" if b.auto_volley else ("holding fire" if b.volley_fire else "firing at will")
	var rt := "[b][color=#ffd773]YOUR COMMAND[/color][/b]\n"
	rt += "[color=#ffe9a8]%s[/color]\n" % _unit_name(b)
	rt += "[color=#cdd6e6]%d men · [color=#%s]%s[/color] · %d rds · %s[/color]\n" % [b.figs.size(), mcol, morale_word, int(round(b.ammo)), b.formation]
	rt += "[color=#9fb0c8]%s · %s[/color]" % [task, firemode]
	if b.masked:
		rt += "\n[color=#ffcf6e]fire masked — friends to the front![/color]"
	if b.colours_down or b.drummer_down:
		rt += "\n[color=#ff9a8a]%s[/color]" % ("colours down!" if b.colours_down else "drummer down")
	if b.detachment != null:
		rt += "\n[color=#ffe9a8]— skirmish company[/color] [color=#cdd6e6]%d men forward[/color]" % b.detachment.figs.size()
	cmd_roster.text = rt
	# the order page
	var ot := "[b][color=#ffd773]%s[/color][/b]\n" % PAGE_TITLES.get(_cmd_page, "ORDERS")
	for item in CMD_PAGES[_cmd_page]:
		ot += "  [color=#ffe9a8]%s[/color]  [color=#cdd6e6]%s[/color]\n" % [item[1], item[2]]
	var foot := "Q close" if _cmd_page == "" else "Esc back · Q close"
	ot += "[right][color=#6f7888]%s[/color][/right]"
	cmd_orders.text = ot % foot

func _build_help(cl: CanvasLayer) -> void:
	help_panel = PanelContainer.new()
	help_panel.anchor_left = 1.0
	help_panel.anchor_top = 1.0
	help_panel.anchor_right = 1.0
	help_panel.anchor_bottom = 1.0
	help_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # grow up-left from corner
	help_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help_panel.offset_right = -16.0
	help_panel.offset_bottom = -16.0
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 0.82)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	help_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(help_panel)

	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(330, 0)
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_font_size_override("bold_font_size", 15)
	var k := "ffe9a8"   # key colour
	var c := "9fb0c8"   # caption colour
	rt.text = "[center][b][color=#ffd773]CONTROLS[/color][/b][/center]\n" + \
		"[color=#%s]MOVE[/color]   [color=#%s]WASD[/color] move · [color=#%s]Shift[/color] run · mouse look · [color=#%s]scroll[/color] zoom\n" % [c, k, k, k] + \
		"[color=#%s]LOOK[/color]   [color=#%s]RMB[/color] spyglass · [color=#%s]E[/color] hail sergeant / general · [color=#%s]Esc[/color] free cursor\n" % [c, k, k, k] + \
		"[color=#%s]ORDERS[/color] [color=#%s]Q[/color] courier order menu (a despatch rides to your battalion)\n" % [c, k] + \
		"[color=#%s]SELF[/color]   [color=#%s]LMB[/color] sabre · [color=#%s]G[/color] pistol\n" % [c, k, k] + \
		"[color=#%s]WORLD[/color]  [color=#%s]N[/color] time of day · [color=#%s]M[/color] weather\n" % [c, k, k] + \
		"[right][color=#6f7888]Tab to hide[/color][/right]"
	help_panel.add_child(rt)

func _scope_tex() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.60, 0.66, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.92, 0.5)
	t.width = 256
	t.height = 256
	return t

func _vignette_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.6))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.85)
	t.width = 256
	t.height = 256
	return t

func _zero_xf() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)

# You are MOUNTED: a battalion commander rides — head and shoulders above the ranks,
# able to see over your own line (and be seen by it).
func _build_officer() -> void:
	officer = Node3D.new()
	add_child(officer)
	# the charger — a dark horse laid along the facing
	var horse := MeshInstance3D.new()
	var hcap := CapsuleMesh.new()
	hcap.radius = 0.34
	hcap.height = 1.95
	horse.mesh = hcap
	horse.rotation = Vector3(PI * 0.5, 0, 0)
	horse.position = Vector3(0, 0.95, 0)
	var hmat2 := StandardMaterial3D.new()
	hmat2.albedo_color = Color(0.16, 0.11, 0.07)   # a dark bay
	hmat2.roughness = 0.9
	horse.material_override = hmat2
	officer.add_child(horse)
	# the rider, in the saddle
	var body := MeshInstance3D.new()
	var bc := CapsuleMesh.new()
	bc.radius = 0.28
	bc.height = 1.45
	body.mesh = bc
	body.position = Vector3(0, 1.85, 0)
	var omat := StandardMaterial3D.new()
	omat.albedo_color = Color(1.0, 0.85, 0.3)
	omat.roughness = 0.5
	body.material_override = omat
	officer.add_child(body)
	var hat := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.55, 0.12, 0.22)
	hat.mesh = hm
	hat.position = Vector3(0, 2.62, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.12, 0.12, 0.14)
	hat.material_override = hmat
	officer.add_child(hat)
	var sab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.05, 0.85)
	sab.mesh = sm
	sab.position = Vector3(0.34, 1.9, 0.25)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.85, 0.9)
	smat.metallic = 0.8
	sab.material_override = smat
	officer.add_child(sab)
	sabre = sab
	# a horse-pistol in the off hand
	pistol_mesh = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.05, 0.10, 0.26)
	pistol_mesh.mesh = pm
	pistol_mesh.position = Vector3(-0.32, 1.9, 0.2)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.20, 0.14, 0.08)
	pmat.metallic = 0.3
	pistol_mesh.material_override = pmat
	officer.add_child(pistol_mesh)

# ------------------------------------------------------------------ armies

func _spawn_armies() -> void:
	if _inflated:
		_spawn_from_setup()
		return
	# which battalion indices are human-led (host knows all; single = just you)
	var humans: Array = [GameConfig.local_slot]
	if GameConfig.mode == "host":
		humans = Net.human_slots()
	for team in [0, 1]:
		var z := -240.0 if team == 0 else 240.0   # the armies deploy well apart — there is a march to make
		var face := 0.0 if team == 0 else PI    # team 0 faces +Z, team 1 faces -Z
		for i in range(BATT_PER_TEAM):
			var gidx: int = team * BATT_PER_TEAM + i
			var b := Batt.new()
			b.team = team
			b.idx = gidx
			# decompose the index into the order of battle to place him in it
			var brig := i / BATTS_PER_BRIGADE
			var kb := i % BATTS_PER_BRIGADE                      # battalion within brigade
			var dv := brig / BRIGADES_PER_DIVISION
			var bd := brig % BRIGADES_PER_DIVISION               # brigade within division
			var cp := dv / DIVISIONS_PER_CORPS
			var dc := dv % DIVISIONS_PER_CORPS                   # 0 = first line, 1 = second
			var bx := (float(cp) - (CORPS_PER_TEAM - 1) * 0.5) * 2700.0 \
				+ (float(bd) - (BRIGADES_PER_DIVISION - 1) * 0.5) * 520.0 \
				+ (float(kb) - (BATTS_PER_BRIGADE - 1) * 0.5) * 96.0
			var bz := z + float(dc) * (200.0 if team == 1 else -200.0)   # 2nd line stands behind
			b.pos = Vector3(bx, 0, bz)
			# regimental dress: facings by brigade, the 5th battalion in the light coat
			var fpal: Array = FACINGS_0 if team == 0 else FACINGS_1
			var fc: Color = fpal[brig % fpal.size()]
			var coat_idx := 1 if kb == BATTS_PER_BRIGADE - 1 else 0
			b.inst_col = Color(fc.r, fc.g, fc.b, float(coat_idx) / 3.0)
			b.spawn = b.pos
			b.facing = face
			b.formation = "column"               # advance in column, deploy on contact
			b.off_facing = face
			b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
			b.human = gidx in humans
			b.is_player = (gidx == GameConfig.local_slot)
			b.companies = 6 if team == 0 else 10  # French 6-coy, Allied 10-coy
			b.ammo = START_ROUNDS
			b.last_pos = b.pos
			var mp := AudioStreamPlayer3D.new()        # the drummer's marching cadence
			mp.max_distance = 700.0
			mp.unit_size = 14.0
			mp.volume_db = 4.0
			add_child(mp)
			b.march_player = mp
			_fill_figs(b)
			# THE SEAM: the world's record for this unit overrides the fresh defaults —
			# survivors, powder, nerve, drill and dress all carry in from outside
			if gidx < _setup.units.size():
				var u: BattleSetup.BattUnit = _setup.units[gidx]
				if u.name != "":
					b.rname = u.name
				b.ammo = u.ammo
				b.morale = u.morale
				b.exp_mul = clampf(2.0 - u.experience, 0.72, 1.45)
				b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, float(u.coat_idx) / 3.0)
				while b.figs.size() > u.men and b.figs.size() > 0:
					b.figs.pop_back()          # losses are forever
			_start_strength[team] += b.figs.size()
			_make_flag(b, team)
			battalions.append(b)
			if b.is_player:
				player = b
				player.formation = "line"
				player.order = Order.IDLE
				off_pos = b.pos - Vector3(sin(face), 0, cos(face)) * 8.0   # just behind your line
				off_facing = face
				off_vis = face
				_cam_yaw = face + PI                                       # look toward the enemy
				_reslot(player)
	if player == null:
		player = battalions[clampi(GameConfig.local_slot, 0, battalions.size() - 1)]

# INFLATION (Phase 2): spawn exactly the battalions the campaign engagement
# involves, each carrying its real history. Positions come authored from the
# world (the two forces already facing each other), so the fight begins in
# contact rather than from a fresh deployment.
func _spawn_from_setup() -> void:
	for ui in range(_setup.units.size()):
		var u: BattleSetup.BattUnit = _setup.units[ui]
		var team := u.team
		var face: float = u.facing
		var b := Batt.new()
		b.team = team
		b.idx = ui
		b.pos = u.pos
		b.spawn = b.pos
		b.facing = face
		b.formation = "line"                 # they meet already deployed for the fight
		b.off_facing = face
		b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
		b.human = (u.human_slot == GameConfig.local_slot)
		b.is_player = b.human
		b.companies = 6 if team == 0 else 10
		b.ammo = u.ammo
		b.morale = u.morale
		b.exp_mul = clampf(2.0 - u.experience, 0.72, 1.45)
		b.rname = u.name
		b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, float(u.coat_idx) / 3.0)
		b.last_pos = b.pos
		var mp := AudioStreamPlayer3D.new()
		mp.max_distance = 700.0
		mp.unit_size = 14.0
		mp.volume_db = 4.0
		add_child(mp)
		b.march_player = mp
		_fill_figs(b)
		while b.figs.size() > u.men and b.figs.size() > 0:
			b.figs.pop_back()                # the survivors who marched here, no more
		_start_strength[team] += b.figs.size()
		_make_flag(b, team)
		battalions.append(b)
		if b.is_player:
			player = b
			player.order = Order.IDLE
			off_pos = b.pos - Vector3(sin(face), 0, cos(face)) * 8.0
			off_facing = face
			off_vis = face
			_cam_yaw = face + PI
			_reslot(player)
	if player == null and not battalions.is_empty():
		# no friendly human unit present — watch as an observer attached to team 0
		for b in battalions:
			if b.team == 0:
				player = b
				break
	# an inflated meeting engagement needs no long deployment lull
	_deploy_t = minf(_deploy_t, 12.0)

func _make_flag(b: Batt, team: int) -> void:
	b.flag = Node3D.new()
	add_child(b.flag)
	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.025
	pcyl.bottom_radius = 0.025
	pcyl.height = 2.6
	pole.mesh = pcyl
	pole.position = Vector3(0, 1.7, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.25, 0.16, 0.08)
	pole.material_override = pmat
	b.flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.95, 0.62, 0.02)
	cloth.mesh = cbox
	cloth.position = Vector3(0.5, 2.55, 0)
	var cmat := StandardMaterial3D.new()
	# the cloth carries the REGIMENT's facing colour quartered with the national one
	var nat := Color(0.22, 0.30, 0.72) if team == 0 else Color(0.72, 0.22, 0.22)
	cmat.albedo_color = nat.lerp(Color(b.inst_col.r, b.inst_col.g, b.inst_col.b), 0.5)
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = cmat
	b.flag.add_child(cloth)
	b.flag_cloth = cloth
	b.flag.visible = false

func _fill_figs(b: Batt) -> void:
	b.figs.clear()
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for e in _layout(MEN, b.formation, b.companies):
		var slot: Vector2 = e["p"]
		var w := b.pos + right * slot.x + fwd * slot.y
		b.figs.append({ "slot": slot, "wpos": Vector3(w.x, 0, w.z), "ph": randf() * TAU,
			"spd": randf_range(0.85, 1.18), "reload": randf_range(0.0, RELOAD_TIME),
			"company": int(e["c"]), "face": float(e.get("f", 0.0)) })

func _reslot(b: Batt) -> void:
	var L := _layout(b.figs.size(), b.formation, b.companies)
	for i in range(b.figs.size()):
		var e: Dictionary = L[i]
		b.figs[i]["slot"] = e["p"]
		b.figs[i]["company"] = int(e["c"])
		b.figs[i]["face"] = float(e.get("f", 0.0))

func _dims(n: int, formation: String) -> Vector2i:
	if formation == "line":
		return Vector2i(int(ceil(float(n) / 3.0)), 3)
	if formation == "skirmish":
		return Vector2i(int(ceil(float(n) / 3.0)), 3)    # loose order, similar frontage
	if formation == "square":
		var perside := int(ceil(float(n) / 4.0))
		return Vector2i(int(ceil(float(perside) / 4.0)), 4)   # files per side, 4 ranks deep
	var files := clampi(int(round(float(n) / 26.0)), 12, 36)
	return Vector2i(files, int(ceil(float(n) / float(files))))

# Returns one entry per man: { p: formation-frame position, c: company index }.
# A line is split into `companies` blocks with a visible gap between each.
func _layout(n: int, formation: String, companies: int) -> Array:
	var d := _dims(n, formation)
	var files := d.x
	var ranks := d.y
	var out: Array = []
	if formation == "line":
		var fpc := int(ceil(files / float(companies)))      # files per company
		var cu := int(ceil(files / float(fpc)))             # companies actually formed
		var total := (files - 1) * SP + (cu - 1) * COMPANY_GAP
		for i in range(n):
			var fi := i % files
			var ra := i / files
			var comp := mini(fi / fpc, cu - 1)
			var x := fi * SP + comp * COMPANY_GAP - total * 0.5 + randf_range(-0.07, 0.07)
			var z := (float(ra) - (ranks - 1) * 0.5) * SP + randf_range(-0.07, 0.07)
			out.append({ "p": Vector2(x, z), "c": comp })
		return out
	if formation == "skirmish":
		# loose open order: wide intervals and big jitter, two ragged ranks
		for i in range(n):
			var fi := i % files
			var ra := i / files
			var x := (float(fi) - (files - 1) * 0.5) * SKIRM_SP + randf_range(-0.5, 0.5)
			var z := (float(ra) - (ranks - 1) * 0.5) * SKIRM_SP + randf_range(-0.6, 0.6)
			out.append({ "p": Vector2(x, z), "c": fi % 6 })
		return out
	if formation == "square":
		# a hollow square: men on four faces, each rank facing OUTWARD (the cavalry-proof
		# formation). `f` carries each man's facing offset from the battalion facing.
		var sranks := 4
		var per_side := int(ceil(float(n) / 4.0))
		var sf := maxi(1, int(ceil(float(per_side) / float(sranks))))
		var side_half := (sf - 1) * SP * 0.5
		var edge := side_half + sranks * SP * 0.6          # outer edge from the centre
		for i in range(n):
			var side := mini(i / per_side, 3)
			var k := i % per_side
			var along := (float(k / sranks) - (sf - 1) * 0.5) * SP + randf_range(-0.05, 0.05)
			var depth := edge - float(k % sranks) * SP
			var px := 0.0
			var pz := 0.0
			var fo := 0.0
			match side:
				0: px = along; pz = depth; fo = 0.0          # front, faces forward
				1: px = depth; pz = -along; fo = -PI * 0.5   # right, faces right
				2: px = -along; pz = -depth; fo = PI         # rear, faces back
				3: px = -depth; pz = along; fo = PI * 0.5    # left, faces left
			out.append({ "p": Vector2(px, pz), "c": 0, "f": fo })
		return out
	for i in range(n):
		var fi := i % files
		var ra := i / files
		var x := (float(fi) - (files - 1) * 0.5) * SP + randf_range(-0.09, 0.09)
		var z := (float(ra) - (ranks - 1) * 0.5) * SP + randf_range(-0.09, 0.09)
		out.append({ "p": Vector2(x, z), "c": 0 })
	return out

func _halfwidth(b: Batt) -> float:
	var files := _dims(b.figs.size(), b.formation).x
	if b.formation == "line":
		var fpc := int(ceil(files / float(b.companies)))
		var cu := int(ceil(files / float(fpc)))
		return ((files - 1) * SP + (cu - 1) * COMPANY_GAP) * 0.5
	if b.formation == "skirmish":
		return files * SKIRM_SP * 0.5
	if b.formation == "square":
		return files * SP * 0.6 + SP * 4.0
	return files * SP * 0.5

# Lateral centre (formation frame) of company c — used to post company sergeants.
func _company_x(b: Batt, c: int) -> float:
	var files := _dims(b.figs.size(), b.formation).x
	var fpc := int(ceil(files / float(b.companies)))
	var cu := int(ceil(files / float(fpc)))
	var total := (files - 1) * SP + (cu - 1) * COMPANY_GAP
	var cc := mini(c, cu - 1)
	var fcenter := (cc * fpc + mini((cc + 1) * fpc - 1, files - 1)) * 0.5
	return fcenter * SP + cc * COMPANY_GAP - total * 0.5

# ------------------------------------------------------------------ artillery

func _build_guns() -> void:
	# flying-roundshot markers (a small dark ball, instanced)
	var smi := MultiMeshInstance3D.new()
	shot_mm = MultiMesh.new()
	shot_mm.transform_format = MultiMesh.TRANSFORM_3D
	var sph := SphereMesh.new()
	sph.radius = 0.11
	sph.height = 0.22
	shot_mm.mesh = sph
	shot_mm.instance_count = SHOT_POOL
	smi.multimesh = shot_mm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.05, 0.05, 0.06)
	smat.metallic = 0.6
	smat.roughness = 0.5
	smi.material_override = smat
	add_child(smi)
	for i in range(SHOT_POOL):
		shot_mm.set_instance_transform(i, _zero_xf())

	# ground furrows torn open where roundshot strikes (a flat dark gouge, instanced)
	var scmi := MultiMeshInstance3D.new()
	scar_mm = MultiMesh.new()
	scar_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pl := PlaneMesh.new()
	pl.size = Vector2(0.8, 5.0)                # narrow and long, laid along the shot's path
	scar_mm.mesh = pl
	scar_mm.instance_count = SCAR_MAX
	scmi.multimesh = scar_mm
	var scmat := StandardMaterial3D.new()
	scmat.albedo_color = Color(0.14, 0.10, 0.07)
	scmat.roughness = 1.0
	scmi.material_override = scmat
	add_child(scmi)
	for i in range(SCAR_MAX):
		scar_mm.set_instance_transform(i, _zero_xf())

	# guns massed into batteries, each posted behind the line of battle. The pieces
	# of a battery stand close together (wheel to wheel) and fire as a body.
	for team in [0, 1]:
		var zline := -262.0 if team == 0 else 262.0   # posted behind the line of battle
		var face := 0.0 if team == 0 else PI
		for bi in range(0 if _inflated else BATTERIES_PER_TEAM):   # v1 inflation: foot only
			# batteries spread across the whole army front, behind the first line
			var bx := (float(bi) - (BATTERIES_PER_TEAM - 1) * 0.5) * 640.0
			var span := (GUNS_PER_BATTERY - 1) * GUN_SPACING
			for i in range(GUNS_PER_BATTERY):
				var g := Gun.new()
				g.team = team
				var x := bx + float(i) * GUN_SPACING - span * 0.5
				var zjit := randf_range(-1.5, 1.5)              # a slightly ragged line
				g.pos = Vector3(x, 0, zline + zjit)
				g.move_to = g.pos
				g.facing = face
				g.reload = ARTY_RELOAD * randf_range(0.2, 1.0)   # stagger the opening rounds
				_make_gun(g)
				guns.append(g)

# Build one piece: a bronze barrel on a wooden carriage with two wheels and a crew.
func _make_gun(g: Gun) -> void:
	var n := Node3D.new()
	n.position = g.pos
	n.rotation.y = g.facing
	add_child(n)
	g.node = n

	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.22, 0.12)
	wood.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.07, 0.07, 0.08)
	iron.metallic = 0.5
	iron.roughness = 0.5
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.42, 0.34, 0.16)
	bronze.metallic = 0.8
	bronze.roughness = 0.4

	# carriage trail (slopes back from the axle to the ground)
	var trail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.5, 0.22, 2.0)
	trail.mesh = tb
	trail.position = Vector3(0, 0.35, -0.7)
	trail.material_override = wood
	n.add_child(trail)

	# two wheels (cylinders laid on the axle)
	for sx in [-0.62, 0.62]:
		var wheel := MeshInstance3D.new()
		var wc := CylinderMesh.new()
		wc.top_radius = 0.55
		wc.bottom_radius = 0.55
		wc.height = 0.14
		wheel.mesh = wc
		wheel.rotation = Vector3(0, 0, PI * 0.5)   # stand the cylinder up on its rim
		wheel.position = Vector3(sx, 0.55, 0.15)
		wheel.material_override = wood
		n.add_child(wheel)

	# the barrel — recoils backward when fired, so keep it on its own node
	var barrel := Node3D.new()
	barrel.position = Vector3(0, 0.78, 0.25)
	n.add_child(barrel)
	g.barrel = barrel
	var tube := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = 0.10
	tc.bottom_radius = 0.135
	tc.height = 1.7
	tube.mesh = tc
	tube.rotation = Vector3(deg_to_rad(-92.0), 0, 0)   # lay it along +Z, muzzle slightly up
	tube.material_override = bronze
	barrel.add_child(tube)

	# the crew — capsules clustered at the breech (the last one is the rammer, who
	# steps up to the muzzle to load). Kept as nodes so they can be animated.
	for off in [Vector3(0.8, 0, -0.4), Vector3(-0.8, 0, -0.4), Vector3(0, 0, -1.4)]:
		var crew := MeshInstance3D.new()
		var cc := CapsuleMesh.new()
		cc.radius = 0.2
		cc.height = 1.7
		crew.mesh = cc
		var base := Vector3(off.x, CAP_HALF, off.z)
		crew.position = base
		var crewmat := StandardMaterial3D.new()
		crewmat.albedo_color = team_color(g.team).darkened(0.25)
		crew.material_override = crewmat
		n.add_child(crew)
		g.crew.append(crew)
		g.crew_base.append(base)

	# the limber — an ammunition chest on an axle drawn by a four-horse team. Hidden
	# until the piece hooks up to move; it leads the gun in the direction of travel.
	g.limber_group = Node3D.new()
	n.add_child(g.limber_group)
	g.limber_group.visible = false
	var horsemat := StandardMaterial3D.new()
	horsemat.albedo_color = Color(0.20, 0.13, 0.08)
	horsemat.roughness = 0.9
	var chest := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.9, 0.55, 1.0)
	chest.mesh = cb
	chest.position = Vector3(0, 0.6, 1.7)
	chest.material_override = wood
	g.limber_group.add_child(chest)
	for sx2 in [-0.55, 0.55]:
		var lw := MeshInstance3D.new()
		var lwc := CylinderMesh.new()
		lwc.top_radius = 0.5
		lwc.bottom_radius = 0.5
		lwc.height = 0.12
		lw.mesh = lwc
		lw.rotation = Vector3(0, 0, PI * 0.5)
		lw.position = Vector3(sx2, 0.5, 1.5)
		lw.material_override = wood
		g.limber_group.add_child(lw)
	for hz in [3.0, 4.7]:
		for sx3 in [-0.45, 0.45]:
			var horse := MeshInstance3D.new()
			var hc := CapsuleMesh.new()
			hc.radius = 0.3
			hc.height = 1.7
			horse.mesh = hc
			horse.rotation = Vector3(PI * 0.5, 0, 0)   # lay it along the travel direction
			horse.position = Vector3(sx3, 0.9, hz)
			horse.material_override = horsemat
			g.limber_group.add_child(horse)

# Pick a gun's target. It obeys its brigade's fire mission when one is set and in
# range, otherwise prioritises by doctrine: the nearest FORMED body (skirmishers make
# poor targets) that it can reach.
func _gun_target(g: Gun) -> Batt:
	if g.brigade != null and g.brigade.fire_mission != null:
		var fm: Batt = g.brigade.fire_mission
		if not fm.spent and fm.figs.size() >= 60 and g.pos.distance_to(fm.pos) <= ARTY_RANGE:
			return fm
	var best: Batt = null
	var best_score := 1.0e18
	for b in battalions:
		if b.team == g.team or b.figs.size() < 60:
			continue
		var d := g.pos.distance_to(b.pos)
		if d > ARTY_RANGE:
			continue
		var score := d * (1.8 if b.skirmish else 1.0)
		if score < best_score:
			best_score = score
			best = b
	return best

# The nearest live enemy gun in front of a battalion (so infantry can rake a battery).
func _nearest_enemy_gun_in_range(b: Batt, rng: float) -> Gun:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var best: Gun = null
	var bd := rng
	for g in guns:
		if g.team == b.team or g.dead or g.crew.is_empty():
			continue
		var to := g.pos - b.pos
		to.y = 0.0
		var d := to.length()
		if d > rng or d < 0.01:
			continue
		if to.normalized().dot(fwd) < 0.2:        # must be roughly to the front
			continue
		if d < bd:
			bd = d
			best = g
	return best

# A musket ball finds the gun crew: enough hits and a man drops; lose the crew and
# the piece falls silent. Returns true if a crewman was actually felled.
func _hit_gun(g: Gun, from_pos: Vector3) -> bool:
	if g.dead:
		return false
	g.crew_dmg += 1.0
	if g.crew_dmg >= CREW_HP:
		g.crew_dmg -= CREW_HP
		_drop_crewman(g, from_pos)
		return true
	return false

func _drop_crewman(g: Gun, from_pos: Vector3) -> void:
	if g.crew.is_empty():
		g.dead = true
		return
	var node: MeshInstance3D = g.crew.pop_back()
	g.crew_base.pop_back()
	var wp: Vector3 = g.node.to_global(node.position)
	var knock := wp - from_pos
	node.queue_free()
	_drop_dead(Vector3(wp.x, 0.0, wp.z), g.team, knock, true)   # he falls where he stood
	if g.crew.is_empty():
		g.dead = true

func _update_guns(delta: float) -> void:
	for g in guns:
		if g.dead:
			continue                                 # crew shot down — the gun stands silent
		g.recoil = maxf(0.0, g.recoil - delta * 3.2)
		if g.barrel:
			g.barrel.position.z = 0.25 - g.recoil   # slide back on the carriage, ease forward
		if g.limber_state == "deployed":
			_animate_gun_crew(g)                     # work the piece only when in battery
		# the gun is a deliberate, slow business to move: hook up the team (limber), trundle
		# to the new ground, then unhook and deploy (unlimber). It cannot fire while limbered.
		var md := Vector2(g.move_to.x - g.pos.x, g.move_to.z - g.pos.z).length()
		match g.limber_state:
			"deployed":
				if md > ARTY_MOVE_THRESHOLD:
					g.limber_state = "limbering"   # the order has shifted far enough to move
					g.limber_t = LIMBER_TIME
				else:
					_gun_serve(g, delta)           # stand and fight
			"limbering":
				g.limber_t -= delta
				_set_limber_visible(g, true)
				if g.limber_t <= 0.0:
					g.limber_state = "moving"
			"moving":
				_set_limber_visible(g, true)
				if md < 1.5:
					g.limber_state = "unlimbering"
					g.limber_t = LIMBER_TIME
				else:
					var to2 := g.move_to - g.pos
					to2.y = 0.0
					g.facing = lerp_angle(g.facing, atan2(to2.x, to2.z), clampf(delta * 0.8, 0.0, 1.0))
					g.pos = g.pos.move_toward(Vector3(g.move_to.x, 0.0, g.move_to.z), ARTY_MOVE_SPEED * delta)
					if g.node:
						g.node.position = g.pos
						g.node.rotation.y = g.facing
			"unlimbering":
				g.limber_t -= delta
				if g.limber_t <= 0.0:
					g.limber_state = "deployed"
					_set_limber_visible(g, false)

func _set_limber_visible(g: Gun, v: bool) -> void:
	if g.limber_group and g.limber_group.visible != v:
		g.limber_group.visible = v

# Serve the piece in place: traverse onto a target and fire when reloaded. Enemy
# horse closing on the battery is the emergency — canister into the charge.
func _gun_serve(g: Gun, delta: float) -> void:
	if not _battle_begun:
		return                           # the batteries stand silent until the step-off
	var cav_foe: Cav = null
	var cbd := CANISTER_RANGE * 1.5
	for c in cavalry:
		if c.team == g.team or c.spent or c.state == "fled" or c.troopers.is_empty():
			continue
		var cd := g.pos.distance_to(c.pos)
		if cd < cbd:
			cbd = cd
			cav_foe = c
	var foe := _gun_target(g)
	var aim_pos: Vector3
	if cav_foe != null:
		aim_pos = cav_foe.pos
	elif foe != null:
		aim_pos = foe.pos
	else:
		return
	# traverse to bear on the target (the crew heaves the trail around)
	var to := aim_pos - g.pos
	to.y = 0.0
	var want := atan2(to.x, to.z)
	g.facing = lerp_angle(g.facing, want, clampf(delta * 1.6, 0.0, 1.0))
	if g.node:
		g.node.rotation.y = g.facing
	g.reload -= delta
	if g.reload <= 0.0:
		g.reload = ARTY_RELOAD * randf_range(0.82, 1.18)
		g.reload_max = g.reload
		if cav_foe != null:
			_gun_fire_cav(g, cav_foe)
		else:
			_gun_fire(g, foe)

# A blast of canister into horse at close range — saddles empty by the half-dozen.
func _gun_fire_cav(g: Gun, c: Cav) -> void:
	var fwd := Vector3(sin(g.facing), 0, cos(g.facing))
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95, 0)
	g.recoil = 0.55
	var near := cam != null and cam.position.distance_to(g.pos) < LOD_VFAR
	if g.node and near:
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_fire(muzzle, fwd)
		for s in range(18):
			_emit_gun_smoke(muzzle + fwd * randf_range(0.0, 0.8), fwd)
		_muzzle_light(muzzle)
	_play_cannon(muzzle)
	var prox := clampf(1.0 - cam.position.distance_to(g.pos) / 160.0, 0.0, 1.0) if cam else 0.0
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.6, SHAKE_MAX)
	_cav_lose(c, randi_range(4, 9), near)

# Drive the crew through the loading drill: the rammer steps to the muzzle and rams,
# the gunners work the piece and flinch back at the discharge.
func _animate_gun_crew(g: Gun) -> void:
	if g.crew.is_empty():
		return
	var ph := clampf(1.0 - g.reload / maxf(0.5, g.reload_max), 0.0, 1.0)   # 0 just fired → 1 ready
	var last := g.crew.size() - 1
	for ci in range(g.crew.size()):
		var node: Node3D = g.crew[ci]
		var base: Vector3 = g.crew_base[ci]
		if ci == last:
			# rammer: advances to the muzzle and rams home the charge mid-cycle
			var stroke := 0.0
			var lean := 0.0
			if ph > 0.1 and ph < 0.4:              # ram early, then stand by the loaded gun
				var u := (ph - 0.1) / 0.3
				stroke = sin(u * PI) * 2.5         # forward toward the muzzle and back
				lean = sin(u * PI) * 0.45          # bends to the work
			node.position = Vector3(base.x, base.y, base.z + stroke)
			node.rotation.x = lean
		else:
			# gunners: a small working sway, then a sharp step back when it fires
			var step := clampf(g.recoil, 0.0, 1.0) * 0.5
			var sway := sin(_t * 3.0 + float(ci) + float(g.team)) * 0.05
			node.position = Vector3(base.x + sway, base.y, base.z - step)

func _gun_fire(g: Gun, foe: Batt) -> void:
	var fwd := Vector3(sin(g.facing), 0, cos(g.facing))
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95, 0)
	var d := g.pos.distance_to(foe.pos)
	# muzzle blast: a deep gout of flame and smoke, a stab of light, a heavy report
	g.recoil = 0.55
	if g.node and cam.position.distance_to(g.pos) < LOD_VFAR:
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_fire(muzzle, fwd)
		_emit_fire(muzzle, fwd)
		# a gun jettisons a huge bank of smoke straight out of the muzzle
		for s in range(18):
			_emit_gun_smoke(muzzle + fwd * randf_range(0.0, 0.8), fwd)
		_muzzle_light(muzzle)
	_play_cannon(muzzle)
	var prox := clampf(1.0 - cam.position.distance_to(g.pos) / 160.0, 0.0, 1.0)
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.6, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * 0.14, 0.32)
	if d <= CANISTER_RANGE:
		_canister(muzzle, fwd, g.team)        # close work: a wall of balls, instantly
	else:
		# gun-laying is never perfect: scatter the fall of shot across (and around) the
		# target so a battery rakes the whole formation instead of one spot in the centre
		var right := Vector3(fwd.z, 0, -fwd.x)
		var lat := clampf(d * 0.085, 4.0, 36.0)       # gun-laying error grows with range
		var rng := clampf(d * 0.10, 5.0, 46.0)
		var aim := foe.pos + right * randfn(0.0, lat) + fwd * randfn(0.0, rng)
		_spawn_shot(muzzle, Vector3(aim.x, 1.0, aim.z), g.team)

# Gouge a furrow in the turf where roundshot strikes and skips along.
func _add_scar(pos: Vector3, dir: Vector3) -> void:
	var yaw := atan2(dir.x, dir.z)            # align the long axis with the shot's flight
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(randf_range(0.8, 1.3), 1.0, randf_range(0.8, 1.4)))
	scar_mm.set_instance_transform(scar_idx, Transform3D(basis, Vector3(pos.x, 0.02, pos.z)))
	scar_idx = (scar_idx + 1) % SCAR_MAX

# Light the field from a pooled muzzle flash (shared with musketry).
func _muzzle_light(pos: Vector3) -> void:
	var l: OmniLight3D = _lights[_light_i]
	_light_i = (_light_i + 1) % _lights.size()
	l.position = pos
	l.light_color = Color(1.0, 0.74, 0.40)
	l.light_energy = 7.0 + _night * 9.0       # a gun's flash floods the field at night
	l.omni_range = 26.0 + _night * 14.0

func _play_cannon(pos: Vector3) -> void:
	# a random cannon-shot recording (falls back to the old single file if present)
	var stream: AudioStream = null
	if not snd_cannon_shots.is_empty():
		stream = snd_cannon_shots[randi() % snd_cannon_shots.size()]
	elif snd_cannon != null:
		stream = snd_cannon
	if stream == null:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = stream
	ap.global_position = to_global(pos)
	ap.volume_db = 16.0
	ap.pitch_scale = randf_range(0.92, 1.06)
	ap.play()

# A roundshot leaves the muzzle and arcs (visibly) to the target, then bowls a lane.
func _spawn_shot(from: Vector3, to: Vector3, team: int) -> void:
	var flat := to - from
	flat.y = 0.0
	var L := flat.length()
	if L < 1.0:
		return
	var dir := flat / L
	var slot := -1
	for i in range(_shots.size()):
		if not _shots[i]["active"]:
			slot = i
			break
	if slot == -1:
		if _shots.size() >= SHOT_POOL:
			_plough(Vector3(to.x, 0, to.z), dir, team)   # no free marker — resolve now
			return
		_shots.append({ "active": false })
		slot = _shots.size() - 1
	# ballistic launch: horizontal speed fixed, vertical set to land on the target
	var tof := L / SHOT_SPEED
	var vy := (to.y - from.y) / tof + 0.5 * GUN_GRAVITY * tof
	var vel := dir * SHOT_SPEED + Vector3(0, vy, 0)
	_shots[slot] = { "active": true, "pos": from, "vel": vel, "from": from,
		"dir": dir, "dist": L, "team": team }

func _update_shots(delta: float) -> void:
	for i in range(_shots.size()):
		var s: Dictionary = _shots[i]
		if not s.get("active", false):
			continue
		var vel: Vector3 = s["vel"]
		var p: Vector3 = (s["pos"] as Vector3) + vel * delta
		vel.y -= GUN_GRAVITY * delta
		s["pos"] = p
		s["vel"] = vel
		var from: Vector3 = s["from"]
		var flat_trav := Vector2(p.x - from.x, p.z - from.z).length()
		if flat_trav >= float(s["dist"]):
			# arrival — plough a lane through whatever stands here
			var dir: Vector3 = s["dir"]
			var impact := Vector3(p.x, 0, p.z)
			_add_scar(impact - dir * 2.0, dir)        # the furrow starts just short of impact
			_plough(impact, dir, int(s["team"]))
			for k in range(3):
				_emit_smoke(Vector3(p.x, 0.3, p.z), Vector3.UP)   # dirt kicked up
			s["active"] = false
	# render the balls in flight
	for i in range(SHOT_POOL):
		if i < _shots.size() and _shots[i].get("active", false):
			shot_mm.set_instance_transform(i, Transform3D(Basis(), _shots[i]["pos"]))
		else:
			shot_mm.set_instance_transform(i, _zero_xf())

# Roundshot bowls a corridor through the enemy: every man in its narrow lane goes
# down, front to back, until the ball spends its force (PLOUGH_DEPTH deep).
func _plough(origin: Vector3, dir: Vector3, shooter_team: int) -> void:
	var enemy := 1 - shooter_team
	for b in battalions:
		if b.team != enemy or b.figs.is_empty():
			continue
		var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var fright := Vector3(ffwd.z, 0, -ffwd.x)
		var victims: Array = []
		for i in range(b.figs.size()):
			var sl: Vector2 = b.figs[i]["slot"]
			var w := b.pos + fright * sl.x + ffwd * sl.y
			var to := w - origin
			to.y = 0.0
			var along := to.dot(dir)
			if along < -1.5 or along > PLOUGH_DEPTH:
				continue
			if (to - dir * along).length() <= BALL_HALFWIDTH:
				victims.append(i)
		if victims.is_empty():
			continue
		victims.reverse()                       # remove back-to-front, keep indices valid
		for idx in victims:
			var sl2: Vector2 = b.figs[idx]["slot"]
			var w2 := b.pos + fright * sl2.x + ffwd * sl2.y
			_drop_dead(w2, b.team, dir, b.visible)
			b.figs.remove_at(idx)
			b.cas_since_redress += 1
		# a roundshot tearing a lane through the ranks shakes the whole formation
		b.morale -= 6.0 + float(victims.size()) * 2.0
		b.flinch = minf(b.flinch + 0.5, 1.6)
		b.calm_t = 0.0

# Canister: the gun vomits a fan of musket-balls — murderous at close range.
func _canister(origin: Vector3, dir: Vector3, shooter_team: int) -> void:
	var enemy := 1 - shooter_team
	var foe: Batt = null
	var bd := 1e9
	for b in battalions:
		if b.team != enemy or b.figs.size() < 1:
			continue
		var d := origin.distance_to(b.pos)
		if d < bd:
			bd = d
			foe = b
	if foe == null:
		return
	for n in range(CANISTER_BALLS):
		var spread := dir.rotated(Vector3.UP, randf_range(-0.16, 0.16))
		_kill_along_ray(foe, origin, spread)
	foe.morale -= 10.0
	foe.flinch = minf(foe.flinch + 0.7, 1.6)
	foe.calm_t = 0.0

# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_t += delta
	_update_player_officer(delta)            # you always drive YOUR own officer
	if authoritative:
		# the host (or single-player) runs the whole simulation
		_player_order_cd = maxf(0.0, _player_order_cd - delta)
		_update_brigades(delta)          # commanders set every AI battalion's task first
		for b in battalions:
			_update_morale(b, delta)
			b.charge_cool = maxf(0.0, b.charge_cool - delta)
			b.flinch = maxf(0.0, b.flinch - delta * 2.2)
			b.melee_vis = b.melee_foe != null
			if b.state == "routing":
				b.charging = false
				b.melee_foe = null
				_sim_flee(b, delta)
			elif b.melee_foe != null:
				_sim_melee(b, delta)
			elif b.charging:
				_sim_charge(b, delta)
			elif b.parent != null:
				_sim_skirm_det(b, delta)     # a detached company screens its battalion
			elif b.human:
				_sim_player(b, delta)        # any player-led battalion
			else:
				_sim_ai(b, delta)
		for b in battalions:
			_update_firing(b, delta)
		for b in battalions:
			if b.kills_pending > 0:                 # melee removes from the contact edge
				_kill_some(b, b.kills_pending)
				b.cas_since_redress += b.kills_pending
				b.kills_pending = 0
			# firing kills men directly (per-shot rays); the NCOs dress the ranks and
			# close the gaps promptly, so re-dress after only a few have fallen
			if b.cas_since_redress >= 6:
				_reslot(b)
				b.cas_since_redress = 0
			_command_casualties(b, delta)   # officer / colours / drummer can be shot away
		_update_guns(delta)
		_update_cavalry(delta)           # the horse looks for its moment
		_warn_player_cavalry(delta)      # "Cavalry! Form square!"
		_update_rally(delta)             # your presence steadies broken men
		_update_caissons(delta)          # the ammunition waggons plod up from the rear
		_update_couriers(delta)
		_update_combat(delta)            # your own sabre, pistol and mortality
		_update_prestige()               # your renown rises and falls with the butcher's bill
		_update_battle_flow(delta)       # deployment, army collapse, victory & defeat
		_net_broadcast(delta)
	else:
		# client: no sim — battalions come from the host via _apply_state. We still
		# generate the continuous fire-at-will crackle locally from synced state.
		for b in battalions:
			b.flinch = maxf(0.0, b.flinch - delta * 2.2)
			_client_firing_fx(b, delta)
		_net_send_input(delta)
	if player != null:
		_shake = maxf(_shake, player.flinch * 0.4)   # you FEEL your unit get hit
	_update_ragdolls(delta)
	_update_wounded(delta)
	_update_shots(delta)
	_update_drums(delta)
	_update_marching_drums(delta)
	_render(delta)
	_decay_cinematic(delta)
	_update_cam(delta)
	_update_environment(delta)        # sky, sun, fog, weather follow the clock
	_update_hud()

# Each battalion's drummer beats the march while the unit is on the move: a random
# cadence is struck up when it starts moving and falls silent the moment it halts.
func _update_marching_drums(_delta: float) -> void:
	if snd_marchdrum.is_empty() or cam == null:
		return
	for b in battalions:
		var mp: AudioStreamPlayer3D = b.march_player
		if mp == null:
			continue
		var moved := b.pos.distance_to(b.last_pos)
		b.last_pos = b.pos
		var moving := moved > 0.004 and not b.spent and b.state != "routing" and not b.drummer_down
		var near := cam.position.distance_to(b.pos) < 950.0   # drums carry down the line
		if moving and near:
			if not b.marching:
				b.marching = true                                  # struck up on the move
				mp.stream = snd_marchdrum[randi() % snd_marchdrum.size()]
				mp.pitch_scale = randf_range(0.97, 1.03)
				mp.play()
			elif not mp.playing:
				mp.play()                                          # keep it going while marching
			mp.global_position = to_global(b.pos + Vector3(0, 1.0, 0))
		elif b.marching or mp.playing:
			b.marching = false
			mp.stop()                                              # halted — the drum stops

# The drum carries the unit's nerve: a steady confident cadence, faltering and
# quiet when shaken, silent when broken. (Needs a Drum.mp3 in sounds/.)
func _update_drums(delta: float) -> void:
	if snd_drum == null or player == null or player.state == "routing" or player.drummer_down:
		return                                   # no drummer, no cadence
	_drum_cd -= delta
	if _drum_cd > 0.0:
		return
	var m := clampf(player.morale / 100.0, 0.0, 1.0)
	_drum_cd = lerpf(0.55, 0.95, 1.0 - m) * randf_range(0.92, 1.08)
	if player.state == "shaken" and randf() < 0.35:
		return                                   # a dropped beat — the cadence falters
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_drum
	ap.global_position = to_global(off_pos + Vector3(0, 1.0, 0))
	ap.volume_db = lerpf(4.0, -7.0, 1.0 - m)
	ap.pitch_scale = randf_range(0.98, 1.02)
	ap.play()

func _decay_cinematic(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
	_flash_amt = maxf(0.0, _flash_amt - delta * 1.2)
	if _flash_rect:
		_flash_rect.color.a = _flash_amt
	_suppress = maxf(0.0, _suppress - delta * 1.1)   # eases off gently
	if _suppress_rect:
		_suppress_rect.modulate.a = _suppress
	for l in _lights:
		if l.light_energy > 0.0:
			l.light_energy = maxf(0.0, l.light_energy - delta * 55.0)

# Each soldier loads on his own ragged clock. He fires when: at will (the instant
# he's loaded), on the officer's "FIRE!" (volley), or when his company's turn comes
# in a fire-by-company sweep — otherwise he stands loaded with his musket levelled.
func _update_firing(b: Batt, delta: float) -> void:
	b.has_target = false
	b.masked = false
	if b.charging or b.melee_foe != null:
		return                           # bayonet work, not musketry
	if b.formation != "line":
		b.rolling = false                # fire-by-company is a line manoeuvre
	if b.state == "routing":
		b.fire_now = false
		b.rolling = false
		return
	var foe := _nearest_enemy_in_range(b, FIRE_RANGE)
	# guns are targets too: if a live enemy battery is nearer than any battalion in
	# front of us, the line turns its fire on the gunners (a tactical objective)
	var gun_foe := _nearest_enemy_gun_in_range(b, FIRE_RANGE)
	var aim_gun := false
	if gun_foe != null and (foe == null or b.pos.distance_to(gun_foe.pos) <= b.pos.distance_to(foe.pos)):
		aim_gun = true
	# and CAVALRY: horse in musket range to the front takes priority over everything —
	# the charge must ride through the fire to reach the line
	var cav_foe := _nearest_enemy_cav_in_range(b, FIRE_RANGE)
	var aim_cav := false
	if cav_foe != null:
		var dc := b.pos.distance_to(cav_foe.pos)
		var dfo: float = b.pos.distance_to(foe.pos) if foe != null else 1.0e9
		var dgu: float = b.pos.distance_to(gun_foe.pos) if gun_foe != null else 1.0e9
		if dc <= dfo and dc <= dgu:
			aim_cav = true
			aim_gun = false
	b.has_target = foe != null or gun_foe != null or cav_foe != null
	if not b.has_target:
		b.fire_now = false
		return
	if b.ammo <= 0.0:
		b.fire_now = false
		b.rolling = false
		return                           # cartridge boxes empty — no musketry left
	var tpos: Vector3 = cav_foe.pos if aim_cav else (gun_foe.pos if aim_gun else foe.pos)
	b.masked = _fire_masked(b, tpos)
	if b.masked:
		b.has_target = false             # friends in the lane — the muskets come up
		b.fire_now = false
		return
	var hc := _hit_chance(b.pos.distance_to(tpos))
	var maxy := -1e9
	for f0 in b.figs:
		maxy = maxf(maxy, (f0["slot"] as Vector2).y)
	var fire_band := maxy - SP * 1.6
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	# volley fire: hold until EVERY front-rank man is loaded, then the words of command
	# run down the line — "Make ready!… Present!… FIRE!" — and the crash follows
	if b.volley_fire and b.auto_volley and not b.fire_now:
		if b.volley_seq > 0.0:
			var prevseq := b.volley_seq
			b.volley_seq -= delta
			if prevseq > 1.2 and b.volley_seq <= 1.2:
				_play_voice(snd_v_present, b.off_pos)
			if b.volley_seq <= 0.0:
				_play_voice(snd_v_fire, b.off_pos)
				b.fire_now = true
		else:
			var all_loaded := true
			for f0 in b.figs:
				if (f0["slot"] as Vector2).y >= fire_band and float(f0["reload"]) > 0.0:
					all_loaded = false
					break
			if all_loaded:
				b.volley_seq = 2.4
				_play_voice(snd_v_ready, b.off_pos)
	var atwill := (not b.volley_fire) and (not b.rolling)
	var commanded := b.fire_now and (not b.rolling)
	var shaken := 1.4 if b.state == "shaken" else 1.0
	var vis := b.visible

	# advance the fire-by-company sweep (right company first, rolling to the left)
	var firing_company := -1
	if b.rolling:
		b.roll_cd -= delta
		if b.roll_cd <= 0.0:
			firing_company = b.roll_company
			b.roll_company -= 1
			if b.roll_company < 0:
				b.roll_company = b.companies - 1   # continuous sweep
			b.roll_cd = COMPANY_ROLL

	var kills := 0
	var felled := 0                  # enemies actually dropped (for the player's prestige)
	var massed_men := 0              # men firing a synchronized volley/company this frame
	var shots := 0                   # rounds expended this frame (for ammunition)
	var volley_pts: Array = []
	for f in b.figs:
		if (f["slot"] as Vector2).y < fire_band:
			continue                     # rear ranks don't fire
		var r := float(f["reload"]) - delta
		if r > 0.0:
			f["reload"] = r
			continue                     # still loading
		# loaded — does he fire this frame?
		var fire := false
		if b.rolling:
			fire = int(f["company"]) == firing_company
		elif atwill or commanded:
			fire = true
		if fire:
			if _wet > 0.0 and randf() < _wet * 0.4:
				f["reload"] = RELOAD_TIME * 0.45 * randf_range(0.7, 1.2)   # damp powder — misfire, re-prime
				continue
			shots += 1
			var w: Vector3 = f["wpos"]
			var mp := w + Vector3(0, 1.35, 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip
			if atwill:
				if vis:
					_emit_flash(mp)
					_emit_smoke(mp, fwd)
					_emit_muzzle_bloom(mp, fwd)
					_play_shot(mp)       # individual crack
			else:
				massed_men += 1
				if vis:
					_emit_flash(mp)
					_emit_smoke(mp, fwd)
					_emit_smoke(mp, fwd)
					_emit_muzzle_bloom(mp, fwd)
					volley_pts.append(mp)
			if randf() < hc:
				if aim_cav:
					kills += 1
					felled += 1
					_cav_lose(cav_foe, 1, vis)       # a trooper pitches from the saddle
				elif aim_gun:
					kills += 1
					if _hit_gun(gun_foe, b.pos):     # rake the gun crew
						felled += 1
				else:
					# a real ball with a cone of dispersion: it strikes the FIRST enemy
					# body in its path — whichever unit that is — or flies clean past
					var sd := _scatter_dir(fwd, MUSKET_YAW_SD, MUSKET_PITCH_SD)
					var hit := _ray_hit_world(Vector3(w.x, 1.3, w.z), sd, FIRE_RANGE, 1 - b.team)
					if not hit.is_empty():
						kills += 1
						felled += 1
						_drop_fig(hit["b"], hit["i"], sd)
			f["reload"] = RELOAD_TIME * shaken * b.exp_mul * randf_range(0.78, 1.3)
		else:
			f["reload"] = 0.0            # stand loaded, musket levelled, waiting
	b.fire_now = false
	if felled > 0 and (b.is_player or (b.parent != null and b.parent.is_player)):
		prestige += felled               # every enemy your command fells adds to your name
	if shots > 0:
		b.ammo = maxf(0.0, b.ammo - float(shots) * AMMO_PER_SHOT)   # spend the cartridges
	var massed := massed_men > 0
	# the report, smoke-wash and screen shake of a volley fire regardless of target
	if massed and vis and not volley_pts.is_empty():
		var sources := clampi(volley_pts.size() / 16, 3, 12)
		for k in range(sources):
			_play_volley(volley_pts[int((float(k) + 0.5) / float(sources) * volley_pts.size())])
		_volley_cinematic(b, volley_pts)
	if massed and GameConfig.mode == "host":
		_fx.append([FX_VOLLEY, b.idx])       # clients reproduce the volley locally
	# morale shock only lands on a battalion (gun crews and troopers just bleed men)
	if not aim_gun and not aim_cav and foe != null:
		if massed:
			# a wall of fire crashing out at once shocks far beyond the bodies it drops
			foe.morale -= kills * MORALE_PER_CASUALTY * VOLLEY_CASUALTY_MULT + massed_men * VOLLEY_SHOCK
			foe.flinch = minf(foe.flinch + massed_men * 0.004 + float(kills) * 0.04, 1.5)
			foe.calm_t = 0.0
		elif kills > 0:
			# independent fire: the men just trickle down — little moral impact
			foe.morale -= kills * MORALE_PER_CASUALTY * INDEP_MULT
			foe.calm_t = 0.0

# No line fires through its friends. If a friendly battalion (or your own skirmish
# screen) stands in the lane between the muzzles and the target, the fire is MASKED
# and the men hold — exactly why screens were recalled before the volleys began.
func _fire_masked(b: Batt, tpos: Vector3) -> bool:
	var from := b.pos
	var dir := tpos - from
	dir.y = 0.0
	var L := dir.length()
	if L < 1.0:
		return false
	dir /= L
	for f in battalions:
		if f == b or f.team != b.team or f.spent or f.figs.size() < 30:
			continue
		var to := f.pos - from
		to.y = 0.0
		var along := to.dot(dir)
		if along < 4.0 or along > L - 4.0:
			continue                          # not between us and the target
		var lat := (to - dir * along).length()
		if lat < _halfwidth(f) * 0.8 + 2.0:
			return true                       # they stand square in the lane
	return false

# fraction of muskets that hit, falling off sharply with range: murderous at point
# blank, almost nothing at maximum range. (battle conditions, not a proof butt)
func _hit_chance(d: float) -> float:
	if d >= FIRE_RANGE:
		return 0.0
	var t := 1.0 - d / FIRE_RANGE          # 1 at the muzzle, 0 at max range
	return HIT_POINT_BLANK * pow(t, HIT_FALLOFF)

func _update_morale(b: Batt, delta: float) -> void:
	# once the ARMY has broken, its men do not rally — the rout is general and final
	if _army_broken[b.team]:
		b.state = "routing"
		b.morale = minf(b.morale, 12.0)
		return
	# a battalion shot to pieces is finished: it breaks for good and streams to the
	# rear. There is NO reinforcement or regeneration — losses are permanent.
	# (a detached company is judged at company scale, not battalion scale)
	if b.figs.size() < (25 if b.parent != null else 60):
		b.spent = true
		# a shattered skirmish company dissolves back into its battalion (deferred:
		# the recall mutates the battalions array we may be iterating)
		if b.parent != null and b.parent.detachment == b:
			call_deferred("_recall_skirmishers", b.parent)
	if b.spent:
		b.state = "routing"
		b.morale = minf(b.morale, 18.0)
		return
	b.calm_t += delta
	if b.calm_t > 4.0:               # recover once the fire slackens
		var rate := MORALE_RECOVER * (1.8 if b.state == "routing" else 1.0)
		b.morale = minf(100.0, b.morale + rate * delta)
	if b.morale < ROUT_THRESHOLD:
		b.state = "routing"
	elif b.state == "routing":
		if b.morale > 55.0:          # rallied
			b.state = "steady"
	elif b.morale < SHAKEN_THRESHOLD:
		b.state = "shaken"
	else:
		b.state = "steady"

# Under fire, the men at the colours draw the eye and the enemy's aim: the officer,
# the colour-bearer and the drummer can be shot down. Losing the colours is a heavy
# blow; they are taken up again after a moment by another man.
func _command_casualties(b: Batt, delta: float) -> void:
	# recovery timers run every frame
	if b.colours_down:
		b.colours_t -= delta
		if b.colours_t <= 0.0:
			b.colours_down = false
			b.morale = minf(100.0, b.morale + COLOURS_RALLY)   # the colours are saved!
	if b.officer_down:
		b.officer_t -= delta
		if b.officer_t <= 0.0:
			b.officer_down = false
	if b.drummer_down:
		b.drummer_t -= delta
		if b.drummer_t <= 0.0:
			b.drummer_down = false
	if b.spent or b.state == "routing" or b.calm_t > 2.5:
		return                               # only while actually under fire
	b.cmd_check -= delta
	if b.cmd_check > 0.0:
		return
	b.cmd_check = 1.0
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var maxy := -1.0e9
	for f0 in b.figs:
		maxy = maxf(maxy, (f0["slot"] as Vector2).y)
	if not b.colours_down and randf() < CMD_HIT_CHANCE:
		b.colours_down = true
		b.colours_t = randf_range(3.5, 6.0)
		b.morale -= COLOURS_SHOCK
		b.calm_t = 0.0
		_drop_dead(b.pos + right * 0.9 + fwd * (maxy + 0.8), b.team, -fwd, b.visible)
	if not b.is_player and not b.officer_down and randf() < CMD_HIT_CHANCE * 0.8:
		b.officer_down = true
		b.officer_t = randf_range(4.0, 7.0)
		b.morale -= OFFICER_SHOCK
		b.calm_t = 0.0
		_drop_dead(b.pos + fwd * (maxy + 1.6), b.team, -fwd, b.visible)
	if not b.drummer_down and randf() < CMD_HIT_CHANCE * 0.6:
		b.drummer_down = true
		b.drummer_t = randf_range(5.0, 8.0)
		_drop_dead(b.pos + right * -0.9 + fwd * (maxy + 0.7), b.team, -fwd, b.visible)

func _sim_flee(b: Batt, delta: float) -> void:
	var foe := _nearest_enemy(b)
	var away := Vector3(0, 0, 1) if b.team == 0 else Vector3(0, 0, -1)
	if foe != null:
		away = b.pos - foe.pos
		away.y = 0.0
		if away.length() > 0.01:
			away = away.normalized()
	b.facing = atan2(away.x, away.z)
	b.pos += away * ROUT_SPEED * delta
	if b.formation != "column":       # routers lose their dressing into a mob
		b.formation = "column"
		_reslot(b)

func _nearest_enemy_in_range(b: Batt, rng: float) -> Batt:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var best: Batt = null
	var bd := rng
	for o in battalions:
		if o.team == b.team or o.figs.size() < 60:
			continue
		var to := o.pos - b.pos
		to.y = 0.0
		var d := to.length()
		if d > rng or d < 0.01:
			continue
		if to.normalized().dot(fwd) < 0.25:   # enemy must be roughly to the front
			continue
		if d < bd:
			bd = d
			best = o
	return best

func _sim_player(b: Batt, delta: float) -> void:
	if b.is_player:
		b.off_pos = off_pos          # the host's own officer
		b.off_facing = off_vis
	# wheeling: the line pivots slowly to its new facing, then stands
	if b.wheeling:
		b.facing = lerp_angle(b.facing, b.wheel_to, clampf(delta * 0.7, 0.0, 1.0))
		if absf(angle_difference(b.facing, b.wheel_to)) < 0.03:
			b.facing = b.wheel_to
			b.wheeling = false
		return
	# a measured move: march to the ordered point and halt. A fighting withdrawal
	# keeps the line FACING the enemy, stepping backward at half pace, still firing.
	if b.has_goal:
		var tog := b.move_goal - b.pos
		tog.y = 0.0
		var dg := tog.length()
		if dg < 0.5:
			b.has_goal = false
			b.fall_back = false
		else:
			var spd := BATT_SPEED * (0.55 if b.fall_back else 1.0)
			if not b.fall_back:
				b.facing = atan2(tog.x, tog.z)
			b.pos = b.pos.move_toward(Vector3(b.move_goal.x, 0.0, b.move_goal.z), spd * delta)
		return
	# (remote players' officers arrive via net_apply_input)
	if b.order == Order.FOLLOW:
		var fwd_o := Vector3(sin(b.off_facing), 0, cos(b.off_facing))
		b.pos = b.pos.move_toward(b.off_pos - fwd_o * FORMUP_DIST, BATT_SPEED * delta)
		b.facing = b.off_facing
	elif b.advancing:
		# march straight onto the enemy, halting to open fire at deploy range
		var foe := _nearest_enemy(b)
		if foe != null:
			var to := foe.pos - b.pos
			to.y = 0.0
			var d := to.length()
			if d > 0.5:
				b.facing = atan2(to.x, to.z)
			if d > DEPLOY_RANGE:
				b.pos += to.normalized() * BATT_SPEED * delta
			else:
				b.advancing = false       # in range — stand and fight
		else:
			b.pos += Vector3(sin(b.facing), 0, cos(b.facing)) * BATT_SPEED * delta

# ============================================== detachments, rallying, resupply

# One company peels off the right flank and runs forward as a skirmish screen —
# a REAL detached unit the enemy can see, shoot and charge.
func _detach_skirmishers(b: Batt) -> void:
	if b.detachment != null or b.spent or b.formation == "square" or b.figs.size() < 200:
		return
	var n_det: int = clampi(int(ceil(float(b.figs.size()) / float(b.companies))), 64, 130)
	# take the right-flank men (highest lateral slot)
	var order_idx: Array = []
	for i in range(b.figs.size()):
		order_idx.append(i)
	order_idx.sort_custom(func(a, c): return (b.figs[a]["slot"] as Vector2).x > (b.figs[c]["slot"] as Vector2).x)
	var take: Array = order_idx.slice(0, n_det)
	take.sort()
	take.reverse()
	var det := Batt.new()
	det.team = b.team
	det.idx = battalions.size()
	det.parent = b
	det.formation = "skirmish"
	det.skirmish = true
	det.companies = 1
	det.morale = b.morale
	det.ammo = b.ammo
	det.inst_col = b.inst_col          # the company wears its regiment's dress
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	det.pos = b.pos + fwd * 14.0
	det.spawn = det.pos
	det.last_pos = det.pos
	det.facing = b.facing
	det.off_pos = det.pos
	for ti in take:
		det.figs.append(b.figs[ti])
		b.figs.remove_at(ti)
	_reslot(det)
	_reslot(b)
	b.detachment = det
	battalions.append(det)

# The screen falls back and the company dissolves into the battalion line.
func _recall_skirmishers(b: Batt) -> void:
	var det: Batt = b.detachment
	if det == null:
		return
	var tot := b.figs.size() + det.figs.size()
	if tot > 0:   # the company brings back what powder it has
		b.ammo = (b.ammo * b.figs.size() + det.ammo * det.figs.size()) / float(tot)
	for f in det.figs:
		b.figs.append(f)
	det.figs.clear()
	det.spent = true
	for o in battalions:    # sever any combat references to the dissolved company
		if o.melee_foe == det:
			o.melee_foe = null
	for c in cavalry:
		if c.target == det:
			c.target = null
	battalions.erase(det)
	b.detachment = null
	_reslot(b)              # the men walk back into their re-dressed places

# A detached company works as a screen ~40 m ahead of its battalion, conforming to
# its movement and facing, firing at will. If the battalion breaks, so does it.
func _sim_skirm_det(b: Batt, delta: float) -> void:
	var p: Batt = b.parent
	if p == null or p.spent:
		b.morale = minf(b.morale, 20.0)   # the battalion is gone — the screen dissolves
		b.calm_t = 0.0
		return
	if p.state == "routing":
		b.morale = minf(b.morale, 25.0)   # the battalion behind them is running
		b.calm_t = 0.0
		return
	if b.figs.size() < 30 and p.detachment == b:
		# too few left to screen — fold them back in. Deferred: we are inside the
		# battalion loop, and the recall erases this unit from that very array.
		call_deferred("_recall_skirmishers", p)
		return
	var fwd := Vector3(sin(p.facing), 0, cos(p.facing))
	var tgt := p.pos + fwd * SKIRM_SCREEN
	var to := tgt - b.pos
	to.y = 0.0
	b.facing = p.facing
	if to.length() > 2.0:
		b.pos = b.pos.move_toward(Vector3(tgt.x, 0, tgt.z), BATT_SPEED * 1.15 * delta)
	b.off_pos = b.pos - fwd * 6.0
	b.off_facing = b.facing

# Your presence steadies broken men: ride in among a routing friendly battalion and
# its morale climbs until it rallies (the old magic of a general under the colours).
func _update_rally(delta: float) -> void:
	_rally_cd = maxf(0.0, _rally_cd - delta)
	if player == null or _off_down:
		return
	for b in battalions:
		if b.team != player.team or b.spent or b.state != "routing" or _army_broken[b.team]:
			continue
		if off_pos.distance_to(b.pos) < RALLY_RANGE:
			b.morale = minf(100.0, b.morale + RALLY_RATE * delta)
			b.calm_t = maxf(b.calm_t, 4.1)         # your voice counts as breathing room
			if _rally_cd <= 0.0:
				_rally_cd = 10.0
				_send_player_despatch("[color=#ffe9a8]You ride among the fugitives[/color] — steady, men, steady! Form on me!", {})

# --- ammunition caissons: a waggon plods up from the rear and refills the boxes ---

func _request_caisson(b: Batt) -> void:
	if b.caisson_coming or b.spent or b.parent != null or caissons.size() >= 12:
		return
	b.caisson_coming = true
	var origin := Vector3(b.pos.x, 0, -420.0 if b.team == 0 else 420.0)
	var node := _make_caisson_node(b.team)
	node.position = origin
	add_child(node)
	caissons.append({ "node": node, "pos": origin, "target": b, "state": "out", "t": 0.0, "origin": origin })

func _make_caisson_node(team: int) -> Node3D:
	var n := Node3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.21, 0.12)
	wood.roughness = 0.9
	var chest := MeshInstance3D.new()
	var cbx := BoxMesh.new()
	cbx.size = Vector3(1.1, 0.8, 1.9)
	chest.mesh = cbx
	chest.position = Vector3(0, 0.75, -0.2)
	chest.material_override = wood
	n.add_child(chest)
	for sx in [-0.62, 0.62]:
		var wh := MeshInstance3D.new()
		var wc := CylinderMesh.new()
		wc.top_radius = 0.5
		wc.bottom_radius = 0.5
		wc.height = 0.12
		wh.mesh = wc
		wh.rotation = Vector3(0, 0, PI * 0.5)
		wh.position = Vector3(sx, 0.5, 0.0)
		wh.material_override = wood
		n.add_child(wh)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.20, 0.13, 0.08)
	for sx2 in [-0.4, 0.4]:
		var horse := MeshInstance3D.new()
		var hc := CapsuleMesh.new()
		hc.radius = 0.3
		hc.height = 1.7
		horse.mesh = hc
		horse.rotation = Vector3(PI * 0.5, 0, 0)
		horse.position = Vector3(sx2, 0.9, 1.7)
		horse.material_override = hmat
		n.add_child(horse)
	return n

func _update_caissons(delta: float) -> void:
	# the AI's quartermasters watch the line and send waggons forward unbidden
	_caisson_scan -= delta
	if _caisson_scan <= 0.0:
		_caisson_scan = 5.0
		for b in battalions:
			if not b.spent and b.parent == null and b.state != "routing" \
					and b.ammo < 6.0 and not b.caisson_coming:
				_request_caisson(b)
	var i := 0
	while i < caissons.size():
		var cs: Dictionary = caissons[i]
		var node: Node3D = cs["node"]
		var b: Batt = cs["target"]
		var pos: Vector3 = cs["pos"]
		var done := false
		match String(cs["state"]):
			"out":
				if b == null or b.spent or b.state == "routing":
					cs["state"] = "back"
				else:
					var to := b.pos - pos
					to.y = 0.0
					if to.length() < 16.0:
						cs["state"] = "unload"
						cs["t"] = CAISSON_UNLOAD
					else:
						pos = pos.move_toward(Vector3(b.pos.x, 0, b.pos.z), CAISSON_SPEED * delta)
						node.rotation.y = atan2(to.x, to.z)
			"unload":
				cs["t"] = float(cs["t"]) - delta
				if float(cs["t"]) <= 0.0:
					if b != null:
						b.ammo = START_ROUNDS          # boxes filled
						b.caisson_coming = false
						if b.is_player:
							_send_player_despatch("[color=#9fe0a0]Cartridges up![/color] Pass them down the line — %d rounds a man." % int(START_ROUNDS), {})
					cs["state"] = "back"
			"back":
				var orig: Vector3 = cs["origin"]
				var tb := orig - pos
				tb.y = 0.0
				if tb.length() < 6.0:
					node.queue_free()
					done = true
				else:
					pos = pos.move_toward(orig, CAISSON_SPEED * delta)
					node.rotation.y = atan2(tb.x, tb.z)
		cs["pos"] = pos
		node.position = pos
		if done:
			caissons.remove_at(i)
		else:
			i += 1

# ================================================================== cavalry

func _spawn_cavalry() -> void:
	# per-team mounts & riders (instanced)
	for team in [0, 1]:
		var hmi := MultiMeshInstance3D.new()
		var hmm := MultiMesh.new()
		hmm.transform_format = MultiMesh.TRANSFORM_3D
		var hcap2 := CapsuleMesh.new()
		hcap2.radius = 0.32
		hcap2.height = 1.85
		hcap2.radial_segments = 6
		hcap2.rings = 2
		hmm.mesh = hcap2
		hmm.instance_count = CAV_PER_TEAM * CAV_MEN
		hmi.multimesh = hmm
		var hmat2 := StandardMaterial3D.new()
		hmat2.albedo_color = Color(0.22, 0.15, 0.09) if team == 0 else Color(0.13, 0.10, 0.07)
		hmat2.roughness = 0.9
		hmi.material_override = hmat2
		add_child(hmi)
		cav_horse_mm[team] = hmm
		var rmi2 := MultiMeshInstance3D.new()
		var rmm := MultiMesh.new()
		rmm.transform_format = MultiMesh.TRANSFORM_3D
		var rcap2 := CapsuleMesh.new()
		rcap2.radius = 0.22
		rcap2.height = 1.35
		rcap2.radial_segments = 6
		rcap2.rings = 2
		rmm.mesh = rcap2
		rmm.instance_count = CAV_PER_TEAM * CAV_MEN
		rmi2.multimesh = rmm
		var rmat2 := StandardMaterial3D.new()
		rmat2.albedo_color = team_color(team).lightened(0.12)
		rmi2.material_override = rmat2
		add_child(rmi2)
		cav_rider_mm[team] = rmm
		for i in range(CAV_PER_TEAM * CAV_MEN):
			hmm.set_instance_transform(i, _zero_xf())
			rmm.set_instance_transform(i, _zero_xf())
	# the regiments — massed in two wings on the army's flanks, behind the line
	var wing := 2750.0
	for team in [0, 1]:
		var z := -320.0 if team == 0 else 320.0
		var face := 0.0 if team == 0 else PI
		var half := maxi(1, CAV_PER_TEAM / 2)
		for r in range(0 if _inflated else CAV_PER_TEAM):   # v1 inflation: foot only
			var c := Cav.new()
			c.team = team
			c.idx = team * CAV_PER_TEAM + r
			var side := -1.0 if r < half else 1.0
			var rank := r % half
			c.pos = Vector3(side * (wing - float(rank) * 200.0), 0, z + float(rank) * (40.0 if team == 1 else -40.0))
			c.reserve_pos = c.pos
			c.facing = face
			c.decide_cd = randf_range(0.0, CAV_DECIDE)
			var hp := AudioStreamPlayer3D.new()    # hooves, audible far across the field
			hp.max_distance = 1100.0
			hp.unit_size = 22.0
			hp.volume_db = 7.0
			add_child(hp)
			c.hoof_player = hp
			_fill_troopers(c)
			cavalry.append(c)

func _fill_troopers(c: Cav) -> void:
	c.troopers.clear()
	var files := int(ceil(CAV_MEN / 2.0))
	var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for i in range(CAV_MEN):
		var fi := i % files
		var ra := i / files
		var slot := Vector2((float(fi) - (files - 1) * 0.5) * CAV_SP + randf_range(-0.12, 0.12),
			(float(ra) - 0.5) * CAV_SP * 1.6 + randf_range(-0.15, 0.15))
		var w := c.pos + right * slot.x + fwd * slot.y
		c.troopers.append({ "slot": slot, "wpos": Vector3(w.x, 0, w.z), "ph": randf() * TAU })

func _update_cavalry(delta: float) -> void:
	for c in cavalry:
		if c.spent:
			continue
		if c.troopers.size() < 25:
			c.spent = true
			continue
		if _army_broken[c.team] and c.state != "fled":
			c.state = "fled"           # the army is broken — the horse rides off the field
		# the gallop is HEARD: hooves thunder while the regiment charges or flees
		if c.hoof_player != null:
			var gallop := c.state == "charging" or c.state == "fled"
			if gallop and snd_hooves != null:
				if not c.hoof_player.playing:
					c.hoof_player.stream = snd_hooves
					c.hoof_player.pitch_scale = randf_range(0.95, 1.05)
					c.hoof_player.play()
				c.hoof_player.global_position = to_global(c.pos + Vector3(0, 1.0, 0))
			elif c.hoof_player.playing:
				c.hoof_player.stop()
		c.decide_cd -= delta
		match c.state:
			"reserve":
				_cav_move(c, c.reserve_pos, CAV_TROT, delta)
				if _battle_begun and c.decide_cd <= 0.0:
					c.decide_cd = CAV_DECIDE * randf_range(0.8, 1.2)
					_cav_decide(c)
			"charging":
				var tp := _cav_target_pos(c)
				if tp == Vector3.INF:
					c.state = "retiring"   # the target is gone
				elif c.troopers.size() < 45:
					c.state = "retiring"   # too many saddles emptied — the charge falters
				else:
					_cav_move(c, tp, CAV_GALLOP, delta)
					if Vector2(c.pos.x - tp.x, c.pos.z - tp.z).length() < CAV_CONTACT + 4.0:
						_cav_resolve(c)
			"retiring":
				_cav_move(c, c.reserve_pos, CAV_TROT, delta)
				if Vector2(c.pos.x - c.reserve_pos.x, c.pos.z - c.reserve_pos.z).length() < 8.0:
					c.state = "rallying"
					c.rally_t = CAV_RALLY_TIME
			"rallying":
				c.rally_t -= delta
				if c.rally_t <= 0.0:
					c.state = "reserve"
			"fled":
				var away := Vector3(c.pos.x, 0, -900.0 if c.team == 0 else 900.0)
				_cav_move(c, away, CAV_GALLOP * 0.8, delta)

func _cav_move(c: Cav, goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - c.pos
	to.y = 0.0
	if to.length() < 0.5:
		return
	c.facing = atan2(to.x, to.z)
	c.pos = c.pos.move_toward(Vector3(goal.x, 0, goal.z), speed * delta)

func _cav_target_pos(c: Cav) -> Vector3:
	match c.target_kind:
		"batt":
			var b: Batt = c.target
			if b == null or b.figs.size() < 30:
				return Vector3.INF
			return b.pos
		"gun":
			var g: Gun = c.target
			if g == null or g.dead:
				return Vector3.INF
			return g.pos
		"cav":
			var e: Cav = c.target
			if e == null or e.spent or e.state == "fled":
				return Vector3.INF
			return e.pos
	return Vector3.INF

# The eye for an opening: enemy horse bearing down on friends, a routing mob, loose
# skirmishers, a shaken line out of square, an unsupported battery.
func _cav_decide(c: Cav) -> void:
	var best = null
	var best_kind := ""
	var best_score := 0.0
	for e in cavalry:                       # countercharge enemy horse on the move
		if e.team == c.team or e.spent or e.state != "charging":
			continue
		var d := c.pos.distance_to(e.pos)
		if d < CAV_CHARGE_RANGE * 1.4:
			var s := 3.0 - d * 0.004
			if s > best_score:
				best_score = s; best = e; best_kind = "cav"
	for b in battalions:
		if b.team == c.team or b.figs.size() < 60:
			continue
		var d2 := c.pos.distance_to(b.pos)
		if d2 > CAV_CHARGE_RANGE:
			continue
		var s2 := 0.0
		if b.state == "routing":
			s2 = 2.6                        # ride down the runners
		elif b.skirmish:
			s2 = 2.2                        # loose order is meat for horsemen
		elif b.formation == "square":
			s2 = -1.0                       # never charge a formed square
		elif b.state == "shaken" or b.morale < 50.0:
			s2 = 1.6                        # a wavering line may break before contact
		elif b.melee_foe != null:
			s2 = 1.4                        # locked fighting — take them in the rear
		else:
			s2 = 0.25                       # a steady line: only if nothing better offers
		s2 -= d2 * 0.003
		if s2 > best_score:
			best_score = s2; best = b; best_kind = "batt"
	for g in guns:                          # sabre an unsupported battery
		if g.team == c.team or g.dead:
			continue
		var d3 := c.pos.distance_to(g.pos)
		if d3 > CAV_CHARGE_RANGE:
			continue
		var guarded := false
		for b2 in battalions:
			if b2.team == g.team and not b2.spent and b2.pos.distance_to(g.pos) < 70.0:
				guarded = true
				break
		if not guarded:
			var s3 := 2.0 - d3 * 0.004
			if s3 > best_score:
				best_score = s3; best = g; best_kind = "gun"
	if best != null and best_score > 0.8:
		c.target = best
		c.target_kind = best_kind
		c.state = "charging"

# The moment of impact.
func _cav_resolve(c: Cav) -> void:
	var near := cam != null and cam.position.distance_to(c.pos) < LOD_VFAR
	var clash := c.pos + Vector3(0, 1.0, 0)
	match c.target_kind:
		"batt":
			var t: Batt = c.target
			if t.formation == "square" and t.state != "routing":
				# the horses refuse the wall of bayonets — the charge breaks on the square
				_cav_lose(c, int(c.troopers.size() * randf_range(0.14, 0.2)), near)
				_client_volley(t)                       # the square's face delivers its fire
				t.morale -= 2.0
			else:
				# closing fire from the defenders, then the shock goes home
				if t.ammo > 0.0 and t.state != "routing" and not t.skirmish:
					_client_volley(t)
					_cav_lose(c, int(c.troopers.size() * randf_range(0.06, 0.12)), near)
				var weak := t.state != "steady" or t.skirmish or t.morale < 48.0
				var frac := 0.42 if weak else 0.22
				var inf_kills := mini(int(c.troopers.size() * frac), t.figs.size() - 1)
				t.kills_pending += inf_kills
				t.shot_from = c.pos
				t.morale -= 34.0 if weak else 22.0
				t.flinch = minf(t.flinch + 1.4, 1.6)
				t.calm_t = 0.0
				if weak:
					t.morale = minf(t.morale, 22.0)     # broken under the sabres
				else:
					_cav_lose(c, int(c.troopers.size() * randf_range(0.05, 0.09)), near)
		"gun":
			var g: Gun = c.target
			while not g.dead:
				_drop_crewman(g, c.pos)                 # the gunners are sabred at their piece
		"cav":
			var e: Cav = c.target
			var my_p := float(c.troopers.size())
			var en_p := float(e.troopers.size()) * (1.15 if e.state == "charging" else 0.85)
			var i_win := my_p * randf_range(0.85, 1.15) > en_p
			_cav_lose(c, int(c.troopers.size() * (0.10 if i_win else 0.22)), near)
			_cav_lose(e, int(e.troopers.size() * (0.22 if i_win else 0.10)), near)
			e.state = "retiring"
	if near:
		_play_melee(clash)
		var prox := clampf(1.0 - cam.position.distance_to(c.pos) / 140.0, 0.0, 1.0)
		_shake = minf(_shake + prox * 0.5, SHAKE_MAX)
	c.state = "retiring"                                # blown — retire and rally
	c.target = null

# Troopers fall: riders into the corpse layer, the odd horse down with them.
func _cav_lose(c: Cav, n: int, seen: bool) -> void:
	for i in range(mini(n, c.troopers.size())):
		var ti := randi() % c.troopers.size()
		var w: Vector3 = c.troopers[ti]["wpos"]
		_drop_dead(w, c.team, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), seen)
		if randf() < 0.4:
			_add_dead_horse(w + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), randf() * TAU, c.team)
		c.troopers.remove_at(ti)

func _render_cavalry(delta: float) -> void:
	for team in [0, 1]:
		var hmm: MultiMesh = cav_horse_mm[team]
		var rmm: MultiMesh = cav_rider_mm[team]
		if hmm == null:
			continue
		var i := 0
		for c in cavalry:
			if c.team != team or c.spent:
				continue
			var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
			var right := Vector3(fwd.z, 0, -fwd.x)
			var spd := CAV_GALLOP if c.state == "charging" or c.state == "fled" else CAV_TROT
			for tr in c.troopers:
				if i >= hmm.instance_count:
					break
				var slot: Vector2 = tr["slot"]
				var tgt := c.pos + right * slot.x + fwd * slot.y
				var w: Vector3 = (tr["wpos"] as Vector3).move_toward(tgt, spd * 1.35 * delta)
				tr["wpos"] = w
				var mv := tgt - w
				var yaw := atan2(mv.x, mv.z) if mv.length() > 0.2 else c.facing
				var ph := float(tr["ph"])
				var bob := absf(sin(_t * (9.0 if spd > CAV_TROT else 5.0) + ph)) * (0.14 if spd > CAV_TROT else 0.06)
				var hb := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
				hmm.set_instance_transform(i, Transform3D(hb, Vector3(w.x, 0.92 + bob, w.z)))
				rmm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(w.x, 1.72 + bob, w.z)))
				i += 1
		for j in range(i, hmm.instance_count):
			hmm.set_instance_transform(j, _zero_xf())
			rmm.set_instance_transform(j, _zero_xf())

# Your sergeants sing out when enemy horse bears down on YOUR battalion — forming
# square is your call to make, and yours to make in time.
func _warn_player_cavalry(delta: float) -> void:
	_cav_warn_cd = maxf(0.0, _cav_warn_cd - delta)
	if player == null or player.spent or _cav_warn_cd > 0.0:
		return
	if player.formation == "square":
		return                              # already proof against them
	var d := _nearest_enemy_cav_dist(player.pos, player.team)
	if d < SQUARE_ALERT * 1.5:
		_cav_warn_cd = 16.0
		_send_player_despatch("[color=#ff9a8a]CAVALRY![/color] Enemy horse bearing down — [color=#ffe9a8]form square![/color]", {})

# The nearest enemy regiment of horse to a battalion's FRONT, in musket range.
func _nearest_enemy_cav_in_range(b: Batt, rng: float) -> Cav:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var best: Cav = null
	var bd := rng
	for c in cavalry:
		if c.team == b.team or c.spent or c.state == "fled" or c.troopers.is_empty():
			continue
		var to := c.pos - b.pos
		to.y = 0.0
		var d := to.length()
		if d > rng or d < 0.01:
			continue
		# a square fires on all faces; a line only to its front
		if b.formation != "square" and to.normalized().dot(fwd) < 0.2:
			continue
		if d < bd:
			bd = d
			best = c
	return best

# The nearest enemy horse still in fighting order (for square drill and warnings).
func _nearest_enemy_cav_dist(p: Vector3, team: int) -> float:
	var bd := 1.0e9
	for c in cavalry:
		if c.team == team or c.spent or c.state == "fled" or c.state == "rallying":
			continue
		bd = minf(bd, Vector2(p.x - c.pos.x, p.z - c.pos.z).length())
	return bd

# ================================================================== brigade command

func _build_dead_horses() -> void:
	var mmi := MultiMeshInstance3D.new()
	dead_horse_mm = MultiMesh.new()
	dead_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.34
	cap.height = 1.9
	dead_horse_mm.mesh = cap
	dead_horse_mm.instance_count = DEAD_HORSE_MAX
	mmi.multimesh = dead_horse_mm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.10, 0.06)
	mat.roughness = 1.0
	mmi.material_override = mat
	add_child(mmi)
	for i in range(DEAD_HORSE_MAX):
		dead_horse_mm.set_instance_transform(i, _zero_xf())

# Lay a dead horse on the ground where a brigadier was shot down.
func _add_dead_horse(pos: Vector3, yaw: float, _team: int) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	dead_horse_mm.set_instance_transform(dead_horse_idx, Transform3D(basis, Vector3(pos.x, 0.34, pos.z)))
	dead_horse_idx = (dead_horse_idx + 1) % DEAD_HORSE_MAX

func _assign_brigades() -> void:
	_build_dead_horses()
	brigades.clear()
	# data-driven: chunk each team's battalions (in spawn order) into brigades. For
	# the 70k field this reproduces the fixed-index OOB exactly; for an inflated
	# campaign force of any size it just works from whatever spawned.
	for team in [0, 1]:
		var mine: Array = []
		for b in battalions:
			if b.team == team:
				mine.append(b)
		var nbri: int = int(ceil(float(mine.size()) / float(BATTS_PER_BRIGADE)))
		for bri in range(nbri):
			var br := Brigade.new()
			br.team = team
			br.idx = team * BRIGADES_PER_TEAM + bri
			br.division = bri / BRIGADES_PER_DIVISION
			br.corps = br.division / DIVISIONS_PER_CORPS
			br.line2 = (br.division % DIVISIONS_PER_CORPS) == 1   # the corps' second line
			for k in range(BATTS_PER_BRIGADE):
				var gi: int = bri * BATTS_PER_BRIGADE + k
				if gi < mine.size():
					var b: Batt = mine[gi]
					b.brigade = br
					br.battalions.append(b)
					if b.is_player:
						br.is_player = true
			if br.battalions.is_empty():
				continue
			br.anchor = _live_center(br.battalions)
			br.objective = br.anchor
			br.facing = 0.0 if team == 0 else PI
			brigades.append(br)
	# attach every battery to the nearest friendly brigade
	for g in guns:
		var best: Brigade = null
		var bd := 1.0e18
		for br in brigades:
			if br.team != g.team:
				continue
			var d: float = g.pos.distance_to(_brigade_center(br))
			if d < bd:
				bd = d
				best = br
		if best != null:
			g.brigade = best
			best.guns.append(g)
	# the two army commanders — each gets a personality (one bolder than the other)
	armies.clear()
	for team in [0, 1]:
		var army := Army.new()
		army.team = team
		army.aggression = randf_range(0.3, 0.85)
		armies.append(army)

func _live_center(batts: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for b in batts:
		if not b.spent:
			sum += b.pos
			n += 1
	if n == 0:
		return batts[0].pos if not batts.is_empty() else Vector3.ZERO
	return sum / float(n)

func _brigade_center(br) -> Vector3:
	return _live_center(br.battalions)

func _brigade_strength(br) -> int:
	var s := 0
	for b in br.battalions:
		if not b.spent:
			s += b.figs.size()
	return s

func _brigade_morale(br) -> float:
	var m := 0.0
	var n := 0
	for b in br.battalions:
		if not b.spent:
			m += b.morale
			n += 1
	return (m / float(n)) if n > 0 else 0.0

func _brigade_live(br) -> int:
	var n := 0
	for b in br.battalions:
		if not b.spent:
			n += 1
	return n

func _nearest_enemy_brigade(br):
	var c := _brigade_center(br)
	var best = null
	var bd := 1.0e18
	for o in brigades:
		if o.team == br.team or _brigade_live(o) == 0:
			continue
		var d := c.distance_to(_brigade_center(o))
		if d < bd:
			bd = d
			best = o
	return best

# ---- army command: read the whole front, find the decisive point, assign missions ----

func _update_armies(delta: float) -> void:
	for army in armies:
		army.decide_cd -= delta
		if army.decide_cd <= 0.0:
			army.decide_cd = ARMY_DECIDE * randf_range(0.85, 1.15)
			_army_decide(army)

func _army_decide(army) -> void:
	var team: int = army.team
	var mine: Array = []
	var foe: Array = []
	for br in brigades:
		if _brigade_live(br) == 0:
			continue
		if br.team == team:
			mine.append(br)
		else:
			foe.append(br)
	if mine.is_empty():
		return
	if foe.is_empty():
		for br in mine:
			br.mission = "hold"
		return
	mine.sort_custom(func(a, b): return _brigade_center(a).x < _brigade_center(b).x)
	foe.sort_custom(func(a, b): return _brigade_center(a).x < _brigade_center(b).x)
	# THE APPRECIATION: the commander deduces his own goal from the field, then the
	# goal chooses the doctrine play, the plan, and the decisive point
	_appreciate(army, mine, foe)
	var target = _goal_target(army, foe)
	var best_w: float = _brigade_weakness(target) if target != null else 0.0
	if target == null:
		return
	var ti: int = foe.find(target)
	# the grand battery masses opposite the chosen point, inside long canister-free range
	if army.play == "grand_battery":
		var tc := _brigade_center(target)
		army.gb_pos = tc + Vector3(0, 0, -230.0 if team == 0 else 230.0)
	# the main effort is chosen from the FIRST line — and its WHOLE DIVISION goes in
	# together, while the other first-line divisions fix and the second line stands by
	var first_line: Array = []
	for br in mine:
		if not br.line2:
			first_line.append(br)
	if first_line.is_empty():
		first_line = mine
	var main = _nearest_brigade_by_x(first_line, _brigade_center(target).x)
	army.main = main
	for br in mine:
		if army.plan != "defend" and br.division == main.division:
			br.mission_target = target
			if br == main and ti == 0:
				br.mission = "flank"
				br.flank_side = -1
			elif br == main and ti == foe.size() - 1:
				br.mission = "flank"
				br.flank_side = 1
			else:
				br.mission = "attack"
		elif br.line2:
			br.mission = "reserve"          # the corps' second line is kept in hand
			br.mission_target = _nearest_brigade_by_x(foe, _brigade_center(br).x)
		else:
			# a defending army STANDS ITS GROUND; an attacking one fixes the enemy line
			br.mission = "refuse" if army.plan == "defend" else "fix"
			br.mission_target = _nearest_brigade_by_x(foe, _brigade_center(br).x)
	# refuse a first-line flank the enemy overlaps
	var ml = first_line[0]
	var mr = first_line[first_line.size() - 1]
	if _brigade_center(foe[0]).x < _brigade_center(ml).x - 130.0 and ml.mission == "fix":
		ml.mission = "refuse"
	if _brigade_center(foe[foe.size() - 1]).x > _brigade_center(mr).x + 130.0 and mr.mission == "fix":
		mr.mission = "refuse"
	# THE RESERVE GOES IN — each corps watches its own first line: when it is bleeding
	# out it is RELIEVED; when the army is pressing and the weak point lies in this
	# corps' sector, the second line is committed to EXPLOIT. Decisions, not scripts.
	for cpn in range(CORPS_PER_TEAM):
		var line_div := cpn * DIVISIONS_PER_CORPS
		var res_div := line_div + 1
		var res: Array = []
		var fl_str := 0
		var fl_live := 0
		for br2 in mine:
			if br2.division == res_div and br2.line2:
				res.append(br2)
			elif br2.division == line_div:
				fl_str += _brigade_strength(br2)
				fl_live += 1
		if res.is_empty():
			continue
		var fl_frac := float(fl_str) / float(BRIGADES_PER_DIVISION * BATTS_PER_BRIGADE * MEN)
		var relieve := fl_frac < 0.5 or fl_live <= 2
		var exploit: bool = army.plan == "press" and main != null and main.corps == cpn and best_w > 1.0
		if relieve or exploit:
			for br3 in res:
				br3.line2 = false           # they are first-line troops from this moment
				br3.mission = "attack" if exploit else "fix"
				br3.mission_target = _nearest_brigade_by_x(foe, _brigade_center(br3).x)
			if player != null and player.team == team:
				_send_player_despatch("[color=#ffd773]The second line is going in![/color] The corps commits its reserve division.", {})
	# CORPS INITIATIVE (step 3): a broken or leaderless enemy opposite any brigade is
	# fallen upon at once, without waiting for the army's next general order
	for br4 in mine:
		if br4.mission == "fix" and br4.mission_target != null:
			var et2 = br4.mission_target
			if et2.commander_down or _brigade_morale(et2) < 34.0:
				br4.mission = "attack"

const INTEL_LAG := 12.0   # reports ride to HQ by courier — the picture lags reality

# THE APPRECIATION (step 1): candidate goals are generated from the situation and
# scored value x feasibility; personality biases the values; the standing goal holds
# a grip (hysteresis) so the commander commits rather than dithers.
func _appreciate(army, mine: Array, foe: Array) -> void:
	army.goal_t += ARMY_DECIDE
	# (4) intelligence: the enemy frontage as last REPORTED, not as it now is
	army.intel_cd -= ARMY_DECIDE
	if army.intel_cd <= 0.0 or not army.intel_fresh:
		army.intel_cd = INTEL_LAG
		army.intel_left = _brigade_center(foe[0]).x
		army.intel_right = _brigade_center(foe[foe.size() - 1]).x
		army.intel_fresh = true
	var my_total := 0
	var foe_total := 0
	var my_mor := 0.0
	for br in mine:
		my_total += _brigade_strength(br)
		my_mor += _brigade_morale(br)
	for br in foe:
		foe_total += _brigade_strength(br)
	my_mor /= float(mine.size())
	var ratio := float(my_total) / maxf(1.0, float(foe_total))
	var my_left: float = _brigade_center(mine[0]).x
	var my_right: float = _brigade_center(mine[mine.size() - 1]).x
	var fresh_res := 0
	for br in mine:
		if br.line2:
			fresh_res += 1
	var ag: float = army.aggression
	# the candidate goals
	var cands := {}
	cands["destroy"] = (0.9 + ag * 0.4) * clampf((ratio - 0.85) * 2.0, 0.0, 1.0) \
		* (1.2 if fresh_res > 0 else 0.8)
	cands["turn_right"] = (0.85 + ag * 0.25) * clampf(ratio, 0.6, 1.2) \
		* (1.0 if my_right > army.intel_right + 120.0 else 0.35)
	cands["turn_left"] = (0.85 + ag * 0.25) * clampf(ratio, 0.6, 1.2) \
		* (1.0 if my_left < army.intel_left - 120.0 else 0.35)
	var ci0 := foe.size() / 3
	var cw := 0.0
	for i in range(ci0, maxi(ci0 + 1, foe.size() - ci0)):
		cw = maxf(cw, _brigade_weakness(foe[i]))
	cands["break_centre"] = (0.8 + ag * 0.2) * clampf(cw + ratio - 0.8, 0.0, 1.4) * 0.8
	cands["bleed"] = (0.8 - ag * 0.4) * clampf((0.95 - ratio) * 2.2, 0.0, 1.2)
	cands["delay"] = (0.9 - ag * 0.45) * clampf((0.62 - ratio) * 3.0, 0.0, 1.5) \
		+ (0.5 if my_mor < 38.0 else 0.0)
	# (5) terrain goals plug in here when key_points exist
	# (7) the campaign may dictate the goal outright
	if GameConfig.battle_goal != "" and cands.has(GameConfig.battle_goal):
		cands[GameConfig.battle_goal] = 9.0
	# hysteresis: the standing goal keeps a +bonus; a new one must clearly outscore it
	var best: String = army.goal
	var bs := -1.0
	for k in cands:
		var s: float = cands[k] + (0.22 if String(k) == army.goal else 0.0)
		if s > bs:
			bs = s
			best = String(k)
	if best != army.goal:
		army.goal = best
		army.goal_t = 0.0
		if player != null and player.team == army.team:
			_send_player_despatch("[color=#ffd773]The army's intent:[/color] %s." % _goal_text(best), {})
	# the goal sets the plan...
	if army.goal in ["bleed", "delay"]:
		army.plan = "defend"
	else:
		army.plan = "press" if (ratio > 0.95 or ag > 0.6) else "develop"
	# ...and chooses the doctrine play that serves it (step 2)
	army.play = ""
	if army.plan != "defend":
		if army.goal in ["turn_left", "turn_right"]:
			army.play = "pin_envelop"      # fix the line, march onto the flank
		elif my_mor > 45.0:
			army.play = "grand_battery"    # mass the guns at the point before the assault

func _goal_text(g: String) -> String:
	match g:
		"destroy": return "destroy their army where it stands"
		"turn_left": return "turn their right flank"
		"turn_right": return "turn their left flank"
		"break_centre": return "break their centre"
		"bleed": return "stand and bleed them white"
		"delay": return "trade ground for time and keep the army whole"
	return g

# The decisive point that serves the chosen goal.
func _goal_target(army, foe: Array):
	if foe.is_empty():
		return null
	match army.goal:
		"turn_left":
			return foe[0]
		"turn_right":
			return foe[foe.size() - 1]
		"break_centre":
			var ci0 := foe.size() / 3
			var best = null
			var bw := -1.0
			for i in range(ci0, maxi(ci0 + 1, foe.size() - ci0)):
				var w := _brigade_weakness(foe[i])
				if w > bw:
					bw = w
					best = foe[i]
			return best
	# destroy / bleed / delay: the weakest formation, flanks counting as weak ground
	var tgt = null
	var tw := -1.0
	for i in range(foe.size()):
		var w2 := _brigade_weakness(foe[i])
		if i == 0 or i == foe.size() - 1:
			w2 += 0.45
		if w2 > tw:
			tw = w2
			tgt = foe[i]
	return tgt

func _brigade_weakness(br) -> float:
	var str_frac: float = float(_brigade_strength(br)) / float(BATTS_PER_BRIGADE * MEN)
	var w := (1.0 - clampf(str_frac, 0.0, 1.0)) * 0.6
	w += (1.0 - clampf(_brigade_morale(br) / 100.0, 0.0, 1.0)) * 0.6
	if br.commander_down:
		w += 0.3
	return w

func _nearest_brigade_by_x(list: Array, x: float):
	var best = null
	var bd := 1.0e18
	for br in list:
		var d: float = absf(_brigade_center(br).x - x)
		if d < bd:
			bd = d
			best = br
	return best

func _update_brigades(delta: float) -> void:
	_update_armies(delta)             # the army HQ plans first, then the brigades execute
	# measure each army's average advance so brigades can dress on the line and move
	# together rather than charging forward piecemeal
	var sum := [0.0, 0.0]
	var cnt := [0, 0]
	for br in brigades:
		if _brigade_live(br) == 0:
			continue
		var s := 1.0 if br.team == 0 else -1.0
		sum[br.team] += _brigade_center(br).z * s
		cnt[br.team] += 1
	for tm in [0, 1]:
		_army_adv[tm] = sum[tm] / float(maxi(1, cnt[tm]))
	for br in brigades:
		_update_brigade(br, delta)
	_update_brigade_couriers(delta)

func _update_brigade(br, delta: float) -> void:
	if _brigade_live(br) == 0:
		return
	br.support_cd = maxf(0.0, br.support_cd - delta)
	br.support_t = maxf(0.0, br.support_t - delta)
	if br.commander_down:
		br.confuse_t -= delta
		if br.confuse_t <= 0.0:
			br.commander_down = false       # a colonel takes command
	br.decide_cd -= delta
	if br.decide_cd <= 0.0:
		br.decide_cd = BRIG_DECIDE * randf_range(0.85, 1.15)
		_brigade_decide(br)
	_brigade_set_anchor(br, delta)        # ease the line toward its objective each frame
	_brigade_assign_slots(br)             # dress the battalions on the brigade line
	_brigade_position_guns(br)            # post the battery to support the line
	var bf := Vector3(sin(br.facing), 0, cos(br.facing))
	br.commander_pos = _brigade_center(br) - bf * 18.0
	if br.is_player:
		_maybe_order_player(br)

# The commander posts his battery behind the brigade line (on the friendly side, so it
# fires over its own infantry), advancing or retiring it as the brigade manoeuvres.
func _brigade_position_guns(br) -> void:
	if br.guns.is_empty():
		return
	var bf := Vector3(sin(br.facing), 0, cos(br.facing))
	var right := Vector3(bf.z, 0, -bf.x)
	var center: Vector3 = br.anchor - bf * 28.0       # posted behind the line of battle
	# the GRAND BATTERY: when the army masses its guns, every battery limbers up and
	# converges on the chosen ground to prepare the assault with concentrated fire
	if br.team < armies.size():
		var army = armies[br.team]
		if army.play == "grand_battery" and army.gb_pos != Vector3.ZERO:
			center = army.gb_pos + right * float((br.idx % 7) - 3) * 42.0
	if br.posture == "withdraw":
		center = _brigade_center(br) - bf * 70.0      # haul the guns out of harm's way
	var n: int = br.guns.size()
	for i in range(n):
		var off: float = (float(i) - (n - 1) * 0.5) * GUN_SPACING
		var g: Gun = br.guns[i]
		g.move_to = center + right * off

# The brigade carries out the mission the army handed it, choosing the moment-to-moment
# posture (advance / engage / assault / withdraw) and the ground to move its line onto.
func _brigade_decide(br) -> void:
	var center := _brigade_center(br)
	if not _battle_begun:
		# the armies stand on their ground until the step-off
		br.posture = "hold"
		br.objective = br.anchor
		br.fire_mission = null
		return
	# fight the enemy the army assigned us; fall back to the nearest if that brigade is gone
	var enemy = br.mission_target if (br.mission_target != null and _brigade_live(br.mission_target) > 0) else _nearest_enemy_brigade(br)
	br.enemy = enemy
	var my_str := _brigade_strength(br)
	var my_mor := _brigade_morale(br)
	if enemy == null:
		br.posture = "hold"
		br.objective = center
		br.fire_mission = _brigade_fire_mission(br)
		return
	var ec := _brigade_center(enemy)
	if center.distance_to(ec) > 1.0:
		br.facing = atan2((ec - center).x, (ec - center).z)   # always face the enemy himself
	var dfront := center.distance_to(ec)
	var en_str := _brigade_strength(enemy)
	var en_mor := _brigade_morale(enemy)
	var bf := Vector3(sin(br.facing), 0, cos(br.facing))
	# for a flanking mission the objective is the ground beyond the enemy's open flank
	var flank_obj := ec + Vector3(float(br.flank_side) * FLANK_REACH, 0.0, 0.0)
	if my_mor < 35.0 or _brigade_live(br) <= 1:
		br.posture = "withdraw"
		br.objective = center - bf * 140.0
	elif br.commander_down:
		br.posture = "engage" if dfront <= BRIG_ENGAGE_RANGE + 35.0 else "hold"
		br.objective = ec - bf * BRIG_ENGAGE_RANGE
	elif br.support_t > 0.0:
		br.posture = "support"
		br.objective = br.support_pos if br.support_pos != Vector3.ZERO else center
	else:
		match br.mission:
			"reserve":
				br.posture = "hold"
				br.objective = center - bf * (RESERVE_DEPTH + 40.0)   # kept in hand behind the line
			"refuse":
				br.posture = "engage" if dfront <= BRIG_ENGAGE_RANGE + 30.0 else "hold"
				br.objective = center - bf * 25.0                     # hold the flank back, defensive
			"fix":
				br.posture = "advance" if dfront > BRIG_ENGAGE_RANGE + 35.0 else "engage"
				br.objective = ec - bf * BRIG_ENGAGE_RANGE            # pin him with fire — do not assault
			"flank":
				if center.distance_to(flank_obj) > BRIG_ENGAGE_RANGE + 20.0:
					br.posture = "advance"
					br.objective = flank_obj                          # march around onto his flank
				else:
					br.posture = "assault" if my_mor > 45.0 else "engage"
					br.objective = ec
			_:   # "attack" — the main effort
				if dfront > BRIG_ENGAGE_RANGE + 35.0:
					br.posture = "advance"
					br.objective = ec - bf * BRIG_ENGAGE_RANGE
				else:
					var overmatch := float(my_str) > float(en_str) * 1.1
					if my_mor > 50.0 and (en_mor < BRIG_ASSAULT_MORALE + 8.0 or overmatch):
						br.posture = "assault"                        # press home where he is weak
						br.objective = ec
					else:
						br.posture = "engage"
						br.objective = ec - bf * BRIG_ENGAGE_RANGE
	if not br.commander_down and br.support_cd <= 0.0 and (float(my_str) < float(en_str) * 0.65 or my_mor < 42.0):
		_brigade_call_support(br)
	if not br.commander_down and dfront < BRIG_ENGAGE_RANGE + 20.0 and randf() < BRIGADIER_HIT:
		_brigadier_falls(br)
	br.fire_mission = _brigade_fire_mission(br)

func _brigade_set_anchor(br, delta: float) -> void:
	var spd := BATT_SPEED * (0.5 if br.posture == "engage" or br.posture == "hold" else 1.0)
	# the main effort (attack / flank) is allowed to press ahead and concentrate; brigades
	# merely fixing or refusing dress on the army so the line stays connected behind it
	if br.mission in ["fix", "hold", "refuse", "reserve"] and br.posture == "advance":
		var s := 1.0 if br.team == 0 else -1.0
		var ahead: float = (br.anchor.z * s) - _army_adv[br.team]
		if ahead > DRESS_MARGIN:
			spd *= 0.12
	br.anchor = br.anchor.move_toward(br.objective, spd * delta)

func _brigade_assign_slots(br) -> void:
	var bf := Vector3(sin(br.facing), 0, cos(br.facing))
	var right := Vector3(bf.z, 0, -bf.x)
	# only LIVE battalions hold the line; as the front bleeds out, the reserve men
	# behind them are promoted into the line (so reserves are committed over time)
	var live: Array = []
	for b in br.battalions:
		if not b.spent:
			live.append(b)
	var nf: int = mini(BRIG_FRONT, live.size())     # front-line battalions
	var nr: int = live.size() - nf                  # reserve battalions
	# while engaged or assaulting, the reserve HOLDS behind; on the march it moves up too
	var rposture: String = "hold" if br.posture in ["engage", "assault"] else br.posture
	for idx in range(live.size()):
		var b: Batt = live[idx]
		if b.human:                      # the player keeps his own counsel
			continue
		if idx < nf:
			var off: float = (float(idx) - (nf - 1) * 0.5) * BRIG_BATT_SPACING
			b.ai_target = br.anchor + right * off
			b.ai_posture = br.posture
		else:
			var ri := idx - nf
			var roff: float = (float(ri) - (nr - 1) * 0.5) * BRIG_BATT_SPACING * 0.8
			b.ai_target = br.anchor - bf * RESERVE_DEPTH + right * roff   # second line
			b.ai_posture = rposture
		b.ai_facing = br.facing

func _brigade_fire_mission(br):
	var c := _brigade_center(br)
	var best = null
	var best_score := 1.0e18
	for o in battalions:
		if o.team == br.team or o.spent or o.figs.size() < 60:
			continue
		var d := c.distance_to(o.pos)
		if d > ARTY_RANGE:
			continue
		var score := d * (1.8 if o.skirmish else 1.0)   # roundshot wants a formed body
		if score < best_score:
			best_score = score
			best = o
	return best

func _brigade_call_support(br) -> void:
	br.support_cd = BRIG_SUPPORT_COOL
	var c := _brigade_center(br)
	var ally = null
	var bd := 1.0e18
	for o in brigades:
		if o.team != br.team or o == br or _brigade_live(o) == 0:
			continue
		var d := c.distance_to(_brigade_center(o))
		if d < bd:
			bd = d
			ally = o
	if ally != null:
		# an aide gallops to the neighbouring brigade with the request
		brigade_couriers.append({ "pos": Vector3(c.x, 1.0, c.z), "to": ally, "point": c })
	# a battalion of YOUR brigade in trouble nearby? you get asked too
	if player != null and not player.spent and br != player.brigade:
		if off_pos.distance_to(c) < 260.0:
			_send_courier_to_player(c, "[color=#ffd773]Despatch:[/color] a neighbouring battalion is hard pressed — lend your support!", {}, true)

func _update_brigade_couriers(delta: float) -> void:
	var i := 0
	while i < brigade_couriers.size():
		var c: Dictionary = brigade_couriers[i]
		var ally = c["to"]
		var dest: Vector3 = ally.commander_pos + Vector3(0, 1.0, 0)
		var p: Vector3 = (c["pos"] as Vector3).move_toward(dest, COURIER_SPEED * delta)
		c["pos"] = p
		if p.distance_to(dest) < 4.0:
			# the ally takes up the call: it shifts to shore up the threatened point
			ally.support_pos = c["point"]
			ally.support_t = 14.0
			brigade_couriers.remove_at(i)
		else:
			i += 1

# The brigadier is shot from the saddle: his brigade is leaderless and reels until a
# colonel takes command. Every battalion feels it.
func _brigadier_falls(br) -> void:
	if br == null or br.commander_down:
		return
	br.commander_down = true
	br.confuse_t = CMD_CONFUSE
	var cp: Vector3 = br.commander_pos
	var bp := cp + Vector3(0.7, 0, 0.5)
	_add_dead_horse(cp, br.facing + randf_range(-0.4, 0.4), br.team)        # his charger falls
	_emit_blood(bp, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	_add_corpse(bp, randf() * TAU, br.team)                                 # the general's body stays
	for b in br.battalions:
		if not b.spent:
			b.morale -= 8.0
			b.calm_t = 0.0
	if br.is_player:
		_send_player_despatch("[color=#ff9a8a]The General is down![/color] The brigade is without a head — hold fast.", {})

func _sim_ai(b: Batt, delta: float) -> void:
	# CAVALRY! The drill that saves a battalion: form square when enemy horse closes,
	# stand fast inside it, and re-form line only once the field is clear again.
	var cav_d := _nearest_enemy_cav_dist(b.pos, b.team)
	if cav_d < SQUARE_ALERT and b.melee_foe == null and not b.charging:
		if b.formation != "square":
			b.skirmish = false
			b.formation = "square"
			_reslot(b)
		return                             # stand fast — nothing else matters now
	elif b.formation == "square" and cav_d > SQUARE_RELAX:
		b.formation = "line"               # the horse is gone; re-form and carry on
		_reslot(b)
	# a battalion fights its part of the brigade's plan, but reacts to an enemy that
	# comes within killing distance whatever its orders
	if b.ai_posture != "skirmish" and b.skirmish:
		b.skirmish = false                # ordered out of open order; re-form
	var foe := _nearest_enemy(b)
	var foe_d := 1.0e9
	if foe != null:
		foe_d = b.pos.distance_to(foe.pos)
	if foe != null and foe_d <= DEPLOY_RANGE:
		# in contact: form line, face him, stand and fire (charge only if ordered to assault)
		if not b.skirmish and b.formation != "line":
			b.formation = "line"
			_reslot(b)
		var to := foe.pos - b.pos
		to.y = 0.0
		if to.length() > 0.3:
			b.facing = atan2(to.x, to.z)
		b.off_pos = b.pos + to.normalized() * 10.0
		b.off_facing = b.facing
		var weak := foe.state != "steady" or foe.morale < BRIG_ASSAULT_MORALE
		var dry := b.ammo <= 0.0          # no powder left — close with the bayonet
		if not b.officer_down and b.charge_cool <= 0.0 and b.state == "steady" and foe_d < CHARGE_RANGE \
				and ((b.ai_posture == "assault" and weak) or dry):
			_begin_charge(b, foe)
		return
	# not in contact: carry out the brigade's movement order
	var deploy: bool = b.ai_posture in ["engage", "hold", "assault"]
	if b.ai_posture == "skirmish" and not b.skirmish:
		b.skirmish = true
		b.formation = "skirmish"
		_reslot(b)
	_ai_move_to(b, b.ai_target, b.ai_facing, delta, deploy)

# March a battalion to its assigned place: column while there's ground to cover, then
# deploy to line and dress to the brigade's facing as it arrives.
func _ai_move_to(b: Batt, tgt: Vector3, face: float, delta: float, deploy_line: bool) -> void:
	var to := tgt - b.pos
	to.y = 0.0
	var d := to.length()
	if d > FORMUP_DIST:
		if not b.skirmish and b.formation != "column":
			b.formation = "column"
			_reslot(b)
		var dir := to / d
		b.facing = atan2(dir.x, dir.z)
		b.pos += dir * BATT_SPEED * delta
		b.off_pos = b.pos + dir * 14.0
		b.off_facing = b.facing
	else:
		if deploy_line and not b.skirmish and b.formation != "line":
			b.formation = "line"
			_reslot(b)
		b.facing = lerp_angle(b.facing, face, clampf(delta * 1.5, 0.0, 1.0))
		if d > 0.4:
			b.pos += (to / d) * BATT_SPEED * 0.5 * delta
		var ff := Vector3(sin(b.facing), 0, cos(b.facing))
		b.off_pos = b.pos + ff * 10.0
		b.off_facing = b.facing

func _begin_charge(b: Batt, foe: Batt) -> void:
	b.charging = true
	b.melee_foe = null
	b.has_goal = false               # the charge overrides any measured move
	b.fall_back = false
	_play_voice(snd_v_charge, b.off_pos, 170.0)   # "CHARGE!"
	_play_voice(snd_cheer, b.pos, 260.0)          # the line goes in with a shout
	if b.formation != "line":
		b.formation = "line"
		_reslot(b)

# Surge toward the enemy at the pas de charge; contact resolves into shock + melee.
func _sim_charge(b: Batt, delta: float) -> void:
	var foe := _nearest_enemy_in_range(b, CHARGE_RANGE * 1.6)
	if foe == null:
		b.charging = false
		b.charge_cool = CHARGE_COOL
		return
	var to := foe.pos - b.pos
	to.y = 0.0
	var d := to.length()
	b.facing = atan2(to.x, to.z)
	b.off_pos = b.pos + to.normalized() * 6.0
	b.off_facing = b.facing
	if d > MELEE_RANGE:
		b.pos += to.normalized() * CHARGE_SPEED * delta
		return
	# impact: shock felt by the camera + a clash of steel
	var prox := clampf(1.0 - cam.position.distance_to(b.pos) / 120.0, 0.0, 1.0)
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.5, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * 0.12, 0.3)
	var clash := (b.pos + foe.pos) * 0.5
	if b.visible or foe.visible:
		_play_melee(clash + Vector3(0, 1.0, 0))
	if GameConfig.mode == "host":
		_fx.append([FX_MELEE, clash.x, clash.z])
	# the shock of the charge lands a heavy morale blow
	foe.morale -= CHARGE_SHOCK
	foe.flinch = minf(foe.flinch + 1.3, 1.6)
	foe.calm_t = 0.0
	if foe.morale < ROUT_THRESHOLD or foe.state == "routing":
		# the enemy breaks before contact — the charge carries the position
		b.charging = false
		b.charge_cool = CHARGE_COOL
	else:
		# both sides lock into the press
		b.charging = false
		b.melee_foe = foe
		foe.melee_foe = b
		foe.charging = false

# Hand-to-hand: both bleed men and morale; the steadier/larger unit prevails.
func _sim_melee(b: Batt, delta: float) -> void:
	var foe := b.melee_foe
	if foe == null or foe.figs.size() < 60 or foe.state == "routing":
		b.melee_foe = null
		b.charge_cool = CHARGE_COOL
		return
	# face each other, grind in place
	var to := foe.pos - b.pos
	to.y = 0.0
	if to.length() > 0.01:
		b.facing = atan2(to.x, to.z)
	# b's fighting power presses on the foe (morale + numbers)
	var power := (b.morale / 100.0) * sqrt(maxf(1.0, float(b.figs.size())))
	foe.dmg_acc += MELEE_RATE * (power / 22.0) * delta
	var k := int(foe.dmg_acc)
	if k > 0:
		foe.dmg_acc -= k
		foe.kills_pending += k
		foe.shot_from = b.pos                # the press comes from the enemy's side
		if b.is_player:
			prestige += k                    # bayonet work under your command counts too
	foe.morale -= MELEE_MORALE * (b.morale / maxf(20.0, foe.morale)) * delta * 0.25
	foe.calm_t = 0.0

func _nearest_enemy(b: Batt) -> Batt:
	var best: Batt = null
	var bd := 1e9
	for o in battalions:
		if o.team == b.team or o.figs.size() < 60:
			continue
		var d := b.pos.distance_to(o.pos)
		if d < bd:
			bd = d
			best = o
	return best

# Casualties fall where the fire lands: the men CLOSEST to the firing line (the
# facing edge) drop first — so a volley visibly chews the front of the enemy line.
func _kill_some(b: Batt, k: int) -> void:
	if k <= 0 or b.figs.is_empty():
		return
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var from := b.shot_from
	if from == Vector3.ZERO:
		# no known source (rare) — fall back to random
		for i in range(mini(k, b.figs.size())):
			var idx := randi() % b.figs.size()
			var sl: Vector2 = b.figs[idx]["slot"]
			var w := b.pos + right * sl.x + fwd * sl.y
			_drop_dead(w, b.team, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), b.visible)
			b.figs.remove_at(idx)
		return
	# rank the men by distance to the incoming fire, drop the nearest k
	var order: Array = []
	for i in range(b.figs.size()):
		var sl: Vector2 = b.figs[i]["slot"]
		var w := b.pos + right * sl.x + fwd * sl.y
		order.append([w.distance_squared_to(from), i, w])
	order.sort_custom(func(a, c): return a[0] < c[0])
	var n := mini(k, order.size())
	var victims: Array = []
	for j in range(n):
		victims.append(order[j][1])      # fig indices
	victims.sort()
	victims.reverse()                    # remove back-to-front so indices stay valid
	for idx in victims:
		var w := order_world(b, idx, fwd, right)
		_drop_dead(w, b.team, w - from, b.visible)   # knocked back, away from the fire
		b.figs.remove_at(idx)

func order_world(b: Batt, idx: int, fwd: Vector3, right: Vector3) -> Vector3:
	var sl: Vector2 = b.figs[idx]["slot"]
	return b.pos + right * sl.x + fwd * sl.y

# A single ball fired from `origin` travelling along `dir` (horizontal, unit).
# It strikes the enemy man standing in its path — the one with the smallest
# perpendicular offset from the line, the frontmost taking it first. This spreads
# a volley's dead across the whole enemy front instead of bunching them at centre.
func _kill_along_ray(foe: Batt, origin: Vector3, dir: Vector3) -> void:
	if foe.figs.is_empty():
		return
	var ffwd := Vector3(sin(foe.facing), 0, cos(foe.facing))
	var fright := Vector3(ffwd.z, 0, -ffwd.x)
	var best_i := -1
	var best_score := 1.0e18
	for i in range(foe.figs.size()):
		var sl: Vector2 = foe.figs[i]["slot"]
		var w := foe.pos + fright * sl.x + ffwd * sl.y
		var to := w - origin
		to.y = 0.0
		var along := to.dot(dir)
		if along < 0.0:
			continue                          # behind the muzzle
		var perp := to - dir * along
		# small lateral offset wins; ties broken toward the nearer (front) man
		var score := perp.length_squared() + along * 0.04
		if score < best_score:
			best_score = score
			best_i = i
	if best_i < 0:
		return
	var sl2: Vector2 = foe.figs[best_i]["slot"]
	var wk := foe.pos + fright * sl2.x + ffwd * sl2.y
	_drop_dead(wk, foe.team, dir, foe.visible)   # knocked back along the ball's flight
	foe.figs.remove_at(best_i)
	foe.cas_since_redress += 1

# ------------------------------------------------------------ ballistics (shared rays)

# Perturb a heading by a gaussian cone (yaw + pitch). This IS the weapon's accuracy:
# a tight cone hits home, a wide one throws balls high and wide.
func _scatter_dir(base: Vector3, yaw_sd: float, pitch_sd: float) -> Vector3:
	var d := base
	d.y = 0.0
	if d.length() < 0.001:
		d = Vector3(0, 0, 1)
	d = d.normalized()
	d = d.rotated(Vector3.UP, randfn(0.0, yaw_sd))
	var right := Vector3(d.z, 0, -d.x)
	d = d.rotated(right, randfn(0.0, pitch_sd))
	return d.normalized()

# True ray test against one battalion's men: returns the frontmost man the ball
# actually passes through (within a body's width, at body height), or -1 if it sails
# over their heads / into the dirt / past them.
func _ray_hit_in_batt(b: Batt, origin: Vector3, dir: Vector3, max_range: float) -> int:
	if b.figs.is_empty():
		return -1
	var dh := Vector2(dir.x, dir.z)
	var dl := dh.length()
	if dl < 0.0001:
		return -1
	var dhn := dh / dl
	var slope := dir.y / dl
	var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var fright := Vector3(ffwd.z, 0, -ffwd.x)
	var best_i := -1
	var best_along := max_range
	for i in range(b.figs.size()):
		var sl: Vector2 = b.figs[i]["slot"]
		var w := b.pos + fright * sl.x + ffwd * sl.y
		var toh := Vector2(w.x - origin.x, w.z - origin.z)
		var along := toh.dot(dhn)
		if along < 0.4 or along >= best_along:
			continue
		if (toh - dhn * along).length() > BULLET_R:
			continue                                    # horizontal miss
		var ball_y := origin.y + slope * along
		if ball_y < 0.2 or ball_y > CAP_HEIGHT - 0.05:
			continue                                    # over the heads / short into the ground
		best_along = along
		best_i = i
	return best_i

# Ray test across every enemy battalion (used by the player's pistol): returns the
# nearest man struck, as { "b": Batt, "i": int }, or {} for a clean miss.
func _ray_hit_world(origin: Vector3, dir: Vector3, max_range: float, enemy_team: int) -> Dictionary:
	var dh := Vector2(dir.x, dir.z)
	var dl := dh.length()
	if dl < 0.0001:
		return {}
	var dhn := dh / dl
	var slope := dir.y / dl
	var best_along := max_range
	var rb: Batt = null
	var ri := -1
	for b in battalions:
		if b.team != enemy_team or b.spent or b.figs.is_empty():
			continue
		if Vector2(b.pos.x - origin.x, b.pos.z - origin.z).length() > max_range + 130.0:
			continue
		var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var fright := Vector3(ffwd.z, 0, -ffwd.x)
		for i in range(b.figs.size()):
			var sl: Vector2 = b.figs[i]["slot"]
			var w := b.pos + fright * sl.x + ffwd * sl.y
			var toh := Vector2(w.x - origin.x, w.z - origin.z)
			var along := toh.dot(dhn)
			if along < 0.4 or along >= best_along:
				continue
			if (toh - dhn * along).length() > BULLET_R:
				continue
			var ball_y := origin.y + slope * along
			if ball_y < 0.2 or ball_y > CAP_HEIGHT - 0.05:
				continue
			best_along = along
			rb = b
			ri = i
	if rb != null:
		return { "b": rb, "i": ri }
	return {}

# Drop a specific man (by index) from a battalion.
func _drop_fig(b: Batt, idx: int, dir: Vector3) -> void:
	if idx < 0 or idx >= b.figs.size():
		return
	var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var fright := Vector3(ffwd.z, 0, -ffwd.x)
	var sl: Vector2 = b.figs[idx]["slot"]
	var w := b.pos + fright * sl.x + ffwd * sl.y
	_drop_dead(w, b.team, dir, b.visible)
	b.figs.remove_at(idx)
	b.cas_since_redress += 1

# ------------------------------------------------------------------ render + LOD

# returns render stride (1/2/3) or 0 to skip entirely (off-screen / too far)
func _batt_lod(b: Batt) -> int:
	var d := cam.position.distance_to(b.pos)
	if d > LOD_VFAR:
		return 0
	var seen := d < 80.0
	if not seen:
		# sample the WHOLE frontage densely: through the spyglass the view is so narrow
		# it can look between sparse samples and wrongly cull a line you're staring at
		var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var right := Vector3(fwd.z, 0, -fwd.x)
		var hw := _halfwidth(b)
		for k in range(9):
			var off := (float(k) / 8.0 * 2.0 - 1.0) * hw      # -hw .. +hw in 9 steps
			if cam.is_position_in_frustum(b.pos + right * off + Vector3(0, 1.0, 0)):
				seen = true
				break
		if not seen:
			# columns and squares have depth too — sample along the march axis
			var dp := _dims(b.figs.size(), b.formation).y * SP * 0.5 + 2.0
			for k2 in range(3):
				var off2 := (float(k2) - 1.0) * dp
				if cam.is_position_in_frustum(b.pos + fwd * off2 + Vector3(0, 1.0, 0)):
					seen = true
					break
	if not seen:
		return 0
	if d < LOD_NEAR:
		return 1
	if d < LOD_MID:
		return 2
	if d < LOD_FAR:
		return 3
	return 6          # the far impression: a static mass on the horizon, stride 6

func _render(delta: float) -> void:
	var idx: Array[int] = [0, 0]
	var off_i := 0
	var bearer_i := 0
	var nco_i := 0
	var drummer_i := 0
	for b in battalions:
		var stride := _batt_lod(b)
		if stride == 0:
			b.visible = false
			if b.flag:
				b.flag.visible = false
			continue
		var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var right := Vector3(fwd.z, 0, -fwd.x)
		# men march to their dressed world spots (animate only what's on screen);
		# snap into place the frame a battalion first comes into view to avoid catch-up
		var snap := not b.visible
		b.visible = true
		# FAR IMPRESSION (beyond LOD_FAR): the battalion is drawn as a static mass —
		# every 6th man placed analytically, no per-man simulation, no muskets — so
		# the whole 5 km line of battle reads on the horizon for almost no cost
		if stride >= 6:
			var fmm: MultiMesh = team_mm[b.team]
			var fgun: MultiMesh = musket_mm[b.team]
			var fi6: int = idx[b.team]
			for k6 in range(0, b.figs.size(), 6):
				if fi6 >= MAX_PER_TEAM:
					break
				var sl6: Vector2 = b.figs[k6]["slot"]
				var w6 := b.pos + right * sl6.x + fwd * sl6.y
				fmm.set_instance_transform(fi6, Transform3D(Basis(Vector3.UP, b.facing), Vector3(w6.x, CAP_HALF, w6.z)))
				fmm.set_instance_color(fi6, b.inst_col)
				fgun.set_instance_transform(fi6, _zero_xf())
				fi6 += 1
			idx[b.team] = fi6
			_place_flag(b, b.pos, b.facing)   # the colours still mark him on the horizon
			continue
		var run := 1.0
		if b.state == "routing":
			run = 1.7
		elif b.charging:
			run = 1.6
		# each man levels his own musket once he's loaded (front two ranks, enemy present)
		var maxy := -1e9
		for f0 in b.figs:
			maxy = maxf(maxy, (f0["slot"] as Vector2).y)
		var fire_band := maxy - SP * 1.6
		# morale read-outs: a wavering unit fidgets, a shocked one lurches back
		var unsteady := clampf((SHAKEN_THRESHOLD - b.morale) / SHAKEN_THRESHOLD, 0.0, 1.0)
		var recoil := -fwd * (b.flinch * 0.55)
		var sway_amp := unsteady * 0.13 + b.flinch * 0.22
		var mm: MultiMesh = team_mm[b.team]
		var gun: MultiMesh = musket_mm[b.team]
		var i: int = idx[b.team]
		for fi in range(b.figs.size()):
			var f: Dictionary = b.figs[fi]
			var slot: Vector2 = f["slot"]
			var target := Vector3(b.pos.x + right.x * slot.x + fwd.x * slot.y, 0, b.pos.z + right.z * slot.x + fwd.z * slot.y)
			var w: Vector3 = target if snap else (f["wpos"] as Vector3).move_toward(target, MAN_SPEED * float(f["spd"]) * run * delta)
			f["wpos"] = w
			if fi % stride != 0:
				continue
			if i >= MAX_PER_TEAM:
				break
			var to := target - w
			var moving := to.length() > 0.06
			var ph := float(f["ph"])
			# in square, each man faces his own outward direction (carried in "face");
			# in a fighting withdrawal he steps BACKWARD, musket still toward the enemy
			var yaw := (atan2(to.x, to.z) if (moving and not b.fall_back) else b.facing + float(f.get("face", 0.0)))
			var bob := (absf(sin(_t * 8.5 * float(f["spd"]) + ph)) * 0.05 if moving else 0.0)
			var swx := sin(_t * 3.4 + ph) * sway_amp     # men fidget/waver as morale drops
			var ox := w.x + recoil.x + right.x * swx
			var oz := w.z + recoil.z + right.z * swx
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(ox, CAP_HALF + bob, oz)))
			mm.set_instance_color(i, b.inst_col)
			var in_band := slot.y >= fire_band
			var leveled := b.charging or b.melee_foe != null or b.melee_vis or (b.has_target and in_band and float(f["reload"]) <= AIM_LEAD)
			# front ranks load while standing; rear ranks stand ready (musket upright)
			var reloading := in_band and float(f["reload"]) > AIM_LEAD
			var work := _t * 9.0 * float(f["spd"]) + ph    # ramrod cadence, desynced per man
			gun.set_instance_transform(i, _musket_xf(w, yaw, leveled, moving, reloading, work))
			i += 1
		idx[b.team] = i
		if b.parent != null:
			continue   # a detached company is just men in open order — no colours, no staff

		# ---- command group: officer, colours, drummer, sergeants, file-closers ----
		# These men are alive, not statues — and they WALK to their posts (smoothed via
		# _cg_step) instead of snapping with the formation frame.
		var fyaw := b.facing
		var hw := _halfwidth(b)
		var idn := float(b.idx)
		var along_yaw := atan2(right.x, right.z)
		var back_yaw := atan2(-right.x, -right.z)
		# officer marker (you ARE your own officer, so skip yours). Other players'
		# officers sit at their actual position; AI officers pace the front-centre.
		if not b.is_player and not b.officer_down and off_i < officer_mm.instance_count:
			var op: Vector3
			var oyaw: float
			if b.human:
				op = b.off_pos
				oyaw = b.off_facing
			else:
				var amp := minf(hw * 0.3, 6.0)                      # a few paces, not a sprint
				var pv := cos(_t * 0.18 + idn)                      # slow pacing direction
				var px := sin(_t * 0.18 + idn) * amp               # walk back and forth
				op = b.pos + right * px + fwd * (maxy + 1.8)
				oyaw = along_yaw if pv >= 0.0 else back_yaw
			var ow := _cg_step(b, "off", op, delta, snap)
			if ow.distance_to(op) > 0.4:
				var omv := op - ow
				oyaw = atan2(omv.x, omv.z)                         # face the way he walks
			var obob := absf(sin(_t * 2.8 + idn)) * 0.06
			officer_mm.set_instance_transform(off_i, Transform3D(Basis(Vector3.UP, oyaw), Vector3(ow.x, 0.85 + obob, ow.z)))
			off_i += 1
		# colour-bearer beside the officer, carrying the standard
		if bearer_i < bearer_mm.instance_count:
			var bp := b.pos + right * 0.9 + fwd * (maxy + 0.8)
			var bw := _cg_step(b, "bearer", bp, delta, snap)
			var byaw := fyaw
			if bw.distance_to(bp) > 0.4:
				var bmv := bp - bw
				byaw = atan2(bmv.x, bmv.z)
			if not b.colours_down:
				var bbob := absf(sin(_t * 2.4 + idn + 1.0)) * 0.04
				bearer_mm.set_instance_transform(bearer_i, Transform3D(Basis(Vector3.UP, byaw), Vector3(bw.x, CAP_HALF + bbob, bw.z)))
				bearer_i += 1
			_place_flag(b, Vector3(bw.x, 0, bw.z), fyaw)   # lays low when the colours are down
		# drummer on the other side of the colours, marking the cadence with a sway
		if not b.drummer_down and drummer_i < drummer_mm.instance_count:
			var dsway := sin(_t * 6.0 + float(b.team)) * 0.06
			var dp := b.pos + right * (-0.9 + dsway) + fwd * (maxy + 0.7)
			var dw := _cg_step(b, "drum", dp, delta, snap)
			var dyaw := fyaw
			if dw.distance_to(dp) > 0.4:
				var dmv := dp - dw
				dyaw = atan2(dmv.x, dmv.z)
			var dbob := absf(sin(_t * 3.0 + idn)) * 0.05
			drummer_mm.set_instance_transform(drummer_i, Transform3D(Basis(Vector3.UP, dyaw), Vector3(dw.x, CAP_HALF + dbob, dw.z)))
			drummer_i += 1
		# a sergeant posted at each company front, stepping along it to dress the ranks
		if b.formation == "line":
			for c in range(b.companies):
				if nco_i >= nco_mm.instance_count:
					break
				var sgn := sin(_t * 0.5 + float(c) + idn)
				var cp := b.pos + right * (_company_x(b, c) + sgn * 0.6) + fwd * (maxy + 0.8)
				var sw := _cg_step(b, "s%d" % c, cp, delta, snap)
				var syaw := along_yaw if sgn >= 0.0 else back_yaw   # faces down the line
				if sw.distance_to(cp) > 0.4:
					var smv := cp - sw
					syaw = atan2(smv.x, smv.z)                      # walking to his post
				var sbob := absf(sin(_t * 2.8 + float(c) * 1.3)) * 0.05
				nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, syaw), Vector3(sw.x, CAP_HALF + sbob, sw.z)))
				nco_i += 1
		# ...and file-closers walking the rear, herding stragglers back into their files
		var rearY := -maxy - 0.9
		for fc in range(3):
			if nco_i >= nco_mm.instance_count:
				break
			var base_rx := (float(fc) - 1.0) * hw * 0.6
			var amp2 := minf(hw * 0.22, 4.0)
			var pv2 := cos(_t * 0.2 + float(fc) * 2.0 + idn)
			var pace := sin(_t * 0.2 + float(fc) * 2.0 + idn) * amp2
			var rp: Vector3 = b.pos + right * (base_rx + pace) + fwd * rearY
			var rw := _cg_step(b, "f%d" % fc, rp, delta, snap)
			var ryaw := along_yaw if pv2 >= 0.0 else back_yaw
			if rw.distance_to(rp) > 0.4:
				var rmv := rp - rw
				ryaw = atan2(rmv.x, rmv.z)
			var rbob := absf(sin(_t * 2.8 + float(fc))) * 0.05
			nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, ryaw), Vector3(rw.x, CAP_HALF + rbob, rw.z)))
			nco_i += 1
	for team in [0, 1]:
		var mm: MultiMesh = team_mm[team]
		var gun: MultiMesh = musket_mm[team]
		for j in range(idx[team], team_prev[team]):
			mm.set_instance_transform(j, _zero_xf())
			gun.set_instance_transform(j, _zero_xf())
		team_prev[team] = idx[team]
	for j in range(off_i, officer_mm.instance_count):
		officer_mm.set_instance_transform(j, _zero_xf())
	for j in range(bearer_i, bearer_mm.instance_count):
		bearer_mm.set_instance_transform(j, _zero_xf())
	for j in range(nco_i, nco_mm.instance_count):
		nco_mm.set_instance_transform(j, _zero_xf())
	for j in range(drummer_i, drummer_mm.instance_count):
		drummer_mm.set_instance_transform(j, _zero_xf())
	_render_commanders()
	_render_cavalry(delta)

# The brigade commanders: mounted generals posted behind the centre of their brigade.
func _render_commanders() -> void:
	for i in range(brigades.size()):
		var br = brigades[i]
		if _brigade_live(br) == 0 or br.commander_down:
			cmd_horse_mm.set_instance_transform(i, _zero_xf())   # the general is dead or down
			cmd_rider_mm.set_instance_transform(i, _zero_xf())
			continue
		var yaw: float = br.facing
		var bf := Vector3(sin(yaw), 0, cos(yaw))
		var pos := _brigade_center(br) - bf * 18.0    # rides behind the line centre
		# horse: a capsule laid horizontal, pointing along the brigade's facing
		var hbasis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
		cmd_horse_mm.set_instance_transform(i, Transform3D(hbasis, Vector3(pos.x, 0.95, pos.z)))
		# rider sits astride, head and shoulders above the infantry
		cmd_rider_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(pos.x, 1.75, pos.z)))

# A command-group man WALKS to his post (officer, colours, drummer, sergeants,
# file-closers) rather than teleporting with the formation frame — this is what
# stops the sergeants "snapping" when the battalion moves, wheels or re-forms.
func _cg_step(b: Batt, key: String, target: Vector3, delta: float, snap: bool) -> Vector3:
	if snap or not b.cg.has(key):
		b.cg[key] = target               # first sight of the unit: take post directly
		return target
	var cur: Vector3 = b.cg[key]
	var run := 1.6 if (b.state == "routing" or b.charging) else 1.0
	cur = cur.move_toward(target, MAN_SPEED * 1.15 * run * delta)
	b.cg[key] = cur
	return cur

func _place_flag(b: Batt, footpos: Vector3, yaw: float) -> void:
	if not b.flag:
		return
	b.flag.visible = true
	b.flag.position = footpos
	if b.colours_down:
		# the bearer is shot — the colours lie pitched over on the ground until raised
		b.flag.rotation = Vector3(deg_to_rad(82.0), yaw, 0.0)
		if b.flag_cloth:
			b.flag_cloth.rotation.y = 0.0
		return
	# the colours read morale: held high & proud when steady, sagging and flapping
	# wildly as the unit wavers, dragged low when it breaks
	var m := clampf(b.morale / 100.0, 0.0, 1.0)
	var lean := (1.0 - m) * 0.6 + b.flinch * 0.3        # pole tips back as morale falls
	b.flag.rotation = Vector3(lean, yaw, 0.0)
	if b.flag_cloth:
		var wave := lerpf(0.3, 1.1, 1.0 - m)            # frantic flapping when shaken
		b.flag_cloth.rotation.y = sin(_t * (3.0 + (1.0 - m) * 6.0) + float(b.team)) * wave

func team_color(team: int) -> Color:
	return Color(0.30, 0.38, 0.78) if team == 0 else Color(0.74, 0.30, 0.30)

# A man falls: ragdoll if he's on screen and the pool has room, else a static body.
# A share of the fallen are wounded, not killed — they drag themselves rearward.
func _drop_dead(pos: Vector3, team: int, knock_dir: Vector3, seen: bool) -> void:
	# the expensive theatrics (blood, ragdolls, crawling wounded) are reserved for
	# deaths NEAR the camera; the far battle still fills with corpses, cheaply
	if seen and cam != null and cam.position.distance_to(pos) > 280.0:
		seen = false
	if seen:
		_emit_blood(pos, knock_dir)          # a spray of blood at the moment of the hit
	if seen and randf() < WOUNDED_FRAC and _wounded_count(team) < WOUNDED_MAX:
		var rear := Vector3(randf_range(-0.35, 0.35), 0, -1.0 if team == 0 else 1.0).normalized()
		wounded.append({ "pos": Vector3(pos.x, 0, pos.z), "dir": rear,
			"t": WOUNDED_TIME * randf_range(0.5, 1.0), "team": team, "ph": randf() * TAU })
		return
	if seen and _spawn_ragdoll(pos, team, knock_dir):
		return
	_add_corpse(pos, randf() * TAU, team)

func _wounded_count(team: int) -> int:
	var n := 0
	for w in wounded:
		if int(w["team"]) == team:
			n += 1
	return n

func _build_wounded_layer() -> void:
	for team in [0, 1]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cap := CapsuleMesh.new()
		cap.radius = CAP_RADIUS
		cap.height = CAP_HEIGHT
		cap.radial_segments = 6
		cap.rings = 2
		mm.mesh = cap
		mm.instance_count = WOUNDED_MAX
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = team_color(team).darkened(0.08)
		mat.roughness = 1.0
		mmi.material_override = mat
		add_child(mmi)
		wounded_mm[team] = mm
		for i in range(WOUNDED_MAX):
			mm.set_instance_transform(i, _zero_xf())

# The wounded crawl toward their own rear in fits and starts, then lie still and
# join the field of the fallen.
func _update_wounded(delta: float) -> void:
	var counts := [0, 0]
	var i := 0
	while i < wounded.size():
		var w: Dictionary = wounded[i]
		var t := float(w["t"]) - delta
		if t <= 0.0:
			_add_corpse(w["pos"], randf() * TAU, int(w["team"]))   # he is still
			wounded.remove_at(i)
			continue
		w["t"] = t
		var ph := float(w["ph"])
		var effort := maxf(0.0, sin(_t * 1.6 + ph))        # crawls in painful heaves
		var p: Vector3 = w["pos"]
		p += (w["dir"] as Vector3) * CRAWL_SPEED * effort * delta
		w["pos"] = p
		var team := int(w["team"])
		if counts[team] < WOUNDED_MAX:
			var dirv: Vector3 = w["dir"]
			var yaw := atan2(dirv.x, dirv.z)
			var wiggle := sin(_t * 3.2 + ph) * 0.12 * effort
			var basis := Basis(Vector3.UP, yaw + wiggle) * Basis(Vector3.RIGHT, PI * 0.5)
			var mm: MultiMesh = wounded_mm[team]
			mm.set_instance_transform(counts[team], Transform3D(basis, Vector3(p.x, CAP_RADIUS + 0.02, p.z)))
			counts[team] += 1
		i += 1
	for team in [0, 1]:
		var mm2: MultiMesh = wounded_mm[team]
		if mm2 == null:
			continue
		for j in range(counts[team], WOUNDED_MAX):
			mm2.set_instance_transform(j, _zero_xf())

func _add_corpse(pos: Vector3, yaw: float, team: int) -> void:
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	_bake_corpse(Transform3D(basis, Vector3(pos.x, CAP_RADIUS, pos.z)), team)
	_add_blood(pos)                          # a pool soaks the ground beneath him

func _bake_corpse(xf: Transform3D, team: int) -> void:
	var mm: MultiMesh = corpse_mm[team]
	mm.set_instance_transform(corpse_idx[team], xf)
	corpse_idx[team] = (corpse_idx[team] + 1) % CORPSE_MAX

# ------------------------------------------------------------------ ragdolls

func _spawn_ragdoll(pos: Vector3, team: int, knock_dir: Vector3) -> bool:
	var r: Dictionary = {}
	for cand in _ragdolls:
		if not cand["active"]:
			r = cand
			break
	if r.is_empty():
		return false                              # pool full — caller drops a static body
	var rb: RigidBody3D = r["body"]
	r["active"] = true
	r["t"] = 0.0
	r["team"] = team
	(r["mat"] as StandardMaterial3D).albedo_color = team_color(team)
	var kd := knock_dir
	kd.y = 0.0
	if kd.length() > 0.01:
		kd = kd.normalized()
	else:
		kd = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var perp := Vector3(-kd.z, 0, kd.x)        # axis to topple about (across the knock)
	rb.freeze = true
	# start already toppling away from the fire so the capsule can't stand on its end
	var basis := Basis(perp, randf_range(0.5, 0.9)) * Basis(Vector3.UP, randf() * TAU)
	rb.global_transform = Transform3D(basis, to_global(Vector3(pos.x, CAP_HALF + 0.05, pos.z)))
	rb.freeze = false
	rb.linear_velocity = kd * randf_range(1.5, 3.0) + Vector3(0, randf_range(1.0, 2.2), 0)
	# a strong tumble (mostly about the topple axis) guarantees he goes down flat
	rb.angular_velocity = perp * randf_range(7.0, 11.0) + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
	return true

func _update_ragdolls(delta: float) -> void:
	for r in _ragdolls:
		if not r["active"]:
			continue
		r["t"] = float(r["t"]) + delta
		var rb: RigidBody3D = r["body"]
		var settled: bool = float(r["t"]) > 0.9 and rb.linear_velocity.length() < 0.4 and rb.angular_velocity.length() < 0.6
		if float(r["t"]) > RAGDOLL_TIME or settled:
			# always bake a body LYING FLAT on the ground at his final spot, so nobody
			# is ever frozen mid-stand
			_add_corpse(to_local(rb.global_position), rb.rotation.y, int(r["team"]))
			rb.freeze = true
			rb.position = Vector3(0, -200, 0)
			r["active"] = false

# ------------------------------------------------------------------ player + camera

func _update_player_officer(delta: float) -> void:
	if _off_down:
		officer.position = off_pos          # you are down — carried, not commanding
		return
	var fwd := (-Vector3(sin(_cam_yaw), 0, cos(_cam_yaw))).normalized()
	var right := fwd.cross(Vector3.UP)
	var iv := 0.0
	var ih := 0.0
	if Input.is_key_pressed(KEY_W): iv += 1.0
	if Input.is_key_pressed(KEY_S): iv -= 1.0
	if Input.is_key_pressed(KEY_D): ih += 1.0
	if Input.is_key_pressed(KEY_A): ih -= 1.0
	var move := fwd * iv + right * ih
	var riding := move.length() > 0.01
	if riding:
		move = move.normalized()
		var spd := OFF_RUN if Input.is_key_pressed(KEY_SHIFT) else OFF_WALK
		off_pos += move * spd * delta
		off_facing = atan2(move.x, move.z)
	off_vis = lerp_angle(off_vis, off_facing, clampf(delta * 8.0, 0.0, 1.0))
	# the horse's gait: a gentle rise and fall at the walk, a rolling beat at the canter
	var bob := 0.0
	if riding:
		var gait := 8.0 if Input.is_key_pressed(KEY_SHIFT) else 4.5
		bob = absf(sin(_t * gait)) * 0.08
	officer.position = off_pos + Vector3(0, bob, 0)
	officer.rotation.y = off_vis

# Every man of yours who falls costs you a point of prestige. Counted centrally from
# your battalion's strength, so every cause — musketry, roundshot, canister, the
# press of the bayonet — is charged to your name the same way.
func _update_prestige() -> void:
	if player == null:
		return
	var n := player.figs.size()
	if player.detachment != null:
		n += player.detachment.figs.size()   # your skirmishers are still your men
	if _player_figs_prev < 0:
		_player_figs_prev = n            # first frame: set the baseline
		return
	if n < _player_figs_prev:
		prestige -= _player_figs_prev - n
	_player_figs_prev = n

# ------------------------------------------------------------ battle flow

# Deployment -> the step-off -> the fight -> one army breaks -> the butcher's bill.
func _update_battle_flow(delta: float) -> void:
	if not _battle_begun:
		if _deploy_t == DEPLOY_TIME:     # opening moment: tell the player the day's shape
			_send_player_despatch("[color=#ffd773]Dawn.[/color] Deploy your battalion — the army steps off shortly. [color=#9fb0c8](Enter to advance the step-off)[/color]", {})
		_deploy_t -= delta
		if _deploy_t <= 0.0:
			_begin_battle()
		return
	if battle_over:
		if _bill_t > 0.0:
			_bill_t -= delta
			if _bill_t <= 0.0:
				_show_bill()
		return
	# does either army still stand? An army breaks when most of its formations are
	# spent or running, or when its strength has bled past holding.
	for team in [0, 1]:
		if _army_broken[team]:
			continue
		var total := 0
		var broken := 0
		var men := 0
		for b in battalions:
			if b.team != team:
				continue
			total += 1
			men += b.figs.size()
			if b.spent or b.state == "routing":
				broken += 1
		var strength_frac := float(men) / maxf(1.0, float(_start_strength[team]))
		if float(broken) / float(maxi(1, total)) >= 0.55 or strength_frac <= 0.45:
			_army_breaks(team)
			return

func _begin_battle() -> void:
	_battle_begun = true
	_deploy_t = 0.0
	_send_player_despatch("[color=#ffd773]The army advances![/color] Drums beating, colours uncased.", {})

# The whole army gives way: every battalion runs, the enemy takes heart, and after a
# few minutes of pursuit the field falls quiet and the bill is presented.
func _army_breaks(team: int) -> void:
	_army_broken[team] = true
	battle_over = true
	_bill_t = 10.0
	for b in battalions:
		if b.team == team:
			b.morale = minf(b.morale, 12.0)   # the rout is general
			b.calm_t = 0.0
		elif not b.spent:
			b.morale = minf(100.0, b.morale + 25.0)   # the victors take heart and cheer
	if player != null and player.team == team:
		_send_player_despatch("[color=#ff7a6a]The army is broken![/color] The day is lost — bring your men off the field.", {})
	else:
		_send_player_despatch("[color=#9fe0a0]The enemy army breaks![/color] The field is yours — the day is won!", {})

func _show_bill() -> void:
	if _bill_panel == null or player == null:
		return
	var pt := player.team
	var et := 1 - pt
	var men_now := [0, 0]
	var guns_lost := [0, 0]
	var horse_now := [0, 0]
	for b in battalions:
		men_now[b.team] += b.figs.size()
	for g in guns:
		if g.dead:
			guns_lost[g.team] += 1
	for c in cavalry:
		horse_now[c.team] += c.troopers.size()
	var won: bool = _army_broken[et]
	var title := "[color=#9fe0a0]VICTORY[/color]" if won else "[color=#ff7a6a]DEFEAT[/color]"
	var pcol := "9fe0a0" if prestige >= 0 else "ff9a8a"
	var txt := "[center][b]%s[/b]\n" % title
	txt += "[color=#6f7888]——————————————[/color]\n"
	var cav_start := (0 if _inflated else CAV_PER_TEAM * CAV_MEN)
	txt += "[color=#cdd6e6]Our losses[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[pt] - men_now[pt], _start_strength[pt], cav_start - horse_now[pt], guns_lost[pt]]
	txt += "[color=#cdd6e6]Theirs[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[et] - men_now[et], _start_strength[et], cav_start - horse_now[et], guns_lost[et]]
	txt += "[color=#cdd6e6]Your battalion[/color]  %d effectives remain\n" % player.figs.size()
	txt += "[color=#cdd6e6]Prestige banked[/color]  [color=#%s]%+d[/color]\n" % [pcol, prestige]
	txt += "[color=#6f7888]——————————————\nEnter — return to the menu[/color][/center]"
	_bill_label.text = txt
	_bill_panel.visible = true
	_write_result(pt, et, won, men_now)
	# (step 8) machine-readable result line, so headless AI-vs-AI batches can be scored
	print("[RESULT] winner_team=%d our=%d/%d theirs=%d/%d prestige=%d goals=%s|%s" % [
		et if won else pt, men_now[pt], _start_strength[pt], men_now[et], _start_strength[et],
		prestige, armies[0].goal if armies.size() > 0 else "-", armies[1].goal if armies.size() > 1 else "-"])

# ------------------------------------------------------------ the player's own fight

func _update_combat(delta: float) -> void:
	_sword_cd = maxf(0.0, _sword_cd - delta)
	_swing = maxf(0.0, _swing - delta)
	_dmg_flash = maxf(0.0, _dmg_flash - delta * 1.5)
	if not _pistol_loaded:
		_pistol_reload -= delta
		if _pistol_reload <= 0.0:
			_pistol_loaded = true
	if _dmg_rect:
		_dmg_rect.color.a = _dmg_flash * 0.45
	if _off_down:
		_off_respawn -= delta
		if _off_respawn <= 0.0:
			_off_down = false
			_off_hp = OFF_HP
			if player != null:
				var bf := Vector3(sin(player.facing), 0, cos(player.facing))
				off_pos = player.pos - bf * 16.0       # back on your feet, behind the line
			_send_player_despatch("[color=#9fe0a0]You are back on your feet, sir.[/color]", {})
		_animate_weapons(delta)
		return
	# vulnerability: men at sword's length cut you down; close fire finds you too
	var threat := 0
	var under_fire := false
	for b in battalions:
		if b.team == player.team or b.spent:
			continue
		var bd := off_pos.distance_to(b.pos)
		if bd > 130.0:
			continue
		if b.has_target and bd < 45.0:
			under_fire = true
		var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var fright := Vector3(ffwd.z, 0, -ffwd.x)
		for i in range(b.figs.size()):
			var sl: Vector2 = b.figs[i]["slot"]
			var w := b.pos + fright * sl.x + ffwd * sl.y
			if off_pos.distance_to(w) < 3.0:
				threat += 1
				if threat >= 8:
					break
		if threat >= 8:
			break
	var dmg := float(threat) * OFF_MELEE_DPS * delta
	if under_fire and threat == 0 and randf() < 0.5:
		dmg += OFF_FIRE_DPS * delta            # a stray ball in the beaten zone
	if dmg > 0.0:
		_off_hp -= dmg
		_dmg_flash = minf(1.0, _dmg_flash + dmg * 0.05)
		if _off_hp <= 0.0:
			_player_down()
	else:
		_off_hp = minf(OFF_HP, _off_hp + OFF_REGEN * delta)
	_animate_weapons(delta)

func _player_down() -> void:
	_off_down = true
	_off_respawn = OFF_DOWN_TIME
	_off_hp = 0.0
	_dmg_flash = 1.0
	if player != null:
		player.morale -= OFFICER_SHOCK * 1.5
		player.calm_t = 0.0
	_send_player_despatch("[color=#ff7a6a]You are cut down![/color] Your men drag you to the rear...", {})

func _animate_weapons(delta: float) -> void:
	if sabre:
		if _swing > 0.0:
			var u := clampf(1.0 - _swing / SWORD_CD, 0.0, 1.0)   # 0..1 over the cut
			sabre.rotation = Vector3(-2.2 * sin(u * PI), 0.0, 0.0)
		else:
			sabre.rotation = sabre.rotation.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	if pistol_mesh:
		var want := 0.0 if _pistol_loaded else 1.1   # lowered while reloading
		pistol_mesh.rotation.x = lerpf(pistol_mesh.rotation.x, want, clampf(delta * 6.0, 0.0, 1.0))

func _swing_sabre() -> void:
	if not authoritative or _off_down or _sword_cd > 0.0:
		return
	_sword_cd = SWORD_CD
	_swing = SWORD_CD
	var aim := (-Vector3(sin(_cam_yaw), 0, cos(_cam_yaw))).normalized()   # where you look
	var vb: Batt = null
	var vi := -1
	var bestd := SWORD_REACH
	for b in battalions:
		if b.team == player.team or b.spent:
			continue
		if off_pos.distance_to(b.pos) > 140.0:
			continue
		var ffwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var fright := Vector3(ffwd.z, 0, -ffwd.x)
		for i in range(b.figs.size()):
			var sl: Vector2 = b.figs[i]["slot"]
			var w := b.pos + fright * sl.x + ffwd * sl.y
			var to := w - off_pos
			to.y = 0.0
			var dd := to.length()
			if dd > SWORD_REACH or dd < 0.05:
				continue
			if to.normalized().dot(aim) < SWORD_ARC:
				continue
			if dd < bestd:
				bestd = dd
				vb = b
				vi = i
	if vb != null:
		_drop_fig(vb, vi, aim)
		prestige += 1                    # cut down by your own sabre
		_play_melee(off_pos + Vector3(0, 1.0, 0))

func _fire_pistol() -> void:
	if not authoritative or _off_down or not _pistol_loaded:
		return
	_pistol_loaded = false
	_pistol_reload = PISTOL_RELOAD
	var aim := (-Vector3(sin(_cam_yaw), 0, cos(_cam_yaw))).normalized()
	var muzzle := off_pos + Vector3(0, 2.0, 0) + aim * 0.5   # fired from the saddle
	var sd := _scatter_dir(aim, PISTOL_YAW_SD, PISTOL_PITCH_SD)
	_emit_flash(muzzle)
	_emit_smoke(muzzle, aim)
	_emit_muzzle_bloom(muzzle, aim)
	_play_shot(muzzle)
	_shake = minf(_shake + 0.15, SHAKE_MAX)
	var hit := _ray_hit_world(muzzle, sd, PISTOL_RANGE, 1 - player.team)
	if not hit.is_empty():
		_drop_fig(hit["b"], hit["i"], sd)
		prestige += 1                    # felled by your own hand

func _update_cam(delta: float) -> void:
	# spyglass: raise the glass (RMB) -> narrow the FOV and mask to a circle
	_scope_amt = move_toward(_scope_amt, 1.0 if _scoped else 0.0, delta * 6.0)
	cam.fov = lerpf(FOV_NORMAL, FOV_SCOPE, _scope_amt)
	if _scope_rect:
		_scope_rect.modulate.a = _scope_amt
	var target := off_pos + Vector3(0, 2.35, 0)   # a mounted man's eyeline — over the ranks
	# 3rd-person orbit behind you (camera height from _cam_pitch)
	var dir := Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch))
	var orbit_pos := target + dir * _cam_dist
	# spyglass: look FORWARD from your eyeline, freely up/down via _scope_pitch
	var hx := -sin(_cam_yaw)
	var hz := -cos(_cam_yaw)
	var look_dir := Vector3(hx * cos(_scope_pitch), sin(_scope_pitch), hz * cos(_scope_pitch))
	var scope_pos := target + look_dir * 0.6
	cam.position = orbit_pos.lerp(scope_pos, _scope_amt)
	var look_pt := target.lerp(target + look_dir * 80.0, _scope_amt)
	cam.look_at(to_global(look_pt), Vector3.UP)   # to_global = identity at origin, offset-safe when hosted
	if _shake > 0.001:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake

func _update_hud() -> void:
	# zero HUD by default: read morale from the colours and your men, hear it from
	# the drums. The controls panel shows briefly on launch, then toggled with Tab.
	if help_panel:
		help_panel.visible = _help_on or _t < 9.0
	if cmd_panel:
		cmd_panel.visible = _cmd_on
		if _cmd_on:
			_refresh_cmd_panel()         # live roster + the current order page
	# a fresh despatch from the commander / a sergeant's report counts down and fades
	_msg_t = maxf(0.0, _msg_t - get_process_delta_time())
	if msg_panel:
		msg_panel.visible = _msg_t > 0.0
		if _msg_t > 0.0:
			msg_label.text = "[center]" + _msg_text + "[/center]"

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured:
		var s := MOUSE_SENS * (1.0 - 0.65 * _scope_amt)   # finer aim through the glass
		_cam_yaw -= event.relative.x * s
		if _scoped:
			# spyglass: free look up and down (mouse up tilts the view up)
			_scope_pitch = clampf(_scope_pitch - event.relative.y * s, deg_to_rad(-55.0), deg_to_rad(70.0))
		else:
			_cam_pitch = clampf(_cam_pitch + event.relative.y * s, deg_to_rad(6.0), deg_to_rad(78.0))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_scoped = event.pressed                       # hold RMB to raise the spyglass
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_swing_sabre()                                # cut at whatever you're facing
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = maxf(4.0, _cam_dist - 3.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = minf(220.0, _cam_dist + 3.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		# while the despatch pad is open: pick a category, then an order
		if _cmd_on:
			if event.keycode == KEY_Q:
				_cmd_on = false
				_cmd_page = ""
				return
			if event.keycode == KEY_ESCAPE:
				if _cmd_page == "":
					_cmd_on = false
				else:
					_cmd_page = ""          # back to the categories
				return
			for item in CMD_PAGES[_cmd_page]:
				if event.keycode == int(item[0]):
					var act := String(item[3])
					if act.begins_with("page:"):
						_cmd_page = act.trim_prefix("page:")
						return
					var o := { "kind": act }
					if act.begins_with("adv:"):
						o = { "kind": "advance_n", "yds": int(act.trim_prefix("adv:")) }
					elif act.begins_with("fallback:"):
						o = { "kind": "fall_back", "yds": int(act.trim_prefix("fallback:")) }
					elif act == "halt":
						o["face"] = off_vis
					_order(o)
					_cmd_on = false
					_cmd_page = ""
					return
			return
		match event.keycode:
			KEY_ENTER:
				if battle_over and _bill_panel and _bill_panel.visible:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					if hosted:
						host_done = true     # the world frees this battle and resumes the war
					elif GameConfig.return_to_world:   # interim scene-swap path
						get_tree().change_scene_to_file("res://world.tscn")
					else:
						get_tree().change_scene_to_file("res://menu.tscn")   # the day is done
				elif authoritative and not _battle_begun:
					_begin_battle()       # advance the step-off
			KEY_E:
				_talk()                   # hail your sergeant / a nearby unit / the general
			KEY_G:
				_fire_pistol()            # one shot from the horse-pistol, point-blank
			KEY_N:
				_time_of_day = fposmod(_time_of_day + 1.5, 24.0)   # push the clock forward
			KEY_M:
				_cycle_weather()          # clear -> overcast -> rain -> fog
			KEY_Q:
				_cmd_on = true
			KEY_TAB:
				_help_on = not _help_on
			KEY_ESCAPE:
				_mouse_captured = not _mouse_captured
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
			_:
				pass              # all unit orders now go through the courier menu (Q)

# Route an order: host/single applies it (manoeuvre orders ride a courier); a client
# forwards it to the host.
func _order(o: Dictionary) -> void:
	# every order now rides a courier from you to your battalion — there is a real delay
	# before it is carried out, so you must think ahead
	if authoritative:
		_dispatch(o)
	else:
		_pending_net_order = o                 # send to host on the next tick

# Apply an order's effect to a battalion (used by couriers, the host directly, and
# for orders forwarded from clients).
func _apply_net_order(b: Batt, o: Dictionary) -> void:
	match String(o.get("kind", "")):
		"move_to_me":
			b.order = Order.FOLLOW           # form up on me and keep with me
			b.advancing = false
			b.wheeling = false
			b.has_goal = false
			b.fall_back = false
		"halt":
			b.order = Order.IDLE
			b.advancing = false
			b.charging = false
			b.wheeling = false
			b.has_goal = false
			b.fall_back = false
			b.facing = float(o.get("face", b.facing))
		"advance":
			b.advancing = true
			b.order = Order.IDLE
			b.has_goal = false
			b.fall_back = false
		"advance_n":
			# a measured advance: N yards straight to the front, then halt and dress
			var yd: float = float(o.get("yds", 25)) * 0.9144
			var bfwd := Vector3(sin(b.facing), 0, cos(b.facing))
			b.move_goal = b.pos + bfwd * yd
			b.has_goal = true
			b.fall_back = false
			b.order = Order.IDLE
			b.advancing = false
			b.wheeling = false
		"fall_back":
			# the fighting withdrawal: step back N yards FACING the enemy, firing all the way
			var yd2: float = float(o.get("yds", 50)) * 0.9144
			var bfwd2 := Vector3(sin(b.facing), 0, cos(b.facing))
			b.move_goal = b.pos - bfwd2 * yd2
			b.has_goal = true
			b.fall_back = true
			b.order = Order.IDLE
			b.advancing = false
			b.wheeling = false
			b.charging = false
		"wheel_left":
			b.order = Order.IDLE
			b.wheeling = true
			b.has_goal = false
			b.wheel_to = b.facing + PI * 0.25   # +yaw turns toward -x: the LEFT, seen from behind
		"wheel_right":
			b.order = Order.IDLE
			b.wheeling = true
			b.has_goal = false
			b.wheel_to = b.facing - PI * 0.25
		"line":
			b.skirmish = false
			if b.formation != "line":
				b.formation = "line"
				_reslot(b)
		"column":
			b.skirmish = false
			if b.formation != "column":
				b.formation = "column"
				_reslot(b)
		"square":
			b.skirmish = false
			b.rolling = false
			if b.formation != "square":
				b.formation = "square"
				_reslot(b)
		"skirmish":
			_detach_skirmishers(b)           # a company goes forward in open order
		"recall":
			_recall_skirmishers(b)           # the screen falls back into the line
		"resupply":
			_request_caisson(b)              # send to the rear for cartridges
		"volley":
			b.volley_fire = true             # hold, then fire as one when all are loaded
			b.auto_volley = true
			b.rolling = false
		"fire_at_will":
			b.volley_fire = false
			b.auto_volley = false
			b.rolling = false
		"hold_fire":
			b.volley_fire = true             # muskets up, not a shot until ordered
			b.auto_volley = false
			b.rolling = false
		"charge":
			if not b.charging and b.melee_foe == null and b.charge_cool <= 0.0:
				var tgt := _nearest_enemy_in_range(b, CHARGE_RANGE)
				if tgt != null:
					_begin_charge(b, tgt)

# ------------------------------------------------------------------ volley fx

# Light up the firing line, shake the camera, and wash the screen for a near volley.
func _volley_cinematic(b: Batt, pts: Array) -> void:
	# dynamic lights only for volleys near enough to light anything you can see
	if cam != null and cam.position.distance_to(b.pos) > 420.0:
		return
	var n := mini(6, pts.size())
	for k in range(n):
		var p: Vector3 = pts[(k * pts.size()) / n]
		var l: OmniLight3D = _lights[_light_i]
		_light_i = (_light_i + 1) % _lights.size()
		l.global_position = to_global(p + Vector3(0, 0.4, 0))
		l.light_color = Color(1.0, 0.78, 0.45)
		l.light_energy = 7.5 + _night * 9.0
		l.omni_range = 18.0 + _night * 12.0
	var d := cam.position.distance_to(b.pos)
	var prox := clampf(1.0 - d / 130.0, 0.0, 1.0)
	if prox > 0.0:
		# a felt "suppress": a gentle camera tremor and a smoky vignette closing in,
		# rather than a jarring shake and bright flash
		_shake = minf(_shake + prox * 0.16, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * (0.05 + _night * 0.18), 0.12 + _night * 0.25)
		_suppress = minf(_suppress + prox * 0.55, 0.7)

func _musket_xf(footpos: Vector3, yaw: float, leveled: bool, moving: bool, reloading: bool, work: float) -> Transform3D:
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var shoulder := footpos + Vector3(0, 1.35, 0) + right * 0.14
	if leveled:
		# levelled at the enemy, ready to fire
		return Transform3D(Basis(Vector3.UP, yaw), shoulder + fwd * 0.5)
	if moving:
		# on the march: barrel slung up over the shoulder
		var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -1.15)
		return Transform3D(basis, shoulder + Vector3(0, 0.32, 0) - fwd * 0.05)
	if reloading:
		# loading drill: musket brought down across the body, the ramrod working in
		# the barrel (a rhythmic pitch about level), held out in front, butt low
		var pitch := -1.15 + sin(work) * 0.32
		var basis2 := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		return Transform3D(basis2, footpos + Vector3(0, 1.0, 0) + fwd * 0.22 + right * 0.05)
	# loaded and standing ready: musket held upright at the order/recover
	var basis3 := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -1.5)
	return Transform3D(basis3, shoulder + Vector3(0, 0.3, 0))

# ------------------------------------------------------------------ particles

func _make_emitter(life: float, amount: int, mat: Material, quad: Vector2, kind: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = false
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-1500, -50, -1500), Vector3(3000, 300, 3000))
	var qm := QuadMesh.new()
	qm.size = quad
	qm.material = mat
	p.draw_pass_1 = qm
	match kind:
		0: p.process_material = _smoke_process()
		2: p.process_material = _fire_process()
		4: p.process_material = _blood_process()
		5: p.process_material = _musket_smoke_process()
		_: p.process_material = _flash_process()
	return p

# Musket smoke: barely damped, so the discharge ROLLS forward off the muzzles and
# thins out over six to ten metres downrange instead of stagnating at the line.
func _musket_smoke_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 0.07, 0)
	m.damping_min = 0.22
	m.damping_max = 0.45
	m.scale_min = 0.9
	m.scale_max = 1.8
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(0.3, 2.2))
	sc.add_point(Vector2(1.0, 3.6))            # spreads as it travels
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# densest at the muzzle, thinning steadily as it drifts downrange
	m.color_ramp = _ramp([0.0, 0.08, 0.45, 1.0], [
		Color(0.85, 0.85, 0.86, 0.0), Color(0.85, 0.85, 0.86, 0.58),
		Color(0.81, 0.81, 0.83, 0.30), Color(0.79, 0.79, 0.81, 0.0)])
	return m

func _blood_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _radial_tex()
	m.vertex_color_use_as_albedo = true
	return m

func _blood_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, -4.5, 0)            # the mist sinks toward the ground
	m.damping_min = 2.5                        # the burst speed bleeds off fast -> hangs as a cloud
	m.damping_max = 5.0
	m.scale_min = 0.8
	m.scale_max = 1.6
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.3, 1.8))            # billows out into a thick mist
	sc.add_point(Vector2(1.0, 2.4))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# vivid, near-opaque red on impact, holding bright before fading out at the end
	m.color_ramp = _ramp([0.0, 0.55, 1.0], [
		Color(0.85, 0.05, 0.05, 1.0), Color(0.6, 0.03, 0.03, 0.9), Color(0.3, 0.0, 0.0, 0.0)])
	return m

func _fire_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 2.2, 0)             # flame licks upward
	m.damping_min = 2.0
	m.damping_max = 5.0
	m.scale_min = 0.7
	m.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.3))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# HDR oranges so the bloom catches the muzzle fire
	m.color_ramp = _ramp([0.0, 0.4, 1.0], [Color(2.4, 1.3, 0.4, 1.0), Color(1.4, 0.5, 0.12, 0.7), Color(0.3, 0.1, 0.05, 0.0)])
	return m

func _smoke_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 0.10, 0)            # barely drifts upward — the bank just hangs
	m.damping_min = 1.6                        # initial puff velocity bleeds off fast
	m.damping_max = 3.2
	m.scale_min = 1.0
	m.scale_max = 2.2
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.4))
	sc.add_point(Vector2(0.35, 2.6))
	sc.add_point(Vector2(1.0, 4.2))            # keeps spreading into a broad haze
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# billows up quickly, then thins very slowly so a grey haze hangs over the field
	m.color_ramp = _ramp([0.0, 0.08, 0.55, 1.0], [
		Color(0.84, 0.84, 0.85, 0.0), Color(0.84, 0.84, 0.85, 0.60),
		Color(0.80, 0.80, 0.82, 0.40), Color(0.78, 0.78, 0.80, 0.0)])
	return m

func _flash_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO
	m.damping_min = 6.0
	m.damping_max = 10.0
	m.scale_min = 0.7
	m.scale_max = 1.1
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(1.0, 0.2))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	m.color_ramp = _ramp([0.0, 1.0], [Color(1.8, 1.3, 0.6, 1.0), Color(1.4, 0.7, 0.2, 0.0)])
	return m

func _ramp(offs: Array, cols: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _radial_tex() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

func _smoke_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _radial_tex()
	m.vertex_color_use_as_albedo = true
	return m

func _flash_material() -> StandardMaterial3D:
	var m := _smoke_material()
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

func _emit_flash(pos: Vector3) -> void:
	flash_p.emit_particle(Transform3D(Basis(), pos),
		Vector3(randf_range(-0.3, 0.3), randf_range(0.1, 0.4), randf_range(-0.3, 0.3)),
		Color(1.7, 1.2, 0.55), Color.WHITE, EMIT_FLAGS)

func _emit_smoke(pos: Vector3, fwd: Vector3) -> void:
	# musket smoke is THROWN forward off the muzzle and rolls slowly downrange,
	# dissipating over distance in front of the line (low-damping emitter)
	var jitter := Vector3(randf_range(-0.2, 0.2), randf_range(-0.1, 0.2), randf_range(-0.2, 0.2))
	var vel := fwd * randf_range(1.6, 2.9) + Vector3(0, randf_range(0.08, 0.22), 0) + _wind
	musket_smoke_p.emit_particle(Transform3D(Basis(), pos + jitter), vel,
		Color(0.88, 0.88, 0.88), Color.WHITE, EMIT_FLAGS)

func _emit_fire(pos: Vector3, fwd: Vector3) -> void:
	var vel := fwd * randf_range(1.0, 2.2) + Vector3(0, randf_range(0.2, 0.5), 0)
	fire_p.emit_particle(Transform3D(Basis(), pos), vel, Color(2.3, 1.3, 0.45), Color.WHITE, EMIT_FLAGS)

# A bright stab of muzzle flame from a musket — HDR so the bloom catches it, thrown
# forward out of the barrel and gone in a flash.
const BLOOM_FLAGS := GPUParticles3D.EMIT_FLAG_POSITION | GPUParticles3D.EMIT_FLAG_VELOCITY \
	| GPUParticles3D.EMIT_FLAG_COLOR | GPUParticles3D.EMIT_FLAG_ROTATION_SCALE
func _emit_muzzle_bloom(pos: Vector3, fwd: Vector3) -> void:
	# brighter and bigger the darker it gets — a stab of flame that lights the night
	var bright := 1.0 + _night * 2.2
	var grow := 1.8 * (1.0 + _night * 0.7)
	var n := 3 if _night > 0.4 else 2
	for i in range(n):
		var v := fwd * randf_range(2.5, 5.0) + Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))
		var big := Basis().scaled(Vector3(grow, grow, grow))
		fire_p.emit_particle(Transform3D(big, pos + fwd * 0.1 * float(i)), v,
			Color(3.4 * bright, 1.9 * bright, 0.7 * bright), Color.WHITE, BLOOM_FLAGS)
	# at night a real flash of light leaps from the muzzle (pooled, so only the nearest
	# shots throw light — which is plenty for the flicker across a firing line)
	if _night > 0.25 and cam and cam.position.distance_to(pos) < 110.0:
		var l: OmniLight3D = _lights[_light_i]
		_light_i = (_light_i + 1) % _lights.size()
		l.position = pos
		l.light_color = Color(1.0, 0.78, 0.45)
		l.light_energy = 5.0 + _night * 6.0
		l.omni_range = 12.0 + _night * 8.0

# A cannon's muzzle blast: smoke fired hard out of the barrel, jetting several metres
# before the high damping arrests it (much faster than a musket's little puff).
func _emit_gun_smoke(pos: Vector3, fwd: Vector3) -> void:
	var lateral := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.5
	var vel := fwd * randf_range(4.0, 9.0) + lateral + Vector3(0, randf_range(0.2, 0.9), 0) + _wind
	smoke_p.emit_particle(Transform3D(Basis(), pos), vel,
		Color(0.9, 0.9, 0.9), Color.WHITE, EMIT_FLAGS)

# A burst of fine blood mist the instant a man is struck — it puffs out away from the
# shot, hangs for a moment, then sinks and leaves a splatter on the ground.
func _emit_blood(pos: Vector3, dir: Vector3) -> void:
	var kd := dir
	kd.y = 0.0
	if kd.length() > 0.01:
		kd = kd.normalized()
	var src := pos + Vector3(0, 1.05, 0)       # chest height
	for i in range(34):
		var spray := kd * randf_range(0.8, 3.0) \
			+ Vector3(randf_range(-2.2, 2.2), randf_range(0.5, 2.8), randf_range(-2.2, 2.2))
		blood_p.emit_particle(Transform3D(Basis(), src + Vector3(randf_range(-0.15, 0.15), randf_range(-0.2, 0.3), randf_range(-0.15, 0.15))), spray,
			Color(0.62, 0.04, 0.04), Color.WHITE, EMIT_FLAGS)
	_add_blood(pos)                            # the spray settles onto the floor

# A pool of blood baked into the ground beneath a body.
func _add_blood(pos: Vector3) -> void:
	var yaw := randf() * TAU
	var sc := randf_range(0.7, 1.4)
	var basis := Basis(Vector3.UP, yaw).scaled(Vector3(sc, 1.0, sc * randf_range(0.8, 1.2)))
	blood_mm.set_instance_transform(blood_idx, Transform3D(basis, Vector3(pos.x, 0.03, pos.z)))
	blood_idx = (blood_idx + 1) % BLOOD_MAX

# Load any of the named files that actually exist, returning a list of streams.
# We test the source file on disk (FileAccess) rather than ResourceLoader.exists(),
# which can wrongly report false for freshly-added .wav files (stale UID cache).
func _load_sound_set(names: Array) -> Array:
	var out: Array = []
	for n in names:
		var s := _load_one(String(n))
		if s != null:
			out.append(s)
	return out

func _load_one(name: String) -> AudioStream:
	var path := "res://sounds/" + name
	if not (FileAccess.file_exists(path) or FileAccess.file_exists(path + ".import")):
		return null
	var r = load(path)
	return r if r is AudioStream else null

# The first of several candidate filenames that actually exists.
func _load_first(names: Array) -> AudioStream:
	for n in names:
		var s := _load_one(String(n))
		if s != null:
			return s
	return null

# An officer's voice or a cheer, audible only near the camera (it's a human voice,
# not a cannon) — silently skipped when the recording isn't in sounds/.
func _play_voice(stream: AudioStream, pos: Vector3, reach := 130.0) -> void:
	if stream == null or cam == null:
		return
	if cam.position.distance_to(pos) > reach:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = stream
	ap.global_position = to_global(pos + Vector3(0, 1.6, 0))
	ap.volume_db = 6.0
	ap.pitch_scale = randf_range(0.96, 1.04)
	ap.play()

func _play_volley(pos: Vector3) -> void:
	if snd_volley.is_empty():
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_volley[randi() % snd_volley.size()]
	ap.global_position = to_global(pos)
	ap.volume_db = 11.0
	ap.pitch_scale = randf_range(0.9, 1.1)   # wider variation = raggeder volley
	ap.play()

func _play_melee(pos: Vector3) -> void:
	if snd_melee == null:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_melee
	ap.global_position = to_global(pos)
	ap.volume_db = 8.0
	ap.pitch_scale = randf_range(0.95, 1.05)
	ap.play()

# a single soldier's shot — a random MusketShot recording for variety
func _play_shot(pos: Vector3) -> void:
	if snd_shots.is_empty():
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_shots[randi() % snd_shots.size()]
	ap.global_position = to_global(pos)
	ap.volume_db = -3.0
	ap.pitch_scale = randf_range(0.92, 1.12)
	ap.play()

# ------------------------------------------------------------------ couriers

func _dispatch(order: Dictionary) -> void:
	couriers.append({ "pos": off_pos + Vector3(0, 0.9, 0), "order": order })
	if couriers.size() > COURIER_MAX:
		var c: Dictionary = couriers.pop_front()
		if not bool(c.get("suggest", false)):
			_apply_order(c["order"])      # buffer overflow: just apply your own orders

# An aide rides from somewhere on the field to YOU, carrying either your own order
# (auto-applied) or a despatch you may choose to obey (suggest = true).
func _send_courier_to_player(from_pos: Vector3, text: String, order: Dictionary, suggest: bool) -> void:
	couriers.append({ "pos": Vector3(from_pos.x, 0.9, from_pos.z), "order": order, "suggest": suggest, "text": text })
	if couriers.size() > COURIER_MAX:
		var c: Dictionary = couriers.pop_front()
		if not bool(c.get("suggest", false)):
			_apply_order(c["order"])

func _update_couriers(delta: float) -> void:
	var i := 0
	while i < couriers.size():
		var c: Dictionary = couriers[i]
		var sug := bool(c.get("suggest", false))
		# a despatch from the commander rides to YOU; your own orders ride to the battalion
		var dest: Vector3 = (off_pos if sug else player.pos) + Vector3(0, 0.0, 0)
		var from_p: Vector3 = c["pos"]
		var p: Vector3 = from_p.move_toward(dest, COURIER_SPEED * delta)
		var hd := p - from_p
		c["pos"] = p
		if hd.length() > 0.001:
			c["dir"] = hd.normalized()
		if Vector2(p.x - dest.x, p.z - dest.z).length() < 3.0:
			if sug:
				_send_player_despatch(String(c.get("text", "")), c.get("order", {}))   # informs you
			else:
				_apply_order(c["order"])                                               # your own order
			couriers.remove_at(i)
		else:
			i += 1
	for j in range(COURIER_MAX):
		if j < couriers.size():
			var cp: Vector3 = couriers[j]["pos"]
			var hdir: Vector3 = couriers[j].get("dir", Vector3(0, 0, 1))
			var yaw := atan2(hdir.x, hdir.z)
			var hbasis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
			courier_horse_mm.set_instance_transform(j, Transform3D(hbasis, Vector3(cp.x, 0.95, cp.z)))
			courier_mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw), Vector3(cp.x, 1.65, cp.z)))
		else:
			courier_mm.set_instance_transform(j, _zero_xf())
			courier_horse_mm.set_instance_transform(j, _zero_xf())

func _apply_order(order: Dictionary) -> void:
	_apply_net_order(player, order)

# Your brigade commander sends you his orders. You are told what is wanted — it is on
# you to carry it out (or not). The despatch never executes anything for you.
func _maybe_order_player(br) -> void:
	if player == null or player.spent or _player_order_cd > 0.0 or not _battle_begun:
		return
	# the order reflects the army's MISSION for this brigade (its attitude) at a LOCATION
	var attitude := ""
	match br.mission:
		"attack":  attitude = "Press the attack"
		"flank":   attitude = "Turn the enemy flank"
		"fix":     attitude = "Hold him with your fire"
		"refuse":  attitude = "Refuse the flank"
		"reserve": attitude = "Stand in reserve"
		_:         attitude = "Hold at all costs"
	# a broken or withdrawing brigade overrides the standing mission
	if br.posture == "withdraw":
		attitude = "Fall back in order"
	elif br.posture == "assault":
		attitude = "Charge home!"
	if attitude == "":
		return
	var loc := "the centre"
	if br.support_t > 0.0 and br.support_pos != Vector3.ZERO:
		var bf := Vector3(sin(br.facing), 0, cos(br.facing))
		var rgt := Vector3(bf.z, 0, -bf.x)
		var side: float = (br.support_pos - _brigade_center(br)).dot(rgt)
		loc = "the right flank" if side > 25.0 else ("the left flank" if side < -25.0 else "the centre")
	var key := attitude + "|" + loc
	if key == _player_order_last:
		return
	_player_order_cd = 14.0
	_player_order_last = key
	_send_courier_to_player(br.commander_pos, "[color=#ffd773]Brigade orders:[/color] %s at %s of the brigade." % [attitude, loc], {}, true)

func _send_player_despatch(text: String, order: Dictionary) -> void:
	_msg_text = text
	_msg_t = 13.0
	if not order.is_empty():
		_pending_player_order = order      # reports (empty order) don't wipe a standing order

# The hail action (E). Context-sensitive: near your brigade commander you get a
# briefing; otherwise the sergeant of the nearest friendly battalion reports.
func _talk() -> void:
	if player == null:
		return
	var unit := _nearest_friendly_batt(TALK_RANGE)          # measured from YOU, not your unit
	var udist: float = off_pos.distance_to(unit.pos) if unit != null else 1.0e9
	# the general only when you've ridden right up to him AND he's nearer than any sergeant
	var br = player.brigade
	if br != null and not br.commander_down:
		var cdist := off_pos.distance_to(br.commander_pos)
		if cdist < 16.0 and cdist <= udist:
			_brigade_briefing(br)
			return
	if unit != null:
		_unit_report(unit)
		return
	_send_player_despatch("[color=#9fb0c8]No one within hail.[/color]", {})

func _nearest_friendly_batt(rng: float) -> Batt:
	var best: Batt = null
	var bd := rng
	for b in battalions:
		if b.team != player.team or b.spent:
			continue
		var d := off_pos.distance_to(b.pos)
		if d < bd:
			bd = d
			best = b
	return best

# A sergeant's report: strength, nerve and ammunition — straight from the man.
func _unit_report(b: Batt) -> void:
	var men := b.figs.size()
	var rpm := int(round(b.ammo))
	var nerve := ""
	if b.state == "routing":
		nerve = "The men are breaking — I can't hold 'em!"
	elif b.morale >= 85.0:
		nerve = "The lads are in fine fettle."
	elif b.state == "shaken" or b.morale < 55.0:
		nerve = "They're shaken but holding."
	else:
		nerve = "Steady."
	var powder := ""
	if rpm <= 0:
		powder = "Cartridge boxes are empty — it's cold steel now!"
	elif rpm <= 6:
		powder = "Near out of powder, %d rounds a man." % rpm
	elif rpm <= 18:
		powder = "Powder's running low, about %d rounds a man." % rpm
	else:
		powder = "Plenty of powder, %d rounds a man." % rpm
	var who := "Sergeant" if b == player else ("Sergeant, " + _unit_name(b))
	var addr := ", sir." if b == player else ":"
	var standing := ""
	if b == player:
		var pcol := "9fe0a0" if prestige >= 0 else "ff9a8a"
		standing = "  [color=#%s](Prestige %+d)[/color]" % [pcol, prestige]
	_send_player_despatch("[color=#cfe3ff]%s:[/color] %d effectives%s %s %s%s" % [who, men, addr, nerve, powder, standing], {})

# A short report from your brigade commander on his intentions and the enemy.
func _brigade_briefing(br) -> void:
	var intent := ""
	match br.posture:
		"advance":  intent = "We advance on the enemy to our front."
		"assault":  intent = "Prepare to assault — we go in with the bayonet!"
		"engage":   intent = "Hold the line and gall them with fire."
		"hold":     intent = "Stand fast and hold this ground."
		"support":  intent = "We wheel to support the threatened flank."
		"withdraw": intent = "We fall back and re-form — steady, now."
		_:          intent = "Hold the line."
	var assess := ""
	if br.enemy != null:
		var em := _brigade_morale(br.enemy)
		if em < BRIG_ASSAULT_MORALE:
			assess = " The enemy yonder is wavering — be ready to go in."
		elif em > 80.0:
			assess = " They stand firm; do not waste your fire."
		else:
			assess = " Keep your men in hand."
	_send_player_despatch("[color=#ffd773]General:[/color] %s%s" % [intent, assess], {})

# THE SEAM (return path): write the day's outcome and every battalion's surviving
# state back into the setup, so the world that handed us this battle learns from it.
# Battles fought in battle survive into the next campaign turn — losses are forever,
# and a unit that bled hard fights the next day shaken and under strength.
func _write_result(pt: int, et: int, won: bool, men_now: Array) -> void:
	if _setup == null:
		return
	var survivors: Array = []
	for b in battalions:
		if b.parent != null:
			continue                   # detachments fold back into their parent's count
		var rec := {
			"idx": b.idx, "men": b.figs.size(), "ammo": b.ammo,
			"morale": b.morale, "state": b.state, "spent": b.spent }
		survivors.append(rec)
	_setup.result = {
		"winner": et if won else pt,
		"survivors": survivors,
		"losses": [_start_strength[0] - men_now[0], _start_strength[1] - men_now[1]],
		"prestige": prestige }

func _unit_name(b: Batt) -> String:
	if b.rname != "":
		return b.rname                 # the name the world gave this regiment (seam)
	var nseq := (b.idx % BATT_PER_TEAM) + 1
	return "%d%s of Foot" % [nseq, _ord(nseq)]

func _ord(n: int) -> String:
	if n % 100 in [11, 12, 13]:
		return "th"
	match n % 10:
		1: return "st"
		2: return "nd"
		3: return "rd"
	return "th"

# ------------------------------------------------------------------ multiplayer

func _batt_by_idx(slot: int) -> Batt:
	if slot >= 0 and slot < battalions.size():
		return battalions[slot]
	return null

func _state_code(s: String) -> int:
	match s:
		"shaken": return 1
		"routing": return 2
	return 0

func _state_name(c: int) -> String:
	match c:
		1: return "shaken"
		2: return "routing"
	return "steady"

# HOST -> clients: a compact snapshot of every battalion, NET_HZ times a second.
func _net_broadcast(delta: float) -> void:
	if GameConfig.mode != "host":
		return                                   # single-player: nobody to tell
	_net_cd -= delta
	if _net_cd > 0.0:
		return
	_net_cd = 1.0 / NET_HZ
	var data: Array = []
	for b in battalions:
		var fm := 2 if b.rolling else (1 if b.volley_fire else 0)
		data.append([
			b.pos.x, b.pos.z, b.facing, b.figs.size(), int(b.morale),
			_state_code(b.state), 1 if b.formation == "line" else 0,
			b.charging, b.melee_foe != null, b.flinch,
			b.off_pos.x, b.off_pos.z, b.off_facing, b.human,
			b.has_target, fm,
		])
	rpc("_apply_state", data)
	if not _fx.is_empty():
		rpc("_apply_fx", _fx.duplicate())
		_fx.clear()

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_state(data: Array) -> void:
	if not _got_state:
		_got_state = true
		print("[NET] client received first state (%d battalions)" % data.size())
	for i in range(mini(data.size(), battalions.size())):
		var e: Array = data[i]
		var b: Batt = battalions[i]
		b.pos = Vector3(e[0], 0.0, e[1])
		b.facing = e[2]
		b.morale = float(e[4])
		b.state = _state_name(int(e[5]))
		var form := "line" if int(e[6]) == 1 else "column"
		if b.formation != form:
			b.formation = form
			_reslot(b)
		b.charging = bool(e[7])
		b.melee_vis = bool(e[8])
		b.flinch = float(e[9])
		b.off_pos = Vector3(e[10], 0.0, e[11])
		b.off_facing = e[12]
		b.human = bool(e[13])
		b.has_target = bool(e[14])
		b.fx_firemode = int(e[15])
		_net_set_strength(b, int(e[3]))

# client: grow/trim a battalion's figures to match the host's reported strength,
# dropping bodies where men fall so the field still fills with casualties.
func _net_set_strength(b: Batt, target: int) -> void:
	if target > b.figs.size():
		_fill_figs(b)                            # reinforced on the host — rebuild
	while b.figs.size() > target and not b.figs.is_empty():
		var idx := randi() % b.figs.size()
		var w: Vector3 = b.figs[idx]["wpos"]
		_drop_dead(w, b.team, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), b.visible)
		b.figs.remove_at(idx)

# client -> host: my officer's position + any order I just gave.
func _net_send_input(delta: float) -> void:
	_net_cd -= delta
	if _net_cd > 0.0 and _pending_net_order.is_empty():
		return                                   # send at NET_HZ, but flush orders at once
	_net_cd = 1.0 / NET_HZ
	Net.send_input(off_pos, off_vis, _pending_net_order)
	_pending_net_order = {}

# host: a client sent its officer + order; apply to that client's battalion.
func net_apply_input(slot: int, c_off_pos: Vector3, c_off_facing: float, order: Dictionary) -> void:
	var b := _batt_by_idx(slot)
	if b == null:
		return
	b.off_pos = c_off_pos
	b.off_facing = c_off_facing
	if not order.is_empty():
		_apply_net_order(b, order)

# HOST -> clients: discrete effects (volleys, melee clashes) the client reproduces.
@rpc("authority", "call_remote", "unreliable")
func _apply_fx(events: Array) -> void:
	if not _got_fx:
		_got_fx = true
		print("[NET] client received first fx batch (%d events)" % events.size())
	for e in events:
		match int(e[0]):
			FX_VOLLEY:
				var b := _batt_by_idx(int(e[1]))
				if b != null and b.visible:
					_client_volley(b)
			FX_MELEE:
				_client_melee(Vector3(e[1], 1.0, e[2]))

func _client_volley(b: Batt) -> void:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var maxy := -1e9
	for f0 in b.figs:
		maxy = maxf(maxy, (f0["slot"] as Vector2).y)
	var fire_band := maxy - SP * 1.6
	var pts: Array = []
	for f in b.figs:
		if (f["slot"] as Vector2).y >= fire_band:
			var w: Vector3 = f["wpos"]
			var mp := w + Vector3(0, 1.35, 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip
			_emit_flash(mp)
			_emit_smoke(mp, fwd)
			_emit_smoke(mp, fwd)
			_emit_muzzle_bloom(mp, fwd)
			pts.append(mp)
	if pts.is_empty():
		return
	var sources := clampi(pts.size() / 16, 3, 12)
	for k in range(sources):
		_play_volley(pts[int((float(k) + 0.5) / float(sources) * pts.size())])
	_volley_cinematic(b, pts)
	# the men who fired now lower their muskets and start reloading
	for f in b.figs:
		if (f["slot"] as Vector2).y >= fire_band:
			f["reload"] = RELOAD_TIME * randf_range(0.78, 1.3)

func _client_melee(pos: Vector3) -> void:
	_play_melee(pos)
	var prox := clampf(1.0 - cam.position.distance_to(pos) / 120.0, 0.0, 1.0)
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.5, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * 0.12, 0.3)

# Client runs the COSMETIC reload cycle per front-rank soldier (no combat). This
# drives both the fire-at-will crackle AND the musket-aiming pose: as each man
# finishes loading he raises his musket; on "fire at will" he then shoots and
# reloads, while under "volley hold"/"by company" he stands aimed awaiting the word.
func _client_firing_fx(b: Batt, delta: float) -> void:
	if not b.visible or not b.has_target:
		return
	if b.state == "routing" or b.charging or b.melee_vis or b.figs.is_empty():
		return
	var atwill := b.fx_firemode == 0
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var maxy := -1e9
	for f0 in b.figs:
		maxy = maxf(maxy, (f0["slot"] as Vector2).y)
	var fire_band := maxy - SP * 1.6
	for f in b.figs:
		if (f["slot"] as Vector2).y < fire_band:
			continue                     # rear ranks don't aim/fire
		var r := float(f["reload"]) - delta
		if r > 0.0:
			f["reload"] = r              # still loading (musket shouldered)
			continue
		# loaded — musket levelled (the render reads reload <= AIM_LEAD)
		if atwill:
			var w: Vector3 = f["wpos"]
			var mp := w + Vector3(0, 1.35, 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip
			_emit_flash(mp)
			_emit_smoke(mp, fwd)
			_emit_muzzle_bloom(mp, fwd)
			_play_shot(mp)
			f["reload"] = RELOAD_TIME * randf_range(0.78, 1.3)
		else:
			f["reload"] = 0.0            # hold aimed for the volley command

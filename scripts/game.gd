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
const MILITIA_START_MEN := 60     # the founded militia steps off small, and grows by recruiting
const MILITIA_MAX_MEN := 900      # a recruited militia caps out around one full battalion's strength
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
const MARCH_MUL := 1.6           # a narrow road/march column covers ground far faster
const MARCH_DIST := 360.0        # beyond this from its post a battalion travels in march column
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
const DECISIVE_RANGE := 46.0      # a steady attacking line presses to THIS (point-blank) to decide it
const HIT_POINT_BLANK := 0.24     # fraction of muskets that go off effectively at the muzzle
const HIT_FALLOFF := 1.0          # effectiveness ~ (1 - d/range)^this (effective ~55 yds)
const ENFILADE_BONUS := 2.6       # fire raking down a line (into its flank) is murderous
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
const ROUT_THRESHOLD := 30.0      # nerve below this and the unit gives way and runs
const SHAKEN_THRESHOLD := 55.0
const MORALE_PER_CASUALTY := 0.7
# --- two-stat morale: NERVE (recovers) and COHESION (the lasting order/will, only spent) ---
# Nerve is the moment's courage; it dips under fire and returns when the fire slackens or
# an officer rallies the men. Cohesion is the unit's structure and will — it is worn away
# by casualties and, above all, by the act of running, and it NEVER comes back. When it is
# gone the unit is BROKEN: it streams off the field for good and will not rally again. This
# is what stops units yo-yoing in and out of the fight — every rout costs them permanently.
const COHESION_BREAK := 35.0      # cohesion below this: the unit breaks for good and quits the field
const COH_PER_CASUALTY := 0.14    # lasting order worn away per man who falls
const COH_ROUT_RATE := 3.2        # order bleeds fast while the men are actually running
const COH_COMMAND_HIT := 5.0      # a lasting blow when the colours or the officer go down
const ROUT_RALLY_NERVE := 50.0    # a running unit must get its nerve back to here to halt
const RALLY_COH_MARGIN := 6.0     # ...and have this much order left, or it cannot re-form
const MAX_ROUT_TIME := 18.0       # run this long without rallying and the rout is permanent
# --- fatigue (stamina), encampment rest, drill and blooding ---
const FATIGUE_MARCH := 2.0        # weariness/sec on the march (before stamina)
const FATIGUE_CHARGE := 5.5       # the pas de charge tells fast
const FATIGUE_MELEE := 6.5        # the press is exhausting
const FATIGUE_FIRE := 0.9         # standing under arms, loading and firing
const REST_RATE := 1.7            # weariness shed/sec when standing easy out of danger
const CAMP_REST_RATE := 7.0       # ...and far faster once properly encamped
const TRAIN_RATE := 0.7           # skill points/sec gained drilling a chosen skill in camp
const PRESTIGE_TRAIN_RATE := 0.12 # prestige/sec earned by an independent battalion drilling in camp
const PRESTIGE_PATROL_RATE := 0.015  # prestige per yard earned patrolling the country, clear of the enemy
const CAMP_SAFE_RANGE := 240.0    # no enemy may stand within this to make camp
const XP_PER_BLOOD := 45.0        # enemies felled before the men's fighting skills harden a notch
# fire discipline: a massed volley SHOCKS far beyond its casualties; independent
# fire is quicker but barely dents morale (men just trickle down).
const VOLLEY_SHOCK := 0.045       # morale shock per musket in a simultaneous volley
const VOLLEY_CASUALTY_MULT := 1.3 # massed-volley casualties also bite morale harder
const INDEP_MULT := 0.4           # independent fire: casualties, little moral effect
const INDEP_RELOAD_MUL := 1.6     # firing at will, wreathed in smoke with fouling barrels, the
								  # cadence slackens — a slower, ragged fire than a disciplined volley
# the held first volley: muskets levelled, loaded, waiting — released by the officer
# at point-blank, it is the deadliest thing on the field
const HELD_VOLLEY_RANGE := 55.0   # paces close enough for the murderous close volley
const HELD_VOLLEY_HIT := 1.55     # the fresh, levelled volley strikes far harder
const HELD_VOLLEY_SHOCK := 2.3    # and shatters nerve far beyond the bodies it drops
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
const MAX_PER_TEAM := BATT_PER_TEAM * MEN + MILITIA_MAX_MEN   # headroom for an independent militia on top of the standing OOB
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
const DUST_RANGE := 260.0         # beyond this, marching/galloping dust isn't worth spawning

enum Order { IDLE, FOLLOW }

class Batt:
	var team: int
	var is_player: bool = false
	var independent: bool = false   # founded militia: never joins the brigade/division/corps OOB
	var pos: Vector3
	var facing: float = 0.0
	var formation: String = "line"
	var figs: Array = []           # { slot: Vector2, wpos: Vector3, ph: float, spd: float }
	var order: int = Order.IDLE
	# --- SKILLS (0..100): every battalion carries a profile the sim reads directly, so a
	# crack regiment loads faster, shoots straighter, and holds where conscripts crack ---
	var skill: Dictionary = { "reload": 50.0, "aim": 50.0, "melee": 50.0, "discipline": 50.0, "stamina": 50.0 }
	var quality: String = "regular"   # green | regular | seasoned | veteran | elite (the readout word)
	var fatigue: float = 0.0       # 0 fresh .. 100 spent — drains marching/fighting, restored in camp
	var xp: float = 0.0            # blooding: combat hones the fighting skills over time
	# --- the MANAGEMENT roster (the player's battalion only): named men under your hand ---
	var roster: Array = []         # [{ name, rank, coy, reload..stamina, xp, kills, alive }]
	var encamped: bool = false     # resting out of danger: fatigue & nerve recover fast, drill progresses
	var train_skill: String = ""   # the skill the battalion is drilling while encamped ("" = none)
	var _fat_pos: Vector3          # last position, to measure marching for fatigue (own tracker)
	var morale: float = 100.0      # NERVE: the moment's courage — dips under fire, recovers
	var cohesion: float = 100.0    # the lasting order/will — spent by casualties & routing, never restored
	var state: String = "steady"   # steady | shaken | routing | broken
	var broken: bool = false       # TERMINAL: routed past recall — runs from the field, never rallies
	var rout_t: float = 0.0        # how long it has been running (toward a permanent break)
	var _coh_figs: int = -1        # strength last frame, to charge casualties against cohesion
	var calm_t: float = 0.0        # seconds since last casualty taken
	var volley_fire: bool = false  # true = hold fire until the officer's command
	var auto_volley: bool = false  # volley fire: wait until all are loaded, then fire as one
	var volley_seq: float = 0.0    # the words of command run their course before the crash
	var fire_now: bool = false     # one-shot: the officer's "FIRE!" this frame
	var presenting: bool = false   # player order "Present!" — muskets up even with no target
	var present_t: float = 0.0     # seconds the present has been held (the arms tire, then lower)
	var fire_forward: bool = false # player order "Fire!" — discharge straight ahead, enemy or not
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
	var _far_fire_acc: float = 0.0 # fractional casualties from battalion-resolution (far) fire
	var _far_audio_cd: float = 0.0 # throttle on the distant-battle rumble this unit emits
	# SLEEP/WAKE: far from the eye a battalion ticks slowly (a sleeping unit on the wider
	# map); near it, every frame. This is what lets ONE scene hold a whole province of men.
	var _sleep_acc: float = 0.0    # elapsed time banked while asleep
	var _active: bool = true       # simulated this frame?
	var _tick_dt: float = 0.0      # the delta to integrate this tick (banked time when waking)
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
	var start_men: int = 0         # strength the regiment marched on with (for the butcher's bill)
	var exp_mul: float = 1.0       # drill quality: veterans reload faster, recruits slower
	var march_player: AudioStreamPlayer3D   # the drummer's marching cadence while moving
	var _reload_snd_cd: float = 0.0   # throttle on the ramrod/reload sound near the camera
	var last_pos: Vector3          # to detect whether the battalion is moving this frame
	var fire_pos: Vector3          # position at the last firing tick (no fire on the move)
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
	# --- the standing ORDER this battalion holds, as words from its commander ---
	var obj_text: String = ""      # "Secure the ridge" — the order in plain words
	var obj_pos: Vector3           # the ground that order points at (marked in 3D for the player)
	var obj_kind: String = ""      # attack | hold | support | reserve | fix (drives the marker colour)

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
	var cmd_t: float = 0.0      # seconds this piece is under the PLAYER's hand (not the brigade's)
	var player: bool = false    # YOU serve this piece in person — you lay and fire it
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
	var seize: Vector3 = Vector3.INF   # a TOWN the army has directed this brigade to take (INF = none)

# A DIVISION: 3-5 brigades under a General. The army hands the division a directive
# (make the main effort / fix the enemy / stand in reserve) and an objective; the
# general then decides FOR HIMSELF which of his brigades lead, which support on the
# flanks, and which he keeps in his own hand — initiative one tier down from the army.
class Division:
	var team: int
	var idx: int = 0
	var corps: int = 0
	var line2: bool = false
	var directive: String = "hold"   # main | fix | reserve | hold — the army's order
	var objective: Vector3           # the ground the army points the division at
	var target = null                # the enemy Brigade the division is set against
	var general_pos: Vector3         # where the divisional general rides (behind his centre)
	var general_down: bool = false   # the general is a casualty — the division loses its grip
	var confuse_t: float = 0.0
	var decide_cd: float = 0.0       # the general re-reads his own front this often

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
	var target_town = null         # the STRATEGIC objective: a town the army is campaigning to take

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
	var player: bool = false       # YOU lead this squadron — it forms on you and charges at your word
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
var divisions: Array = []                 # the divisional tier between army and brigade
var _army_adv := [0.0, 0.0]               # each army's average advance (for dressing the line)
const DRESS_MARGIN := 70.0                # a brigade won't outrun the army by more than this
var brigade_couriers: Array = []          # aides riding support requests between brigades
var _shots: Array = []                    # flying roundshot: {active,pos,vel,from,dist,team}
var shot_mm: MultiMesh
var scar_mm: MultiMesh                     # furrows gouged in the ground by roundshot
var scar_idx := 0
var _gunner_mesh_cache: ArrayMesh          # shared detailed gun-crew figure (built once, lazily)
var _gunner_mats: Array = [null, null]     # per-team gunner ShaderMaterial, built once each
var _draft_horse_mesh_cache: ArrayMesh     # shared limber/caisson draft-horse mesh (built once)
var _draft_horse_mats: Array = []          # a couple of coat-colour variants, built once

# regimental dress: facing colours cycle per BRIGADE (a brigade was usually one
# regiment's battalions); coat variants pick from each team's small uniform table
const FACINGS_0 := [Color(0.95, 0.92, 0.85), Color(0.85, 0.15, 0.15), Color(0.92, 0.80, 0.15),
	Color(0.65, 0.10, 0.35), Color(0.95, 0.50, 0.12), Color(0.45, 0.70, 0.90)]
const FACINGS_1 := [Color(0.92, 0.85, 0.30), Color(0.20, 0.45, 0.20), Color(0.10, 0.15, 0.40),
	Color(0.95, 0.95, 0.92), Color(0.55, 0.12, 0.45), Color(0.05, 0.05, 0.06)]
# each army wears ONE distinctive coat — Blue vs Red — and only the facings (collar)
# change from regiment to regiment. (All three variants are the same colour now.)
const ARMY_BLUE := Color(0.07, 0.10, 0.30)   # navy blue
const ARMY_RED := Color(0.64, 0.15, 0.15)
const COATS_0 := [ARMY_BLUE, ARMY_BLUE, ARMY_BLUE]
const COATS_1 := [ARMY_RED, ARMY_RED, ARMY_RED]

var battalions: Array[Batt] = []
var player: Batt
# --- which arm you command in person (chosen at the step-off) ---
var player_arm: String = "infantry"       # infantry | artillery | cavalry
var player_guns: Array = []               # the battery you lay and fire yourself
var player_cav: Cav = null                # the squadron you lead at its head
var _arm_chosen: bool = false             # you have made your choice this battle
# --- sighting a gun: you put your eye to the barrel of one piece and lay it; the
# rest of the battery converges its fire on the same ground ---
var _gun_sight: bool = false              # you are looking down the barrel
var _sighted_gun: Gun = null              # the piece you have your eye to
var _sight_yaw: float = 0.0               # the line you are laying along (traverse)
var _sight_pitch: float = 0.0             # the depression of your gaze (sets the range)
var _aim_marker: MeshInstance3D = null    # a ring on the ground where the battery is laid
var _obj_label: Label3D = null            # the player battalion's order, painted in the world
var _obj_marker: MeshInstance3D = null    # a ring on the ground at the objective
var team_mm: Array = [null, null]
var _troop_glb := false            # the living troops render the Blender vertex-coloured LOD
# TROOP-TYPE MODELS FOR ALL INFANTRY: every man is drawn from his battalion's detailed Blender
# model — line (shako), light (green plume, wings) or grenadier (bearskin) — through one MultiMesh
# per (team, troop-type). `visible_instance_count` keeps the GPU to the men actually drawn, and the
# troop shader fades the small accents (plume/belts/brass) into the coat with distance so the far
# ranks read as clean blocks rather than speckle. Only the >340 m horizon impression stays box-man.
const NEAR_CAP := 64               # near_mm currently unused (all infantry go through team_mm); keep tiny
const TROOP_GLB := ["res://models/troop_line.glb", "res://models/troop_light.glb", "res://models/troop_grenadier.glb"]
const TROOP_PLUME := [Color(0.92, 0.90, 0.86), Color(0.12, 0.42, 0.16), Color(0.80, 0.14, 0.12)]  # white / green / red
var near_mm: Array = [[null, null, null], [null, null, null]]    # [team][troop_type] LOD bodies
var near_gun: Array = [[null, null, null], [null, null, null]]   # [team][troop_type] their muskets
var near_prev: Array = [[0, 0, 0], [0, 0, 0]]                    # tail-zero watermark, per team/type
var team_prev: Array[int] = [0, 0]
var musket_mm: Array = [null, null]      # a placeholder musket per rendered soldier
var musket_prev: Array[int] = [0, 0]
var bearer_mm: MultiMesh                  # colour-bearer per battalion
var nco_mm: MultiMesh                     # company sergeants + rear file-closers
var spontoon_mm: MultiMesh               # the half-pikes (spontoons) the NCOs carry
const MAX_NCO := 16   # sergeants + file-closers + the colour party's two guards
var _lights: Array = []                   # pooled muzzle-flash OmniLights
var _light_i := 0
var _shake := 0.0
# the player's personal objective in this battle (theme 6)
var _obj_text := ""
var _obj_target: Batt = null
var _obj_done := false
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
var gen_rider_mm: MultiMesh      # mounted divisional generals (the rider)
var gen_horse_mm: MultiMesh      # their chargers
var colonel_rider_mm: MultiMesh  # the mounted colonel commanding each battalion
var colonel_horse_mm: MultiMesh  # his horse
var dead_horse_mm: MultiMesh     # fallen horses (generals' chargers, troopers' mounts)
var dead_horse_idx := 0
const DEAD_HORSE_MAX := 420

# player officer (3rd person)
var officer: Node3D
var _horse_legs: Array = []       # the charger's four leg pivots, swung at the gait
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
var _autorun := false              # ride forward without holding W (R toggles; S cancels)
var _off_respawn := 0.0
# prestige — the player's renown as a commander: +1 for every enemy felled by men
# under your command (or your own hand), -1 for every man of yours lost. Later the
# currency for upgrades: items, skills, better officers.
var prestige := 0
var _prestige_acc := 0.0   # fractional prestige (e.g. from drilling), banked until it rounds to a point
var _player_figs_prev := -1        # last known strength, for counting losses centrally

# --- battle flow: deployment, army collapse, victory & the butcher's bill ---
const DEPLOY_TIME := 75.0          # quiet minutes to read the ground before the step-off
var _deploy_t := DEPLOY_TIME
var _battle_begun := false
var battle_over := false
var _night_end := false             # the battle was closed by nightfall (not a rout)
var _town_winner := -1              # >=0 if the day was decided by a clean sweep of the towns
const NIGHTFALL_HOUR := 20.0        # when dusk deepens to this hour, the day's fighting ends
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
# dev free-fly / RTS camera (F4): roam the whole province to watch the AI and the sea-fight
var _rts_cam := false
var _rts_focus := Vector3.ZERO
var _rts_dist := 320.0

var smoke_p: GPUParticles3D                # cannon smoke: jets hard, blooms, then drifts downwind
var musket_smoke_p: GPUParticles3D         # musket smoke: rolls forward, then drifts downwind, thinning
var _smoke_proc: ParticleProcessMaterial    # cannon smoke's process material (wind pushes its gravity)
var _musket_smoke_proc: ParticleProcessMaterial  # musket smoke's process material (same)
var flash_p: GPUParticles3D
var fire_p: GPUParticles3D
var blood_p: GPUParticles3D                # red spray when a man is hit
var dirt_p: GPUParticles3D                 # earth thrown up by a roundshot striking the ground
var dust_p: GPUParticles3D                 # the haze kicked up by marching feet and hooves
var _dust_proc: ParticleProcessMaterial     # dust's process material (wind pushes its gravity)
var wake_p: GPUParticles3D                 # the foam a ship's bow turns over under way
var splash_p: GPUParticles3D               # waterspouts where roundshot pitches into the sea
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
var snd_reload: AudioStream               # ramrod work — the firing line loading
var snd_ball_land: AudioStream            # a roundshot striking the ground
var snd_ball_over: AudioStream            # a roundshot screaming overhead the player
var snd_hooves: AudioStream               # the thunder of a charge (optional file)
var snd_cheer: AudioStream                # the charge goes in with a shout (optional)
var snd_v_ready: AudioStream              # officer: "Make ready!"  (optional)
var snd_v_present: AudioStream            # officer: "Present!"
var snd_v_fire: AudioStream               # officer: "FIRE!"
var snd_v_charge: AudioStream             # officer: "Charge!"
var _audio_pool: Array = []
var _distant_pool: Array = []     # far-carrying, muffled players for distant battle rumble
var _distant_i := 0
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
var _task_cd := 9.0                           # throttle on the army commander's despatches to you
var _last_task := ""                          # the last task sent (so it isn't repeated)
var _last_target_town := ""                   # the army's last strategic town objective (dedup)
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
		[KEY_3, "3", "Hold fire  —  then press F to GIVE FIRE", "hold_fire"],
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
var _weather_timer := 200.0               # seconds until the weather shifts on its own
var _night := 0.0                         # 0 broad day .. 1 deep night (muzzle flashes glow)
var _cloud := 0.0                         # smoothed cloud cover 0..1
var _fogw := 0.0                          # smoothed extra fog 0..1
var _rainw := 0.0                         # smoothed rain intensity 0..1
var _wind := Vector3.ZERO                 # gentle wind (drifts smoke, stirs the colours)
var _wet := 0.0                           # how damp the powder is (misfires in rain)
var rain_p: GPUParticles3D
var _rain_proc: ParticleProcessMaterial   # rain's process material (wind lays the streaks over)
var _grad_skytop: Gradient
var _grad_skyhorizon: Gradient
var _grad_sun: Gradient
var _grad_fog: Gradient
const DAY_RATE := 24.0 / 3600.0           # a full day cycles in ~60 minutes (N to skip ahead)
const WEATHERS := ["clear", "overcast", "rain", "fog"]
# which way the weather plausibly turns next — a clear sky builds to overcast before it can
# rain, and rain clears back through overcast rather than snapping straight to blue sky
const WEATHER_NEXT := {
	"clear": ["overcast"],
	"overcast": ["clear", "clear", "rain", "rain", "fog"],
	"rain": ["overcast"],
	"fog": ["overcast", "clear"],
}
const WEATHER_CLOUD_RATE := 0.018         # clouds build/break over roughly a minute, not seconds
const WEATHER_FOG_RATE := 0.02
const WEATHER_RAIN_RATE := 0.06           # once the sky's heavy enough, rain can pick up quicker
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
# AI DEBUG OVERLAY (F3) — a window into what each commander has deduced, so the AI can
# be observed and tuned. Plus a headless AI-vs-AI batch mode (--ai-batch) for measurement.
var _aidbg_on := false
var aidbg_panel: Control
var aidbg_label: RichTextLabel
var _ai_batch := false             # pure AI-vs-AI: no human, auto step-off, quit on result
# the field map: a top-down plot of the whole action, toggled with M
var _map_on := false
var map_panel: Control
var _map_dots: Array = []          # pooled unit markers, repositioned each frame
var _map_towns: Array = []         # pooled site markers (square/diamond + name), repositioned each frame
var _map_roads: Array = []         # pooled Line2D road segments
var _map_sea: ColorRect            # the sea off the eastern shore on the province map
var _map_river: Line2D             # the river drawn on the province map
var _map_bridges: Array = []       # pooled bridge markers on the province map
var wind_hud: RichTextLabel        # dev readout: wind, sea state, sky, time (F3 / F4)
var compass_panel: Control         # the bearing strip at the foot of the screen
var _compass_ticks: Array = []
var _compass_labels: Array = []
var _compass_center: ColorRect
var _compass_read: Label
var map_legend: RichTextLabel
# the camp & command screen — a Football-Manager-style overview of your battalion (C)
var _camp_on := false
var _camp_town := ""               # the town whose camp is presently open (for the header)
var _at_town_prev := ""            # last town the rider was standing in (edge-detect entry)
var camp_panel: Control
var camp_label: RichTextLabel
var _train_idx := -1               # which skill is being drilled (-1 = none), index into SKILL_KEYS
# the interactive, mouse-driven company roster (a real GUI, opened from the camp screen)
var roster_panel: Control
var _roster_coy := 0               # which company tab is open
var _roster_man = null             # the selected soldier (a roster dict) or null
var _roster_tabs: VBoxContainer    # the company buttons (grouping)
var _roster_list: VBoxContainer    # the soldier rows for the open company
var _roster_detail: VBoxContainer  # the selected soldier's card + action buttons
var _camp_btn_rest: Button
var _camp_btn_drill: Button
var _camp_btn_recruit: Button   # an independent militia's hand: take on men at a friendly town
var _camp_btn_hire: Button      # commission a Lieutenant over a company that lacks one
var _camp_btn_equip: Button     # spend prestige on better muskets and kit
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
	var batch := "--ai-batch" in OS.get_cmdline_user_args()
	# THE SEAM: consume the BattleSetup (or build a field). The AI-tuning batch uses a small,
	# fast skirmish so hundreds of matches resolve quickly — not the 70k set-piece.
	if GameConfig.setup == null:
		GameConfig.setup = BattleSetup.skirmish(10, []) if batch else BattleSetup.default_field()
	_setup = GameConfig.setup
	_inflated = _setup.units.size() > 0    # a campaign engagement, not the 70k set-piece
	_weather = _setup.weather
	_time_of_day = _setup.time_of_day
	_build_world()
	if not hosted:
		_build_scenery()            # host uses the province's own woods & fields
	_build_ocean()                  # the sea anchors the eastern flank
	if not hosted:
		_build_clouds()             # a drifting cloud sheet overhead, driven by the wind
	_spawn_ships()                  # shipping and a running sea-fight, out beyond the shore
	_build_field_settlements()      # the province's towns, spread across the wider map
	_build_province_sites()         # forts & depots: a garrison home per brigade, plus roads
	_build_homesteads()             # farmsteads, fields, fences and stock across the country
	_build_farmland()               # crop fields in varied colours, hedgerows along roads & fields
	_build_officer()
	_build_wounded_layer()
	_spawn_armies()
	_build_guns()
	_spawn_cavalry()
	_assign_brigades()
	_set_objective()                  # your personal charge for the day
	# AI-vs-AI batch (--ai-batch): no human commander, step off at once, run flat out and
	# quit with the [RESULT] line so a script can run hundreds of matches and score the AI
	if batch:
		_ai_batch = true
		if player != null:
			player.human = false          # the player's battalion fights under the AI too
		Engine.time_scale = 12.0          # run the day fast
		_begin_battle()
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
	env.fog_density = 0.00012
	env.fog_sky_affect = 0.1                # keep the sky/horizon clean — no grey haze band
	env.fog_aerial_perspective = 1.0        # distant land takes the sky's tint, not a fog wall
	# SSAO — contact shadows that GROUND the ranks: dark in the creases between men,
	# under eaves and along walls. Screen-space, so the cost is fixed (not 70k-dependent).
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.5
	env.ssao_horizon = 0.07
	env.ssao_sharpness = 0.98
	env.ssao_light_affect = 0.15        # a touch of AO even in direct light, for solidity
	env.ssao_ao_channel_affect = 0.0
	# a gentle filmic grade so the field reads richer
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.10
	env.adjustment_saturation = 1.16
	we.environment = env
	if not hosted:                  # the province supplies sky, fog and grade
		add_child(we)
	_build_tod_palette()

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.25
	sun.light_specular = 0.6                       # a little glint on muskets, bayonets, water
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 340.0    # a touch more shadow reach over the field
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.06          # tight near split = crisp shadows around you
	sun.directional_shadow_split_2 = 0.18
	sun.directional_shadow_split_3 = 0.45
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04                          # tuned to the soft penumbra below (less acne)
	sun.shadow_normal_bias = 1.3
	sun.light_angular_distance = 0.75              # softer penumbra — a sunny-day look, not hard CG
	if not hosted:                  # the province supplies the sun
		add_child(sun)

	var ground := MeshInstance3D.new()
	# the LAND ends at the shoreline (the sea owns everything east); the surface ROLLS — a
	# displaced grid following _gh, so the province is gentle hills and dales, not a table
	ground.mesh = _build_ground_mesh()
	ground_mat = _make_ground_material()
	ground.material_override = ground_mat
	if not hosted:                  # the province supplies the ground
		add_child(ground)

	rain_p = _build_rain()

	# corpses/NCOs always use the procedural box-man; the LIVING troops use a Blender-built
	# vertex-coloured LOD if present (laid out to the same band layout so the GPU march/reload
	# animation still drives it), giving the masses the modelled gear & colours.
	var soldier_mesh := _soldier_mesh()
	# THE MASSES STAY ON THE CLEAN BOX-MAN. A detailed per-man LOD drawn 70k strong aliases into
	# busy speckle ("spotty") no matter how it's coloured — the box-man reads clean BECAUSE it is
	# simple. Crucially, NO variety is lost: per-battalion dress (coat/belt/trouser/facing/hat
	# colour) AND headgear SHAPE (shako/round hat/bicorne) are morphed in `_soldier_shader` from
	# the per-instance packing, not the mesh, so battalions still read distinct in line. The
	# Blender models are reserved for the figures you see up close (the player's officer; nearby
	# NCOs/colour party are candidates). To re-enable the LOD experiment: load soldier_troop.glb.
	# ALL infantry draw the detailed PROCEDURAL soldier (no Blender) via the team MultiMesh +
	# `_soldier_shader`, which colours every part by vertex position and morphs the headgear
	# (shako / round hat / bicorne) per battalion from the packed dress.
	var troop_mesh: Mesh = null
	_troop_glb = troop_mesh != null
	for team in [0, 1]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true         # per-instance: r=wear  g=gait phase  b=march amount
		mm.use_colors = true              # per-instance: rgb=facings, a=packed dress (set BEFORE count)
		mm.instance_count = MAX_PER_TEAM
		if _troop_glb:
			mm.mesh = troop_mesh          # the Blender model, recoloured per region by the dress
			mmi.material_override = _soldier_glb_shader(team)
		else:
			mm.mesh = soldier_mesh
			mmi.material_override = _soldier_shader(team)
		mmi.multimesh = mm
		add_child(mmi)
		team_mm[team] = mm
		var def := Color(COATS_0[0], 0.0) if team == 0 else Color(COATS_1[0], 0.0)
		for i in range(MAX_PER_TEAM):
			mm.set_instance_transform(i, _zero_xf())
			mm.set_instance_color(i, def)
			mm.set_instance_custom_data(i, Color(1, 1, 1, 1))

	# a placeholder musket (thin box) per soldier — shouldered, levelled to fire
	for team in [0, 1]:
		var gmi := MultiMeshInstance3D.new()
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		gmm.mesh = _musket_mesh()
		gmm.instance_count = MAX_PER_TEAM
		gmi.multimesh = gmm
		gmi.material_override = _musket_shader()
		add_child(gmi)
		musket_mm[team] = gmm
		for i in range(MAX_PER_TEAM):
			gmm.set_instance_transform(i, _zero_xf())

	# (near_mm is retired now that ALL infantry use the procedural soldier through team_mm;
	# these tiny buffers stay only so the struct/draw code keeps working — no Blender models.)
	var troop_lod := soldier_mesh
	var lod_musket := _musket_mesh()
	for team in [0, 1]:
		for tt in range(3):
			var nmi := MultiMeshInstance3D.new()
			var nm := MultiMesh.new()
			nm.transform_format = MultiMesh.TRANSFORM_3D
			nm.use_custom_data = true
			nm.use_colors = true
			nm.instance_count = NEAR_CAP
			nm.mesh = troop_lod
			nmi.multimesh = nm
			nmi.material_override = _soldier_glb_shader(team)
			nmi.custom_aabb = AABB(Vector3(-4000, -300, -4000), Vector3(8000, 600, 8000))   # never wrongly culled
			add_child(nmi)
			near_mm[team][tt] = nm
			var ngi := MultiMeshInstance3D.new()
			var ng := MultiMesh.new()
			ng.transform_format = MultiMesh.TRANSFORM_3D
			ng.mesh = lod_musket
			ng.instance_count = NEAR_CAP
			ngi.multimesh = ng
			ngi.material_override = _musket_shader()
			ngi.custom_aabb = AABB(Vector3(-4000, -300, -4000), Vector3(8000, 600, 8000))
			add_child(ngi)
			near_gun[team][tt] = ng
			nm.visible_instance_count = 0    # nothing drawn until _render fills it each frame
			ng.visible_instance_count = 0

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
		cmm.mesh = soldier_mesh           # blocky fallen men, banded just like the living
		cmm.use_colors = true
		cmm.use_custom_data = true
		cmm.instance_count = CORPSE_MAX
		cmi.multimesh = cmm
		cmi.material_override = _soldier_shader(team)   # shako / coat / facings / trousers, static
		add_child(cmi)
		corpse_mm[team] = cmm
		var cfac: Color = FACINGS_0[0] if team == 0 else FACINGS_1[0]
		var ccol := Color(cfac.r, cfac.g, cfac.b, 0.0)
		for i in range(CORPSE_MAX):
			cmm.set_instance_transform(i, _zero_xf())
			cmm.set_instance_color(i, ccol)                                  # banded coat/facings
			cmm.set_instance_custom_data(i, Color(randf_range(0.7, 1.0), 0.0, 0.0, 0.0))   # wear; no march/arm

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
		rmi.mesh = soldier_mesh           # a blocky man tumbling, matching the line
		var rmat := StandardMaterial3D.new()
		rmi.material_override = rmat
		rb.add_child(rmi)
		rb.position = Vector3(0, -200, 0)
		add_child(rb)
		_ragdolls.append({ "body": rb, "mat": rmat, "active": false, "t": 0.0, "team": 0 })

	var officer_mesh := _officer_mesh()   # blocky body + bicorne; coat colour set per instance
	var omi := MultiMeshInstance3D.new()
	officer_mm = MultiMesh.new()
	officer_mm.transform_format = MultiMesh.TRANSFORM_3D
	officer_mm.mesh = officer_mesh
	officer_mm.use_colors = true
	officer_mm.use_custom_data = true
	officer_mm.instance_count = BATT_PER_TEAM * 2
	omi.multimesh = officer_mm
	omi.material_override = _officer_shader()
	add_child(omi)
	for i in range(BATT_PER_TEAM * 2):
		officer_mm.set_instance_transform(i, _zero_xf())

	# brigade commanders — mounted generals riding behind the centre of their brigade,
	# on the shared detailed mount/rider meshes. A dark horse, shabraqued in the army's
	# colour, under a rider in solid gold with dark trim — stands out as the brigadier.
	var mount_mesh := _mount_horse_mesh()
	var rider_mesh := _mount_rider_mesh()
	var bn := BRIGADES_PER_TEAM * 2
	var hmi := MultiMeshInstance3D.new()
	cmd_horse_mm = MultiMesh.new()
	cmd_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	cmd_horse_mm.use_colors = true
	cmd_horse_mm.mesh = mount_mesh
	cmd_horse_mm.instance_count = bn
	hmi.multimesh = cmd_horse_mm
	hmi.material_override = _mount_horse_shader()
	add_child(hmi)
	var rmi := MultiMeshInstance3D.new()
	cmd_rider_mm = MultiMesh.new()
	cmd_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	cmd_rider_mm.use_colors = true
	cmd_rider_mm.mesh = rider_mesh
	cmd_rider_mm.instance_count = bn
	rmi.multimesh = cmd_rider_mm
	rmi.material_override = _mount_rider_shader(Color(0.10, 0.10, 0.13))   # dark trim on gold
	add_child(rmi)
	for i in range(bn):
		cmd_horse_mm.set_instance_transform(i, _zero_xf())
		cmd_rider_mm.set_instance_transform(i, _zero_xf())
		cmd_rider_mm.set_instance_color(i, Color(0.80, 0.65, 0.25))   # solid gold coat

	# divisional generals — one rank up from the brigadiers: a larger charger (scaled
	# up in the transform), a rider in white-and-silver, riding behind the division.
	var dn := CORPS_PER_TEAM * DIVISIONS_PER_CORPS * 2
	var ghmi := MultiMeshInstance3D.new()
	gen_horse_mm = MultiMesh.new()
	gen_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	gen_horse_mm.use_colors = true
	gen_horse_mm.mesh = mount_mesh
	gen_horse_mm.instance_count = dn
	ghmi.multimesh = gen_horse_mm
	ghmi.material_override = _mount_horse_shader()
	add_child(ghmi)
	var grmi := MultiMeshInstance3D.new()
	gen_rider_mm = MultiMesh.new()
	gen_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	gen_rider_mm.use_colors = true
	gen_rider_mm.mesh = rider_mesh
	gen_rider_mm.instance_count = dn
	grmi.multimesh = gen_rider_mm
	grmi.material_override = _mount_rider_shader(Color(0.75, 0.75, 0.78))   # silver trim
	add_child(grmi)
	for i in range(dn):
		gen_horse_mm.set_instance_transform(i, _zero_xf())
		gen_rider_mm.set_instance_transform(i, _zero_xf())
		gen_rider_mm.set_instance_color(i, Color(0.92, 0.92, 0.95))   # white-and-silver coat

	# battalion colonels — one mounted field officer riding behind every battalion's
	# colours, coated in his army's colour with gold lace, so blue and red are told
	# apart from afar (the player rides his own, much more detailed, hero in his place).
	var coln := BATT_PER_TEAM * 2
	var colhmi := MultiMeshInstance3D.new()
	colonel_horse_mm = MultiMesh.new()
	colonel_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	colonel_horse_mm.use_colors = true
	colonel_horse_mm.mesh = mount_mesh
	colonel_horse_mm.instance_count = coln
	colhmi.multimesh = colonel_horse_mm
	colhmi.material_override = _mount_horse_shader()
	add_child(colhmi)
	var colrmi := MultiMeshInstance3D.new()
	colonel_rider_mm = MultiMesh.new()
	colonel_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	colonel_rider_mm.use_colors = true
	colonel_rider_mm.mesh = rider_mesh
	colonel_rider_mm.instance_count = coln
	colrmi.multimesh = colonel_rider_mm
	colrmi.material_override = _mount_rider_shader(Color(0.83, 0.68, 0.21))   # gold lace
	add_child(colrmi)
	for i in range(coln):
		colonel_horse_mm.set_instance_transform(i, _zero_xf())
		colonel_rider_mm.set_instance_transform(i, _zero_xf())

	# colour-bearers (one per battalion) — the same detailed officer figure as
	# officer_mm/nco_mm, shouldering the colours instead of a musket
	var bmi := MultiMeshInstance3D.new()
	bearer_mm = MultiMesh.new()
	bearer_mm.transform_format = MultiMesh.TRANSFORM_3D
	bearer_mm.mesh = officer_mesh
	bearer_mm.use_colors = true
	bearer_mm.use_custom_data = true
	bearer_mm.instance_count = BATT_PER_TEAM * 2
	bmi.multimesh = bearer_mm
	bmi.material_override = _officer_shader()
	add_child(bmi)
	for i in range(BATT_PER_TEAM * 2):
		bearer_mm.set_instance_transform(i, _zero_xf())

	# NCOs / file-closers (grey, posted on the ends and rear)
	var nmi := MultiMeshInstance3D.new()
	nco_mm = MultiMesh.new()
	nco_mm.transform_format = MultiMesh.TRANSFORM_3D
	nco_mm.mesh = soldier_mesh          # sergeants & file-closers wear the shako, like the line
	nco_mm.use_colors = true
	nco_mm.use_custom_data = true
	nco_mm.instance_count = BATT_PER_TEAM * 2 * MAX_NCO
	nmi.multimesh = nco_mm
	nmi.material_override = _officer_shader()
	add_child(nmi)
	for i in range(BATT_PER_TEAM * 2 * MAX_NCO):
		nco_mm.set_instance_transform(i, _zero_xf())

	# the spontoons (half-pikes) the NCOs carry — one per NCO slot
	var spmi := MultiMeshInstance3D.new()
	spontoon_mm = MultiMesh.new()
	spontoon_mm.transform_format = MultiMesh.TRANSFORM_3D
	spontoon_mm.mesh = _spontoon_mesh()
	spontoon_mm.instance_count = BATT_PER_TEAM * 2 * MAX_NCO
	spmi.multimesh = spontoon_mm
	spmi.material_override = _spontoon_material()
	add_child(spmi)
	for i in range(BATT_PER_TEAM * 2 * MAX_NCO):
		spontoon_mm.set_instance_transform(i, _zero_xf())

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
	musket_smoke_p = _make_emitter(20.0, 140000, _smoke_material(), Vector2(2.0, 2.0), 5)
	_smoke_proc = smoke_p.process_material
	_musket_smoke_proc = musket_smoke_p.process_material
	flash_p = _make_emitter(0.16, 20000, _flash_material(), Vector2(1.0, 1.0), 1)
	fire_p = _make_emitter(0.4, 20000, _flash_material(), Vector2(0.8, 0.8), 2)
	blood_p = _make_emitter(0.85, 24000, _blood_material(), Vector2(0.5, 0.5), 4)
	dirt_p = _make_emitter(1.4, 24000, _smoke_material(), Vector2(1.3, 1.3), 6)
	dust_p = _make_emitter(7.0, 50000, _smoke_material(), Vector2(2.0, 2.0), 7)
	_dust_proc = dust_p.process_material
	wake_p = _make_emitter(2.6, 20000, _smoke_material(), Vector2(1.1, 1.1), 8)
	splash_p = _make_emitter(1.8, 12000, _smoke_material(), Vector2(1.4, 1.4), 9)
	add_child(smoke_p)
	add_child(musket_smoke_p)
	add_child(flash_p)
	add_child(fire_p)
	add_child(blood_p)
	add_child(dirt_p)
	add_child(dust_p)
	add_child(wake_p)
	add_child(splash_p)

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
	snd_reload = _load_first(["MusketReload1.wav", "MusketReload.wav", "MusketReload.mp3"])
	snd_ball_land = _load_first(["CannonballLanding.wav", "CannonballLanding.mp3"])
	snd_ball_over = _load_first(["CannonballOverhead.wav", "CannonballOverhead.mp3", "CannonballOverhear.wav"])
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
	# DISTANT BATTLE — a muffled rumble that carries clear across the map, so fighting you
	# cannot see is HEARD and ridden toward (the abstracted far battalions speak through it)
	for i in range(12):
		var dp := AudioStreamPlayer3D.new()
		dp.max_distance = 7000.0     # carries the length of the field
		dp.unit_size = 140.0
		dp.volume_db = 4.0
		dp.attenuation_filter_cutoff_hz = 1400.0   # low-pass with distance: a dull thud, not a crack
		dp.attenuation_filter_db = -26.0
		add_child(dp)
		_distant_pool.append(dp)

	# the battle builds its own camera even when hosted — as a child of this node it
	# rides in local space, and the node's world position drops it on the province
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 13000.0                 # the province is wide — see to the far towns (fog veils them)
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
	_build_map(cl)
	_build_camp(cl)
	_build_roster_ui(cl)
	_build_ai_debug(cl)
	_build_wind_hud(cl)
	_build_compass(cl)

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
	_bill_label.custom_minimum_size = Vector2(540, 0)
	_bill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bill_label.add_theme_font_size_override("normal_font_size", 16)
	_bill_label.add_theme_font_size_override("bold_font_size", 22)
	_bill_panel.add_child(_bill_label)
	_bill_panel.visible = false

# ---------------------------------------------------------------- sky, light, weather

# A blocky soldier: a head/shako block, a coat block, two leg blocks. One combined
# mesh (one draw call per army), instanced 70,000 times. Centred at the origin so it
# drops into the same per-man transform as the old capsule.
# Pack a battalion's dress into one byte stored in COLOR.a: coat + belt*3 + pants*9 + hat*36.
# AI battalions roll a random crossbelt / trouser / hat; the player's unit wears his militia.
func _dress_packed(coat: int, idx: int, is_player: bool) -> float:
	var belt: int
	var pants: int
	var hat: int
	if is_player and GameConfig.has_militia:
		hat = clampi(GameConfig.militia_hat, 0, 2)
		belt = clampi(GameConfig.militia_belt, 0, 2)
		pants = clampi(GameConfig.militia_pants, 0, 3)
	else:
		var h: int = ((idx + 1) * 2654435761) & 0x3fffffff
		belt = h % 3
		pants = (h / 3) % 4
		hat = (h / 12) % 3
	var packed := clampi(coat, 0, 2) + belt * 3 + pants * 9 + hat * 36
	return float(packed) / 255.0

# Pull the first mesh out of an imported .glb scene (so a Blender model can stand in for a
# procedural one). Returns null if the file isn't there, so callers fall back cleanly.
func _load_glb_mesh(path: String) -> Mesh:
	if not ResourceLoader.exists(path):
		return null
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var inst := ps.instantiate()
	var found: Mesh = null
	var stack: Array = [inst]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			found = (n as MeshInstance3D).mesh
			break
		for c in n.get_children():
			stack.append(c)
	inst.queue_free()
	return found

# A fully procedural line-infantryman — no Blender. Built to the same height bands the
# shader colours and animates by (game coords: +Z front, Y up). ~30 primitives, one mesh,
# instanced across the whole army; the shader paints each part by position.
func _soldier_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# --- legs: white overalls over dark gaiters, with shoes ---
	for sx in [-0.105, 0.105]:
		_add_box(st, Vector3(sx, -0.285, 0.0), Vector3(0.155, 0.46, 0.18))   # overalls (vy -0.52..-0.06)
		_add_box(st, Vector3(sx, -0.68, 0.0), Vector3(0.165, 0.32, 0.19))    # gaiter (vy -0.84..-0.52)
		_add_box(st, Vector3(sx, -0.86, 0.05), Vector3(0.165, 0.10, 0.24))   # shoe
	# --- coat: body, short tails behind, a stand collar and a faced plastron down the breast ---
	_add_box(st, Vector3(0, 0.175, 0.0), Vector3(0.40, 0.49, 0.24))          # coat body (vy -0.07..0.42)
	_add_box(st, Vector3(0, -0.04, -0.085), Vector3(0.36, 0.22, 0.13))       # coat tails (back)
	_add_box(st, Vector3(0, 0.435, 0.0), Vector3(0.345, 0.075, 0.245))       # collar (facing)
	_add_box(st, Vector3(0, 0.20, 0.125), Vector3(0.22, 0.40, 0.035))        # plastron / lapels (front, facing)
	# --- arms: sleeves with faced cuffs and bare hands ---
	for sx in [-0.265, 0.265]:
		_add_box(st, Vector3(sx, 0.18, 0.0), Vector3(0.115, 0.46, 0.13))     # sleeve (|x|>0.215 -> swings)
		_add_box(st, Vector3(sx, -0.03, 0.0), Vector3(0.125, 0.075, 0.145))  # cuff (facing)
		_add_box(st, Vector3(sx, -0.13, -0.01), Vector3(0.10, 0.10, 0.11))   # hand (skin)
	# --- knapsack & rolled blanket slung on the back ---
	_add_box(st, Vector3(0, 0.15, -0.185), Vector3(0.30, 0.30, 0.14))        # pack (leather)
	_add_box(st, Vector3(0, 0.31, -0.19), Vector3(0.32, 0.07, 0.12))         # rolled blanket on top
	# --- head ---
	var head := SphereMesh.new()
	head.radius = 0.112; head.height = 0.224; head.radial_segments = 8; head.rings = 4
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.55, 0)))       # skin (vy 0.44..0.66)
	# --- shako: tapered cap with a brass band & front peak, surmounted by a plume. The shader
	# MORPHS this block (vy>0.655) per battalion into a round hat or a bicorne, from COLOR.a. ---
	_add_cyl(st, Vector3(0, 0.78, 0.0), 0.125, 0.150, 0.225, 12)             # shako body (vy 0.67..0.89)
	_add_box(st, Vector3(0, 0.672, 0.0), Vector3(0.27, 0.05, 0.27))          # brass band (low)
	_add_box(st, Vector3(0, 0.685, 0.16), Vector3(0.22, 0.035, 0.10))        # peak (front)
	_add_cyl(st, Vector3(0, 1.02, -0.02), 0.035, 0.018, 0.22, 8)             # plume (vy > 0.90)
	return st.commit()

func _add_box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var b := BoxMesh.new()
	b.size = s
	st.append_from(b, 0, Transform3D(Basis(), c))

# a tapered cylinder (shako body, plume) — height runs along +Y, centred on c
func _add_cyl(st: SurfaceTool, c: Vector3, r_bottom: float, r_top: float, h: float, sides: int) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 0
	st.append_from(cm, 0, Transform3D(Basis(), c))

# A musket: walnut stock, iron barrel, a steel bayonet at the muzzle. One combined
# mesh along local Z; a shader paints wood/iron/steel by position.
func _musket_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0, -0.40), Vector3(0.055, 0.105, 0.52))    # stock / butt
	_add_box(st, Vector3(0, 0.01, 0.12), Vector3(0.032, 0.042, 0.96))  # barrel
	_add_box(st, Vector3(0, 0.01, 0.74), Vector3(0.014, 0.014, 0.30))  # bayonet
	return st.commit()

func _musket_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying float vz;
void vertex() { vz = VERTEX.z; }
void fragment() {
	vec3 col = vec3(0.12, 0.12, 0.14);                 // iron barrel
	float metal = 0.6; float rough = 0.35;
	if (vz < -0.15) { col = vec3(0.30, 0.18, 0.09); metal = 0.0; rough = 0.8; }   // walnut stock
	else if (vz > 0.60) { col = vec3(0.56, 0.57, 0.62); metal = 0.7; rough = 0.3; } // steel bayonet
	ALBEDO = col;
	METALLIC = metal;
	ROUGHNESS = rough;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# A spontoon (half-pike): an ash pole with a steel head and crossbar. Stands upright;
# the mesh runs from the butt at y=0 up to the blade, so it plants at the man's feet.
func _spontoon_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 1.05, 0), Vector3(0.035, 2.10, 0.035))   # pole
	_add_box(st, Vector3(0, 1.92, 0), Vector3(0.17, 0.03, 0.03))     # crossbar
	_add_box(st, Vector3(0, 2.20, 0), Vector3(0.085, 0.34, 0.022))   # blade
	return st.commit()

func _spontoon_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying float vy;
void vertex() { vy = VERTEX.y; }
void fragment() {
	vec3 col = vec3(0.32, 0.22, 0.12);                 // ash pole
	float metal = 0.0; float rough = 0.85;
	if (vy > 1.98) { col = vec3(0.55, 0.56, 0.61); metal = 0.7; rough = 0.3; }   // steel head
	ALBEDO = col; METALLIC = metal; ROUGHNESS = rough;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# An officer/NCO: like the blocky man, but a wide fore-and-aft BICORNE instead of
# the shako, and the coat colour comes per-instance (so one mesh serves both armies).
# Brought up to the line soldier's level of detail (collar, lapels, faced cuffs, coat
# tails, hands) PLUS the marks that read as authority at a glance: a waist sash and
# gold lace at the collar/lapels/cuffs/shoulders. Position bands match `_soldier_mesh()`
# exactly wherever it matters, so the one shader below paints this mesh AND the NCOs'
# full soldier_mesh (see `nco_mm`) correctly from the same coordinates.
func _officer_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.70, 0), Vector3(0.16, 0.11, 0.50))         # bicorne (wide fore-aft)
	_add_box(st, Vector3(0, 0.55, 0), Vector3(0.21, 0.22, 0.21))         # head
	_add_box(st, Vector3(0, 0.175, 0.0), Vector3(0.40, 0.49, 0.24))      # coat body
	_add_box(st, Vector3(0, -0.04, -0.085), Vector3(0.36, 0.22, 0.13))   # coat tails (back)
	_add_box(st, Vector3(0, 0.435, 0.0), Vector3(0.34, 0.075, 0.245))    # collar (gold lace)
	_add_box(st, Vector3(0, 0.20, 0.125), Vector3(0.22, 0.40, 0.035))    # plastron / lapels (gold lace)
	_add_box(st, Vector3(0, 0.06, 0.0), Vector3(0.40, 0.09, 0.27))       # waist sash (crimson)
	for sx in [-0.265, 0.265]:
		_add_box(st, Vector3(sx, 0.18, 0.0), Vector3(0.115, 0.46, 0.13))    # sleeve
		_add_box(st, Vector3(sx, -0.03, 0.0), Vector3(0.125, 0.075, 0.145)) # cuff (gold lace)
		_add_box(st, Vector3(sx, -0.13, -0.01), Vector3(0.10, 0.10, 0.11))  # hand (skin)
		_add_box(st, Vector3(sx, 0.44, 0.0), Vector3(0.15, 0.05, 0.15))     # epaulette (gold)
	for sx in [-0.105, 0.105]:
		_add_box(st, Vector3(sx, -0.45, 0), Vector3(0.17, 0.80, 0.20))      # leg
	return st.commit()

# Shared by the company officers (`officer_mm`, mesh = `_officer_mesh()`) AND the
# NCOs/file-closers (`nco_mm`, mesh = the full `soldier_mesh`) — the coat colour rides
# per-instance in COLOR.rgb (the army's colour); gold lace marks the collar, lapels,
# cuffs and (officers only — no such geometry on the soldier mesh) shoulder boards; a
# crimson sash marks the waist. The hat is properly banded (brass band / body / dark
# peak / plume) instead of one flat block, and the back gets the soldier's knapsack
# tint where that geometry exists. The legs swing as he paces (CUSTOM.b = march,
# CUSTOM.g = phase), same as before.
func _officer_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
uniform vec3 gold = vec3(0.83, 0.68, 0.21);
uniform vec3 sash_col = vec3(0.55, 0.05, 0.08);
varying float vy;
varying float vx;
varying float vz;
varying float vnz;
void vertex() {
	vy = VERTEX.y; vx = VERTEX.x; vz = VERTEX.z; vnz = NORMAL.z;
	float march = INSTANCE_CUSTOM.b;
	float phase = INSTANCE_CUSTOM.g;
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(TIME * 6.0 + phase * 6.28318) * march * 0.5 * legside;
		float yy = VERTEX.y - hip;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + hip;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
}
void fragment() {
	vec3 col = COLOR.rgb;                                               // coat: the army's colour
	if (vy < -0.05) col = vec3(0.58, 0.56, 0.52);                       // trousers
	if (vz < -0.11 && vy > -0.02 && vy < 0.36)                          // knapsack/blanket (NCOs) / tails corner
		col = (vy > 0.27) ? vec3(0.55, 0.52, 0.47) : vec3(0.31, 0.21, 0.12);
	if (vy > 0.015 && vy < 0.105) col = sash_col;                       // the waist sash
	if (vy > 0.40 && vy < 0.47) col = gold;                             // collar (gold lace)
	if (vz > 0.10 && abs(vx) < 0.12 && vy > 0.0 && vy < 0.40) col = gold;   // plastron / lapels (gold lace)
	if (abs(vx) > 0.21 && vy > -0.07 && vy < 0.02) col = gold;          // cuffs (gold lace)
	if (abs(vx) > 0.21 && vy > 0.415 && vy < 0.47) col = gold;          // shoulder boards (officers only)
	if (abs(vx) > 0.21 && vy < -0.07) col = skin;                       // bare hands
	if (vy > 0.44 && vy < 0.655) col = skin;                            // head / neck
	if (vy > 0.655 && vy < 0.695) col = vec3(0.72, 0.55, 0.20);         // brass hat band
	if (vy >= 0.695 && vy < 0.90) col = vec3(0.05, 0.05, 0.06);         // shako / bicorne body
	if (vz > 0.10 && vy > 0.655 && vy < 0.715) col = vec3(0.06, 0.06, 0.07); // peak (dark visor)
	if (vy >= 0.90) col = vec3(0.92, 0.90, 0.86);                       // plume
	// white CROSSBELTS for the NCOs/file-closers (COLOR.a flags it; company officers wear none)
	if (COLOR.a > 0.5 && abs(vx) < 0.215 && vy > -0.05 && vy < 0.45 && abs(vnz) > 0.5) {
		float u = vx / 0.21; float v = (vy - 0.22) / 0.27;
		if (min(abs(u - v), abs(u + v)) < 0.20) { col = vec3(0.90, 0.88, 0.82); }
	}
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# ===================================================== mounted commanders (AI)
# Battalion colonels, brigade commanders and divisional generals share ONE detailed
# horse mesh and ONE detailed rider mesh (each is a MultiMesh across many instances,
# so — like the soldiers — it's one mesh + one shader, never per-instance nodes). Rank
# reads by SIZE (a uniform scale per tier, applied in the instance transform) and by
# the rider's coat/trim: the colonel rides in his army's colour with gold lace; the
# brigadier in solid gold with dark trim; the general in white-and-silver — same
# silhouette logic the bare capsules used, just with an actual horse and officer under
# it now. The saddle cloth always carries the army's colour, tying every tier visually
# to its side. Built ground-up (origin at the horse's feet) like `_build_horse()` /
# `_build_officer_colonel()`, just flattened to axis-aligned boxes for the shader.
func _mount_horse_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.98, -0.05), Vector3(0.5, 0.62, 1.42))      # barrel
	_add_box(st, Vector3(0, 1.02, 0.62), Vector3(0.46, 0.52, 0.42))      # chest
	_add_box(st, Vector3(0, 1.02, -0.78), Vector3(0.52, 0.6, 0.5))       # hindquarters
	_add_box(st, Vector3(0, 1.55, 1.05), Vector3(0.26, 0.55, 0.45))      # neck, arched
	_add_box(st, Vector3(0, 1.58, 0.90), Vector3(0.08, 0.58, 0.18))      # mane
	_add_box(st, Vector3(0, 1.78, 1.42), Vector3(0.22, 0.26, 0.42))      # head
	_add_box(st, Vector3(0, 1.86, 1.46), Vector3(0.06, 0.02, 0.30))      # blaze
	_add_box(st, Vector3(0, 1.68, 1.62), Vector3(0.18, 0.16, 0.16))      # muzzle
	for ex in [-0.07, 0.07]:
		_add_box(st, Vector3(ex, 1.95, 1.18), Vector3(0.05, 0.13, 0.05))    # ears
	_add_box(st, Vector3(0, 0.78, -1.10), Vector3(0.13, 0.62, 0.13))     # tail
	for lp in [Vector2(0.18, 0.52), Vector2(-0.18, 0.52), Vector2(0.2, -0.58), Vector2(-0.2, -0.58)]:
		_add_box(st, Vector3(lp.x, 0.36, lp.y), Vector3(0.15, 0.72, 0.17))       # leg
		_add_box(st, Vector3(lp.x, 0.02, lp.y + 0.02), Vector3(0.17, 0.12, 0.2)) # hoof
	_add_box(st, Vector3(0, 1.32, -0.02), Vector3(0.30, 0.14, 0.46))     # saddle
	_add_box(st, Vector3(0, 1.17, -0.46), Vector3(0.42, 0.05, 0.56))     # shabraque (army colour)
	_add_box(st, Vector3(0, 1.14, -0.46), Vector3(0.46, 0.02, 0.60))     # shabraque trim
	_add_box(st, Vector3(0, 1.70, 1.34), Vector3(0.24, 0.025, 0.025))    # bit
	_add_box(st, Vector3(0, 1.62, 1.50), Vector3(0.19, 0.022, 0.022))    # noseband
	_add_box(st, Vector3(0, 1.16, 0.56), Vector3(0.30, 0.02, 0.02))      # breast strap
	for sx2 in [-0.26, 0.26]:
		_add_box(st, Vector3(sx2, 0.96, 0.06), Vector3(0.07, 0.05, 0.10))   # stirrup
	return st.commit()

func _mount_horse_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying float vx;
varying float vy;
varying float vz;
void vertex() { vx = VERTEX.x; vy = VERTEX.y; vz = VERTEX.z; }
void fragment() {
	vec3 hide = vec3(0.17, 0.11, 0.07);
	vec3 dark = vec3(0.06, 0.04, 0.03);
	vec3 leather = vec3(0.22, 0.13, 0.07);
	vec3 brass = vec3(0.80, 0.64, 0.22);
	vec3 col = hide;
	if (vy < 0.10) col = dark;                                              // hooves
	if (vz < -0.75 && vy > 0.40 && vy < 1.15) col = dark;                   // tail
	if (vz > 0.78 && vz < 1.0 && vy > 1.25 && abs(vx) < 0.08) col = dark;   // mane
	if (vz > 1.50 && vy < 1.85) col = dark;                                 // muzzle
	if (vz > 1.30 && vy > 1.83 && abs(vx) < 0.05) col = vec3(0.86, 0.84, 0.80); // blaze
	if (vy > 0.85 && vy < 1.05 && abs(vx) > 0.20 && vz > -0.05 && vz < 0.20) col = brass; // stirrups
	if (vy > 1.10 && vy < 1.22 && vz < -0.10) col = COLOR.rgb;              // shabraque: the army's colour
	if (vy > 1.10 && vy < 1.15 && vz < -0.10) col = brass;                  // its piped edge
	if (vy > 1.22 && vy < 1.42 && vz > -0.30 && vz < 0.25) col = leather;   // saddle
	if (vy > 1.55 && vy < 1.75 && vz > 1.20 && vz < 1.55) col = leather;    // bit / noseband
	if (vy > 1.10 && vy < 1.22 && vz > 0.40 && vz < 0.70) col = leather;    // breast strap
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _mount_rider_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-0.27, 0.27]:
		_add_box(st, Vector3(sx, 1.35, 0.08), Vector3(0.16, 0.72, 0.18))    # thigh (buff breeches)
		_add_box(st, Vector3(sx, 1.02, 0.20), Vector3(0.17, 0.40, 0.19))    # riding boot
	_add_box(st, Vector3(0, 1.95, 0), Vector3(0.42, 0.62, 0.26))            # coat body
	_add_box(st, Vector3(0, 1.66, -0.16), Vector3(0.36, 0.30, 0.14))        # coat tails
	_add_box(st, Vector3(0, 2.20, 0.10), Vector3(0.30, 0.10, 0.10))         # collar (trim)
	_add_box(st, Vector3(0, 1.92, 0.14), Vector3(0.20, 0.50, 0.04))         # lapel (trim)
	_add_box(st, Vector3(0, 1.72, 0), Vector3(0.46, 0.10, 0.30))            # waist sash
	_add_box(st, Vector3(-0.20, 1.55, 0.06), Vector3(0.07, 0.22, 0.07))     # sash knot
	_add_box(st, Vector3(0, 2.27, 0.13), Vector3(0.14, 0.06, 0.02))         # gorget (trim)
	_add_box(st, Vector3(0.18, 1.96, 0.15), Vector3(0.03, 0.34, 0.03))      # aiguillette cord
	_add_box(st, Vector3(0.20, 1.74, 0.16), Vector3(0.04, 0.08, 0.04))      # aiguillette tip
	_add_box(st, Vector3(0, 2.38, 0), Vector3(0.22, 0.22, 0.22))            # head
	for sx in [-0.30, 0.30]:
		_add_box(st, Vector3(sx, 1.92, 0.04), Vector3(0.13, 0.5, 0.14))        # sleeve
		_add_box(st, Vector3(sx, 1.70, 0.05), Vector3(0.15, 0.10, 0.16))       # cuff (trim)
		_add_box(st, Vector3(sx * 0.85, 1.66, 0.16), Vector3(0.08, 0.08, 0.09)) # hand (skin)
		_add_box(st, Vector3(sx, 2.18, 0.0), Vector3(0.17, 0.05, 0.17))         # epaulette (trim)
	_add_box(st, Vector3(0, 2.55, 0), Vector3(0.55, 0.12, 0.22))            # bicorne
	_add_box(st, Vector3(0, 2.49, 0), Vector3(0.58, 0.025, 0.25))           # hat trim (piping)
	_add_box(st, Vector3(0, 2.58, 0.11), Vector3(0.06, 0.06, 0.03))         # cockade
	_add_cyl(st, Vector3(0, 2.65, -0.04), 0.045, 0.04, 0.08, 8)             # plume base
	_add_cyl(st, Vector3(0, 2.86, -0.05), 0.035, 0.015, 0.34, 8)            # plume
	_add_box(st, Vector3(0.34, 1.9, 0.25), Vector3(0.05, 0.05, 0.85))       # sabre
	_add_box(st, Vector3(0.34, 1.9, -0.17), Vector3(0.07, 0.07, 0.14))      # hilt (trim)
	_add_box(st, Vector3(-0.32, 1.9, 0.2), Vector3(0.05, 0.10, 0.26))       # holstered pistol
	return st.commit()

# Shared by all three mounted-leadership tiers — only the `trim` uniform differs
# (gold / dark / silver), painted on by a separate ShaderMaterial per tier. The coat
# itself reads COLOR.rgb (the colonel's team colour, or a fixed gold/white set per
# instance for the brigadiers/generals — see `_render_commanders()`).
func _mount_rider_shader(trim: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 trim;
varying float vx;
varying float vy;
varying float vz;
void vertex() { vx = VERTEX.x; vy = VERTEX.y; vz = VERTEX.z; }
void fragment() {
	vec3 buff = vec3(0.82, 0.78, 0.65);
	vec3 boot = vec3(0.07, 0.06, 0.07);
	vec3 skin = vec3(0.72, 0.56, 0.43);
	vec3 sash_col = vec3(0.55, 0.05, 0.08);
	vec3 col = COLOR.rgb;                                                // coat: the army's colour
	if (vy < 1.92) col = buff;                                           // buff breeches
	if (vy < 1.22) col = boot;                                           // riding boots
	if (vy > 1.67 && vy < 1.77) col = sash_col;                          // waist sash
	if (vy > 2.15 && vy < 2.25) col = trim;                             // collar
	if (vz > 0.10 && abs(vx) < 0.12 && vy > 1.65 && vy < 2.15) col = trim;  // lapel
	if (abs(vx) > 0.22 && vy > 1.63 && vy < 1.78) col = trim;            // cuffs
	if (abs(vx) > 0.22 && vy > 2.13 && vy < 2.24) col = trim;            // epaulettes
	if (vy > 2.24 && vy < 2.30 && vz > 0.10) col = trim;                 // gorget
	if (abs(vx) > 0.22 && vy > 1.60 && vy < 1.71) col = skin;            // bare hands
	if (vy > 2.27 && vy < 2.49) col = skin;                              // head
	if (vy > 2.40 && vy < 2.62) col = vec3(0.05, 0.05, 0.06);            // bicorne body
	if (vy > 2.475 && vy < 2.505) col = trim;                           // hat piping
	if (vy > 2.55 && vy < 2.61 && vz > 0.08) col = trim;                 // cockade
	if (vy > 2.62 && vy < 2.70) col = trim;                             // plume base
	if (vy >= 2.70) col = vec3(0.92, 0.90, 0.86);                        // plume
	if (abs(vx) > 0.28 && vy > 1.83 && vy < 1.97) col = trim;            // sabre / pistol
	ALBEDO = col;
	ROUGHNESS = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("trim", Vector3(trim.r, trim.g, trim.b))
	return m

# The uniform, painted in bands by height (shako / facing collar / coat / trousers).
# The vertex stage swings the LEG blocks fore-and-aft as the man marches — a per-man
# gait, driven entirely on the GPU from per-instance data, so it costs no CPU at 140k.
# Per-instance: COLOR.rgb = facings, COLOR.a = coat variant; CUSTOM.r = wear,
# CUSTOM.g = gait phase (0..1), CUSTOM.b = march amount (0 standing .. 1 marching).
# For the Blender LOD: colour comes from the model's baked VERTEX COLOURS, the legs/arms
# still swing by the same position bands (driven by per-instance CUSTOM data), and the coat
# blue is recoloured per team so the two armies read apart.
func _soldier_glb_shader(team: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coats[3];
uniform vec3 belt_pal[3];
uniform vec3 pants_pal[4];
uniform vec3 hat_pal[3];
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
varying float region;
varying vec3 facing;
varying flat int v_coat;
varying flat int v_belt;
varying flat int v_pants;
varying flat int v_hat;
varying float wear;
void vertex() {
	region = round(UV.x * 16.0);          // baked region id (0 coat 1 facing 2 belt 3 trousers...)
	facing = COLOR.rgb;                    // the battalion's facing colour
	int p = int(round(COLOR.a * 255.0));   // packed dress: coat + belt*3 + pants*9 + hat*36
	v_coat = p % 3; p /= 3;
	v_belt = p % 3; p /= 3;
	v_pants = p % 4; p /= 4;
	v_hat = p % 3;
	// MORPH the headgear per battalion type (band-matched LOD: hat y>0.655, plume y>0.90)
	if (VERTEX.y > 0.90) {
		if (v_hat != 0) { VERTEX = vec3(0.0, 0.55, 0.0); }          // plume only on the shako
	} else if (VERTEX.y > 0.655) {
		if (v_hat == 1) {                                           // round / slouch hat
			VERTEX.x *= 1.75; VERTEX.z *= 1.75;
			VERTEX.y = 0.655 + (VERTEX.y - 0.655) * 0.42;
		} else if (v_hat == 2) {                                    // bicorne, worn fore-and-aft
			VERTEX.x *= 0.55; VERTEX.z *= 2.15;
			VERTEX.y = 0.655 + (VERTEX.y - 0.655) * 0.5;
		}
	}
	wear = INSTANCE_CUSTOM.r;
	float phase = INSTANCE_CUSTOM.g;
	float march = INSTANCE_CUSTOM.b;
	float armp = INSTANCE_CUSTOM.a;
	float t6 = TIME * 6.5 + phase * 6.28318;
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(t6) * march * 0.55 * legside;
		float yy = VERTEX.y - hip; float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy*cs - VERTEX.z*sn + hip; VERTEX.z = yy*sn + VERTEX.z*cs;
	}
	if (abs(VERTEX.x) > 0.215) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float raise = -clamp(armp, 0.0, 1.0) * 1.35;
		float ram = sin(TIME * 8.0 + phase * 6.28318); ram = ram * abs(ram);
		float ramrod = (armp > 0.4 && armp < 0.85) ? (ram * 0.6 * (armside < 0.0 ? 1.0 : 0.3)) : 0.0;
		float swing = (march > 0.001 && armp < 0.15) ? (sin(t6) * march * 0.35 * -armside) : 0.0;
		float ang = raise + ramrod + swing; float sh2 = 0.45;
		float yy = VERTEX.y - sh2; float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy*cs - VERTEX.z*sn + sh2; VERTEX.z = yy*sn + VERTEX.z*cs;
	}
}
void fragment() {
	int reg = int(region);
	vec3 base = coats[v_coat];
	vec3 c;
	bool accent = false;                                  // small bright bits that speckle en masse
	if (reg == 1)       c = facing;                       // collar/cuffs/lapels/turnbacks
	else if (reg == 3)  c = pants_pal[v_pants];           // breeches
	else if (reg == 4)  c = vec3(0.09, 0.09, 0.10);       // gaiters / boots
	else if (reg == 5)  c = skin;                         // head / hands
	else if (reg == 6)  c = hat_pal[v_hat];               // headgear
	else if (reg == 11) c = vec3(0.18, 0.12, 0.07);       // hair
	else if (reg == 2)  { c = belt_pal[v_belt];          accent = true; }  // crossbelts
	else if (reg == 7)  { c = vec3(0.62, 0.18, 0.16);    accent = true; }  // plume (toned down)
	else if (reg == 8)  { c = vec3(0.30, 0.20, 0.12);    accent = true; }  // knapsack leather
	else if (reg == 9)  { c = vec3(0.50, 0.47, 0.42);    accent = true; }  // rolled blanket
	else if (reg == 10) { c = vec3(0.55, 0.45, 0.22);    accent = true; }  // brass (muted)
	else                c = base;                         // coat & sleeves (reg 0 / fallback)
	// DISTANCE COLOUR-LOD: a detailed man seen by the thousand aliases into speckle. With
	// distance, fold his small bright accents into the coat AND even out the per-man wear
	// brightness, so the MASS reads as clean blocks of colour while the men you ride among
	// keep their detail.
	float fade = smoothstep(22.0, 60.0, length(VERTEX));
	if (accent) c = mix(c, base, fade * 0.9);
	float w = mix(wear, 0.92, fade);
	ALBEDO = c * w;
	ROUGHNESS = 0.92;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var coats := PackedVector3Array()
	for c in (COATS_0 if team == 0 else COATS_1):
		coats.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("coats", coats)
	_set_dress_palettes(m)
	return m

# Which detailed troop-type model a battalion draws when it's near the camera: within each
# brigade of five, the first battalion is grenadiers (bearskins), the last is the light
# battalion (green plume, wings), the rest are line. (Cheap, deterministic from the index.)
func _troop_type_of(b: Batt) -> int:
	var kb := (b.idx % BATT_PER_TEAM) % BATTS_PER_BRIGADE
	if kb == 0:
		return 2          # grenadier
	if kb == BATTS_PER_BRIGADE - 1:
		return 1          # light
	return 0              # line

# The near-LOD shader for the detailed Blender troop models. Same per-instance dress decode and
# the same band-driven march/reload animation as the box-man, but it reads the baked REGION id
# from UV.x (like the soldier LOD) and colours each part — with the headgear a fixed dark and the
# PLUME taken from a per-troop-type uniform (white line / green light / red grenadier). No hat
# morph: each variant already carries its correct headgear (shako / bearskin) in the mesh.
func _troop_lod_shader(team: int, ttype: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coats[3];
uniform vec3 belt_pal[3];
uniform vec3 pants_pal[4];
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
uniform vec3 plume_col = vec3(0.9);
uniform float plume_y = 0.93;          // height above which the headgear gives way to the plume
varying float vy;                      // captured BEFORE animation, so colour bands stay put
varying float vx;
varying float vz;
varying vec3 facing;
varying flat int v_coat;
varying flat int v_belt;
varying flat int v_pants;
varying float wear;
void vertex() {
	vy = VERTEX.y; vx = VERTEX.x; vz = VERTEX.z;
	facing = COLOR.rgb;
	int p = int(round(COLOR.a * 255.0));
	v_coat = p % 3; p /= 3;
	v_belt = p % 3; p /= 3;
	v_pants = p % 4;
	wear = INSTANCE_CUSTOM.r;
	float phase = INSTANCE_CUSTOM.g;
	float march = INSTANCE_CUSTOM.b;
	float armp = INSTANCE_CUSTOM.a;
	float t6 = TIME * 6.5 + phase * 6.28318;
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(t6) * march * 0.55 * legside;
		float yy = VERTEX.y - hip; float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy*cs - VERTEX.z*sn + hip; VERTEX.z = yy*sn + VERTEX.z*cs;
	}
	if (abs(VERTEX.x) > 0.215) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float raise = -clamp(armp, 0.0, 1.0) * 1.35;
		float ram = sin(TIME * 8.0 + phase * 6.28318); ram = ram * abs(ram);
		float ramrod = (armp > 0.4 && armp < 0.85) ? (ram * 0.6 * (armside < 0.0 ? 1.0 : 0.3)) : 0.0;
		float swing = (march > 0.001 && armp < 0.15) ? (sin(t6) * march * 0.35 * -armside) : 0.0;
		float ang = raise + ramrod + swing; float sh2 = 0.45;
		float yy = VERTEX.y - sh2; float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy*cs - VERTEX.z*sn + sh2; VERTEX.z = yy*sn + VERTEX.z*cs;
	}
}
void fragment() {
	// COLOUR BY POSITION (the proven box-man method) — not by UV codes. game coords:
	// y = height (legs<-0.05, coat, head .45-.66, headgear>.66), z = front(+)/back(-), x = sides.
	vec3 c = coats[v_coat];                                            // coat & sleeves (default)
	if (vy < -0.05) c = (vy < -0.55) ? vec3(0.08,0.08,0.09) : pants_pal[v_pants];  // gaiters / trousers
	if (abs(vx) > 0.21 && vy < 0.0) c = skin;                          // hands at the wrists
	if (vy > 0.40 && vy < 0.47) c = facing;                            // collar
	if (abs(vx) > 0.21 && vy > -0.06 && vy < 0.04) c = facing;         // cuffs
	if (abs(vx) < 0.12 && vz > 0.09 && vy > 0.02 && vy < 0.40) c = facing;  // lapels (breast, front)
	if (abs(vx) > 0.20 && vy > 0.33 && vy < 0.49) c = facing;          // shoulder wings (light/gren)
	if (vz < -0.13 && vy > 0.05 && vy < 0.33) c = vec3(0.30,0.20,0.12);     // knapsack on the back
	if (vy > 0.45 && vy < 0.66 && abs(vx) < 0.16) c = skin;            // head
	if (vy >= 0.66 && vy < plume_y) c = vec3(0.07,0.07,0.08);          // shako / bearskin
	if (vy >= plume_y) c = plume_col;                                  // plume
	// white crossbelts: an X over the front of the chest
	if (abs(vx) < 0.21 && vy > -0.05 && vy < 0.42 && vz > 0.0) {
		float u = vx / 0.20;
		float v = (vy - 0.20) / 0.27;
		if (min(abs(u - v), abs(u + v)) < 0.16) c = belt_pal[v_belt];
	}
	ALBEDO = c * wear;
	ROUGHNESS = 0.9;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var coats := PackedVector3Array()
	for c in (COATS_0 if team == 0 else COATS_1):
		coats.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("coats", coats)
	_set_dress_palettes(m)
	var pc: Color = TROOP_PLUME[ttype]
	m.set_shader_parameter("plume_col", Vector3(pc.r, pc.g, pc.b))
	m.set_shader_parameter("plume_y", [0.93, 0.91, 1.06][ttype])   # shako / shako / tall bearskin
	return m

func _soldier_shader(team: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coats[3];
uniform vec3 hat_pal[3];
uniform vec3 belt_pal[3];
uniform vec3 pants_pal[4];
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
varying float vy;
varying float vx;
varying float vz;
varying float vnz;
varying float wear;
varying flat int v_belt;
varying flat int v_pants;
varying flat int v_hat;
varying flat int v_coat;
void vertex() {
	vy = VERTEX.y;                       // band/belt by TRUE position (stable as limbs move)
	vx = VERTEX.x;
	vz = VERTEX.z;
	vnz = NORMAL.z;
	wear = INSTANCE_CUSTOM.r;
	// DECODE the per-man dress packed into COLOR.a: coat + belt*3 + pants*9 + hat*36
	int p = int(round(COLOR.a * 255.0));
	v_coat = p % 3; p /= 3;
	v_belt = p % 3; p /= 3;
	v_pants = p % 4; p /= 4;
	v_hat = p % 3;
	// MORPH the hat block (vy>0.655) per type; the plume (vy>0.90) shows only for the shako
	if (VERTEX.y > 0.90) {
		if (v_hat != 0) { VERTEX = vec3(0.0, 0.55, 0.0); }                 // hide plume unless shako
	} else if (VERTEX.y > 0.655) {
		if (v_hat == 1) {                                                  // round / slouch hat
			VERTEX.x *= 1.75; VERTEX.z *= 1.75;
			VERTEX.y = 0.655 + (VERTEX.y - 0.655) * 0.42;
		} else if (v_hat == 2) {                                           // bicorne (wide fore-aft)
			VERTEX.x *= 0.55; VERTEX.z *= 2.15;
			VERTEX.y = 0.655 + (VERTEX.y - 0.655) * 0.5;
		}
	}
	float phase = INSTANCE_CUSTOM.g;
	float march = INSTANCE_CUSTOM.b;
	float armp = INSTANCE_CUSTOM.a;      // 0 at rest .. ~0.6 reloading .. 1 presenting/firing
	float t6 = TIME * 6.5 + phase * 6.28318;
	// LEGS swing fore-and-aft as he marches
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;          // left & right out of phase
		float ang = sin(t6) * march * 0.55 * legside;
		float yy = VERTEX.y - hip;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + hip;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
	// ARMS: raise to present the musket, work the ramrod while reloading, swing on the march
	if (abs(VERTEX.x) > 0.215) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float raise = -clamp(armp, 0.0, 1.0) * 1.35;                                  // FORWARD, holding it up
		// reloading: the working arm drives the ramrod down the barrel with a sharp stroke,
		// the other steadies the piece
		float ram = sin(TIME * 8.0 + phase * 6.28318);
		ram = ram * abs(ram);                                                         // sharper push than draw
		float ramrod = (armp > 0.4 && armp < 0.85) ? (ram * 0.6 * (armside < 0.0 ? 1.0 : 0.3)) : 0.0;
		float swing = (march > 0.001 && armp < 0.15) ? (sin(t6) * march * 0.35 * -armside) : 0.0;
		float ang = raise + ramrod + swing;
		float sh = 0.45;                                                              // shoulder pivot
		float yy = VERTEX.y - sh;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + sh;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
}
void fragment() {
	vec3 col = coats[v_coat];                                               // coat & sleeves (default)
	if (vy < -0.05) col = (vy < -0.52) ? vec3(0.10, 0.10, 0.11) : pants_pal[v_pants];   // gaiters / overalls
	if (abs(vx) > 0.21 && vy < -0.07) col = skin;                           // bare hands at the wrists
	if (vz < -0.11 && vy > -0.02 && vy < 0.36)                              // knapsack & blanket on the back
		col = (vy > 0.27) ? vec3(0.55, 0.52, 0.47) : vec3(0.31, 0.21, 0.12);
	if (vy > 0.40 && vy < 0.47) col = COLOR.rgb;                            // collar (facing)
	if (vz > 0.10 && abs(vx) < 0.12 && vy > 0.0 && vy < 0.40) col = COLOR.rgb;   // plastron down the breast
	if (abs(vx) > 0.21 && vy > -0.07 && vy < 0.02) col = COLOR.rgb;         // cuffs (facing)
	if (vy > 0.44 && vy < 0.655 && abs(vx) < 0.16) col = skin;             // head / neck
	if (vy > 0.655 && vy < 0.695) col = vec3(0.72, 0.55, 0.20);            // brass shako band
	if (vy >= 0.695 && vy < 0.90) col = hat_pal[v_hat];                    // shako body (battalion colour)
	if (vz > 0.10 && vy > 0.655 && vy < 0.715) col = vec3(0.06, 0.06, 0.07);   // shako peak (dark visor)
	if (vy >= 0.90) col = vec3(0.92, 0.90, 0.86);                          // plume
	// white CROSSBELTS — an X over the breast (front faces only, so the knapsack stays clean)
	if (abs(vx) < 0.215 && vy > -0.05 && vy < 0.42 && vnz > 0.45) {
		float u = vx / 0.21;
		float v = (vy - 0.20) / 0.27;
		if (min(abs(u - v), abs(u + v)) < 0.17) col = belt_pal[v_belt];
	}
	ALBEDO = col * wear;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var coats := PackedVector3Array()
	for c in (COATS_0 if team == 0 else COATS_1):
		coats.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("coats", coats)
	_set_dress_palettes(m)
	return m

# the shared dress palettes (crossbelts, trousers, headgear colours) for the in-shader lookup
func _set_dress_palettes(m: ShaderMaterial) -> void:
	var belt := PackedVector3Array()
	for c in GameConfig.BELT_COLS:
		belt.append(Vector3(c.r, c.g, c.b))
	var pants := PackedVector3Array()
	for c in GameConfig.PANTS_COLS:
		pants.append(Vector3(c.r, c.g, c.b))
	var hats := PackedVector3Array()
	for c in GameConfig.HAT_COLS:
		hats.append(Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("belt_pal", belt)
	m.set_shader_parameter("pants_pal", pants)
	m.set_shader_parameter("hat_pal", hats)

# A rolling ground: a grid over the land, each vertex lifted by _gh, with UVs for the
# turf material and computed normals so the light catches the slopes.
func _build_ground_mesh() -> ArrayMesh:
	var x0 := -PROVINCE_SIZE * 0.5
	var x1 := COAST_X + 60.0
	var z0 := -PROVINCE_SIZE * 0.5
	var z1 := PROVINCE_SIZE * 0.5
	var cols := 150
	var rows := 240
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(rows):
		for c in range(cols):
			var xa := lerpf(x0, x1, float(c) / float(cols))
			var xb := lerpf(x0, x1, float(c + 1) / float(cols))
			var za := lerpf(z0, z1, float(r) / float(rows))
			var zb := lerpf(z0, z1, float(r + 1) / float(rows))
			var p00 := Vector3(xa, _gh(xa, za), za)
			var p10 := Vector3(xb, _gh(xb, za), za)
			var p01 := Vector3(xa, _gh(xa, zb), zb)
			var p11 := Vector3(xb, _gh(xb, zb), zb)
			var uvs := 1.0 / 21.0   # ~21 m per turf tile (matches the old uv1_scale feel)
			# wound so the face normals point UP (Godot culls back-faces; the reverse order
			# left the top facing down — the ground read as see-through from above)
			for v in [[p00, xa, za], [p10, xb, za], [p11, xb, zb], [p00, xa, za], [p11, xb, zb], [p01, xa, zb]]:
				st.set_uv(Vector2(float(v[1]) * uvs, float(v[2]) * uvs))
				st.add_vertex(v[0])
	st.generate_normals()
	return st.commit()

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
	m.uv1_scale = Vector3(1, 1, 1)           # UVs are authored per-vertex on the rolling mesh
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
	pm.direction = Vector3(0, -1.0, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 32.0
	pm.gravity = Vector3(0, -12.0, 0)         # wind adds a sideways pull on top of this, live
	pm.scale_min = 1.0
	pm.scale_max = 1.0
	pm.set_particle_flag(ParticleProcessMaterial.PARTICLE_FLAG_ALIGN_Y_TO_VELOCITY, true)   # streaks rake to match how they're actually falling
	p.process_material = pm
	_rain_proc = pm
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
	# the weather turns over on its own, slowly, only to a state the current one plausibly leads to
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()
	# ease the weather toward the chosen state — clouds and fog build over roughly a minute,
	# never snap, so nothing changes from clear to foul in the space of a few seconds
	var tc := 0.0
	var tf := 0.0
	var tr := 0.0
	match _weather:
		"overcast": tc = 0.85; tf = 0.22
		"rain": tc = 1.0; tf = 0.45; tr = 1.0
		"fog": tc = 0.55; tf = 1.0
	_cloud = lerpf(_cloud, tc, clampf(delta * WEATHER_CLOUD_RATE, 0.0, 1.0))
	_fogw = lerpf(_fogw, tf, clampf(delta * WEATHER_FOG_RATE, 0.0, 1.0))
	# rain can't break until the sky is actually heavy enough to carry it — a storm announces
	# itself in the clouds well before the first drop falls, and tails off the same way as
	# they thin, so "clear" never tips straight into "raining"
	var rain_target := tr * smoothstep(0.55, 0.85, _cloud)
	_rainw = lerpf(_rainw, rain_target, clampf(delta * WEATHER_RAIN_RATE, 0.0, 1.0))
	_wet = _rainw
	# the sun arcs across the sky; stays just above the horizon so shadows always cast
	var pitch := -clampf(h * 70.0, 4.0, 76.0)
	sun.rotation_degrees = Vector3(pitch, lerpf(-110.0, -250.0, u), 0.0)
	var sun_col: Color = _grad_sun.sample(u)
	# WARM KEY / COOL FILL: nudge the daytime sun toward warm gold; the sky-derived ambient
	# stays cool, so lit faces read warm and shadows read cool — depth and a sunny mood.
	var keyed := sun_col.lerp(Color(1.0, 0.93, 0.80), day * 0.22)
	sun.light_color = keyed.lerp(Color(0.55, 0.57, 0.60), _cloud * 0.7)
	sun.light_energy = lerpf(0.06, 1.55, day) * lerpf(1.0, 0.38, _cloud)
	# a slightly deeper ambient floor by day lets the SSAO and warm key carry the depth
	env.ambient_light_energy = lerpf(0.14, 0.48, day) * lerpf(1.0, 1.45, _cloud)
	# at night the powder-flashes bloom far harder against the dark
	env.glow_intensity = lerpf(0.9, 1.7, _night)
	env.glow_hdr_threshold = lerpf(1.0, 0.7, _night)
	psm.sky_top_color = _grad_skytop.sample(u).lerp(Color(0.50, 0.52, 0.55), _cloud * 0.6)
	psm.sky_horizon_color = _grad_skyhorizon.sample(u).lerp(Color(0.56, 0.57, 0.59), _cloud * 0.6)
	var fog_col: Color = _grad_fog.sample(u).lerp(Color(0.56, 0.57, 0.60), _cloud * 0.5)
	env.fog_light_color = fog_col
	# a light atmospheric haze only — clear by day so the province reads to its edges,
	# thickening at dusk/night and in foul weather (no grey wall at the borders)
	env.fog_density = lerpf(0.00010, 0.00040, 1.0 - day) + _fogw * 0.004
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
	# the wind is a continuous force on every puff already aloft, not just a kick at the
	# muzzle — banks of smoke keep drifting downwind for their whole life, same as the real
	# thing, while still buoying gently upward as they thin
	if _smoke_proc:
		_smoke_proc.gravity = Vector3(_wind.x, 0.10, _wind.z)
	if _musket_smoke_proc:
		_musket_smoke_proc.gravity = Vector3(_wind.x, 0.012, _wind.z)
	if _dust_proc:
		_dust_proc.gravity = Vector3(_wind.x, 0.02, _wind.z)
	if _rain_proc:
		# the same wind that drifts the smoke lays the rain over — the harder it blows,
		# the harder the streaks rake as they fall, instead of always dropping dead straight
		_rain_proc.gravity = Vector3(_wind.x * 2.6, -12.0, _wind.z * 2.6)
	# the sea and the clouds answer to that same wind
	var wdir := Vector2(_wind.x, _wind.z)
	wdir = wdir.normalized() if wdir.length() > 0.01 else Vector2(1, 0)
	var wstr := 0.8 + _wind.length() * 0.7
	var horizon: Color = psm.sky_horizon_color
	if ocean_mat != null:
		var dl := lerpf(0.18, 1.0, day)
		ocean_mat.set_shader_parameter("wtime", _t)        # shared clock so ships ride the visible swell
		ocean_mat.set_shader_parameter("wind_dir", SEA_WIND_DIR.normalized())   # fixed swell heading
		ocean_mat.set_shader_parameter("wind_str", wstr)
		ocean_mat.set_shader_parameter("sky_tint", horizon)
		ocean_mat.set_shader_parameter("deep", Color(0.015, 0.055, 0.10) * dl)
		ocean_mat.set_shader_parameter("shallow", Color(0.07, 0.21, 0.27) * dl)
		ocean_mat.set_shader_parameter("foam_col", Color(0.86, 0.90, 0.92) * lerpf(0.35, 1.0, day))
	if cloud_mat != null and cam != null:
		cloud_layer.global_position = Vector3(cam.global_position.x, 1700.0, cam.global_position.z)
		cloud_mat.set_shader_parameter("wind", wdir)
		cloud_mat.set_shader_parameter("coverage", clampf(0.34 + _cloud * 0.5, 0.0, 0.9))
		var dcl := lerpf(0.22, 1.0, day)
		cloud_mat.set_shader_parameter("lit", sun.light_color.lerp(Color(1, 1, 1), 0.35) * dcl)
		cloud_mat.set_shader_parameter("shade", horizon.lerp(Color(0.60, 0.64, 0.72), 0.5) * dcl)

func _cycle_weather() -> void:
	# only turn toward a state the current weather plausibly leads to — clear builds to
	# overcast before anything else, rain settles back to overcast rather than blue sky
	var options: Array = WEATHER_NEXT.get(_weather, WEATHERS)
	_weather = options[randi() % options.size()]
	_weather_timer = randf_range(180.0, 360.0)       # hold the chosen weather a good while —
													   # the change itself already takes a minute or so
	_send_player_despatch("[color=#bcd] Weather turning %s.[/color]" % _weather, {})

# ============================================================= THE FIELD MAP (M)
# A top-down read of the whole action: every battalion plotted as a small counter,
# your own army toward the bottom, the enemy across the table. Your battalion glows.

# ============================================== AI DEBUG OVERLAY (F3) + batch mode
func _build_ai_debug(cl: CanvasLayer) -> void:
	aidbg_panel = PanelContainer.new()
	aidbg_panel.anchor_left = 1.0
	aidbg_panel.anchor_right = 1.0
	aidbg_panel.offset_left = -560.0
	aidbg_panel.offset_top = 92.0
	aidbg_panel.offset_right = -12.0
	aidbg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.05, 0.86)
	sb.border_color = Color(0.4, 0.9, 0.6, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	aidbg_panel.add_theme_stylebox_override("panel", sb)
	cl.add_child(aidbg_panel)
	aidbg_label = RichTextLabel.new()
	aidbg_label.bbcode_enabled = true
	aidbg_label.fit_content = true
	aidbg_label.scroll_active = false
	aidbg_label.custom_minimum_size = Vector2(540, 0)
	aidbg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aidbg_label.add_theme_font_size_override("normal_font_size", 12)
	aidbg_panel.add_child(aidbg_label)
	aidbg_panel.visible = false

# A dev weather readout (shown with the F3 overlay or the F4 RTS camera): wind bearing &
# speed, sea state, cloud cover and the clock — handy while tuning the sky and sea.
func _build_wind_hud(cl: CanvasLayer) -> void:
	wind_hud = RichTextLabel.new()
	wind_hud.bbcode_enabled = true
	wind_hud.fit_content = true
	wind_hud.scroll_active = false
	wind_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wind_hud.custom_minimum_size = Vector2(244, 0)
	wind_hud.add_theme_font_size_override("normal_font_size", 14)
	wind_hud.visible = false
	cl.add_child(wind_hud)

const _WIND_ARROWS := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
const _WIND_NAMES := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
func _update_wind_hud() -> void:
	if wind_hud == null:
		return
	var on := _aidbg_on or _rts_cam
	wind_hud.visible = on
	if not on:
		return
	wind_hud.position = Vector2(get_viewport().get_visible_rect().size.x - 262.0, 64.0)
	var spd := _wind.length()
	var sector := 0
	if spd > 0.001:
		sector = int(round(atan2(_wind.z, _wind.x) / (PI / 4.0)))
		sector = ((sector % 8) + 8) % 8
	var knots := int(round(spd * 26.0))
	var ss := clampf(0.8 + spd * 0.7, 0.3, 3.0)
	var sea: String = "calm" if ss < 0.9 else ("slight" if ss < 1.3 else ("moderate" if ss < 1.9 else "rough"))
	var sky: String = "clear" if _cloud < 0.15 else ("scattered" if _cloud < 0.45 else ("broken" if _cloud < 0.75 else "overcast"))
	var clk := int(_time_of_day)
	var mins := int((_time_of_day - float(clk)) * 60.0)
	var t := "[b][color=#bcd6ff]WEATHER[/color][/b]   [color=#6f7888](dev)[/color]\n"
	t += "[color=#9fb0c8]Wind[/color]  [color=#ffe9a8]%s %s[/color]  [color=#cdd6e6]%d kn[/color]\n" % [_WIND_ARROWS[sector], _WIND_NAMES[sector], knots]
	t += "[color=#9fb0c8]Sea[/color]   [color=#cdd6e6]%s[/color]\n" % sea
	t += "[color=#9fb0c8]Sky[/color]   [color=#cdd6e6]%s[/color]\n" % sky
	t += "[color=#9fb0c8]Time[/color]  [color=#cdd6e6]%02d:%02d[/color]  ·  [color=#cdd6e6]%s[/color]" % [clk, mins, _weather]
	wind_hud.text = t

# A bearing strip at the foot of the screen — a ribbon of ticks and cardinal points that
# slides as you turn, with the bearing you face read off the centre (N = -Z, E = +X).
const _COMPASS_W := 480.0
func _build_compass(cl: CanvasLayer) -> void:
	compass_panel = Control.new()
	compass_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(compass_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.07, 0.46)
	bg.position = Vector2(0, 9)
	bg.size = Vector2(_COMPASS_W, 26)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(bg)
	for i in range(24):
		var tk := ColorRect.new()
		tk.color = Color(0.82, 0.85, 0.92, 0.7)
		tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		compass_panel.add_child(tk)
		_compass_ticks.append(tk)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	for i in range(8):
		var lb := Label.new()
		lb.text = names[i]
		lb.add_theme_font_size_override("font_size", 15 if i % 2 == 0 else 11)
		lb.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42) if i == 0 else Color(0.86, 0.90, 0.96))
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		compass_panel.add_child(lb)
		_compass_labels.append(lb)
	_compass_center = ColorRect.new()
	_compass_center.color = Color(1.0, 0.84, 0.42)
	_compass_center.size = Vector2(2, 28)
	_compass_center.position = Vector2(_COMPASS_W * 0.5 - 1.0, 8)
	_compass_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(_compass_center)
	_compass_read = Label.new()
	_compass_read.add_theme_font_size_override("font_size", 12)
	_compass_read.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_compass_read.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass_panel.add_child(_compass_read)

func _update_compass() -> void:
	if compass_panel == null:
		return
	var hide := _camp_on or _gun_sight or _scoped or (battle_over and _bill_panel != null and _bill_panel.visible)
	compass_panel.visible = not hide
	if hide:
		return
	var vp := get_viewport().get_visible_rect().size
	compass_panel.position = Vector2(vp.x * 0.5 - _COMPASS_W * 0.5, vp.y - 58.0)
	var lf := -Vector3(sin(_cam_yaw), 0, cos(_cam_yaw))         # where you are looking
	var cur := fposmod(rad_to_deg(atan2(lf.x, lf.z)), 360.0)    # bearing: 0 = N(+Z), 90 = E(+X)
	var cx := _COMPASS_W * 0.5
	var ppd := cx / 92.0                                        # show a touch over ±90 deg
	for i in range(24):
		var dd := wrapf(float(i) * 15.0 - cur, -180.0, 180.0)
		var tk: ColorRect = _compass_ticks[i]
		if absf(dd) <= 92.0:
			var major := i % 3 == 0
			tk.size = Vector2(1.5, 13.0 if major else 7.0)
			tk.position = Vector2(cx + dd * ppd - 0.75, 11.0 if major else 14.0)
			tk.visible = true
		else:
			tk.visible = false
	for i in range(8):
		var dd := wrapf(float(i) * 45.0 - cur, -180.0, 180.0)
		var lb: Label = _compass_labels[i]
		if absf(dd) <= 90.0:
			lb.visible = true
			lb.position = Vector2(cx + dd * ppd - lb.size.x * 0.5, -7.0)
		else:
			lb.visible = false
	_compass_read.text = "%03d°" % int(round(cur))
	_compass_read.position = Vector2(cx - _compass_read.size.x * 0.5, 32.0)

# A live read of what each army has DEDUCED — the goal, the plan, the doctrine play, the
# main effort and its target, its (lagged) intelligence, and every brigade's mission.
func _update_ai_debug() -> void:
	if aidbg_label == null:
		return
	var t := "[b][color=#7fe0a0]AI APPRECIATION[/color][/b]   [color=#6f7888](F3)[/color]\n"
	for army in armies:
		var col := "7a93ea" if army.team == 0 else "d07068"
		t += "[color=#%s]── %s ──[/color]  goal [color=#ffe9a8]%s[/color] · plan [color=#ffe9a8]%s[/color] · play [color=#ffe9a8]%s[/color] · aggr %.2f\n" % [
			col, _faction_word(army.team), army.goal, army.plan, (army.play if army.play != "" else "—"), army.aggression]
		var mainname := "—"
		if army.main != null:
			mainname = "Bde %d (Div %d)" % [int(army.main.idx % BRIGADES_PER_TEAM) + 1, int(army.main.division) + 1]
		var tgt := "—"
		if army.main != null and army.main.mission_target != null:
			tgt = _unit_name(army.main.mission_target.battalions[0]) if not army.main.mission_target.battalions.is_empty() else "?"
		var fresh: String = "fresh" if army.intel_fresh else "stale"
		t += "    main: [color=#cdd6e6]%s[/color]  target: [color=#cdd6e6]%s[/color]  intel L%d R%d (%s)\n" % [
			mainname, tgt, int(army.intel_left), int(army.intel_right), fresh]
		# brigade missions, compact
		var miss := ""
		var k := 0
		for br in brigades:
			if br.team != army.team or _brigade_live(br) == 0:
				continue
			miss += "%s " % _mission_glyph(br.mission)
			k += 1
			if k % 12 == 0:
				miss += "\n            "
		t += "    bdes: [color=#9fb0c8]%s[/color]\n" % miss
	t += "[color=#6f7888]glyphs: A=attack F=flank x=fix s=support r=reserve _=refuse h=hold[/color]"
	aidbg_label.text = t

func _faction_word(team: int) -> String:
	return "BLUE" if team == 0 else "RED"

func _mission_glyph(m: String) -> String:
	match m:
		"attack": return "[color=#ff7a6a]A[/color]"
		"flank": return "[color=#ffb060]F[/color]"
		"fix": return "[color=#cdd6e6]x[/color]"
		"support": return "[color=#ffe08a]s[/color]"
		"reserve": return "[color=#7fb0ff]r[/color]"
		"refuse": return "[color=#9fb0c8]_[/color]"
	return "[color=#9fb0c8]h[/color]"

func _build_map(cl: CanvasLayer) -> void:
	map_panel = Control.new()
	map_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.visible = false
	cl.add_child(map_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(dim)
	var field := ColorRect.new()             # the parchment the province is drawn on
	field.name = "field"
	field.color = Color(0.20, 0.18, 0.13, 0.92)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(field)
	_map_sea = ColorRect.new()               # the sea off the eastern shore
	_map_sea.color = Color(0.13, 0.22, 0.30, 0.92)
	_map_sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_sea.visible = false
	map_panel.add_child(_map_sea)
	var title := Label.new()
	title.name = "title"
	title.text = "PROVINCE MAP"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	title.position = Vector2(122, 30)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(title)
	map_legend = RichTextLabel.new()
	map_legend.bbcode_enabled = true
	map_legend.fit_content = true
	map_legend.scroll_active = false
	map_legend.custom_minimum_size = Vector2(520, 0)
	map_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_legend.add_theme_font_size_override("normal_font_size", 13)
	map_legend.position = Vector2(122, 58)
	map_panel.add_child(map_legend)

func _toggle_map() -> void:
	_map_on = not _map_on
	if map_panel != null:
		map_panel.visible = _map_on
	if _map_on:
		_update_map()

# The PROVINCE MAP (M): a paper-map read of the whole country — its roads, towns, forts
# and depots, the coast, and YOUR own forces. The enemy is fogged: you see only the towns
# you can read from a despatch, not where his army stands (dev reveal: F3 lifts the fog).
const _MAP_WMIN := Vector2(-8700.0, -8500.0)   # province extent shown on the map (world x,z)
const _MAP_WMAX := Vector2(2100.0, 8500.0)
func _update_map() -> void:
	if map_panel == null or not _map_on:
		return
	var vp := get_viewport().get_visible_rect().size
	var ml := 120.0
	var mt := 92.0
	var mb := 56.0
	var plot := Rect2(ml, mt, maxf(80.0, vp.x - 2.0 * ml), maxf(80.0, vp.y - mt - mb))
	# aspect-preserving projection of the whole province onto the plot (a real map, not stretched)
	var wmin := _MAP_WMIN
	var wsize := _MAP_WMAX - _MAP_WMIN
	var scl: float = minf(plot.size.x / wsize.x, plot.size.y / wsize.y)
	var drawn := wsize * scl
	var origin := plot.position + (plot.size - drawn) * 0.5
	var flip: bool = player != null and player.team == 0   # keep your own country toward the bottom
	var P := func(w: Vector3) -> Vector2:
		var nx := (w.x - wmin.x) / wsize.x
		var nz := (w.z - wmin.y) / wsize.y
		if flip:
			nz = 1.0 - nz
		return origin + Vector2(nx * drawn.x, nz * drawn.y)
	var field := map_panel.get_node("field") as ColorRect
	if field != null:
		field.position = origin
		field.size = drawn
	# the sea off the eastern shore
	if _map_sea != null:
		var a: Vector2 = P.call(Vector3(COAST_X, 0, wmin.y))
		var b: Vector2 = P.call(Vector3(_MAP_WMAX.x, 0, _MAP_WMAX.y))
		_map_sea.position = Vector2(minf(a.x, b.x), origin.y)
		_map_sea.size = Vector2(absf(b.x - a.x), drawn.y)
		_map_sea.visible = true
	# the road network between the towns
	var ri := 0
	for seg in field_roads:
		var ln := _map_road(ri); ri += 1
		ln.points = PackedVector2Array([P.call(seg[0] as Vector3), P.call(seg[1] as Vector3)])
		ln.visible = true
	for j in range(ri, _map_roads.size()):
		(_map_roads[j] as Line2D).visible = false
	# the river and its bridges
	if not river_pts.is_empty():
		if _map_river == null:
			_map_river = Line2D.new()
			_map_river.width = 3.0
			_map_river.default_color = Color(0.30, 0.52, 0.66, 0.95)
			_map_river.joint_mode = Line2D.LINE_JOINT_ROUND
			map_panel.add_child(_map_river)
		var rpv := PackedVector2Array()
		for rp in river_pts:
			rpv.append(P.call(rp as Vector3))
		_map_river.points = rpv
		_map_river.visible = true
		for bi in range(bridges.size()):
			var bm: ColorRect = _map_bridge(bi)
			var bp2: Vector2 = P.call(bridges[bi] as Vector3)
			var bs := Vector2(7, 7)
			bm.position = bp2 - bs * 0.5
			bm.size = bs
			bm.visible = true
		for j in range(bridges.size(), _map_bridges.size()):
			(_map_bridges[j] as ColorRect).visible = false
	var reveal := _map_reveal
	# the named places: towns (public), and your own forts & depots. Enemy garrisons are fogged.
	var ti := 0
	for s in field_sites:
		var kind: String = s["kind"]
		var steam: int = int(s["team"])
		var mine: bool = player != null and steam == player.team
		var public_town: bool = kind == "town"
		if not (public_town or mine or reveal):
			continue                                  # enemy fort/depot: hidden unless dev-revealed
		var mk: Dictionary = _map_town(ti); ti += 1
		var box := mk["box"] as ColorRect
		var lbl := mk["lbl"] as Label
		var bp: Vector2 = P.call(s["pos"] as Vector3)
		var col: Color
		if kind == "town":
			col = Color(0.45, 0.62, 1.0) if steam == 0 else (Color(1.0, 0.5, 0.42) if steam == 1 else Color(0.78, 0.74, 0.62))
		else:
			col = (Color(0.5, 0.66, 1.0) if steam == 0 else Color(1.0, 0.55, 0.48))
		var bsz: Vector2 = Vector2(13, 13) if kind == "town" else (Vector2(11, 11) if kind == "fort" else Vector2(9, 9))
		box.color = col
		box.size = bsz
		box.pivot_offset = bsz * 0.5
		box.rotation = (PI * 0.25) if kind == "fort" else 0.0   # forts as a diamond, towns/depots square
		box.position = bp - bsz * 0.5
		box.visible = true
		# name towns always; name your own (or revealed) forts/depots — keeps the map legible
		if kind == "town" or mine or reveal:
			lbl.text = String(s["name"])
			lbl.add_theme_color_override("font_color", col.lightened(0.3) if kind == "town" else col.darkened(0.05))
			lbl.add_theme_font_size_override("font_size", 13 if kind == "town" else 11)
			lbl.position = bp + Vector2(9, -8)
			lbl.visible = true
		else:
			lbl.visible = false
	for j in range(ti, _map_towns.size()):
		var m2: Dictionary = _map_towns[j]
		(m2["box"] as ColorRect).visible = false
		(m2["lbl"] as Label).visible = false
	# YOUR forces (and, under dev reveal, the enemy's): a counter per living battalion
	var di := 0
	for b in battalions:
		if b.figs.is_empty():
			continue
		if not reveal and player != null and b.team != player.team:
			continue                                  # the enemy is fogged on the strategic map
		var sp: Vector2 = P.call(b.pos)
		var dot := _map_dot(di); di += 1
		var base: Color = (ARMY_BLUE.lightened(0.45) if b.team == 0 else ARMY_RED.lightened(0.32))
		if b.broken or b.state == "routing":
			base = base.darkened(0.45)
		var is_me: bool = b == player
		dot.color = Color(1.0, 0.88, 0.3) if is_me else base
		var sz := Vector2(11, 5) if is_me else (Vector2(8, 4) if not b.spent else Vector2(5, 3))
		dot.size = sz
		dot.pivot_offset = sz * 0.5
		dot.position = sp - sz * 0.5
		dot.rotation = atan2(sin(b.facing), cos(b.facing) * (-1.0 if flip else 1.0))
		dot.visible = true
	# a bright marker for where YOU ride
	if player != null:
		var rp: Vector2 = P.call(off_pos)
		var me := _map_dot(di); di += 1
		me.color = Color(1.0, 0.92, 0.4)
		var msz := Vector2(7, 7)
		me.size = msz
		me.pivot_offset = msz * 0.5
		me.rotation = PI * 0.25
		me.position = rp - msz * 0.5
		me.visible = true
	for j in range(di, _map_dots.size()):
		(_map_dots[j] as ColorRect).visible = false
	# the legend / readout
	var fr_live := 0
	var fr_broke := 0
	var towns_mine := 0
	for t in field_towns:
		if player != null and int(t["owner"]) == player.team:
			towns_mine += 1
	for b in battalions:
		if b.figs.is_empty():
			continue
		if player != null and b.team == player.team:
			if b.broken or b.state == "routing": fr_broke += 1
			else: fr_live += 1
	if map_legend != null:
		var clk := int(_time_of_day)
		var mins := int((_time_of_day - float(clk)) * 60.0)
		var rev := "   [color=#ff9a8a](dev: enemy revealed)[/color]" if reveal else ""
		map_legend.text = "[color=#9fb0c8]Your army: [/color][color=#bcd6ff]%d steady[/color] · [color=#ff9a8a]%d broken[/color]   [color=#9fb0c8]Towns held: [/color][color=#ffe9a8]%d / %d[/color]   [color=#9fb0c8]·  %02d:%02d[/color]   [color=#ffe9a8](M to close)[/color]%s" % [fr_live, fr_broke, towns_mine, field_towns.size(), clk, mins, rev]

func _map_bridge(i: int) -> ColorRect:
	while i >= _map_bridges.size():
		var d := ColorRect.new()
		d.color = Color(0.78, 0.66, 0.42)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_panel.add_child(d)
		_map_bridges.append(d)
	return _map_bridges[i]

func _map_dot(i: int) -> ColorRect:
	while i >= _map_dots.size():
		var d := ColorRect.new()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_panel.add_child(d)
		_map_dots.append(d)
	return _map_dots[i]

func _map_road(i: int) -> Line2D:
	while i >= _map_roads.size():
		var ln := Line2D.new()
		ln.width = 2.5
		ln.default_color = Color(0.52, 0.40, 0.24, 0.85)   # an inked road on the paper map
		ln.joint_mode = Line2D.LINE_JOINT_ROUND
		map_panel.add_child(ln)
		_map_roads.append(ln)
	return _map_roads[i]

func _map_town(i: int) -> Dictionary:
	while i >= _map_towns.size():
		var box := ColorRect.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_panel.add_child(box)
		var lbl := Label.new()
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_size_override("font_size", 12)
		map_panel.add_child(lbl)
		_map_towns.append({ "box": box, "lbl": lbl })
	return _map_towns[i]

# ============================================================ CAMP & COMMAND (C)
# A Football-Manager-style overview of your battalion: its skills, its condition, its
# companies and named men — and the orders to rest, drill, and promote.

func _build_camp(cl: CanvasLayer) -> void:
	camp_panel = Control.new()
	camp_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	camp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_panel.visible = false
	cl.add_child(camp_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.9)
	camp_panel.add_child(dim)          # STOP (default) absorbs clicks that miss the buttons
	var pc := PanelContainer.new()
	pc.anchor_left = 0.5
	pc.anchor_right = 0.5
	pc.anchor_top = 0.5
	pc.anchor_bottom = 0.5
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.97)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	pc.add_theme_stylebox_override("panel", sb)
	camp_panel.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	camp_label = RichTextLabel.new()
	camp_label.bbcode_enabled = true
	camp_label.fit_content = true
	camp_label.scroll_active = false
	camp_label.custom_minimum_size = Vector2(560, 0)
	camp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camp_label.add_theme_font_size_override("normal_font_size", 15)
	camp_label.add_theme_font_size_override("bold_font_size", 19)
	vb.add_child(camp_label)
	# the action bar — mouse-driven (the keyboard shortcuts still work too)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	vb.add_child(bar)
	_camp_btn_rest = Button.new()
	_camp_btn_rest.text = "Make Camp"
	_camp_btn_rest.pressed.connect(_camp_rest)
	bar.add_child(_camp_btn_rest)
	_camp_btn_drill = Button.new()
	_camp_btn_drill.text = "Drill"
	_camp_btn_drill.pressed.connect(_camp_train)
	bar.add_child(_camp_btn_drill)
	var bsup := Button.new()
	bsup.text = "Resupply"
	bsup.pressed.connect(_camp_resupply)
	bar.add_child(bsup)
	_camp_btn_recruit = Button.new()
	_camp_btn_recruit.text = "Recruit"
	_camp_btn_recruit.pressed.connect(_camp_recruit)
	bar.add_child(_camp_btn_recruit)
	_camp_btn_hire = Button.new()
	_camp_btn_hire.text = "Hire Officer"
	_camp_btn_hire.pressed.connect(_camp_hire_officer)
	bar.add_child(_camp_btn_hire)
	_camp_btn_equip = Button.new()
	_camp_btn_equip.text = "Buy Muskets"
	_camp_btn_equip.pressed.connect(_camp_equip)
	bar.add_child(_camp_btn_equip)
	var bins := Button.new()
	bins.text = "Inspect Companies ›"
	bins.pressed.connect(_open_roster)
	bar.add_child(bins)
	var bcl := Button.new()
	bcl.text = "Close (Esc)"
	bcl.pressed.connect(_close_camp)
	bar.add_child(bcl)

func _toggle_camp() -> void:
	if _camp_on:
		_close_camp()
		return
	_camp_on = true
	_roster_man = null
	if camp_panel != null:
		camp_panel.visible = true
	if roster_panel != null:
		roster_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the camp is a mouse-driven GUI
	_refresh_camp()

func _close_camp() -> void:
	_camp_on = false
	if camp_panel != null:
		camp_panel.visible = false
	if roster_panel != null:
		roster_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

func _bar(v: float, width: int) -> String:
	var filled := clampi(int(round(v / 100.0 * float(width))), 0, width)
	var col := "9fe0a0" if v >= 66.0 else ("ffcf6e" if v >= 40.0 else "ff9a8a")
	return "[color=#%s]%s[/color][color=#33394a]%s[/color]" % [col, "█".repeat(filled), "█".repeat(width - filled)]

func _fatigue_word(f: float) -> String:
	if f < 20.0: return "[color=#9fe0a0]fresh[/color]"
	if f < 45.0: return "[color=#cfe08a]winded[/color]"
	if f < 70.0: return "[color=#ffcf6e]weary[/color]"
	if f < 90.0: return "[color=#ff9a8a]flagging[/color]"
	return "[color=#ff5a4a]blown[/color]"

func _refresh_camp() -> void:
	if camp_label == null or player == null:
		return
	# the camp lives in-world: if somehow you are no longer at a town, strike it
	if _player_town().is_empty():
		_close_camp()
		_send_player_despatch("[color=#ffe9a8]You leave the town[/color] — camp is struck.", {})
		return
	var b := player
	var dash := "[color=#3f4658]————————————————————————————————[/color]\n"
	var seat: String = "  [color=#9fb0c8]at %s[/color]" % _camp_town if _camp_town != "" else ""
	var t := "[center][b][color=#ffd773]CAMP & COMMAND[/color][/b]%s[/center]\n" % seat
	t += "[b][color=#ffe9a8]%s[/color][/b]   [color=#9fb0c8](%s)[/color]\n" % [_unit_name(b), b.quality]
	t += "[color=#cdd6e6]%d / %d effectives · %d companies · %d rounds a man[/color]\n" % [b.figs.size(), b.start_men, b.companies, int(round(b.ammo))]
	if b.independent:
		t += "[color=#ffe9a8]Prestige: %d[/color]\n" % prestige
	t += dash
	t += "[b][color=#bcd6ff]SKILLS[/color][/b]\n"
	for key in SKILL_KEYS:
		var v := _sk(b, key)
		var drilling: String = "   [color=#ffe08a]‹ drilling[/color]" if b.train_skill == key else ""
		t += "[color=#cdd6e6]%s[/color]  %s  [color=#e8ecf5]%d[/color]%s\n" % [SKILL_NAMES[key], _bar(v, 14), int(round(v)), drilling]
	t += dash
	t += "[b][color=#bcd6ff]CONDITION[/color][/b]\n"
	t += "[color=#cdd6e6]Fatigue[/color]  %s  %s\n" % [_bar(b.fatigue, 14), _fatigue_word(b.fatigue)]
	var mword := "BROKEN" if b.broken else ("running" if b.state == "routing" else ("shaken" if b.state == "shaken" else "steady"))
	t += "[color=#cdd6e6]Nerve[/color] %d · [color=#cdd6e6]order[/color] %d (%s)\n" % [int(round(b.morale)), int(round(b.cohesion)), mword]
	if b.encamped:
		if _camp_safe(b):
			t += "[color=#9fe0a0]● ENCAMPED — the men rest and drill[/color]\n"
		else:
			t += "[color=#ff9a8a]● ordered to camp, but the enemy stands too near to rest[/color]\n"
	t += dash
	t += "[b][color=#bcd6ff]COMPANIES[/color][/b]\n"
	t += _company_lines(b)
	t += dash
	var tw: String = SKILL_NAMES.get(b.train_skill, "none") if b.train_skill != "" else "none"
	t += "[color=#9fb0c8]Drilling: [/color][color=#e8ecf5]%s[/color]   [color=#9fb0c8]·  use the buttons below[/color]" % tw
	camp_label.text = t
	if _camp_btn_rest != null:
		_camp_btn_rest.text = "Break Camp" if b.encamped else "Make Camp"
	if _camp_btn_drill != null:
		_camp_btn_drill.text = "Drill: %s" % tw
	if _camp_btn_recruit != null:
		_camp_btn_recruit.visible = b.independent
	if _camp_btn_hire != null:
		_camp_btn_hire.visible = b.independent
	if _camp_btn_equip != null:
		_camp_btn_equip.visible = b.independent

# One line per company: its strength and the senior man standing with it.
func _company_lines(b: Batt) -> String:
	if b.roster.is_empty():
		return "[color=#9fb0c8](no roster)[/color]\n"
	var rankval := { "Pte.": 0, "Cpl.": 1, "Sgt.": 2, "C/Sgt.": 3, "Lt.": 4, "Capt.": 5 }
	var counts: Array = []
	var leaders: Array = []
	var lead_rv: Array = []
	for i in range(b.companies):
		counts.append(0); leaders.append(""); lead_rv.append(-1)
	for m in b.roster:
		if not m["alive"]:
			continue
		var c: int = clampi(int(m["coy"]), 0, b.companies - 1)
		counts[c] += 1
		var rv: int = int(rankval.get(m["rank"], 0))
		if rv > int(lead_rv[c]):
			lead_rv[c] = rv
			leaders[c] = "%s %s" % [m["rank"], m["name"]]
	var out := ""
	for i in range(b.companies):
		var ld: String = leaders[i] if String(leaders[i]) != "" else "(no NCO)"
		out += "[color=#9fb0c8]%d Coy[/color]  [color=#cdd6e6]%2d men[/color]  [color=#e8ecf5]%s[/color]\n" % [i + 1, int(counts[i]), ld]
	return out

# ----------------------------------------------- the interactive company roster (V)
const _RANK_ORDER := { "Pte.": 0, "Cpl.": 1, "Sgt.": 2, "C/Sgt.": 3, "Lt.": 4, "Capt.": 5 }
const _RANK_LADDER := ["Pte.", "Cpl.", "Sgt.", "C/Sgt."]   # the ladder you can promote/reduce along
const _SK_ABBR := { "reload": "Dr", "aim": "Mk", "melee": "By", "discipline": "Di", "stamina": "St" }

# The living men of the selected company, seniors first.
func _roster_coy_men(b: Batt) -> Array:
	var out: Array = []
	for m in b.roster:
		if m["alive"] and int(m["coy"]) == _roster_coy:
			out.append(m)
	out.sort_custom(func(a, c):
		var ra: int = int(_RANK_ORDER.get(a["rank"], 0))
		var rc: int = int(_RANK_ORDER.get(c["rank"], 0))
		if ra != rc:
			return ra > rc
		return String(a["name"]) < String(c["name"]))
	return out

func _roster_selected_man():
	if _roster_man == null:
		return null
	if not bool(_roster_man.get("alive", false)):
		return null
	return _roster_man

# ---- the GUI: a left rail of company tabs, the company's men in the middle, and the
# selected soldier's card with his actions on the right. All mouse-driven.
func _build_roster_ui(cl: CanvasLayer) -> void:
	roster_panel = Control.new()
	roster_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	roster_panel.visible = false
	cl.add_child(roster_panel)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.04, 0.06, 0.92)
	roster_panel.add_child(dim)                       # STOP (default) absorbs stray clicks
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.07, 0.10, 0.98)
	sb.border_color = Color(1.0, 0.84, 0.42, 0.7)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)
	roster_panel.add_child(pc)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	pc.add_child(root)
	var title := Label.new()
	title.name = "title"
	title.text = "COMPANY ROSTER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	root.add_child(title)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	main.custom_minimum_size = Vector2(880, 470)
	root.add_child(main)
	# left: the company tabs (grouping)
	_roster_tabs = VBoxContainer.new()
	_roster_tabs.add_theme_constant_override("separation", 4)
	_roster_tabs.custom_minimum_size = Vector2(150, 0)
	main.add_child(_roster_tabs)
	# middle: the men of the open company, in a scroll
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(420, 470)
	main.add_child(scroll)
	_roster_list = VBoxContainer.new()
	_roster_list.add_theme_constant_override("separation", 2)
	_roster_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_list)
	# right: the selected man's card + actions
	_roster_detail = VBoxContainer.new()
	_roster_detail.add_theme_constant_override("separation", 8)
	_roster_detail.custom_minimum_size = Vector2(290, 0)
	main.add_child(_roster_detail)
	# bottom: back / close
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	root.add_child(foot)
	var back := Button.new()
	back.text = "‹ Back to Camp"
	back.pressed.connect(_close_roster)
	foot.add_child(back)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(func(): _close_roster(); _close_camp())
	foot.add_child(close)

func _open_roster() -> void:
	if roster_panel == null or player == null:
		return
	if _roster_coy >= player.companies:
		_roster_coy = 0
	camp_panel.visible = false
	roster_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_roster_ui()

func _close_roster() -> void:
	if roster_panel != null:
		roster_panel.visible = false
	if _camp_on and camp_panel != null:
		camp_panel.visible = true            # back to the camp overview

func _refresh_roster_ui() -> void:
	if roster_panel == null or not roster_panel.visible or player == null:
		return
	var b := player
	# rebuild the company tabs
	for c in _roster_tabs.get_children():
		_roster_tabs.remove_child(c)
		c.queue_free()
	# count living men per company
	var counts: Array = []
	for i in range(b.companies):
		counts.append(0)
	for m in b.roster:
		if m["alive"]:
			var ci: int = clampi(int(m["coy"]), 0, b.companies - 1)
			counts[ci] += 1
	for i in range(b.companies):
		var tb := Button.new()
		tb.text = "No. %d Coy   %d" % [i + 1, int(counts[i])]
		tb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tb.toggle_mode = true
		tb.button_pressed = (i == _roster_coy)
		var ci := i
		tb.pressed.connect(func(): _roster_pick_company(ci))
		_roster_tabs.add_child(tb)
	# rebuild the soldier list for the open company
	for c in _roster_list.get_children():
		_roster_list.remove_child(c)
		c.queue_free()
	var men := _roster_coy_men(b)
	if _roster_man != null:
		var still := false
		for mm in men:
			if is_same(mm, _roster_man):
				still = true
				break
		if not still:
			_roster_man = null
	for m in men:
		var row := Button.new()
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = is_same(m, _roster_man)
		var fck: String = m.get("focus", "")
		var foc: String = "   ‹%s" % _SK_ABBR.get(fck, "") if fck != "" else ""
		row.text = "%-7s %-16s  Dr%d Mk%d By%d Di%d St%d%s" % [m["rank"], m["name"],
			int(m["reload"]), int(m["aim"]), int(m["melee"]), int(m["discipline"]), int(m["stamina"]), foc]
		row.add_theme_font_size_override("font_size", 13)
		var man = m
		row.pressed.connect(func(): _roster_pick_man(man))
		_roster_list.add_child(row)
	_refresh_roster_detail()

func _roster_pick_company(ci: int) -> void:
	_roster_coy = ci
	_refresh_roster_ui()

func _roster_pick_man(m) -> void:
	_roster_man = m
	_refresh_roster_ui()

func _refresh_roster_detail() -> void:
	for c in _roster_detail.get_children():
		_roster_detail.remove_child(c)
		c.queue_free()
	var m = _roster_selected_man()
	if m == null:
		var hint := Label.new()
		hint.text = "Select a soldier\nto inspect and train him."
		hint.add_theme_color_override("font_color", Color(0.62, 0.66, 0.74))
		_roster_detail.add_child(hint)
		return
	var card := RichTextLabel.new()
	card.bbcode_enabled = true
	card.fit_content = true
	card.custom_minimum_size = Vector2(280, 0)
	var t := "[b][color=#ffe9a8]%s[/color][/b]\n[color=#bcd6ff]%s · No. %d Coy[/color]\n\n" % [m["name"], m["rank"], int(m["coy"]) + 1]
	for key in SKILL_KEYS:
		var v := float(m[key])
		var foc: String = "  [color=#ffe08a]‹ drilling[/color]" if String(m.get("focus", "")) == key else ""
		t += "[color=#cdd6e6]%-13s[/color] %s [color=#e8ecf5]%d[/color]%s\n" % [SKILL_NAMES[key], _bar(v, 12), int(round(v)), foc]
	t += "\n[color=#9fb0c8]kills %d · seasoning %d[/color]" % [int(m["kills"]), int(m["xp"])]
	_roster_detail.add_child(card)
	card.text = t
	# focus drill selector
	var foc_row := HBoxContainer.new()
	var foc_lbl := Label.new(); foc_lbl.text = "Focus drill:"
	foc_row.add_child(foc_lbl)
	var opt := OptionButton.new()
	opt.add_item("None", 0)
	for i in range(SKILL_KEYS.size()):
		opt.add_item(SKILL_NAMES[SKILL_KEYS[i]], i + 1)
	var cur: String = m.get("focus", "")
	opt.selected = (SKILL_KEYS.find(cur) + 1) if cur != "" else 0
	opt.item_selected.connect(_roster_set_focus)
	foc_row.add_child(opt)
	_roster_detail.add_child(foc_row)
	# promote / reduce
	var pk := HBoxContainer.new()
	pk.add_theme_constant_override("separation", 6)
	var pb := Button.new(); pb.text = "Promote"; pb.pressed.connect(_roster_promote)
	var kb := Button.new(); kb.text = "Reduce"; kb.pressed.connect(_roster_demote)
	pk.add_child(pb); pk.add_child(kb)
	_roster_detail.add_child(pk)
	# rename
	var rn := HBoxContainer.new()
	rn.add_theme_constant_override("separation", 6)
	var edit := LineEdit.new()
	edit.text = String(m["name"])
	edit.custom_minimum_size = Vector2(170, 0)
	edit.max_length = 22
	edit.text_submitted.connect(_roster_apply_rename)
	rn.add_child(edit)
	var setb := Button.new(); setb.text = "Rename"
	setb.pressed.connect(func(): _roster_apply_rename(edit.text))
	rn.add_child(setb)
	_roster_detail.add_child(rn)

func _roster_set_focus(idx: int) -> void:
	var m = _roster_selected_man()
	if m == null:
		return
	m["focus"] = "" if idx <= 0 else SKILL_KEYS[idx - 1]
	var fw: String = SKILL_NAMES.get(m["focus"], "—") if String(m["focus"]) != "" else "none"
	_send_player_despatch("[color=#ffe08a]%s now drilling: %s[/color]" % [m["name"], fw], {})
	_refresh_roster_ui()

func _roster_promote() -> void:
	var m = _roster_selected_man()
	if m == null:
		return
	var idx := _RANK_LADDER.find(String(m["rank"]))
	if idx < 0:
		_send_player_despatch("[color=#9fb0c8]%s holds a commission — not yours to promote.[/color]" % m["rank"], {})
		return
	if idx >= _RANK_LADDER.size() - 1:
		_send_player_despatch("[color=#9fb0c8]%s is already a Colour-Sergeant.[/color]" % m["name"], {})
		return
	m["rank"] = _RANK_LADDER[idx + 1]
	m["discipline"] = clampf(float(m["discipline"]) + 3.0, 6.0, 99.0)
	_reprofile(player)
	_send_player_despatch("[color=#9fe0a0]%s promoted to %s.[/color]" % [m["name"], m["rank"]], {})
	_refresh_roster_ui()

func _roster_demote() -> void:
	var m = _roster_selected_man()
	if m == null:
		return
	var idx := _RANK_LADDER.find(String(m["rank"]))
	if idx < 0:
		_send_player_despatch("[color=#9fb0c8]%s holds a commission — not yours to reduce.[/color]" % m["rank"], {})
		return
	if idx == 0:
		_send_player_despatch("[color=#9fb0c8]%s is already a private.[/color]" % m["name"], {})
		return
	m["rank"] = _RANK_LADDER[idx - 1]
	m["discipline"] = clampf(float(m["discipline"]) - 3.0, 6.0, 99.0)
	_reprofile(player)
	_send_player_despatch("[color=#ffcf6e]%s reduced to %s.[/color]" % [m["name"], m["rank"]], {})
	_refresh_roster_ui()

func _roster_apply_rename(text: String) -> void:
	var m = _roster_selected_man()
	if m == null:
		return
	var nm := text.strip_edges()
	if nm != "":
		m["name"] = nm
		_send_player_despatch("[color=#9fe0a0]Henceforth: %s %s.[/color]" % [m["rank"], nm], {})
	_refresh_roster_ui()

# Order the battalion to make/break camp (rest), cycle the drill, or shuffle the NCOs.
func _camp_rest() -> void:
	if player == null:
		return
	player.encamped = not player.encamped
	if player.encamped and not _camp_safe(player):
		_send_player_despatch("[color=#ff9a8a]You cannot make camp with the enemy so near.[/color]", {})
	else:
		_send_player_despatch("[color=#ffe9a8]%s[/color]" % ("The battalion makes camp — stand easy." if player.encamped else "Strike camp — to arms!"), {})
	_refresh_camp()

func _camp_train() -> void:
	if player == null:
		return
	_train_idx = (_train_idx + 1) % (SKILL_KEYS.size() + 1)
	player.train_skill = "" if _train_idx >= SKILL_KEYS.size() else SKILL_KEYS[_train_idx]
	_refresh_camp()

func _best_by_discipline(pool: Array):
	var best = null
	var bv := -1.0
	for m in pool:
		if float(m["discipline"]) > bv:
			bv = float(m["discipline"])
			best = m
	return best

func _camp_promote() -> void:
	if player == null or player.roster.is_empty():
		return
	var b := player
	var ptes: Array = []
	var cpls: Array = []
	var sgts: Array = []
	for m in b.roster:
		if not m["alive"]:
			continue
		match m["rank"]:
			"Pte.": ptes.append(m)
			"Cpl.": cpls.append(m)
			"Sgt.": sgts.append(m)
	var strength := b.figs.size()
	var ideal_sgt := clampi(int(ceil(float(strength) / 90.0)), 2, 12)
	var ideal_cpl := clampi(int(ceil(float(strength) / 40.0)), 4, 24)
	var man = null
	var newrank := ""
	if sgts.size() < ideal_sgt and not cpls.is_empty():
		man = _best_by_discipline(cpls); newrank = "Sgt."
	elif cpls.size() < ideal_cpl and not ptes.is_empty():
		man = _best_by_discipline(ptes); newrank = "Cpl."
	if man == null:
		_send_player_despatch("[color=#9fb0c8]No vacancies — your NCOs are at full strength.[/color]", {})
		return
	var oldrank: String = man["rank"]
	man["rank"] = newrank
	man["discipline"] = clampf(float(man["discipline"]) + 6.0, 6.0, 99.0)
	b.skill["discipline"] = minf(95.0, _sk(b, "discipline") + 1.1)   # a steadier chain of command
	_send_player_despatch("[color=#9fe0a0]%s %s raised to %s.[/color]" % [oldrank, man["name"], newrank], {})
	_refresh_camp()

func _camp_demote() -> void:
	if player == null or player.roster.is_empty():
		return
	var b := player
	var down := { "Cpl.": "Pte.", "Sgt.": "Cpl.", "C/Sgt.": "Sgt." }
	var worst = null
	var wv := 1.0e9
	for m in b.roster:
		if not m["alive"] or not (m["rank"] in down):
			continue
		if float(m["discipline"]) < wv:
			wv = float(m["discipline"])
			worst = m
	if worst == null:
		_send_player_despatch("[color=#9fb0c8]No NCOs to reduce.[/color]", {})
		return
	var oldrank: String = worst["rank"]
	worst["rank"] = down[oldrank]
	worst["discipline"] = clampf(float(worst["discipline"]) - 3.0, 6.0, 99.0)
	b.skill["discipline"] = maxf(8.0, _sk(b, "discipline") - 0.9)
	_send_player_despatch("[color=#ffcf6e]%s %s reduced to %s.[/color]" % [oldrank, worst["name"], down[oldrank]], {})
	_refresh_camp()

# The town quartermaster: spend prestige at the depot to refill the battalion's
# cartridge boxes. The cost scales with how empty they are.
const RESUPPLY_FULL_COST := 45     # prestige to fill cartridge boxes from bone-dry
func _camp_resupply() -> void:
	if player == null:
		return
	var deficit := START_ROUNDS - player.ammo
	if deficit <= 0.5:
		_send_player_despatch("[color=#9fe0a0]The cartridge boxes are already full.[/color]", {})
		return
	var cost := int(ceil(deficit / START_ROUNDS * float(RESUPPLY_FULL_COST)))
	if prestige < cost:
		_send_player_despatch("[color=#ff9a8a]The quartermaster wants %d prestige for a resupply — you have %d.[/color]" % [cost, prestige], {})
		return
	prestige -= cost
	player.ammo = START_ROUNDS
	_send_player_despatch("[color=#9fe0a0]Cartridge boxes filled at the depot[/color] — %d prestige to the quartermaster." % cost, {})
	_refresh_camp()

# Recruiting (Phase 1): an independent militia takes on men only at a town in its own
# country — not a fort or depot, and not enemy ground. The price rises as the
# battalion grows, so a small militia stays a real choice, not a free snowball.
const RECRUIT_BATCH := 10           # men taken on at a time
const RECRUIT_COST_PER_MAN := 3     # prestige per recruit, before the size surcharge
func _camp_recruit() -> void:
	if player == null or not player.independent:
		return
	var town := _player_town()
	if town.is_empty() or town.has("kind"):
		_send_player_despatch("[color=#ff9a8a]Recruiting needs a town, not a garrison.[/color]", {})
		return
	if player.figs.size() >= MILITIA_MAX_MEN:
		_send_player_despatch("[color=#9fb0c8]The battalion is at full strength — there's no more room in the ranks.[/color]", {})
		return
	var n := mini(RECRUIT_BATCH, MILITIA_MAX_MEN - player.figs.size())
	var surcharge := 1.0 + float(player.figs.size()) / 200.0
	var cost := int(ceil(float(n) * float(RECRUIT_COST_PER_MAN) * surcharge))
	if prestige < cost:
		_send_player_despatch("[color=#ff9a8a]Recruiting %d more would cost %d prestige — you have %d.[/color]" % [n, cost, prestige], {})
		return
	prestige -= cost
	_recruit_men(player, n)
	_send_player_despatch("[color=#9fe0a0]%d men enlist at %s[/color] — %d prestige spent." % [n, String(town.get("name", "the town")), cost], {})
	_refresh_camp()

# Fold n green recruits into a battalion: new figures fall in behind the colours and
# walk up into their slot, new named men join the roster well below the veterans'
# polish, and the living profile is re-derived so the new hands drag the average down
# a touch — exactly as drilling and blooding will bring them up over time.
func _recruit_men(b: Batt, n: int) -> void:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	for i in range(n):
		var w := b.pos - fwd * 6.0
		b.figs.append({ "slot": Vector2.ZERO, "wpos": Vector3(w.x, 0, w.z), "ph": randf() * TAU,
			"spd": randf_range(0.85, 1.18), "reload": randf_range(0.0, RELOAD_TIME),
			"company": 0, "face": 0.0,
			"bw": randf_range(0.92, 1.07), "bh": randf_range(0.90, 1.10),
			"wear": randf_range(0.82, 1.07), "march": 0.0,
			"flinch": 0.0, "nerve": randf_range(0.0, 1.0) })
	_reslot(b)
	if not b.roster.is_empty():
		for i in range(n):
			var coy := b.roster.size() % b.companies
			var man := { "name": _rand_name(), "rank": "Pte.", "coy": coy,
				"xp": 0.0, "kills": 0, "alive": true, "focus": "" }
			for key in SKILL_KEYS:
				man[key] = clampf(_sk(b, key) - 14.0 + randf_range(-8.0, 8.0), 6.0, 90.0)
			b.roster.append(man)
		_reprofile(b)
	b.start_men = maxi(b.start_men, b.figs.size())

# Hire an officer (Phase 1): commission a Lieutenant over the first company that lacks
# one, raised from its most promising NCO/man. A separate mechanic from the NCO ladder
# (promote/demote) — this is a commission, bought with prestige, not earned in the ranks.
const HIRE_OFFICER_COST := 80
func _camp_hire_officer() -> void:
	if player == null or not player.independent or player.roster.is_empty():
		return
	var b := player
	var has_off := {}
	for m in b.roster:
		if m["alive"] and String(m["rank"]) in ["Lt.", "Capt."]:
			has_off[int(m["coy"])] = true
	var coy := -1
	for c in range(b.companies):
		if not has_off.has(c):
			coy = c
			break
	if coy == -1:
		_send_player_despatch("[color=#9fb0c8]Every company already has its officer.[/color]", {})
		return
	if prestige < HIRE_OFFICER_COST:
		_send_player_despatch("[color=#ff9a8a]Commissioning an officer costs %d prestige — you have %d.[/color]" % [HIRE_OFFICER_COST, prestige], {})
		return
	var pool: Array = []
	for m in b.roster:
		if m["alive"] and int(m["coy"]) == coy and String(m["rank"]) != "Capt.":
			pool.append(m)
	if pool.is_empty():
		return
	var man = _best_by_discipline(pool)
	prestige -= HIRE_OFFICER_COST
	man["rank"] = "Lt."
	for key in SKILL_KEYS:
		man[key] = clampf(float(man[key]) + 9.0, 6.0, 99.0)
	_send_player_despatch("[color=#9fe0a0]%s commissioned Lieutenant of No. %d Company.[/color]" % [man["name"], coy + 1], {})
	_refresh_camp()

# Buy gear (Phase 1): better muskets and kit from the town armourer, a flat prestige
# spend that lifts marksmanship and loading a notch for every man, veteran and recruit
# alike — instant, unlike drill, but with no ceiling-breaking effect on its own.
const EQUIP_COST := 60
const EQUIP_AIM_GAIN := 6.0
func _camp_equip() -> void:
	if player == null or not player.independent:
		return
	if prestige < EQUIP_COST:
		_send_player_despatch("[color=#ff9a8a]Better muskets cost %d prestige — you have %d.[/color]" % [EQUIP_COST, prestige], {})
		return
	prestige -= EQUIP_COST
	var b := player
	b.skill["aim"] = clampf(_sk(b, "aim") + EQUIP_AIM_GAIN, 6.0, 99.0)
	b.skill["reload"] = clampf(_sk(b, "reload") + EQUIP_AIM_GAIN * 0.6, 6.0, 99.0)
	b.exp_mul = _reload_factor(b)
	for m in b.roster:
		if m["alive"]:
			m["aim"] = clampf(float(m["aim"]) + EQUIP_AIM_GAIN, 6.0, 99.0)
			m["reload"] = clampf(float(m["reload"]) + EQUIP_AIM_GAIN * 0.6, 6.0, 99.0)
	_send_player_despatch("[color=#9fe0a0]New muskets issued from store[/color] — %d prestige spent." % EQUIP_COST, {})
	_refresh_camp()

# ---------------------------------------------------------------- terrain & scenery

# The battlefield floor stays flat (the whole sim is on the plane); the terrain,
# woods and villages frame it as scenery so the field reads as a real valley.
func _build_scenery() -> void:
	# the old decorative dome "hills" are gone — the ground itself now rolls (see _gh)
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
		if pos.x > COAST_X - 200.0:
			mm.set_instance_transform(i, _zero_xf())   # the eastern ring is open sea now
			continue
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
			var tgh := _gh(p.x, p.z)
			trunk_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 2.0 * s + tgh, p.z)))
			foliage_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 5.6 * s + tgh, p.z)))
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
			wall_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx, wy, wz)), Vector3(p.x, wy * 0.5 + _gh(p.x, p.z), p.z)))
			roof_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx * 1.06, roofh, wz * 1.06)), Vector3(p.x, wy + roofh * 0.5 + _gh(p.x, p.z), p.z)))
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

# The two market towns nearest the coast on each side — Crown-held Hartsfield, Continental-
# held Oakford — are the navy's future build-points: a visible shipyard goes up at each now,
# ahead of the actual design/spawn logic that will one day launch a side's fleet from here.
const SHIPYARD_TOWNS := ["Hartsfield", "Oakford"]

# The province's towns, spread across the wider map — the strategic landmarks brought
# INTO the tactical scene (the first of world.gd's content to live in the one world).
# Far out and fogged: you ride toward them, not survey them from afar.
func _build_field_settlements() -> void:
	var towns := [
		["Fairhaven", Vector3(-7600, 0, 7200), 3],
		["Bridgewater", Vector3(-3400, 0, 4600), 2],
		["Greenfield", Vector3(-6400, 0, 2200), 2],
		["Millbrook", Vector3(-800, 0, 1100), 2],
		["Stonebrook", Vector3(-5600, 0, -1400), 2],
		["Oakford", Vector3(900, 0, 3400), 2],
		["Hartsfield", Vector3(-2200, 0, -4800), 1],
		["Kingsferry", Vector3(-6800, 0, -5200), 2],
		["Drayton", Vector3(-3800, 0, 6800), 1],
		["Redding", Vector3(-8000, 0, -7600), 3],
	]
	# towns sized to the army scale: a market town is hundreds of houses across half a
	# kilometre, dense at its heart and thinning to the edges, with a church at its centre
	var total := 0
	for t in towns:
		total += 50 + int(t[2]) * 55
	var wall_mm := _make_scenery_mm(_box(1, 1, 1), Color(0.76, 0.71, 0.61), total)
	var roof_mm := _make_scenery_mm(_prism(1, 1, 1), Color(0.46, 0.25, 0.18), total)
	var ti := 0
	for t in towns:
		var c: Vector3 = t[1]
		var sz: int = int(t[2])
		var n := 50 + sz * 55
		var rad := 200.0 + float(sz) * 150.0
		for j in range(n):
			var a := randf() * TAU
			var rr := pow(randf(), 0.6) * rad          # denser toward the centre
			var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
			var core := 1.0 - rr / rad                  # taller, larger houses at the heart
			var two_storey := randf() < 0.25 + core * 0.4
			var wx := randf_range(6.0, 11.0)
			var wy := randf_range(4.5, 6.5) * (1.7 if two_storey else 1.0)
			var wz := randf_range(5.0, 9.0)
			var rh := randf_range(2.6, 4.6)
			var yaw := randf() * TAU
			var rot := Basis(Vector3.UP, yaw)
			wall_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx, wy, wz)), Vector3(p.x, wy * 0.5 + _gh(p.x, p.z), p.z)))
			roof_mm.set_instance_transform(ti, Transform3D(rot.scaled(Vector3(wx * 1.06, rh, wz * 1.06)), Vector3(p.x, wy + rh * 0.5 + _gh(p.x, p.z), p.z)))
			ti += 1
		_build_church(c)
		var has_yard := String(t[0]) in SHIPYARD_TOWNS
		if has_yard:
			_build_shipyard(c)
		# (no floating name billboard — you learn a place's name as a quiet toast on arrival)
		# the town starts in the hands of whichever army's country it sits in (north Crown,
		# south Continental, the middle neutral) — and can change hands as the war moves
		var owner := -1
		if c.z < -1800.0:
			owner = 0
		elif c.z > 1800.0:
			owner = 1
		# (no coloured ownership disc on the ground — ownership reads from the M map instead)
		field_towns.append({ "name": String(t[0]), "pos": c, "size": sz, "owner": owner,
			"cap_t": 0.0, "cap_team": -1, "disc": null, "shipyard": has_yard })

# A parish church at the heart of a town: a stone nave, a square tower and a spire —
# the landmark you pick the town out by from across the fields.
func _build_church(c: Vector3) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.66, 0.64, 0.58)
	stone.roughness = 1.0
	var slate := StandardMaterial3D.new()
	slate.albedo_color = Color(0.30, 0.32, 0.36)
	slate.roughness = 1.0
	var off := Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
	var gy := _gh(c.x + off.x, c.z + off.z)
	var nave := MeshInstance3D.new()
	nave.mesh = _box(13, 11, 26)
	nave.material_override = stone
	nave.position = c + off + Vector3(0, 5.5 + gy, 0)
	add_child(nave)
	var roof := MeshInstance3D.new()
	roof.mesh = _prism(13.6, 5.0, 26.6)
	roof.material_override = slate
	roof.position = c + off + Vector3(0, 13.5 + gy, 0)
	add_child(roof)
	var tower := MeshInstance3D.new()
	tower.mesh = _box(7, 24, 7)
	tower.material_override = stone
	tower.position = c + off + Vector3(0, 12 + gy, -15)
	add_child(tower)
	var spire := MeshInstance3D.new()
	var sp := CylinderMesh.new()
	sp.top_radius = 0.2; sp.bottom_radius = 4.0; sp.height = 12.0; sp.radial_segments = 6
	spire.mesh = sp
	spire.material_override = slate
	spire.position = c + off + Vector3(0, 30 + gy, -15)
	add_child(spire)

# A shipyard at the edge of a market town: a slipway with a part-built hull on the stocks
# (a keel and a row of ribs — the unmistakable skeleton of a ship under construction), a
# timber-built yard crane for lowering frames and masts into place, stacked seasoning logs,
# and a sawpit shed. Marks the spot a side's navy will one day be designed and launched from.
func _build_shipyard(c: Vector3) -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.42, 0.30, 0.18); timber.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.08, 0.07); dark.roughness = 1.0
	var deckwood := StandardMaterial3D.new()
	deckwood.albedo_color = Color(0.50, 0.40, 0.26); deckwood.roughness = 1.0
	var log := StandardMaterial3D.new()
	log.albedo_color = Color(0.55, 0.40, 0.22); log.roughness = 1.0
	var off := Vector3(randf_range(-20.0, 20.0), 0, randf_range(-20.0, 20.0))
	var gy := _gh(c.x + off.x, c.z + off.z)
	var base := c + off + Vector3(0, gy, 0)
	# the slipway: a long inclined way a hull is built on and would be launched down
	var way := MeshInstance3D.new()
	way.mesh = _box(8.0, 0.6, 34.0)
	way.material_override = deckwood
	way.rotation_degrees = Vector3(-6.0, 0, 0)
	way.position = base + Vector3(0, 1.0, 0)
	add_child(way)
	# a part-built hull on the stocks: a keel and a row of ribs
	var keel := MeshInstance3D.new()
	keel.mesh = _box(1.2, 1.0, 30.0)
	keel.material_override = timber
	keel.position = base + Vector3(0, 2.4, -2.0)
	add_child(keel)
	for i in range(9):
		var rz := -12.0 + float(i) * 3.0
		var rib := MeshInstance3D.new()
		rib.mesh = _box(7.0, 4.0, 0.6)
		rib.material_override = timber
		rib.position = base + Vector3(0, 4.6, rz - 2.0)
		add_child(rib)
	# the yard crane: an A-frame with a raking boom, for swinging frames and masts into place
	var legA := MeshInstance3D.new()
	legA.mesh = _box(0.5, 9.0, 0.5)
	legA.material_override = dark
	legA.position = base + Vector3(-2.2, 4.5, 16.0)
	legA.rotation_degrees = Vector3(0, 0, 8.0)
	add_child(legA)
	var legB := MeshInstance3D.new()
	legB.mesh = _box(0.5, 9.0, 0.5)
	legB.material_override = dark
	legB.position = base + Vector3(2.2, 4.5, 16.0)
	legB.rotation_degrees = Vector3(0, 0, -8.0)
	add_child(legB)
	var boom := MeshInstance3D.new()
	boom.mesh = _box(0.4, 0.4, 9.0)
	boom.material_override = dark
	boom.position = base + Vector3(0, 9.2, 20.0)
	boom.rotation_degrees = Vector3(-20.0, 0, 0)
	add_child(boom)
	# stacks of seasoning ship's timber beside the ways
	for i in range(3):
		var pile := MeshInstance3D.new()
		pile.mesh = _cylinder(0.35, 9.0)
		pile.material_override = log
		pile.rotation_degrees = Vector3(0, 0, 90.0)
		pile.position = base + Vector3(7.0 + float(i % 2), 0.4 + float(i) * 0.7, -16.0 + float(i) * 1.2)
		add_child(pile)
	# a sawpit shed at the head of the ways
	var shed := MeshInstance3D.new()
	shed.mesh = _box(6.0, 4.0, 5.0)
	shed.material_override = timber
	shed.position = base + Vector3(8.0, 2.0, 14.0)
	add_child(shed)
	var shed_roof := MeshInstance3D.new()
	shed_roof.mesh = _prism(6.4, 2.4, 5.4)
	shed_roof.material_override = dark
	shed_roof.position = base + Vector3(8.0, 5.2, 14.0)
	add_child(shed_roof)

# The lived-in countryside: farmsteads scattered across the land between the towns —
# a farmhouse and barn, a haystack, a tilled field, a paddock fence and grazing stock.
# Kept clear of the towns and the garrisons, seeded so MP peers see the same country.
func _build_homesteads() -> void:
	if _inflated or hosted:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (GameConfig.match_seed if GameConfig.match_seed != 0 else 1) ^ 0x9e3779b9
	var n := 60
	var house_w := _make_scenery_mm(_box(1, 1, 1), Color(0.80, 0.74, 0.62), n)      # farmhouse
	var house_r := _make_scenery_mm(_prism(1, 1, 1), Color(0.44, 0.23, 0.17), n)
	var barn_w := _make_scenery_mm(_box(1, 1, 1), Color(0.55, 0.27, 0.21), n)        # red barn
	var barn_r := _make_scenery_mm(_prism(1, 1, 1), Color(0.32, 0.17, 0.13), n)
	var hay_mm := _make_scenery_mm(_cylinder(1, 1), Color(0.84, 0.71, 0.34), n)      # haystack
	var field_mm := _make_scenery_mm(_box(1, 1, 1), Color(0.38, 0.33, 0.18), n)      # tilled field
	var fence_mm := _make_scenery_mm(_box(1, 1, 1), Color(0.40, 0.30, 0.18), n * 4)  # paddock rails
	var stock_mm := _make_scenery_mm(_box(1, 1, 1), Color(0.34, 0.26, 0.20), n * 6)  # grazing beasts
	var hi := 0
	var fi := 0
	var si := 0
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 40:
		tries += 1
		var x := rng.randf_range(-8600.0, COAST_X - 280.0)
		var z := rng.randf_range(-8400.0, 8400.0)
		var p := Vector3(x, 0, z)
		var ok := true
		for t in field_towns:
			if p.distance_to(t["pos"]) < 650.0 + float(t["size"]) * 150.0:
				ok = false; break
		if ok:
			for s in field_sites:
				if String(s["kind"]) != "town" and p.distance_to(s["pos"]) < 380.0:
					ok = false; break
		if not ok:
			continue
		placed += 1
		var yaw := rng.randf_range(0.0, TAU)
		var rot := Basis(Vector3.UP, yaw)
		# farmhouse
		var hw := rng.randf_range(6.0, 9.0); var hh := rng.randf_range(4.0, 5.5); var hd := rng.randf_range(5.0, 7.0)
		var hrh := rng.randf_range(2.4, 3.6)
		var hgh := _gh(x, z)
		house_w.set_instance_transform(hi, Transform3D(rot.scaled(Vector3(hw, hh, hd)), Vector3(x, hh * 0.5 + hgh, z)))
		house_r.set_instance_transform(hi, Transform3D(rot.scaled(Vector3(hw * 1.08, hrh, hd * 1.08)), Vector3(x, hh + hrh * 0.5 + hgh, z)))
		# barn, off to one side
		var bo: Vector3 = rot * Vector3(rng.randf_range(15.0, 22.0), 0, rng.randf_range(-7.0, 7.0))
		var bw := rng.randf_range(10.0, 14.0); var bh := rng.randf_range(5.0, 7.0); var bd := rng.randf_range(7.0, 10.0)
		var brh := rng.randf_range(3.0, 4.5)
		var bgh := _gh(x + bo.x, z + bo.z)
		barn_w.set_instance_transform(hi, Transform3D(rot.scaled(Vector3(bw, bh, bd)), Vector3(x + bo.x, bh * 0.5 + bgh, z + bo.z)))
		barn_r.set_instance_transform(hi, Transform3D(rot.scaled(Vector3(bw * 1.08, brh, bd * 1.08)), Vector3(x + bo.x, bh + brh * 0.5 + bgh, z + bo.z)))
		# haystack
		var ho: Vector3 = rot * Vector3(rng.randf_range(-16.0, -10.0), 0, rng.randf_range(8.0, 14.0))
		var hr := rng.randf_range(2.0, 3.0); var hht := rng.randf_range(3.0, 4.5)
		hay_mm.set_instance_transform(hi, Transform3D(Basis().scaled(Vector3(hr, hht, hr)), Vector3(x + ho.x, hht * 0.5 + _gh(x + ho.x, z + ho.z), z + ho.z)))
		# a tilled field beyond the yard
		var fo: Vector3 = rot * Vector3(rng.randf_range(-46.0, -24.0), 0, rng.randf_range(-52.0, -22.0))
		field_mm.set_instance_transform(hi, Transform3D(rot.scaled(Vector3(rng.randf_range(42.0, 72.0), 0.4, rng.randf_range(30.0, 56.0))), Vector3(x + fo.x, 0.2 + _gh(x + fo.x, z + fo.z), z + fo.z)))
		hi += 1
		# a square paddock fence (a long rail to each side)
		var yard := rng.randf_range(18.0, 26.0)
		for k in range(4):
			var ang := yaw + float(k) * PI * 0.5
			var sd := Vector3(sin(ang), 0, cos(ang))
			var ctr := Vector3(x, 0, z) + sd * (yard * 0.5)
			fence_mm.set_instance_transform(fi, Transform3D(Basis(Vector3.UP, ang + PI * 0.5).scaled(Vector3(yard, 1.2, 0.3)), Vector3(ctr.x, 0.6 + _gh(ctr.x, ctr.z), ctr.z)))
			fi += 1
		# a few beasts grazing the field / paddock
		for k in range(rng.randi_range(3, 6)):
			var lo: Vector3 = rot * Vector3(rng.randf_range(-50.0, -12.0), 0, rng.randf_range(-50.0, -10.0))
			var syaw := rng.randf_range(0.0, TAU)
			stock_mm.set_instance_transform(si, Transform3D(Basis(Vector3.UP, syaw).scaled(Vector3(rng.randf_range(1.4, 2.0), rng.randf_range(1.0, 1.4), rng.randf_range(2.2, 3.0))), Vector3(x + lo.x, 0.75 + _gh(x + lo.x, z + lo.z), z + lo.z)))
			si += 1

# The patchwork of farmland: crop fields in varied colours (wheat, barley, ploughed earth,
# pasture, fallow) scattered across the country, hemmed by HEDGEROWS along the roads and
# field edges. All draped onto the rolling ground via _gh.
const CROP_COLS := [Color(0.78, 0.68, 0.30), Color(0.72, 0.66, 0.40), Color(0.34, 0.26, 0.17),
	Color(0.36, 0.46, 0.24), Color(0.52, 0.52, 0.34)]   # wheat, barley, ploughed, pasture, fallow
func _build_farmland() -> void:
	if _inflated or hosted:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (GameConfig.match_seed if GameConfig.match_seed != 0 else 1) ^ 0x1d872b41
	# --- crop fields: a flat coloured patch each, draped to the ground ---
	var nf := 150
	var fmi := MultiMeshInstance3D.new()
	var fmm := MultiMesh.new()
	fmm.transform_format = MultiMesh.TRANSFORM_3D
	fmm.use_colors = true
	fmm.mesh = _box(1, 1, 1)
	fmm.instance_count = nf
	fmi.multimesh = fmm
	var fmat := StandardMaterial3D.new()
	fmat.vertex_color_use_as_albedo = true
	fmat.roughness = 1.0
	fmi.material_override = fmat
	add_child(fmi)
	var fi := 0
	var hedge_lines: Array = []        # [a, b] horizontal segments to plant hedges along
	var tries := 0
	while fi < nf and tries < nf * 30:
		tries += 1
		var x := rng.randf_range(-8600.0, COAST_X - 300.0)
		var z := rng.randf_range(-8400.0, 8400.0)
		var p := Vector3(x, 0, z)
		var ok := true
		for t in field_towns:
			if p.distance_to(t["pos"]) < 500.0 + float(t["size"]) * 150.0:
				ok = false; break
		if ok and not river_pts.is_empty() and _in_river(p):
			ok = false
		if not ok:
			continue
		var w := rng.randf_range(60.0, 150.0)
		var d := rng.randf_range(55.0, 130.0)
		var yaw := rng.randf_range(0.0, TAU)
		var rot := Basis(Vector3.UP, yaw)
		var cidx := rng.randi_range(0, CROP_COLS.size() - 1)
		fmm.set_instance_transform(fi, Transform3D(rot.scaled(Vector3(w, 0.4, d)), Vector3(x, _gh(x, z) + 0.22, z)))
		fmm.set_instance_color(fi, CROP_COLS[cidx])
		fi += 1
		# hedge the field's four edges (some of the time, for variety)
		if rng.randf() < 0.7:
			for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				var sd: Vector3 = rot * side
				var ext: float = (w * 0.5) if absf(side.x) > 0.5 else (d * 0.5)
				var a := Vector3(x, 0, z) + sd * ext
				var perp: Vector3 = rot * (Vector3(0, 0, 1) if absf(side.x) > 0.5 else Vector3(1, 0, 0))
				var hl: float = (d * 0.5) if absf(side.x) > 0.5 else (w * 0.5)
				hedge_lines.append([a - perp * hl, a + perp * hl])
	# --- hedgerows: rows of low bushes along the field edges and both sides of the roads ---
	for s in road_segs:
		var a: Vector3 = s[0]; var b: Vector3 = s[1]
		var dir := (b - a); dir.y = 0.0
		if dir.length() < 1.0:
			continue
		dir = dir.normalized()
		var perp := Vector3(dir.z, 0, -dir.x)
		hedge_lines.append([a + perp * 9.0, b + perp * 9.0])
		hedge_lines.append([a - perp * 9.0, b - perp * 9.0])
	var bushes: Array = []
	for hl in hedge_lines:
		var a: Vector3 = hl[0]; var b: Vector3 = hl[1]
		var ln := a.distance_to(b)
		var nb := int(ln / 7.0)
		for k in range(nb):
			var pt := a.lerp(b, float(k) / float(maxi(1, nb)))
			if not river_pts.is_empty() and _in_river(pt):
				continue
			bushes.append(pt)
	var hedge := _make_scenery_mm(_box(1, 1, 1), Color(0.16, 0.28, 0.15), bushes.size())
	for i in range(bushes.size()):
		var pt: Vector3 = bushes[i]
		var sx := rng.randf_range(1.6, 2.6); var sy := rng.randf_range(1.6, 2.4)
		hedge.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(sx, sy, sx)), Vector3(pt.x, _gh(pt.x, pt.z) + sy * 0.5, pt.z)))

# Lay out the strategic furniture of the province: the towns (already built) plus a
# spread of FORTS and DEPOTS across each side's territory — a distinct garrison home
# for every brigade, so the armies start dispersed across the map, not lined up. Then
# join the towns with a road network. Determined by the match seed so MP peers agree.
const FORT_NAMES := ["Ashwood", "Blackrock", "Crowmoor", "Dunbar", "Elmcrest", "Ferncliff",
	"Granite", "Harlow", "Ironside", "Juniper", "Kestrel", "Larkspur", "Marsh End",
	"Norwood", "Oakhanger", "Pinehill", "Quarrow", "Ravens", "Stonewall", "Thornton"]
const DEPOT_NAMES := ["Ashby", "Beck", "Carrow", "Dell", "Esker", "Fenwick", "Garth",
	"Holt", "Ingle", "Jarrow", "Keld", "Lund", "Mere", "Nethers", "Orme", "Pike"]
func _build_province_sites() -> void:
	if _inflated:
		return                              # a small MP skirmish keeps its tight deployment
	# towns are public sites everyone can read on the map
	for t in field_towns:
		field_sites.append({ "name": String(t["name"]), "pos": t["pos"], "kind": "town", "team": int(t["owner"]) })
	var rng := RandomNumberGenerator.new()
	rng.seed = (GameConfig.match_seed if GameConfig.match_seed != 0 else 1) ^ 0x5f3a91
	var fni := 0
	var dni := 0
	for team in [0, 1]:
		var sites: Array = []
		# the team's own towns are garrisons too — some brigades hold the towns
		for t in field_towns:
			if int(t["owner"]) == team:
				sites.append(t["pos"])
		# generate forts & depots on a jittered grid across the team's half of the map
		var need: int = BRIGADES_PER_TEAM
		var gen: int = maxi(0, need - sites.size())
		var cols := 5
		var rows: int = int(ceil(float(gen) / float(cols)))
		var zlo := -8000.0 if team == 0 else 700.0
		var zhi := -700.0 if team == 0 else 8000.0
		var k := 0
		for ri in range(rows):
			for ci in range(cols):
				if k >= gen:
					break
				var fx := lerpf(-8000.0, 200.0, (float(ci) + rng.randf_range(0.15, 0.85)) / float(cols))
				var fz := lerpf(zlo, zhi, (float(ri) + rng.randf_range(0.15, 0.85)) / float(maxi(1, rows)))
				var pos := Vector3(fx, 0, fz)
				var kind := "depot" if k % 3 == 2 else "fort"
				var nm: String
				if kind == "fort":
					nm = "Fort %s" % FORT_NAMES[fni % FORT_NAMES.size()]; fni += 1
				else:
					nm = "%s Depot" % DEPOT_NAMES[dni % DEPOT_NAMES.size()]; dni += 1
				sites.append(pos)
				field_sites.append({ "name": nm, "pos": pos, "kind": kind, "team": team })
				_build_site_scenery(pos, kind, team, nm)
				k += 1
		_team_sites[team] = sites
	_build_town_roads()

# A blockhouse-and-flag fort, or a tented depot of crates — a small landmark you ride
# up on, and the brigade's home on the map.
func _build_site_scenery(pos: Vector3, kind: String, team: int, nm: String) -> void:
	var sgy := _gh(pos.x, pos.z)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.30, 0.22, 0.14)
	wood.roughness = 0.95
	if kind == "fort":
		var bh := MeshInstance3D.new()
		bh.mesh = _box(9.0, 6.0, 9.0)
		bh.material_override = wood
		bh.position = pos + Vector3(0, 3.0 + sgy, 0)
		add_child(bh)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new(); pm.top_radius = 0.18; pm.bottom_radius = 0.18; pm.height = 11.0
		pole.mesh = pm
		pole.position = pos + Vector3(0, 5.5 + sgy, 0)
		add_child(pole)
		var flag := MeshInstance3D.new()
		flag.mesh = _box(3.2, 1.8, 0.2)
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = (ARMY_BLUE if team == 0 else ARMY_RED) if team >= 0 else Color(0.6, 0.6, 0.6)
		flag.material_override = fmat
		flag.position = pos + Vector3(1.7, 10.0 + sgy, 0)
		add_child(flag)
	else:
		var tent := MeshInstance3D.new()
		tent.mesh = _prism(8.0, 4.0, 6.0)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.62, 0.58, 0.46)
		tent.material_override = tmat
		tent.position = pos + Vector3(0, 2.0 + sgy, 0)
		add_child(tent)
		for j in range(4):
			var crate := MeshInstance3D.new()
			crate.mesh = _box(2.0, 2.0, 2.0)
			crate.material_override = wood
			var a := float(j) / 4.0 * TAU
			crate.position = pos + Vector3(cos(a) * 6.0, 1.0 + sgy, sin(a) * 6.0)
			add_child(crate)
	# (no floating label — the name arrives as a discreet toast when you ride up on it)

# A believable road network: a minimum spanning tree over the towns, so every town is
# reachable and the map reads as a connected country. (Towns are public; enemy garrison
# forts are NOT road-linked here, so the network gives nothing of the enemy away.)
func _build_town_roads() -> void:
	var pts: Array = []
	for t in field_towns:
		pts.append(t["pos"])
	var n := pts.size()
	if n < 2:
		return
	var intree := [0]
	var rest: Array = []
	for i in range(1, n):
		rest.append(i)
	while not rest.is_empty():
		var best_a := -1
		var best_b := -1
		var bd := 1.0e18
		for a in intree:
			for b in rest:
				var d: float = (pts[a] as Vector3).distance_to(pts[b])
				if d < bd:
					bd = d; best_a = a; best_b = b
		if best_b < 0:
			break
		field_roads.append([pts[best_a], pts[best_b]])
		intree.append(best_b)
		rest.erase(best_b)
	_build_road_meshes()

# Lay the road network into the WORLD as worn dirt tracks: the town highways (field_roads),
# plus a short access track from every fort and depot to its nearest town. Built as one
# flat ribbon mesh on the ground — a gentle meander, so it reads as a real country road.
func _build_road_meshes() -> void:
	var segs: Array = field_roads.duplicate()
	# garrison access tracks (3D only — these are NOT added to field_roads, so the strategic
	# map still shows only the public town highways and gives nothing of the enemy away)
	for s in field_sites:
		if String(s["kind"]) == "town":
			continue
		var sp: Vector3 = s["pos"]
		var best: Vector3 = sp
		var bd := 1.0e18
		for t in field_towns:
			var d: float = sp.distance_to(t["pos"])
			if d < bd:
				bd = d; best = t["pos"]
		segs.append([sp, best])
	road_segs = segs
	if segs.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 5.5
	for seg in segs:
		var a: Vector3 = seg[0]; a.y = 0.0
		var b: Vector3 = seg[1]; b.y = 0.0
		var ln := a.distance_to(b)
		if ln < 2.0:
			continue
		var dir := (b - a) / ln
		var perp := Vector3(dir.z, 0.0, -dir.x)
		var steps: int = maxi(2, int(ln / 110.0))
		var pl := Vector3.ZERO
		var pr := Vector3.ZERO
		for i in range(steps + 1):
			var tt := float(i) / float(steps)
			var ctr := a.lerp(b, tt) + perp * (sin(tt * PI * 2.0 + a.x * 0.0007) * 22.0)
			var cgy := _gh(ctr.x, ctr.z) + 0.16        # drape the track over the rolling ground
			var l := ctr + perp * hw + Vector3(0, cgy, 0)
			var r := ctr - perp * hw + Vector3(0, cgy, 0)
			if i > 0:
				st.set_normal(Vector3.UP); st.add_vertex(pl)
				st.set_normal(Vector3.UP); st.add_vertex(pr)
				st.set_normal(Vector3.UP); st.add_vertex(r)
				st.set_normal(Vector3.UP); st.add_vertex(pl)
				st.set_normal(Vector3.UP); st.add_vertex(r)
				st.set_normal(Vector3.UP); st.add_vertex(l)
			pl = l; pr = r
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.40, 0.32, 0.21)   # packed earth
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_build_river()

# A river winds across the province to the sea — a real obstacle that funnels the armies
# onto the BRIDGES where the roads cross it (fording elsewhere is slow). Built as a sunk
# water ribbon with muddy banks; bridges are dropped wherever a road meets the water.
func _build_river() -> void:
	if field_towns.is_empty():
		return
	# control points for a meandering course (NW headwaters down toward the coast)
	var ctrl := [
		Vector3(-8200, 0, -8400), Vector3(-6400, 0, -5200), Vector3(-4900, 0, -2400),
		Vector3(-3000, 0, -300), Vector3(-1600, 0, 2200), Vector3(-200, 0, 4400),
		Vector3(700, 0, 6400), Vector3(COAST_X - 60, 0, 7600),
	]
	# Catmull-Rom subdivision into a smooth polyline
	river_pts.clear()
	for i in range(ctrl.size() - 1):
		var p0: Vector3 = ctrl[maxi(0, i - 1)]
		var p1: Vector3 = ctrl[i]
		var p2: Vector3 = ctrl[i + 1]
		var p3: Vector3 = ctrl[mini(ctrl.size() - 1, i + 2)]
		var steps := 7
		for s in range(steps):
			var t := float(s) / float(steps)
			var t2 := t * t
			var t3 := t2 * t
			var pt := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
			pt.y = 0.0
			river_pts.append(pt)
	river_pts.append(ctrl[ctrl.size() - 1])
	# the water ribbon + a muddy bank just under it
	var water := SurfaceTool.new(); water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bank := SurfaceTool.new(); bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(water, river_pts, RIVER_HALF, -0.5)
	_ribbon(bank, river_pts, RIVER_HALF + 10.0, -0.15)
	var wmi := MeshInstance3D.new(); wmi.mesh = water.commit()
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.10, 0.26, 0.34)
	wmat.roughness = 0.12; wmat.metallic = 0.0
	wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	wmi.material_override = wmat
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)
	var bmi := MeshInstance3D.new(); bmi.mesh = bank.commit()
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.34, 0.29, 0.19); bmat.roughness = 1.0
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmi.material_override = bmat
	bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bmi)
	# drop a bridge wherever a road crosses the river
	for rseg in road_segs:
		for i in range(river_pts.size() - 1):
			var hit = _seg_xz(rseg[0], rseg[1], river_pts[i], river_pts[i + 1])
			if hit != null:
				var along: Vector3 = (rseg[1] - rseg[0])
				along.y = 0.0
				_build_bridge(hit, atan2(along.x, along.z))
				bridges.append(hit)

# Lay a flat ribbon (forced up-normals) down a polyline at height y, into SurfaceTool st.
func _ribbon(st: SurfaceTool, pts: Array, hw: float, y: float) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]; var b: Vector3 = pts[i + 1]
		var dir := (b - a)
		dir.y = 0.0
		if dir.length() < 0.01:
			continue
		dir = dir.normalized()
		var perp := Vector3(dir.z, 0, -dir.x)
		var ya := y + _gh(a.x, a.z); var yb := y + _gh(b.x, b.z)   # the river drapes the valley floor
		var al := a + perp * hw + Vector3(0, ya, 0); var ar := a - perp * hw + Vector3(0, ya, 0)
		var bl := b + perp * hw + Vector3(0, yb, 0); var br := b - perp * hw + Vector3(0, yb, 0)
		for v in [al, ar, br, al, br, bl]:
			st.set_normal(Vector3.UP); st.add_vertex(v)

# A timber bridge spanning the river along the road's heading (yaw).
func _build_bridge(pos: Vector3, yaw: float) -> void:
	var rot := Basis(Vector3.UP, yaw)
	var gy := Vector3(0, _gh(pos.x, pos.z), 0)        # sit the bridge on the banks
	var deck := MeshInstance3D.new()
	deck.mesh = _box(9.0, 0.6, RIVER_HALF * 2.4)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color(0.32, 0.22, 0.13); wood.roughness = 1.0
	deck.material_override = wood
	deck.transform = Transform3D(rot, pos + Vector3(0, 0.55, 0) + gy)
	add_child(deck)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = _box(0.3, 1.0, RIVER_HALF * 2.4)
		rail.material_override = wood
		rail.transform = Transform3D(rot, pos + rot * Vector3(side * 4.2, 1.1, 0) + gy)
		add_child(rail)
	for zz in [-RIVER_HALF * 0.7, RIVER_HALF * 0.7]:
		var pile := MeshInstance3D.new()
		pile.mesh = _box(8.0, 1.6, 1.0)
		pile.material_override = wood
		pile.transform = Transform3D(rot, pos + rot * Vector3(0, -0.3, zz) + gy)
		add_child(pile)

# 2D (XZ) segment intersection; returns the crossing point or null.
func _seg_xz(p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3):
	var den := (p1.x - p2.x) * (p3.z - p4.z) - (p1.z - p2.z) * (p3.x - p4.x)
	if absf(den) < 1.0e-6:
		return null
	var t := ((p1.x - p3.x) * (p3.z - p4.z) - (p1.z - p3.z) * (p3.x - p4.x)) / den
	var u := -((p1.x - p2.x) * (p1.z - p3.z) - (p1.z - p2.z) * (p1.x - p3.x)) / den
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return p1.lerp(p2, t)
	return null

# ---- TERRAIN HEIGHT: one shared rolling-ground field. Everything in the world drapes onto
# this (the ground mesh, the men, the scenery), and the GLSL twin in the ground shader MUST
# match. Faded to sea level near the shore so the beach and coast stay flat. ----
func _gh(x: float, z: float) -> float:
	var c := clampf((COAST_X - x) / 350.0, 0.0, 1.0)   # flatten only the immediate shore
	if c <= 0.0:
		return 0.0
	# hills on a BATTLEFIELD scale (wavelengths ~1–2.5 km) so the ground visibly rolls over
	# the ground a player can see — not a 14 km swell that reads as dead flat up close
	var h := sin(x * 0.0038 + 1.7) * 13.0 + sin(z * 0.0045 - 0.6) * 11.0
	h += sin((x * 0.7 + z) * 0.0026) * 8.0 + sin((x - z * 0.6) * 0.0064) * 5.0
	return h * c

func _gh3(p: Vector3) -> Vector3:
	return Vector3(p.x, _gh(p.x, p.z), p.z)

# ---- terrain & movement: roads quicken the march, the river off a bridge is a slow ford ----
func _dist_point_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a; ab.y = 0.0
	var ap := p - a; ap.y = 0.0
	var l2 := ab.length_squared()
	if l2 < 1.0e-6:
		return ap.length()
	var t := clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()

func _on_road(p: Vector3) -> bool:
	for s in road_segs:
		if _dist_point_seg(p, s[0], s[1]) < ROAD_WIDTH:
			return true
	return false

func _in_river(p: Vector3) -> bool:
	for i in range(river_pts.size() - 1):
		if _dist_point_seg(p, river_pts[i], river_pts[i + 1]) < RIVER_HALF:
			return true
	return false

func _near_bridge(p: Vector3) -> bool:
	for br in bridges:
		if p.distance_to(br) < BRIDGE_REACH:
			return true
	return false

func _terrain_speed_mul(p: Vector3) -> float:
	if not river_pts.is_empty() and _in_river(p) and not _near_bridge(p):
		return FORD_SPEED_MUL
	if _on_road(p):
		return ROAD_SPEED_MUL
	return 1.0

func _seg_crosses_river(a: Vector3, b: Vector3) -> bool:
	for i in range(river_pts.size() - 1):
		if _seg_xz(a, b, river_pts[i], river_pts[i + 1]) != null:
			return true
	return false

# Steer a mover toward the nearest BRIDGE when its path would otherwise cross the river —
# so the AI funnels onto the crossings instead of fording. Once at the bridge, push through.
func _route_via_bridge(from: Vector3, to: Vector3) -> Vector3:
	if bridges.is_empty() or _near_bridge(from):
		return to
	if not _seg_crosses_river(from, to):
		return to
	var best := to
	var bd := 1.0e18
	for br in bridges:
		var d: float = from.distance_to(br)
		if d < bd:
			bd = d; best = br
	return best

func _color_towns() -> void:
	for t in field_towns:
		var d = t["disc"]
		if d == null:
			continue                 # no ground disc any more — ownership shows on the map
		var col: Color
		match int(t["owner"]):
			0: col = ARMY_BLUE.lightened(0.35)
			1: col = ARMY_RED.lightened(0.25)
			_: col = Color(0.55, 0.55, 0.55)
		(d.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.7)

# Towns change hands: a force that holds a town uncontested takes it after a while.
func _update_capture(delta: float) -> void:
	if field_towns.is_empty():
		return
	_cap_cd -= delta
	if _cap_cd > 0.0:
		return
	var tick := 1.0
	_cap_cd = tick
	var changed := false
	for t in field_towns:
		var tp: Vector3 = t["pos"]
		var men := [0, 0]
		for b in battalions:
			if b.spent or b.state == "routing":
				continue
			if b.pos.distance_to(tp) < TOWN_CAPTURE_RANGE:
				men[b.team] += b.figs.size()
		var holder := -1
		if men[0] > 60 and men[1] < 40:
			holder = 0
		elif men[1] > 60 and men[0] < 40:
			holder = 1
		if holder >= 0 and holder != int(t["owner"]):
			if int(t["cap_team"]) != holder:
				t["cap_team"] = holder
				t["cap_t"] = 0.0
			t["cap_t"] = float(t["cap_t"]) + tick
			if float(t["cap_t"]) >= TOWN_CAPTURE_TIME:
				t["owner"] = holder
				t["cap_t"] = 0.0
				t["cap_team"] = -1
				changed = true
				_send_player_despatch("[color=#ffd773]%s has fallen[/color] to %s." % [t["name"], "the Crown" if holder == 0 else "the Continentals"], {})
		else:
			t["cap_t"] = maxf(0.0, float(t["cap_t"]) - tick)
	if changed:
		_color_towns()

func _town_counts() -> Array:
	var c := [0, 0, 0]   # crown, continental, neutral
	for t in field_towns:
		var o := int(t["owner"])
		c[o if o >= 0 else 2] += 1
	return c

# A side swept from all its towns has lost the province — the campaign is decided.
func _strategic_win(winner: int) -> void:
	if battle_over:
		return
	battle_over = true
	_town_winner = winner
	_bill_t = 8.0
	var won_it: bool = player != null and player.team == winner
	_send_player_despatch(("[color=#9fe0a0]The province is yours![/color] Every enemy town is taken — the campaign is won." if won_it else "[color=#ff7a6a]The province is lost![/color] The enemy has swept every town from your hands."), {})

# The friendly PLACE the rider is presently standing in — a town you hold, or one of your
# own forts/depots — or {} if he is in open country. Camp & command opens at any of these.
const TOWN_PRESENCE_RANGE := 360.0   # how near the officer must ride to be "at" a place
func _player_town() -> Dictionary:
	if player == null:
		return {}
	var best := {}
	var bd := TOWN_PRESENCE_RANGE
	# towns you currently hold (live ownership)
	for t in field_towns:
		if int(t["owner"]) != player.team:
			continue
		var d: float = off_pos.distance_to(t["pos"])
		if d < bd:
			bd = d
			best = t
	# your own forts & depots
	for s in field_sites:
		if String(s["kind"]) == "town" or int(s["team"]) != player.team:
			continue
		var d2: float = off_pos.distance_to(s["pos"])
		if d2 < bd:
			bd = d2
			best = s
	return best

# Whether a named site is in the player's hands (towns by live ownership, garrisons by team).
func _site_friendly(s: Dictionary) -> bool:
	if player == null:
		return false
	if String(s["kind"]) == "town":
		for t in field_towns:
			if String(t["name"]) == String(s["name"]):
				return int(t["owner"]) == player.team
		return false
	return int(s["team"]) == player.team

# A discreet, transient toast when the rider comes upon a named place — no in-world icon.
const LOCATION_TOAST_RANGE := 360.0
func _update_location_toast() -> void:
	if field_sites.is_empty():
		return
	var best := {}
	var bd := LOCATION_TOAST_RANGE
	for s in field_sites:
		var d: float = off_pos.distance_to(s["pos"])
		if d < bd:
			bd = d
			best = s
	var nm: String = String(best["name"]) if not best.is_empty() else ""
	if nm == _at_town_prev:
		return
	_at_town_prev = nm
	if nm == "":
		return
	if _site_friendly(best):
		_send_player_despatch("[color=#ffd773]You ride into %s.[/color]  [color=#9fb0c8]Press[/color] [color=#ffe9a8]C[/color] [color=#9fb0c8]to make camp.[/color]" % nm, {})
	else:
		var kind: String = String(best["kind"])
		var what: String = "the town of %s" % nm if kind == "town" else nm
		_send_player_despatch("[color=#cdd6e6]You come upon %s.[/color]" % what, {})

# The nearest town not already in this faction's hands — the brigade's strategic objective
# when there is no enemy to its front.
func _nearest_contestable_town(team: int, pos: Vector3):
	var best = null
	var bd := 1.0e18
	for t in field_towns:
		if int(t["owner"]) == team:
			continue
		var d: float = pos.distance_to(t["pos"])
		if d < bd:
			bd = d
			best = t
	return best

# The army's strategic objective: the best town to take, weighing its value (size, and
# more if it is the enemy's), how near it lies, and the commander's temperament.
func _pick_target_town(army, mine: Array):
	if field_towns.is_empty() or mine.is_empty():
		return null
	var center := Vector3.ZERO
	for br in mine:
		center += _brigade_center(br)
	center /= float(mine.size())
	var best = null
	var bs := -1.0
	for t in field_towns:
		if int(t["owner"]) == army.team:
			continue
		var v := float(t["size"]) * (1.7 if int(t["owner"]) == 1 - army.team else 1.0)
		var def := 0                      # how strongly the enemy holds it (prefer weak ground)
		for b in battalions:
			if b.team != army.team and not b.spent and b.pos.distance_to(t["pos"]) < 800.0:
				def += b.figs.size()
		var weak := 1.0 / (1.0 + float(def) / 1500.0)
		var d: float = center.distance_to(t["pos"])
		var sc := v * weak / (1.0 + d / 4000.0)
		sc *= lerpf(0.85, 1.25, army.aggression)
		if sc > bs:
			bs = sc
			best = t
	return best

# Where a brigade marches when it has no enemy to fight: the town its army directed it to
# seize, or — failing that — simply the nearest one to be taken.
func _brigade_town_objective(br) -> Vector3:
	if br.seize != Vector3.INF:
		return br.seize
	var t = _nearest_contestable_town(br.team, _brigade_center(br))
	return (t["pos"] as Vector3) if t != null else Vector3.INF

# =============================================================== THE SEA (naval)
# The eastern flank is open water. Squadrons patrol the coast and trade broadsides —
# real shipping and a running sea-fight a land officer can watch from the shore. (First
# increment: a living backdrop; commandable fleets and amphibious play come next.)
var ships: Array = []              # { node, pos, heading, speed, team, fire_cd }
var ocean: MeshInstance3D
var ocean_mat: ShaderMaterial      # wind-driven Gerstner sea (uniforms updated each frame)
var cloud_layer: MeshInstance3D    # drifting cloud sheet that follows the camera
var cloud_mat: ShaderMaterial
const COAST_X := 1650.0            # the shoreline — land to the west, open sea to the east
const SHIP_SPEED := 2.4            # a ship under sail makes way slowly (an accurate pace)
const SHIP_TURN := 0.09            # max turn rate (rad/s) — a big, ponderous turning circle
const SHIP_HP_MAX := 60.0          # round shot needed to take a frigate out of the fight
const SHIP_HULL_HALFLEN := 21.0    # hull oriented-box half-length, bow to stern (local +Z is the bow)
const SHIP_HULL_HALFWIDTH := 6.5   # hull oriented-box half-width at the wale
const SHIP_SINK_TIME := 7.0        # how long a struck ship takes to founder and go under
# the sea's wave model — MUST mirror the ocean shader so ships ride the visible swell.
# each wave: [angle offset from wind, steepness, wavelength, amplitude factor, speed]
const SEA_BASE_Y := -1.0
const SEA_WAVE_SPEED := 0.03       # global slow-down on the wave motion (lower = lazier sea; 0 = frozen)
# a STABLE prevailing swell direction — the sea does NOT follow the gusty, veering surface
# wind (whose constant rotation, across the huge ocean coords, made the wave field race)
const SEA_WIND_DIR := Vector2(0.82, 0.57)
const SEA_WAVES := [
	[0.0,  0.82, 150.0, 2.6,  1.0],
	[0.5,  0.70, 88.0,  1.6,  1.1],
	[-0.7, 0.62, 50.0,  0.95, 1.25],
	[1.2,  0.52, 28.0,  0.55, 1.5],
]

# the height of the sea surface at a world point — the CPU twin of the ocean shader
func _sea_y(wx: float, wz: float) -> float:
	var wd := SEA_WIND_DIR.normalized()              # fixed swell heading (not the veering wind)
	var s := clampf(0.8 + _wind.length() * 0.7, 0.3, 3.0)
	var depth := clampf((wx - COAST_X) / 1400.0, 0.0, 1.0)
	var damp := lerpf(0.22, 1.0, depth)
	var p := Vector2(wx, wz)
	var y := 0.0
	for wv in SEA_WAVES:
		var d := wd.rotated(float(wv[0]))
		var k := TAU / float(wv[2])
		var w := sqrt(9.8 * k)
		var amp := float(wv[3]) * s
		y += amp * sin(k * d.dot(p) - w * float(wv[4]) * _t * SEA_WAVE_SPEED)
	return SEA_BASE_Y + y * damp

# the sea-surface normal at a world point (finite-difference of the height field)
func _sea_normal(wx: float, wz: float) -> Vector3:
	var e := 4.0
	var hl := _sea_y(wx - e, wz)
	var hr := _sea_y(wx + e, wz)
	var hb := _sea_y(wx, wz - e)
	var hf := _sea_y(wx, wz + e)
	return Vector3(hl - hr, 2.0 * e, hb - hf).normalized()

func _build_ocean() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep : source_color = vec3(0.015, 0.055, 0.10);
uniform vec3 shallow : source_color = vec3(0.07, 0.21, 0.27);
uniform vec3 foam_col : source_color = vec3(0.86, 0.90, 0.92);
uniform vec3 sky_tint : source_color = vec3(0.55, 0.62, 0.72);
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float wind_str = 1.0;
uniform float wave_speed = 0.4;
uniform float wtime = 0.0;
uniform float coast_x = 1650.0;

varying float v_jac;
varying float v_depth;

vec2 rot2(vec2 v, float a){ float c = cos(a); float s = sin(a); return vec2(v.x*c - v.y*s, v.x*s + v.y*c); }

// one Gerstner wave -> accumulate displacement, analytic normal and a crest factor
void gwave(vec2 dir, float steep, float wlen, float amp, float spd, vec2 p, float t,
		   inout vec3 disp, inout vec3 nrm, inout float jac){
	float k = 6.28318530718 / wlen;
	float w = sqrt(9.8 * k);
	vec2 d = normalize(dir);
	float f = k * dot(d, p) - w * spd * t * wave_speed;
	float WA = k * amp;
	float cf = cos(f); float sf = sin(f);
	disp += vec3(d.x * steep * amp * cf, amp * sf, d.y * steep * amp * cf);
	nrm.x -= d.x * WA * cf;
	nrm.z -= d.y * WA * cf;
	nrm.y -= steep * WA * sf;
	jac += steep * WA * sf;
}

void vertex(){
	vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float t = wtime;
	vec2 w = normalize(wind_dir);
	float s = clamp(wind_str, 0.3, 3.0);
	vec3 disp = vec3(0.0);
	vec3 nrm = vec3(0.0, 1.0, 0.0);
	float jac = 0.0;
	gwave(w,            0.82, 150.0, 2.6*s,  1.0,  p, t, disp, nrm, jac);
	gwave(rot2(w, 0.5), 0.70, 88.0,  1.6*s,  1.1,  p, t, disp, nrm, jac);
	gwave(rot2(w,-0.7), 0.62, 50.0,  0.95*s, 1.25, p, t, disp, nrm, jac);
	gwave(rot2(w, 1.2), 0.52, 28.0,  0.55*s, 1.5,  p, t, disp, nrm, jac);
	v_depth = clamp((p.x - coast_x) / 1400.0, 0.0, 1.0);
	float damp = mix(0.22, 1.0, v_depth);   // the sea lies calmer in the shallows by the shore
	VERTEX += disp * damp;
	NORMAL = normalize(nrm);
	v_jac = jac * damp;
}

void fragment(){
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	vec3 base = mix(shallow, deep, v_depth);
	base = mix(base, sky_tint, clamp(fres, 0.0, 0.82));      // the sky mirrored at grazing angles
	float crest = smoothstep(0.55, 1.10, v_jac);             // white water where crests pinch
	float shore = 1.0 - smoothstep(0.0, 0.07, v_depth);      // surf along the beach
	float foam = clamp(crest + shore * 0.85, 0.0, 1.0);
	ALBEDO = mix(base, foam_col, foam);
	ROUGHNESS = mix(0.06, 0.55, foam);                       // glassy water, matte foam
	SPECULAR = 0.85;
	METALLIC = 0.0;
}
"""
	ocean_mat = ShaderMaterial.new()
	ocean_mat.shader = sh
	ocean_mat.set_shader_parameter("coast_x", COAST_X)
	ocean_mat.set_shader_parameter("wave_speed", SEA_WAVE_SPEED)
	# the SEA is two coplanar sheets sharing one material: a dense inshore sheet with the
	# detailed swell where the ships sail, and a vast low-detail sheet that carries the same
	# wave shape on to the horizon (set a hair lower so the inshore sheet always sits on top).
	var near := PlaneMesh.new()
	near.size = Vector2(6000, 16000)
	near.subdivide_width = 240
	near.subdivide_depth = 320
	ocean = MeshInstance3D.new()
	ocean.mesh = near
	ocean.position = Vector3(COAST_X + 3000.0, SEA_BASE_Y, 0.0)
	ocean.material_override = ocean_mat
	add_child(ocean)
	var far := PlaneMesh.new()
	far.size = Vector2(40000, 40000)
	far.subdivide_width = 80
	far.subdivide_depth = 80
	var far_mi := MeshInstance3D.new()
	far_mi.mesh = far
	far_mi.position = Vector3(COAST_X + 20000.0, SEA_BASE_Y - 0.3, 0.0)
	far_mi.material_override = ocean_mat
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_mi)
	# a pale ribbon of beach where the sea meets the land
	var beach := MeshInstance3D.new()
	var bm := PlaneMesh.new()
	bm.size = Vector2(200, 16000)
	beach.mesh = bm
	beach.position = Vector3(COAST_X - 40.0, 0.15, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.80, 0.74, 0.55)
	bmat.roughness = 1.0
	beach.material_override = bmat
	add_child(beach)

# A high sheet of fair-weather cloud that follows the camera and drifts with the wind.
# World-anchored noise gives parallax as you ride; coverage thickens in foul weather.
func _build_clouds() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.9
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	var ntex := NoiseTexture2D.new()
	ntex.noise = noise
	ntex.width = 512
	ntex.height = 512
	ntex.seamless = true
	var pm := PlaneMesh.new()
	pm.size = Vector2(34000, 34000)
	cloud_layer = MeshInstance3D.new()
	cloud_layer.mesh = pm
	cloud_layer.position = Vector3(0, 1700, 0)
	cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_layer.extra_cull_margin = 20000.0          # never frustum-culled out from under you
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D noise : repeat_enable;
uniform vec2 wind = vec2(1.0, 0.0);
uniform float coverage = 0.42;
uniform float softness = 0.16;
uniform vec3 lit : source_color = vec3(1.0, 0.98, 0.94);
uniform vec3 shade : source_color = vec3(0.60, 0.64, 0.72);
uniform float half_size = 17000.0;

varying vec2 wxz;
varying vec2 lxz;

void vertex(){
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	lxz = VERTEX.xz;
}

void fragment(){
	vec2 uv = wxz * 0.00004 + wind * TIME * 0.00045;
	float n = texture(noise, uv).r;
	float n2 = texture(noise, uv * 2.7 + vec2(3.1, 1.7)).r;
	float dns = n * 0.62 + n2 * 0.38;
	float a = smoothstep(1.0 - coverage - softness, 1.0 - coverage + softness, dns);
	float r = length(lxz) / half_size;
	a *= 1.0 - smoothstep(0.55, 1.0, r);            // dissolve toward the horizon edges
	vec3 col = mix(shade, lit, smoothstep(0.45, 0.95, dns));
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * 0.92;
}
"""
	cloud_mat = ShaderMaterial.new()
	cloud_mat.shader = sh
	cloud_mat.set_shader_parameter("noise", ntex)
	cloud_layer.material_override = cloud_mat
	add_child(cloud_layer)

func _smesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, b: Basis = Basis()) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(b, pos)
	parent.add_child(mi)
	return mi

# A blocky-but-believable sloop-of-war, bow toward +Z: a tapered hull that sits properly IN
# the water (a coppered underbody below the waterline, a boot-topping stripe right at it,
# then the turn of the bilge up to the wale and a chequered gun-deck), a raised quarterdeck
# and forecastle, a carved figurehead and stowed anchors at the beak, a bowsprit crossed with
# headsails, three masts crossed with yards and graduated square sails, and the ensign astern.
func _ship_node(team: int) -> Node3D:
	var n := Node3D.new()
	var timber := StandardMaterial3D.new()
	timber.albedo_color = Color(0.24, 0.16, 0.10); timber.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.06, 0.05); dark.roughness = 1.0
	var deckwood := StandardMaterial3D.new()
	deckwood.albedo_color = Color(0.50, 0.40, 0.26); deckwood.roughness = 1.0
	var strake := StandardMaterial3D.new()
	strake.albedo_color = Color(0.86, 0.72, 0.30); strake.roughness = 0.9   # the yellow gun strake
	var trim := StandardMaterial3D.new()
	trim.albedo_color = (ARMY_BLUE.lightened(0.22) if team == 0 else ARMY_RED.lightened(0.16))
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color(0.90, 0.87, 0.80); canvas.roughness = 1.0
	canvas.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.16, 0.13, 0.10); rope.roughness = 1.0
	var copper := StandardMaterial3D.new()
	copper.albedo_color = Color(0.42, 0.24, 0.14); copper.roughness = 0.55; copper.metallic = 0.3   # coppered bottom
	var boot := StandardMaterial3D.new()
	boot.albedo_color = Color(0.05, 0.05, 0.05); boot.roughness = 0.9        # boot-topping at the waterline
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.80, 0.66, 0.22); gold.roughness = 0.35; gold.metallic = 0.6
	# ---- hull: a coppered underbody below the waterline (the ship rides IN the sea, not on
	# top of it), the bilge turning up to the wale, a wider deck breadth, a tapering bow and
	# a tall transom ----
	_smesh(n, _box(7.6, 4.2, 40.0), Vector3(0, -2.1, -1.0), copper)           # coppered underbody (submerged)
	_smesh(n, _box(7.8, 0.5, 40.2), Vector3(0, 0.0, -1.0), boot)              # boot-topping at the waterline
	_smesh(n, _box(7.8, 4.2, 40.0), Vector3(0, 2.1, -1.0), timber)            # bilge, waterline up to the wale
	_smesh(n, _box(12.5, 5.0, 44.0), Vector3(0, 6.5, -1.0), timber)           # main hull at the deck
	_smesh(n, _box(9.5, 5.0, 6.0), Vector3(0, 5.6, 23.0), timber)             # bow shoulder
	_smesh(n, _box(5.4, 4.6, 5.0), Vector3(0, 5.4, 27.0), timber)             # bow taper
	_smesh(n, _box(2.6, 3.6, 4.0), Vector3(0, 4.8, 30.0), dark)               # beakhead / stem
	_smesh(n, _box(13.4, 6.0, 4.0), Vector3(0, 8.0, -23.0), timber)           # stern transom (tall)
	_smesh(n, _box(8.6, 2.6, 0.6), Vector3(0, 9.2, -25.1), trim)              # stern gallery windows
	# the wale (a heavy rubbing strake at the turn of the bilge) and the chequered gun deck
	_smesh(n, _box(12.9, 1.2, 45.0), Vector3(0, 4.6, -1.0), dark)             # wale
	_smesh(n, _box(12.7, 1.8, 43.5), Vector3(0, 7.2, -1.0), strake)          # gun strake
	for side in [-1.0, 1.0]:
		for k in range(6):
			var pz := -15.0 + float(k) * 6.4
			_smesh(n, _box(0.6, 1.1, 1.6), Vector3(side * 6.4, 7.2, pz), dark)   # gun ports
	# bulwarks + the upper decks
	_smesh(n, _box(12.5, 1.6, 44.0), Vector3(0, 9.6, -1.0), timber)           # bulwark rail
	_smesh(n, _box(11.4, 0.5, 43.0), Vector3(0, 9.3, -1.0), deckwood)         # weather deck
	_smesh(n, _box(11.3, 2.2, 13.5), Vector3(0, 10.7, -15.0), timber)         # quarterdeck (raised aft)
	_smesh(n, _box(9.6, 1.8, 8.5), Vector3(0, 10.5, 17.0), timber)            # forecastle (raised fwd)
	# a ship's wheel & binnacle hint on the quarterdeck, and a ship's boat stowed amidships
	_smesh(n, _box(0.4, 1.4, 0.4), Vector3(0, 11.8, -10.5), deckwood)
	_smesh(n, _box(2.0, 0.9, 6.5), Vector3(0, 10.4, -4.0), deckwood)
	# ---- the beak: a carved, gilt figurehead, cathead beams and anchors stowed each side ----
	_smesh(n, _box(0.9, 2.0, 1.4), Vector3(0, 4.6, 32.0), trim)               # figurehead
	_smesh(n, _box(0.5, 0.9, 0.8), Vector3(0, 5.7, 32.2), gold)               # figurehead's gilt crest
	for side in [-1.0, 1.0]:
		var ax := side * 5.6
		_smesh(n, _box(0.45, 0.45, 2.6), Vector3(side * 5.6, 9.0, 26.5), deckwood)        # cathead beam
		_smesh(n, _box(0.18, 3.4, 0.18), Vector3(ax, 5.4, 26.0), dark)                     # anchor shank
		_smesh(n, _box(0.95, 0.18, 0.18), Vector3(ax, 7.0, 26.0), dark)                    # anchor stock
		_smesh(n, _box(0.75, 0.5, 0.14), Vector3(ax, 3.7, 26.3), dark, Basis(Vector3.RIGHT, deg_to_rad(35.0)))   # fluke
	# ---- bowsprit + headsails ----
	var bsB := Basis(Vector3.RIGHT, deg_to_rad(-22.0))
	_smesh(n, _box(0.85, 0.85, 17.0), Vector3(0, 11.5, 29.0), deckwood, bsB)
	_smesh(n, _box(0.1, 5.2, 7.5), Vector3(0, 12.6, 25.5), canvas, Basis(Vector3.UP, deg_to_rad(90.0)) * Basis(Vector3.RIGHT, deg_to_rad(8.0)))
	_smesh(n, _box(0.1, 4.4, 6.5), Vector3(0, 10.8, 20.5), canvas, Basis(Vector3.UP, deg_to_rad(90.0)) * Basis(Vector3.RIGHT, deg_to_rad(6.0)))   # inner jib
	# ---- three masts: fore, main (tallest), mizzen — each crossed with yards & sails ----
	var masts := [
		{ "z": 13.0, "h": 44.0, "course": Vector2(24.0, 13.0), "top": Vector2(17.0, 10.0) },   # fore
		{ "z": -1.0, "h": 52.0, "course": Vector2(28.0, 15.0), "top": Vector2(21.0, 11.0) },   # main
		{ "z": -15.0, "h": 38.0, "course": Vector2(19.0, 11.0), "top": Vector2(14.0, 9.0) },   # mizzen
	]
	for m in masts:
		var mz: float = m["z"]
		var mh: float = m["h"]
		var mcyl := CylinderMesh.new(); mcyl.top_radius = 0.38; mcyl.bottom_radius = 0.75; mcyl.height = mh
		_smesh(n, mcyl, Vector3(0, 8.0 + mh * 0.5, mz), deckwood)
		var top := CylinderMesh.new(); top.top_radius = 0.19; top.bottom_radius = 0.38; top.height = mh * 0.5
		_smesh(n, top, Vector3(0, 8.0 + mh + mh * 0.25, mz), deckwood)        # topmast
		var cs: Vector2 = m["course"]
		var ts: Vector2 = m["top"]
		var y_course := 8.0 + mh * 0.42
		var y_top := 8.0 + mh * 0.78
		_smesh(n, _box(cs.x, 0.5, 0.5), Vector3(0, y_course + cs.y * 0.5, mz), deckwood)  # lower yard
		_smesh(n, _box(cs.x, cs.y, 0.25), Vector3(0, y_course, mz), canvas)               # course sail
		_smesh(n, _box(ts.x, 0.4, 0.4), Vector3(0, y_top + ts.y * 0.5, mz), deckwood)     # upper yard
		_smesh(n, _box(ts.x, ts.y, 0.2), Vector3(0, y_top, mz), canvas)                   # topsail
		# shrouds: a few raked ropes from the masthead down to the channels each side
		for side in [-1.0, 1.0]:
			for sh in range(3):
				var foot := Vector3(side * 6.1, 9.5, mz + float(sh - 1) * 3.2)
				var head := Vector3(side * 0.65, 8.0 + mh * 0.7, mz)
				var mid := (foot + head) * 0.5
				var dir := head - foot
				var b := Basis.looking_at(dir.normalized(), Vector3.UP)
				var rod := _box(0.12, 0.12, dir.length())
				_smesh(n, rod, mid, rope, b)
	# the ensign at the stern staff
	var staffB := Basis(Vector3.RIGHT, deg_to_rad(-18.0))
	_smesh(n, _box(0.2, 0.2, 7.5), Vector3(0, 13.0, -25.5), deckwood, staffB)
	_smesh(n, _box(0.15, 3.4, 5.4), Vector3(0, 15.1, -29.2), trim)
	return n

func _spawn_ships() -> void:
	ships.clear()
	for team in [0, 1]:
		for i in range(3):
			var node := _ship_node(team)
			add_child(node)
			var x := COAST_X + randf_range(1000.0, 2900.0) + float(i) * 130.0
			var z := randf_range(-1300.0, 1300.0) + (-700.0 if team == 0 else 700.0)
			var ph := 0.0 if team == 0 else PI
			ships.append({ "node": node, "pos": Vector3(x, 0, z), "heading": ph, "patrol_h": ph,
				"speed": SHIP_SPEED * randf_range(0.9, 1.1), "team": team, "fire_cd": randf_range(2.0, 6.0),
				"hp": SHIP_HP_MAX, "sinking": false })

func _nearest_enemy_ship(s: Dictionary):
	var best = null
	var bd := 1.0e18
	for o in ships:
		if o["team"] == s["team"] or o.get("sinking", false):
			continue
		var d: float = (o["pos"] as Vector3).distance_to(s["pos"])
		if d < bd:
			bd = d; best = o
	return best

# is this point inside the ship's hull — an oriented box, local +Z toward the bow
func _ship_hit_test(ship: Dictionary, point: Vector3) -> bool:
	var hd := Vector3(sin(ship["heading"]), 0, cos(ship["heading"]))
	var right := Vector3(hd.z, 0, -hd.x)
	var rel: Vector3 = point - (ship["pos"] as Vector3)
	rel.y = 0.0
	return absf(rel.dot(hd)) <= SHIP_HULL_HALFLEN and absf(rel.dot(right)) <= SHIP_HULL_HALFWIDTH

func _sink_ship(s: Dictionary) -> void:
	if s.get("sinking", false):
		return
	s["sinking"] = true
	s["sink_t"] = 0.0

func _update_sinking_ship(s: Dictionary, delta: float) -> void:
	s["sink_t"] = float(s.get("sink_t", 0.0)) + delta
	var t: float = s["sink_t"]
	var node: Node3D = s["node"]
	var sx: float = s["pos"].x
	var sz: float = s["pos"].z
	var wy := _sea_y(sx, sz)
	var hd := Vector3(sin(s["heading"]), 0, cos(s["heading"]))
	var up := _sea_normal(sx, sz)
	var fwd := (hd - up * hd.dot(up)).normalized()
	var right := up.cross(fwd).normalized()
	var settle := clampf(t / SHIP_SINK_TIME, 0.0, 1.0)
	var basis := Basis(right, up, fwd).rotated(fwd, settle * 0.55)   # she rolls onto her beam-ends
	node.transform = Transform3D(basis, Vector3(sx, wy + 0.2 - settle * 6.0, sz))
	if randf() < delta * 6.0:
		_emit_wake(Vector3(sx, wy + 0.3, sz) + fwd * randf_range(-20.0, 20.0), fwd)
	if randf() < delta * 3.0:
		_emit_splash(Vector3(sx, wy + 0.3, sz))

func _update_ships(delta: float) -> void:
	if ships.is_empty():
		return
	var sunk: Array = []
	for s in ships:
		if s.get("sinking", false):
			_update_sinking_ship(s, delta)
			if float(s["sink_t"]) > SHIP_SINK_TIME:
				sunk.append(s)
			continue
		# --- decide where to steer ---
		var foe = _nearest_enemy_ship(s)
		var fdist := 1.0e9
		var to_foe := Vector3.ZERO
		if foe != null:
			to_foe = (foe["pos"] as Vector3) - s["pos"]
			to_foe.y = 0.0
			fdist = to_foe.length()
		var target_h: float = s["heading"]
		if foe != null and fdist < 1600.0:
			# bring a broadside to bear: steer so the enemy lies abeam (90 deg off the bow),
			# choosing whichever beam swings round soonest
			var bearing := atan2(to_foe.x, to_foe.z)
			var h1 := bearing + PI * 0.5
			var h2 := bearing - PI * 0.5
			target_h = h1 if absf(wrapf(h1 - s["heading"], -PI, PI)) < absf(wrapf(h2 - s["heading"], -PI, PI)) else h2
		else:
			# patrol the coast; put the helm over at the ends of the beat
			if s["pos"].z > 2300.0:
				s["patrol_h"] = PI
			elif s["pos"].z < -2300.0:
				s["patrol_h"] = 0.0
			target_h = s["patrol_h"]
		# stand off the beach — steer back out to sea if it is crowding the shore
		if s["pos"].x < COAST_X + 650.0:
			target_h = 0.0 if cos(s["heading"]) >= 0.0 else PI    # keep way on, edge seaward
			s["pos"].x += (COAST_X + 650.0 - s["pos"].x) * minf(1.0, delta)
		# --- turn slowly toward that heading, then make way ---
		var dh := clampf(wrapf(target_h - s["heading"], -PI, PI), -SHIP_TURN * delta, SHIP_TURN * delta)
		s["heading"] = s["heading"] + dh
		var hd := Vector3(sin(s["heading"]), 0, cos(s["heading"]))
		# a ship loses way while hauling round hard; full speed only when steady on course
		var way: float = s["speed"] * lerpf(0.55, 1.0, 1.0 - clampf(absf(dh) / (SHIP_TURN * delta + 0.0001), 0.0, 1.0))
		s["pos"] += hd * way * delta
		# ride the swell: float on the actual sea surface and tilt to its normal
		var node: Node3D = s["node"]
		var sx: float = s["pos"].x
		var sz: float = s["pos"].z
		var wy := _sea_y(sx, sz)
		var up := _sea_normal(sx, sz)
		var fwd := (hd - up * hd.dot(up)).normalized()   # keep the bow level with the surface
		var right := up.cross(fwd).normalized()
		node.transform = Transform3D(Basis(right, up, fwd), Vector3(sx, wy + 0.2, sz))
		# the bow turns the sea over white as the ship makes way — more foam the faster she sails
		if way > 0.3 and cam != null and cam.position.distance_to(s["pos"]) < 700.0:
			var bow := Vector3(sx, wy + 0.3, sz) + fwd * 29.0
			if randf() < delta * 5.0 * (way / SHIP_SPEED):
				_emit_wake(bow, fwd)
		# --- gunnery: a ship can ONLY fire broadsides — the enemy must lie abeam and in range ---
		s["fire_cd"] -= delta
		if s["fire_cd"] <= 0.0:
			var abeam := 1.0
			if foe != null and fdist > 1.0:
				abeam = absf(hd.dot(to_foe / fdist))     # 0 = dead abeam, 1 = bow/stern on
			if foe != null and fdist < 950.0 and abeam < 0.5:
				s["fire_cd"] = randf_range(7.0, 11.0)    # a slow, deliberate reload
				_ship_broadside(s, foe)
			else:
				s["fire_cd"] = 1.0                       # not yet bearing — check again shortly
	for s in sunk:
		var node: Node3D = s["node"]
		node.queue_free()
		ships.erase(s)

func _ship_broadside(s: Dictionary, foe) -> void:
	var hd := Vector3(sin(s["heading"]), 0, cos(s["heading"]))
	var right := Vector3(hd.z, 0, -hd.x)
	var to_foe: Vector3 = (foe["pos"] as Vector3) - s["pos"]
	var side := right if right.dot(to_foe) > 0.0 else -right
	var base: Vector3 = s["pos"] + Vector3(0, 5.0, 0)
	# a full gun-deck speaks as one — same flash, smoke-bloom and report as the land batteries
	for k in range(9):
		var muzzle := base + hd * ((float(k) - 4.0) * 5.3) + side * 7.3
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_muzzle_bloom(muzzle, side)
		_emit_gun_smoke(muzzle + side * randf_range(0.0, 4.0), side)
		_emit_gun_smoke(muzzle + side * randf_range(2.0, 6.0), side)
		# every other gun actually sends iron downrange — a tracked ball, not a cosmetic guess
		if k % 2 == 0:
			_spawn_naval_shot(muzzle + side * 3.0, foe, int(s["team"]))
	if cam != null:
		_play_cannon(base + hd * 12.5 + side * 7.3)
		_play_cannon(base - hd * 12.5 + side * 7.3)   # the report rolls down the ship's length

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
	if b.broken:
		morale_word = "BROKEN"; mcol = "ff5a4a"
	elif b.state == "routing":
		morale_word = "breaking"; mcol = "ff7a6a"
	elif b.state == "shaken":
		morale_word = "shaken"; mcol = "ffcf6e"
	elif b.cohesion < COHESION_BREAK + 18.0:
		morale_word = "wavering"; mcol = "ffe08a"   # order fraying — close to the break
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
		"[color=#%s]MOVE[/color]   [color=#%s]WASD[/color] move · [color=#%s]Shift[/color] run · [color=#%s]R[/color] autorun · mouse look · [color=#%s]scroll[/color] zoom\n" % [c, k, k, k, k] + \
		"[color=#%s]LOOK[/color]   [color=#%s]RMB[/color] spyglass · [color=#%s]E[/color] hail sergeant / general · [color=#%s]Esc[/color] free cursor\n" % [c, k, k, k] + \
		"[color=#%s]ORDERS[/color] [color=#%s]Q[/color] courier order menu (a despatch rides to your battalion)\n" % [c, k] + \
		"[color=#%s]SELF[/color]   [color=#%s]LMB[/color] sabre/fire · [color=#%s]G[/color] pistol · [color=#%s]V[/color] present · [color=#%s]F[/color] fire/charge · [color=#%s]T[/color] bring up the guns\n" % [c, k, k, k, k, k] + \
		"[color=#%s]ARM[/color]    [color=#%s]1[/color] foot · [color=#%s]2[/color] guns ([color=#%s]E[/color] sight the barrel · LMB fires) · [color=#%s]3[/color] horse (F charges) — at the step-off\n" % [c, k, k, k, k] + \
		"[color=#%s]CAMP[/color]   [color=#%s]C[/color] camp & companies — a mouse GUI [color=#6f7888](while standing in one of your towns)[/color]\n" % [c, k] + \
		"[color=#%s]WORLD[/color]  [color=#%s]N[/color] push the clock on · [color=#%s]M[/color] province map  [color=#6f7888](dusk ends the day)[/color]\n" % [c, k, k] + \
		"[color=#%s]DEV[/color]    [color=#%s]F3[/color] AI overlay + reveal map · [color=#%s]F4[/color] RTS free-fly camera\n" % [c, k, k] + \
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
# able to see over your own line (and be seen by it). Built procedurally (low-poly
# box/cylinder primitives, like the rank-and-file) rather than imported from Blender —
# there's no live Blender link in every environment this game gets built in, so the
# hero has to be buildable headless, same as everyone else on the field.
func _build_officer() -> void:
	officer = Node3D.new()
	add_child(officer)
	var coat_col: Color = GameConfig.UNIFORM_COLS[clampi(GameConfig.militia_uniform, 0, GameConfig.UNIFORM_COLS.size() - 1)]
	var facing_col: Color = GameConfig.militia_facing
	_build_horse(officer, facing_col)
	_build_officer_colonel(officer, coat_col, facing_col)

# The rider: a low-poly stylized COLONEL in the saddle. His coat takes the militia's
# uniform colour, his collar/lapels/cuffs/cockade the facing colour the player chose
# when raising the force. Marked out from a plain line officer by a gorget, a crimson
# waist sash, gold fringed epaulettes on BOTH shoulders (one was a subaltern's mark;
# both a field officer's), an aiguillette, and a gold-piped, taller-plumed bicorne.
func _build_officer_colonel(parent: Node3D, coat_col: Color, facing: Color) -> void:
	var coat := StandardMaterial3D.new()
	coat.albedo_color = coat_col.lightened(0.12)
	coat.roughness = 0.6
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = facing
	face_mat.roughness = 0.6
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.56, 0.43)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.83, 0.68, 0.21)
	gold.metallic = 0.7
	gold.roughness = 0.25
	var crimson := StandardMaterial3D.new()
	crimson.albedo_color = Color(0.55, 0.05, 0.08)
	crimson.roughness = 0.55
	var buff := StandardMaterial3D.new()
	buff.albedo_color = Color(0.82, 0.78, 0.65)
	buff.roughness = 0.75
	var boot := StandardMaterial3D.new()
	boot.albedo_color = Color(0.07, 0.06, 0.07)
	boot.roughness = 0.4

	# --- torso: coat body, short tails behind, a stand collar and lapels (facing) ---
	var chest := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.42, 0.62, 0.26)
	chest.mesh = cb
	chest.position = Vector3(0, 1.95, 0)
	chest.material_override = coat
	parent.add_child(chest)
	var tails := MeshInstance3D.new()
	var tlb := BoxMesh.new()
	tlb.size = Vector3(0.36, 0.30, 0.14)
	tails.mesh = tlb
	tails.position = Vector3(0, 1.66, -0.16)
	tails.material_override = coat
	parent.add_child(tails)
	var collar := MeshInstance3D.new()
	var clb := BoxMesh.new()
	clb.size = Vector3(0.30, 0.10, 0.10)
	collar.mesh = clb
	collar.position = Vector3(0, 2.20, 0.10)
	collar.material_override = face_mat
	parent.add_child(collar)
	var lapel := MeshInstance3D.new()
	var lpb := BoxMesh.new()
	lpb.size = Vector3(0.20, 0.50, 0.04)
	lapel.mesh = lpb
	lapel.position = Vector3(0, 1.92, 0.14)
	lapel.material_override = face_mat
	parent.add_child(lapel)

	# --- the waist sash and its hanging knot, a field officer's badge ---
	var sash := MeshInstance3D.new()
	var ssb := BoxMesh.new()
	ssb.size = Vector3(0.46, 0.10, 0.30)
	sash.mesh = ssb
	sash.position = Vector3(0, 1.72, 0)
	sash.material_override = crimson
	parent.add_child(sash)
	var knot := MeshInstance3D.new()
	var knb := BoxMesh.new()
	knb.size = Vector3(0.07, 0.22, 0.07)
	knot.mesh = knb
	knot.position = Vector3(-0.20, 1.55, 0.06)
	knot.material_override = crimson
	parent.add_child(knot)

	# --- the gorget, gold, at the throat ---
	var gorget := MeshInstance3D.new()
	var gtb := BoxMesh.new()
	gtb.size = Vector3(0.14, 0.06, 0.02)
	gorget.mesh = gtb
	gorget.position = Vector3(0, 2.27, 0.13)
	gorget.material_override = gold
	parent.add_child(gorget)

	# --- the aiguillette, a gold cord looped on the right breast ---
	var aig := MeshInstance3D.new()
	var agb := BoxMesh.new()
	agb.size = Vector3(0.03, 0.34, 0.03)
	aig.mesh = agb
	aig.position = Vector3(0.18, 1.96, 0.15)
	aig.rotation = Vector3(0, 0, 0.15)
	aig.material_override = gold
	parent.add_child(aig)
	var aigtip := MeshInstance3D.new()
	var atb := BoxMesh.new()
	atb.size = Vector3(0.04, 0.08, 0.04)
	aigtip.mesh = atb
	aigtip.position = Vector3(0.20, 1.74, 0.16)
	aigtip.material_override = gold
	parent.add_child(aigtip)

	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.22, 0.22, 0.22)
	head.mesh = hb
	head.position = Vector3(0, 2.38, 0)
	head.material_override = skin
	parent.add_child(head)

	# --- arms, faced cuffs, hands, and gold fringed epaulettes on both shoulders ---
	for ax in [-0.30, 0.30]:
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.13, 0.5, 0.14)
		arm.mesh = ab
		arm.position = Vector3(ax, 1.92, 0.04)
		arm.material_override = coat
		parent.add_child(arm)
		var cuff := MeshInstance3D.new()
		var cfb := BoxMesh.new()
		cfb.size = Vector3(0.15, 0.10, 0.16)
		cuff.mesh = cfb
		cuff.position = Vector3(ax, 1.70, 0.05)
		cuff.material_override = face_mat
		parent.add_child(cuff)
		var hand := MeshInstance3D.new()
		var hdb := BoxMesh.new()
		hdb.size = Vector3(0.08, 0.08, 0.09)
		hand.mesh = hdb
		hand.position = Vector3(ax * 0.85, 1.66, 0.16)
		hand.material_override = skin
		parent.add_child(hand)
		var epau := MeshInstance3D.new()
		var epb := BoxMesh.new()
		epb.size = Vector3(0.17, 0.05, 0.17)
		epau.mesh = epb
		epau.position = Vector3(ax, 2.18, 0.0)
		epau.material_override = gold
		parent.add_child(epau)

	# --- legs: buff breeches over the thigh, black riding boots below ---
	for sx in [-0.27, 0.27]:
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.16, 0.72, 0.18)
		leg.mesh = lb
		leg.position = Vector3(sx, 1.35, 0.08)
		leg.rotation = Vector3(0.35, 0, sx * 1.2)   # thighs astride the horse
		leg.material_override = buff
		parent.add_child(leg)
		var bootm := MeshInstance3D.new()
		var btb := BoxMesh.new()
		btb.size = Vector3(0.17, 0.40, 0.19)
		bootm.mesh = btb
		bootm.position = Vector3(sx, 1.02, 0.20)
		bootm.rotation = Vector3(0.35, 0, sx * 1.2)
		bootm.material_override = boot
		parent.add_child(bootm)

	# --- the bicorne: gold piping, a facing-coloured cockade, a taller plume ---
	var hat := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.55, 0.12, 0.22)
	hat.mesh = hm
	hat.position = Vector3(0, 2.55, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.08, 0.08, 0.10)
	hat.material_override = hmat
	parent.add_child(hat)
	var hat_trim := MeshInstance3D.new()
	var htb := BoxMesh.new()
	htb.size = Vector3(0.58, 0.025, 0.25)
	hat_trim.mesh = htb
	hat_trim.position = Vector3(0, 2.49, 0)
	hat_trim.material_override = gold
	parent.add_child(hat_trim)
	var cockade := MeshInstance3D.new()
	var ckb := BoxMesh.new()
	ckb.size = Vector3(0.06, 0.06, 0.03)
	cockade.mesh = ckb
	cockade.position = Vector3(0, 2.58, 0.11)
	cockade.material_override = face_mat
	parent.add_child(cockade)
	var plumebase := MeshInstance3D.new()
	var pbb := CylinderMesh.new()
	pbb.bottom_radius = 0.045
	pbb.top_radius = 0.04
	pbb.height = 0.08
	plumebase.mesh = pbb
	plumebase.position = Vector3(0, 2.65, -0.04)
	plumebase.material_override = face_mat
	parent.add_child(plumebase)
	var plume := MeshInstance3D.new()
	var plm := CylinderMesh.new()
	plm.bottom_radius = 0.035
	plm.top_radius = 0.015
	plm.height = 0.34
	plume.mesh = plm
	plume.position = Vector3(0, 2.86, -0.05)
	var pmat2 := StandardMaterial3D.new()
	pmat2.albedo_color = Color(0.93, 0.92, 0.88)
	plume.material_override = pmat2
	parent.add_child(plume)

	# --- the sabre, with a gilt hilt, and a horse-pistol holstered in the off hand ---
	var sab := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.05, 0.85)
	sab.mesh = sm
	sab.position = Vector3(0.34, 1.9, 0.25)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.85, 0.85, 0.9)
	smat.metallic = 0.8
	sab.material_override = smat
	parent.add_child(sab)
	sabre = sab
	var hilt := MeshInstance3D.new()
	var hib := BoxMesh.new()
	hib.size = Vector3(0.07, 0.07, 0.14)
	hilt.mesh = hib
	hilt.position = Vector3(0, 0, -0.42)
	hilt.material_override = gold
	sab.add_child(hilt)
	pistol_mesh = MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.05, 0.10, 0.26)
	pistol_mesh.mesh = pm
	pistol_mesh.position = Vector3(-0.32, 1.9, 0.2)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.20, 0.14, 0.08)
	pmat.metallic = 0.3
	pistol_mesh.material_override = pmat
	parent.add_child(pistol_mesh)

# Build a blocky charger under the rider: barrel, chest, hindquarters, an arched neck
# and head, a tail, and four legs on pivots so they can swing at the gait — plus the
# tack that marks a senior officer's mount: a leather saddle, a gold-piped shabraque
# (saddle cloth) in the militia's facing colour, a bridle, a breast strap and brass
# stirrups. Faces +Z.
func _build_horse(parent: Node3D, facing: Color) -> void:
	var hide := StandardMaterial3D.new()
	hide.albedo_color = Color(0.17, 0.11, 0.07)   # a dark bay
	hide.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.04, 0.03)   # mane, tail, hooves, muzzle
	dark.roughness = 1.0
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.86, 0.84, 0.80)   # a blaze down the face
	white.roughness = 0.9
	# --- the body: barrel, deeper chest at the front, fuller hindquarters at the rear
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.5, 0.62, 1.42)
	body.mesh = bb
	body.position = Vector3(0, 0.98, -0.05)
	body.material_override = hide
	parent.add_child(body)
	var chest := MeshInstance3D.new()
	var cbb := BoxMesh.new()
	cbb.size = Vector3(0.46, 0.52, 0.42)
	chest.mesh = cbb
	chest.position = Vector3(0, 1.02, 0.62)
	chest.material_override = hide
	parent.add_child(chest)
	var rump := MeshInstance3D.new()
	var rbb := BoxMesh.new()
	rbb.size = Vector3(0.52, 0.6, 0.5)
	rump.mesh = rbb
	rump.position = Vector3(0, 1.02, -0.78)
	rump.material_override = hide
	parent.add_child(rump)
	# --- the neck, arched up and forward, with a dark mane along its crest
	var neck := MeshInstance3D.new()
	var nbb := BoxMesh.new()
	nbb.size = Vector3(0.26, 0.7, 0.3)
	neck.mesh = nbb
	neck.position = Vector3(0, 1.42, 0.86)
	neck.rotation = Vector3(-0.7, 0, 0)
	neck.material_override = hide
	parent.add_child(neck)
	var mane := MeshInstance3D.new()
	var mbb := BoxMesh.new()
	mbb.size = Vector3(0.08, 0.72, 0.13)
	mane.mesh = mbb
	mane.position = Vector3(0, 1.45, 0.74)
	mane.rotation = Vector3(-0.7, 0, 0)
	mane.material_override = dark
	parent.add_child(mane)
	# --- the head and muzzle, dropped a little forward, ears pricked, a white blaze
	var head := MeshInstance3D.new()
	var hbb := BoxMesh.new()
	hbb.size = Vector3(0.22, 0.28, 0.5)
	head.mesh = hbb
	head.position = Vector3(0, 1.72, 1.14)
	head.rotation = Vector3(0.42, 0, 0)
	head.material_override = hide
	parent.add_child(head)
	var blaze := MeshInstance3D.new()
	var zbb := BoxMesh.new()
	zbb.size = Vector3(0.06, 0.02, 0.34)
	blaze.mesh = zbb
	blaze.position = Vector3(0, 1.86, 1.2)
	blaze.rotation = Vector3(0.42, 0, 0)
	blaze.material_override = white
	parent.add_child(blaze)
	var muzzle := MeshInstance3D.new()
	var ubb := BoxMesh.new()
	ubb.size = Vector3(0.18, 0.18, 0.2)
	muzzle.mesh = ubb
	muzzle.position = Vector3(0, 1.6, 1.36)
	muzzle.material_override = dark
	parent.add_child(muzzle)
	for ex in [-0.07, 0.07]:
		var ear := MeshInstance3D.new()
		var ebb := BoxMesh.new()
		ebb.size = Vector3(0.05, 0.14, 0.05)
		ear.mesh = ebb
		ear.position = Vector3(ex, 1.92, 0.98)
		ear.material_override = hide
		parent.add_child(ear)
	# --- the tail, hanging off the hindquarters
	var tail := MeshInstance3D.new()
	var tbb := BoxMesh.new()
	tbb.size = Vector3(0.13, 0.58, 0.13)
	tail.mesh = tbb
	tail.position = Vector3(0, 0.84, -1.04)
	tail.rotation = Vector3(0.5, 0, 0)
	tail.material_override = dark
	parent.add_child(tail)
	# --- four legs, each on a hip pivot at the body so it can swing at the gait
	_horse_legs.clear()
	for lp in [Vector3(0.18, 0, 0.52), Vector3(-0.18, 0, 0.52), Vector3(0.2, 0, -0.58), Vector3(-0.2, 0, -0.58)]:
		var hip := Node3D.new()
		hip.position = Vector3(lp.x, 0.72, lp.z)
		parent.add_child(hip)
		var leg := MeshInstance3D.new()
		var lbb := BoxMesh.new()
		lbb.size = Vector3(0.15, 0.72, 0.17)
		leg.mesh = lbb
		leg.position = Vector3(0, -0.36, 0)
		leg.material_override = hide
		hip.add_child(leg)
		var hoof := MeshInstance3D.new()
		var hfb := BoxMesh.new()
		hfb.size = Vector3(0.17, 0.12, 0.2)
		hoof.mesh = hfb
		hoof.position = Vector3(0, -0.72, 0.02)
		hoof.material_override = dark
		hip.add_child(hoof)
		_horse_legs.append(hip)
	# --- tack: saddle, gold-piped shabraque, bridle, breast strap, brass stirrups ---
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.22, 0.13, 0.07)
	leather.roughness = 0.85
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.80, 0.64, 0.22)
	brass.metallic = 0.75
	brass.roughness = 0.25
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = facing
	cloth.roughness = 0.7
	var saddle := MeshInstance3D.new()
	var sbb := BoxMesh.new()
	sbb.size = Vector3(0.30, 0.14, 0.46)
	saddle.mesh = sbb
	saddle.position = Vector3(0, 1.32, -0.02)
	saddle.material_override = leather
	parent.add_child(saddle)
	var shabraque := MeshInstance3D.new()
	var shb := BoxMesh.new()
	shb.size = Vector3(0.42, 0.05, 0.56)
	shabraque.mesh = shb
	shabraque.position = Vector3(0, 1.17, -0.46)
	shabraque.material_override = cloth
	parent.add_child(shabraque)
	var shab_trim := MeshInstance3D.new()
	var stmb := BoxMesh.new()
	stmb.size = Vector3(0.46, 0.02, 0.60)
	shab_trim.mesh = stmb
	shab_trim.position = Vector3(0, 1.14, -0.46)
	shab_trim.material_override = brass
	parent.add_child(shab_trim)
	var bit := MeshInstance3D.new()
	var bmb := BoxMesh.new()
	bmb.size = Vector3(0.24, 0.025, 0.025)
	bit.mesh = bmb
	bit.position = Vector3(0, 1.70, 1.18)
	bit.material_override = leather
	parent.add_child(bit)
	var noseband := MeshInstance3D.new()
	var nmb := BoxMesh.new()
	nmb.size = Vector3(0.19, 0.022, 0.022)
	noseband.mesh = nmb
	noseband.position = Vector3(0, 1.60, 1.30)
	noseband.material_override = leather
	parent.add_child(noseband)
	var breaststrap := MeshInstance3D.new()
	var brb := BoxMesh.new()
	brb.size = Vector3(0.30, 0.02, 0.02)
	breaststrap.mesh = brb
	breaststrap.position = Vector3(0, 1.16, 0.56)
	breaststrap.material_override = leather
	parent.add_child(breaststrap)
	for sx2 in [-0.26, 0.26]:
		var stirrup := MeshInstance3D.new()
		var stb := BoxMesh.new()
		stb.size = Vector3(0.07, 0.05, 0.10)
		stirrup.mesh = stb
		stirrup.position = Vector3(sx2, 0.96, 0.06)
		stirrup.material_override = brass
		parent.add_child(stirrup)

# ------------------------------------------------------------------ armies

func _spawn_armies() -> void:
	if _inflated:
		_spawn_from_setup()
		return
	# which battalion indices are human-led (host knows all; single = just you)
	var humans: Array = [GameConfig.local_slot]
	if GameConfig.mode == "host":
		humans = Net.human_slots()
	# a founded militia rides INDEPENDENT of the order of battle (see _spawn_independent_militia) —
	# no slot in the standard 100-per-team OOB is the player's, so none should be marked human/player
	if GameConfig.has_militia:
		humans = []
	for team in [0, 1]:
		var z := -360.0 if team == 0 else 360.0   # deploy further apart: a deeper field, a real march
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
			var cp := dv / DIVISIONS_PER_CORPS
			# EACH BRIGADE GARRISONS ITS OWN PLACE — a town, fort or depot scattered across the
			# province — so the armies begin dispersed, not lined up. The campaign becomes a
			# string of engagements you ride between and HEAR before you see; the AI marches
			# the brigades together onto the contested towns.
			var sites: Array = _team_sites[team]
			var site: Vector3 = sites[brig] if brig < sites.size() else Vector3(_sector_x(cp), 0, z)
			# a tight block at the garrison, facing the enemy's country: 3 abreast, two deep
			var fwd := Vector3(sin(face), 0, cos(face))
			var rightv := Vector3(fwd.z, 0, -fwd.x)
			var col := kb % 3
			var row := kb / 3
			b.pos = site + rightv * ((float(col) - 1.0) * 92.0) - fwd * (float(row) * 74.0)
			# regimental dress: facings by brigade, the 5th battalion in the light coat
			var fpal: Array = FACINGS_0 if team == 0 else FACINGS_1
			var fc: Color = fpal[brig % fpal.size()]
			var coat_idx := 1 if kb == BATTS_PER_BRIGADE - 1 else 0
			b.inst_col = Color(fc.r, fc.g, fc.b, _dress_packed(coat_idx, gidx, gidx == GameConfig.local_slot and not GameConfig.has_militia))
			b.spawn = b.pos
			b.facing = face
			b.formation = "column"               # advance in column, deploy on contact
			b.off_facing = face
			b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
			b.human = gidx in humans
			b.is_player = (gidx == GameConfig.local_slot) and not GameConfig.has_militia
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
			_assign_battalion_skills(b)        # every regiment rolls a distinct profile
			# THE SEAM: the world's record for this unit overrides the fresh defaults —
			# survivors, powder, nerve, drill, SKILLS and dress all carry in from outside
			if gidx < _setup.units.size():
				var u: BattleSetup.BattUnit = _setup.units[gidx]
				if u.name != "":
					b.rname = u.name
				b.ammo = u.ammo
				b.morale = u.morale
				_apply_seam_skills(b, u)
				b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, _dress_packed(int(u.coat_idx), gidx, gidx == GameConfig.local_slot and not GameConfig.has_militia))
				while b.figs.size() > u.men and b.figs.size() > 0:
					b.figs.pop_back()          # losses are forever
			b.start_men = b.figs.size()
			if b.is_player:
				_build_roster(b)               # name the men under your hand
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
	if GameConfig.has_militia:
		_spawn_independent_militia()
	elif player == null:
		player = battalions[clampi(GameConfig.local_slot, 0, battalions.size() - 1)]

# THE FOUNDED MILITIA (Phase 0): the player's own battalion, raised on the intro
# screen, never enters the brigade/division/corps order of battle — it rides as an
# extra unit outside the fixed 100-per-team OOB, so the AI commanders can request it
# (a courier, not a command) but never absorb it. See _assign_brigades, which skips
# `independent` battalions when chunking each team into brigades.
func _spawn_independent_militia() -> void:
	var team := 0   # rides with the Crown until a side-choice exists at founding
	var face := 0.0 if team == 0 else PI
	var spawn_pos := Vector3(_sector_x(0), 0, -360.0)
	for t in field_towns:
		if int(t.get("owner", -1)) == team:
			spawn_pos = (t["pos"] as Vector3) + Vector3(60.0, 0, 0)
			break
	var gidx: int = BATT_PER_TEAM * 2   # synthetic index, outside the standard OOB
	var b := Batt.new()
	b.team = team
	b.idx = gidx
	b.independent = true
	b.pos = spawn_pos
	b.spawn = b.pos
	b.facing = face
	b.formation = "line"
	b.off_facing = face
	b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
	b.human = true
	b.is_player = true
	b.companies = 6 if team == 0 else 10
	b.ammo = START_ROUNDS
	b.last_pos = b.pos
	var mp := AudioStreamPlayer3D.new()        # the drummer's marching cadence
	mp.max_distance = 700.0
	mp.unit_size = 14.0
	mp.volume_db = 4.0
	add_child(mp)
	b.march_player = mp
	_fill_figs(b, MILITIA_START_MEN)           # a small band, not a full battalion
	_assign_battalion_skills(b)
	b.rname = "%s (yours)" % GameConfig.militia_name
	var mf: Color = GameConfig.militia_facing
	b.inst_col = Color(mf.r, mf.g, mf.b, _dress_packed(0, gidx, true))
	b.start_men = b.figs.size()
	_build_roster(b)                           # name the men under your hand
	_start_strength[team] += b.figs.size()
	_make_flag(b, team)
	battalions.append(b)
	player = b
	off_pos = b.pos - Vector3(sin(face), 0, cos(face)) * 8.0   # just behind your line
	off_facing = face
	off_vis = face
	_cam_yaw = face + PI                                       # look toward the enemy
	_reslot(player)

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
		b.human = (u.human_slot >= 0)                          # any player-commanded unit
		b.is_player = (u.human_slot == GameConfig.local_slot)  # the one THIS peer drives
		b.companies = 6 if team == 0 else 10
		b.ammo = u.ammo
		b.morale = u.morale
		b.rname = u.name
		b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, _dress_packed(int(u.coat_idx), ui, b.is_player))
		b.last_pos = b.pos
		var mp := AudioStreamPlayer3D.new()
		mp.max_distance = 700.0
		mp.unit_size = 14.0
		mp.volume_db = 4.0
		add_child(mp)
		b.march_player = mp
		_fill_figs(b)
		_assign_battalion_skills(b)
		_apply_seam_skills(b, u)             # carry the regiment's real skills from the world
		while b.figs.size() > u.men and b.figs.size() > 0:
			b.figs.pop_back()                # the survivors who marched here, no more
		b.start_men = b.figs.size()
		if b.is_player:
			_build_roster(b)
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
	pcyl.height = 2.0
	pole.mesh = pcyl
	pole.position = Vector3(0, 1.15, 0)        # pole spans the line's height, not towering over it
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.25, 0.16, 0.08)
	pole.material_override = pmat
	b.flag.add_child(pole)

	# a gold spearhead finial atop the staff, the mark of a proper stand of colours
	var gold := Color(0.83, 0.68, 0.21)
	var finial := MeshInstance3D.new()
	var fcone := CylinderMesh.new()
	fcone.top_radius = 0.0
	fcone.bottom_radius = 0.04
	fcone.height = 0.16
	finial.mesh = fcone
	finial.position = Vector3(0, 2.23, 0)
	var finmat := StandardMaterial3D.new()
	finmat.albedo_color = gold
	finmat.metallic = 0.6
	finmat.roughness = 0.3
	finial.material_override = finmat
	b.flag.add_child(finial)

	var nat := ARMY_BLUE if team == 0 else ARMY_RED
	var fac := Color(b.inst_col.r, b.inst_col.g, b.inst_col.b)

	# the cloth assembly: one wrapper node so the existing sway/flap animation
	# (which rotates b.flag_cloth as a whole) still drives every part together
	var cloth := Node3D.new()
	cloth.position = Vector3(0.5, 1.85, 0)      # the colours fly just above the men's heads
	b.flag.add_child(cloth)
	b.flag_cloth = cloth

	# the field — the regiment's facing colour quartered with the national one
	var field := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(0.95, 0.62, 0.018)
	field.mesh = cbox
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = nat.lerp(fac, 0.5)
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	field.material_override = cmat
	cloth.add_child(field)

	# a hoist canton in the facing colour, by the staff edge
	var canton := MeshInstance3D.new()
	var canbox := BoxMesh.new()
	canbox.size = Vector3(0.34, 0.29, 0.02)
	canton.mesh = canbox
	canton.position = Vector3(-0.30, 0.16, 0.0015)
	var canmat := StandardMaterial3D.new()
	canmat.albedo_color = fac
	canmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canton.material_override = canmat
	cloth.add_child(canton)

	# a gold roundel at the centre, standing for the regimental badge
	var roundel := MeshInstance3D.new()
	var rcyl := CylinderMesh.new()
	rcyl.top_radius = 0.13
	rcyl.bottom_radius = 0.13
	rcyl.height = 0.012
	roundel.mesh = rcyl
	roundel.rotation_degrees = Vector3(90, 0, 0)
	roundel.position = Vector3(0.05, 0, 0.013)
	var rolmat := StandardMaterial3D.new()
	rolmat.albedo_color = gold
	rolmat.metallic = 0.4
	roundel.material_override = rolmat
	cloth.add_child(roundel)

	# a gold fringe along the top, bottom and fly edge
	var fringe_mat := StandardMaterial3D.new()
	fringe_mat.albedo_color = gold
	for fr in [
		[Vector3(0, 0.325, 0), Vector3(0.99, 0.03, 0.02)],   # top edge
		[Vector3(0, -0.325, 0), Vector3(0.99, 0.03, 0.02)],  # bottom edge
		[Vector3(0.49, 0, 0), Vector3(0.03, 0.65, 0.02)],    # fly edge
	]:
		var fr_mi := MeshInstance3D.new()
		var fr_box := BoxMesh.new()
		fr_box.size = fr[1]
		fr_mi.mesh = fr_box
		fr_mi.position = fr[0]
		fr_mi.material_override = fringe_mat
		cloth.add_child(fr_mi)

	b.flag.visible = false

func _fill_figs(b: Batt, n: int = MEN) -> void:
	b.figs.clear()
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for e in _layout(n, b.formation, b.companies):
		var slot: Vector2 = e["p"]
		var w := b.pos + right * slot.x + fwd * slot.y
		# every man is an individual: his own build, the wear on his coat, his nerve
		var br := randf_range(0.82, 1.07)              # how his uniform has weathered
		b.figs.append({ "slot": slot, "wpos": Vector3(w.x, 0, w.z), "ph": randf() * TAU,
			"spd": randf_range(0.85, 1.18), "reload": randf_range(0.0, RELOAD_TIME),
			"company": int(e["c"]), "face": float(e.get("f", 0.0)),
			"bw": randf_range(0.92, 1.07), "bh": randf_range(0.90, 1.10),   # width / height
			"wear": br, "march": 0.0,
			"flinch": 0.0, "nerve": randf_range(0.0, 1.0) })

func _reslot(b: Batt) -> void:
	var L := _layout(b.figs.size(), b.formation, b.companies)
	for i in range(b.figs.size()):
		var e: Dictionary = L[i]
		b.figs[i]["slot"] = e["p"]
		b.figs[i]["company"] = int(e["c"])
		b.figs[i]["face"] = float(e.get("f", 0.0))

# =============================================================== SKILLS & ROSTER
const SKILL_KEYS := ["reload", "aim", "melee", "discipline", "stamina"]
const SKILL_NAMES := { "reload": "Drill", "aim": "Marksmanship", "melee": "Bayonet",
	"discipline": "Discipline", "stamina": "Stamina" }
const _SURNAMES := ["Sharpe", "Harper", "Cooper", "Hagman", "Perkins", "Tongue", "Harris",
	"Mercer", "Plunkett", "Dodd", "Fletcher", "Carson", "Bell", "Mason", "Webb", "Ward",
	"Pike", "Reed", "Holt", "Lowe", "Vane", "Fenn", "Doyle", "Gale", "Frost", "Sully",
	"Tanner", "Burke", "Coltrane", "Maguire", "Rourke", "Slade", "Croft", "Brand", "Hale"]
const _FORENAMES := ["Richard", "Patrick", "Daniel", "Thomas", "William", "Henry", "George",
	"James", "John", "Edward", "Francis", "Samuel", "Isaac", "Joseph", "Robert", "Hugh"]
const _RANKS := ["Pte.", "Cpl.", "Sgt.", "C/Sgt.", "Lt.", "Capt."]

func _sk(b: Batt, key: String) -> float:
	return float(b.skill.get(key, 50.0))

# a crack battalion loads near twice as fast as raw conscripts
func _reload_factor(b: Batt) -> float:
	return lerpf(1.4, 0.7, clampf(_sk(b, "reload") / 100.0, 0.0, 1.0))
func _aim_factor(b: Batt) -> float:
	return lerpf(0.7, 1.34, clampf(_sk(b, "aim") / 100.0, 0.0, 1.0))
func _melee_factor(b: Batt) -> float:
	return lerpf(0.72, 1.36, clampf(_sk(b, "melee") / 100.0, 0.0, 1.0))
# fatigue tells: tired hands fumble the cartridge and the aim wanders
func _fatigue_reload_mul(b: Batt) -> float:
	return 1.0 + clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.55
func _fatigue_aim_mul(b: Batt) -> float:
	return 1.0 - clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.35
# discipline buys lasting order — a steady battalion has more cohesion to spend before it breaks
func _disc_cohesion(b: Batt) -> float:
	return lerpf(72.0, 122.0, clampf(_sk(b, "discipline") / 100.0, 0.0, 1.0))

func _quality_label(base: float) -> String:
	if base >= 84.0: return "elite"
	if base >= 70.0: return "veteran"
	if base >= 56.0: return "seasoned"
	if base >= 40.0: return "regular"
	return "green"

# Roll a battalion's profile: a base competence with a personality (one regiment shoots,
# another holds, another loves the bayonet), so no two battalions feel the same.
func _roll_skills(base: float, spread: float) -> Dictionary:
	var d := {}
	for key in SKILL_KEYS:
		d[key] = clampf(base + randf_range(-spread, spread), 6.0, 99.0)
	# give each battalion ONE thing it is notably good at — its reputation
	var star: String = SKILL_KEYS[randi() % SKILL_KEYS.size()]
	d[star] = clampf(float(d[star]) + randf_range(8.0, 18.0), 6.0, 99.0)
	return d

# Assign a fresh battalion its skills (the standalone field rolls every regiment varied).
func _assign_battalion_skills(b: Batt) -> void:
	var base := randf_range(34.0, 82.0)
	b.skill = _roll_skills(base, 13.0)
	b.quality = _quality_label(base)
	b.exp_mul = _reload_factor(b)
	b.cohesion = _disc_cohesion(b)
	b.fatigue = 0.0

func _skill_avg(b: Batt) -> float:
	var s := 0.0
	for key in SKILL_KEYS:
		s += _sk(b, key)
	return s / float(SKILL_KEYS.size())

# Carry a regiment's drilled skills in from the world (the seam), if it tracks them;
# otherwise bias the rolled profile by its experience so veterans come in sharper.
func _apply_seam_skills(b: Batt, u) -> void:
	if u.skills != null and not (u.skills as Dictionary).is_empty():
		for key in SKILL_KEYS:
			if u.skills.has(key):
				b.skill[key] = clampf(float(u.skills[key]), 6.0, 99.0)
	else:
		var scale := clampf(u.experience, 0.6, 1.5)
		for key in SKILL_KEYS:
			b.skill[key] = clampf(_sk(b, key) * scale, 6.0, 99.0)
	b.quality = _quality_label(_skill_avg(b))
	b.exp_mul = _reload_factor(b)
	b.cohesion = _disc_cohesion(b)

# Build the player's named roster: one record per man, ranks salted through, the
# command cast (officer, sergeants) drawn as the most capable. Skills scatter around
# the battalion profile, and the profile is then re-derived as their living average.
func _build_roster(b: Batt) -> void:
	b.roster.clear()
	var n := b.figs.size()
	if n <= 0:
		return
	var ncos := clampi(int(round(float(n) / 90.0)), 3, 9)   # a sergeant to roughly each company
	for i in range(n):
		var coy := (i * b.companies) / maxi(1, n)
		var rank := "Pte."
		if i == 0:
			rank = "Capt."          # the commanding officer (you)
		elif i <= ncos:
			rank = "Sgt."
		elif i <= ncos * 3:
			rank = "Cpl."
		var lift := 0.0
		if rank == "Capt.": lift = 16.0
		elif rank == "Sgt.": lift = 11.0
		elif rank == "Cpl.": lift = 5.0
		var man := { "name": _rand_name(), "rank": rank, "coy": coy, "xp": 0.0, "kills": 0, "alive": true, "focus": "" }
		for key in SKILL_KEYS:
			man[key] = clampf(_sk(b, key) + lift + randf_range(-12.0, 12.0), 6.0, 99.0)
		b.roster.append(man)
	# the officers you commissioned on the intro screen lead the companies of YOUR battalion
	if b.is_player and GameConfig.has_militia and not GameConfig.militia_officers.is_empty():
		var offs: Array = GameConfig.militia_officers
		for coy in range(b.companies):
			if coy >= offs.size():
				break
			for m in b.roster:
				if int(m["coy"]) == coy and String(m["rank"]) != "Capt.":
					m["name"] = String(offs[coy]["name"])
					m["rank"] = "Lt."
					m["discipline"] = clampf(float(offs[coy]["skill"]), 6.0, 99.0)
					break
	_reprofile(b)

func _rand_name() -> String:
	return "%s %s" % [_FORENAMES[randi() % _FORENAMES.size()], _SURNAMES[randi() % _SURNAMES.size()]]

# Re-derive the battalion profile from the living roster (so casualties, promotions and
# training all flow through to what the sim actually reads).
func _reprofile(b: Batt) -> void:
	if b.roster.is_empty():
		return
	var sums := { "reload": 0.0, "aim": 0.0, "melee": 0.0, "discipline": 0.0, "stamina": 0.0 }
	var live := 0
	for m in b.roster:
		if not m["alive"]:
			continue
		live += 1
		for key in SKILL_KEYS:
			sums[key] += float(m[key])
	if live == 0:
		return
	# reload/aim/melee/stamina are the men's averages (note: as privates fall first, the
	# survivors skew tougher — a mauled battalion's remnant is its hardest men). DISCIPLINE
	# is a managed leadership value driven by promotions and drill, so it is left alone here.
	for key in SKILL_KEYS:
		if key == "discipline":
			continue
		b.skill[key] = sums[key] / float(live)
	b.exp_mul = _reload_factor(b)

# Keep the named roster in step with the strength: as figs fall, mark men dead from the
# rank and file first (privates before corporals before sergeants), so the leaders endure.
func _sync_roster_losses(b: Batt) -> void:
	if b.roster.is_empty():
		return
	var want := b.figs.size()
	var live := 0
	for m in b.roster:
		if m["alive"]:
			live += 1
	var to_kill := live - want
	if to_kill <= 0:
		return
	var order := { "Pte.": 0, "Cpl.": 1, "Sgt.": 2, "C/Sgt.": 3, "Lt.": 4, "Capt.": 5 }
	# walk privates → leaders, dropping the rank and file first
	for tier in range(6):
		if to_kill <= 0:
			break
		for m in b.roster:
			if to_kill <= 0:
				break
			if m["alive"] and int(order.get(m["rank"], 0)) == tier:
				m["alive"] = false
				to_kill -= 1
	_reprofile(b)

func _dims(n: int, formation: String) -> Vector2i:
	if formation == "march":
		# the road/march column — only a few files wide, so it makes far better speed than
		# the broad assault column or a deployed line
		var mf := clampi(int(round(float(n) / 130.0)), 4, 8)
		return Vector2i(mf, int(ceil(float(n) / float(mf))))
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

# The x-centre of a corps' sector on the standalone province (corps fight kilometres apart).
func _sector_x(cp: int) -> float:
	return -1000.0 - float(cp) * 3800.0

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

	# guns massed into batteries. In a campaign each battery is posted just behind one of
	# its army's garrisons (so every brigade has its guns); in an MP skirmish they line up.
	for team in [0, 1]:
		var face := 0.0 if team == 0 else PI
		var fwd := Vector3(sin(face), 0, cos(face))
		var rightv := Vector3(fwd.z, 0, -fwd.x)
		var nbat: int = 2 if _inflated else BATTERIES_PER_TEAM   # a couple of batteries in a small action
		var sites: Array = _team_sites[team]
		for bi in range(nbat):
			var base: Vector3
			if _inflated or sites.is_empty():
				var bx := (float(bi) - (nbat - 1) * 0.5) * 300.0
				base = Vector3(bx, 0, -384.0 if team == 0 else 384.0)
			else:
				var site: Vector3 = sites[bi % sites.size()]
				base = site - fwd * 150.0                       # posted just behind the garrison
			var span := (GUNS_PER_BATTERY - 1) * GUN_SPACING
			for i in range(GUNS_PER_BATTERY):
				var g := Gun.new()
				g.team = team
				var off := rightv * (float(i) * GUN_SPACING - span * 0.5) + fwd * randf_range(-1.5, 1.5)
				g.pos = base + off
				g.move_to = g.pos
				g.facing = face
				g.reload = ARTY_RELOAD * randf_range(0.2, 1.0)   # stagger the opening rounds
				_make_gun(g)
				guns.append(g)

# A gun-crew figure: the same coat/collar/cuff/leg layout idiom as the soldiers and
# officers, but a working gunner's rig — short-skirted coat, no shako, a round forage
# cap, and a cartridge pouch at the hip instead of crossbelts. One shared mesh, painted
# by a per-team ShaderMaterial (coat = the army's colour; trim is brass/buff on both
# sides — the artillery's own branch colour, not the infantry's gold lace).
func _gunner_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.175, 0.0), Vector3(0.38, 0.46, 0.22))         # coat body
	_add_box(st, Vector3(0, -0.02, -0.08), Vector3(0.34, 0.18, 0.12))      # short coat skirt (back)
	_add_box(st, Vector3(0, 0.40, 0.0), Vector3(0.32, 0.06, 0.225))        # collar
	_add_box(st, Vector3(0, 0.18, 0.118), Vector3(0.20, 0.36, 0.03))       # lapel / plastron
	_add_box(st, Vector3(0, 0.0, 0.10), Vector3(0.42, 0.07, 0.18))         # waist belt
	_add_box(st, Vector3(0.22, -0.08, 0.16), Vector3(0.12, 0.13, 0.08))    # cartridge pouch (hip)
	for sx in [-0.255, 0.255]:
		_add_box(st, Vector3(sx, 0.17, 0.0), Vector3(0.11, 0.44, 0.125))      # sleeve
		_add_box(st, Vector3(sx, -0.05, 0.0), Vector3(0.12, 0.07, 0.135))     # cuff
		_add_box(st, Vector3(sx, -0.15, -0.01), Vector3(0.095, 0.10, 0.105)) # hand
	for sx in [-0.10, 0.10]:
		_add_box(st, Vector3(sx, -0.45, 0), Vector3(0.16, 0.78, 0.19))        # leg
	_add_box(st, Vector3(0, 0.555, 0), Vector3(0.205, 0.21, 0.205))         # head
	_add_cyl(st, Vector3(0, 0.70, 0), 0.165, 0.155, 0.10, 10)               # forage cap body
	_add_box(st, Vector3(0, 0.655, 0.155), Vector3(0.14, 0.03, 0.07))      # cap peak
	_add_box(st, Vector3(0, 0.765, 0), Vector3(0.05, 0.035, 0.05))         # cap top button
	return st.commit()

func _gunner_shader(coat: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coat_col;
uniform vec3 trim = vec3(0.62, 0.50, 0.22);    // brass / buff — the artillery's own colour
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
varying float vy;
varying float vx;
varying float vz;
void vertex() { vy = VERTEX.y; vx = VERTEX.x; vz = VERTEX.z; }
void fragment() {
	vec3 col = coat_col;
	if (vy < -0.05) col = vec3(0.16, 0.16, 0.18);                          // dark trousers
	if (vy > 0.37 && vy < 0.43) col = trim;                                // collar
	if (vz > 0.09 && abs(vx) < 0.13 && vy > 0.0 && vy < 0.36) col = trim;  // lapel
	if (abs(vx) > 0.20 && vy > -0.09 && vy < -0.015) col = trim;           // cuffs
	if (vy > -0.04 && vy < 0.07 && vz > 0.0) col = vec3(0.30, 0.27, 0.20); // waist belt (buff leather)
	if (vx > 0.13 && vy < -0.01 && vy > -0.22) col = vec3(0.22, 0.16, 0.10); // cartridge pouch
	if (abs(vx) > 0.20 && vy < -0.10) col = skin;                          // hands
	if (vy > 0.44 && vy < 0.65) col = skin;                                // head
	if (vy >= 0.65 && vy < 0.76) col = vec3(0.07, 0.07, 0.08);             // forage cap body
	if (vz > 0.10 && vy > 0.60 && vy < 0.70) col = vec3(0.05, 0.05, 0.06); // cap peak
	if (vy >= 0.75) col = trim;                                            // cap top button
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("coat_col", Vector3(coat.r, coat.g, coat.b))
	return m

# Lazily build (once) and return [mesh, material] for a gunner of the given team —
# every gun on the field shares the same two materials, so building 30+ pieces costs
# nothing extra beyond the first gunner of each side.
func _gunner_assets(team: int) -> Array:
	if _gunner_mesh_cache == null:
		_gunner_mesh_cache = _gunner_mesh()
	if _gunner_mats[team] == null:
		_gunner_mats[team] = _gunner_shader(team_color(team).darkened(0.15))
	return [_gunner_mesh_cache, _gunner_mats[team]]

# A draft horse in harness — the same body plan as the cavalry's mount but stripped of
# saddle/shabraque/stirrups and given a collar, back band and breeching strap instead,
# since it tows the limber rather than carries a rider.
func _draft_horse_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(st, Vector3(0, 0.95, 0), Vector3(0.46, 0.58, 1.30))            # barrel
	_add_box(st, Vector3(0, 0.98, 0.60), Vector3(0.42, 0.48, 0.38))        # chest
	_add_box(st, Vector3(0, 0.98, -0.70), Vector3(0.46, 0.55, 0.46))       # hindquarters
	_add_box(st, Vector3(0, 1.48, 0.95), Vector3(0.24, 0.50, 0.40))        # neck
	_add_box(st, Vector3(0, 1.72, 1.28), Vector3(0.20, 0.24, 0.38))        # head
	_add_box(st, Vector3(0, 1.62, 1.46), Vector3(0.16, 0.14, 0.14))        # muzzle
	for ex in [-0.06, 0.06]:
		_add_box(st, Vector3(ex, 1.88, 1.06), Vector3(0.045, 0.12, 0.045))    # ears
	_add_box(st, Vector3(0, 1.50, 0.95), Vector3(0.30, 0.10, 0.46))        # mane crest
	_add_box(st, Vector3(0, 0.76, -1.00), Vector3(0.12, 0.58, 0.12))       # tail
	for lp in [Vector2(0.17, 0.48), Vector2(-0.17, 0.48), Vector2(0.19, -0.52), Vector2(-0.19, -0.52)]:
		_add_box(st, Vector3(lp.x, 0.34, lp.y), Vector3(0.14, 0.68, 0.16))        # leg
		_add_box(st, Vector3(lp.x, 0.02, lp.y + 0.02), Vector3(0.16, 0.12, 0.19)) # hoof
	_add_box(st, Vector3(0, 1.20, 0.58), Vector3(0.36, 0.22, 0.18))        # neck collar (harness)
	_add_box(st, Vector3(0, 1.08, -0.05), Vector3(0.42, 0.10, 0.30))       # back band
	_add_box(st, Vector3(0, 0.92, -0.62), Vector3(0.40, 0.06, 0.10))       # breeching strap (hip band)
	return st.commit()

func _draft_horse_shader(coat: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 coat_col;
varying float vy;
varying float vz;
void vertex() { vy = VERTEX.y; vz = VERTEX.z; }
void fragment() {
	vec3 col = coat_col;
	if (vy < 0.10) col = vec3(0.07, 0.06, 0.05);                                     // hooves
	if (vz < -0.85) col = vec3(0.05, 0.05, 0.05);                                    // tail
	if (vy > 1.40 && vz > 0.75 && vz < 1.15) col = vec3(0.07, 0.06, 0.05);           // mane
	if (vz > 1.35) col = vec3(0.10, 0.08, 0.07);                                     // muzzle
	if (vy > 1.05 && vy < 1.32 && vz > 0.35 && vz < 0.85) col = vec3(0.32, 0.25, 0.14); // collar
	if (vy > 0.98 && vy < 1.20 && vz > -0.35 && vz < 0.20) col = vec3(0.30, 0.24, 0.14); // back band
	if (vy > 0.82 && vy < 1.00 && vz < -0.45) col = vec3(0.30, 0.24, 0.14);          // breeching
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("coat_col", Vector3(coat.r, coat.g, coat.b))
	return m

# Lazily build (once) the shared draft-horse mesh and a couple of coat-colour variants
# (bay / black) so every limber and caisson team draws from the same two materials.
func _draft_horse_assets() -> Array:
	if _draft_horse_mesh_cache == null:
		_draft_horse_mesh_cache = _draft_horse_mesh()
		_draft_horse_mats = [_draft_horse_shader(Color(0.34, 0.22, 0.12)), _draft_horse_shader(Color(0.14, 0.13, 0.12))]
	return [_draft_horse_mesh_cache, _draft_horse_mats]

# Build one piece: a bronze barrel on a wooden carriage with two wheels and a crew.
func _make_gun(g: Gun) -> void:
	var n := Node3D.new()
	n.position = Vector3(g.pos.x, _gh(g.pos.x, g.pos.z), g.pos.z)
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

	# carriage cheeks — the wooden sidewalls that cradle the barrel's trunnions
	for sx0 in [-0.30, 0.30]:
		var cheek := MeshInstance3D.new()
		var chb := BoxMesh.new()
		chb.size = Vector3(0.08, 0.50, 1.55)
		cheek.mesh = chb
		cheek.position = Vector3(sx0, 0.58, 0.10)
		cheek.material_override = wood
		n.add_child(cheek)

	# axle binding the two wheels under the trail
	var axle := MeshInstance3D.new()
	var axb := BoxMesh.new()
	axb.size = Vector3(1.3, 0.10, 0.12)
	axle.mesh = axb
	axle.position = Vector3(0, 0.55, 0.15)
	axle.material_override = iron
	n.add_child(axle)

	# trail spade — digs into the ground at the rear and takes the recoil
	var spade := MeshInstance3D.new()
	var spb := BoxMesh.new()
	spb.size = Vector3(0.42, 0.30, 0.06)
	spade.mesh = spb
	spade.rotation.x = deg_to_rad(-25.0)
	spade.position = Vector3(0, 0.18, -1.68)
	spade.material_override = iron
	n.add_child(spade)

	# elevating-screw block, under the breech
	var quoin := MeshInstance3D.new()
	var qb := BoxMesh.new()
	qb.size = Vector3(0.22, 0.20, 0.30)
	quoin.mesh = qb
	quoin.position = Vector3(0, 0.62, -0.30)
	quoin.material_override = wood
	n.add_child(quoin)

	# two wheels (cylinders laid on the axle), each with a hub cap
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
		var hub := MeshInstance3D.new()
		var hc2 := CylinderMesh.new()
		hc2.top_radius = 0.12
		hc2.bottom_radius = 0.12
		hc2.height = 0.16
		hub.mesh = hc2
		hub.material_override = iron
		wheel.add_child(hub)

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

	# reinforcing rings, the muzzle swell, the cascabel knob and the trunnions —
	# children of the tube itself, so they recoil with the barrel and need no extra
	# rotation (the tube's local Y is already its own long axis)
	for ry in [-0.35, 0.22]:
		var ring := MeshInstance3D.new()
		var rc := CylinderMesh.new()
		rc.top_radius = 0.155
		rc.bottom_radius = 0.155
		rc.height = 0.05
		ring.mesh = rc
		ring.position = Vector3(0, ry, 0)
		ring.material_override = bronze
		tube.add_child(ring)
	var muzzle_swell := MeshInstance3D.new()
	var msc := CylinderMesh.new()
	msc.top_radius = 0.155
	msc.bottom_radius = 0.13
	msc.height = 0.16
	muzzle_swell.mesh = msc
	muzzle_swell.position = Vector3(0, 0.79, 0)
	muzzle_swell.material_override = bronze
	tube.add_child(muzzle_swell)
	var cascabel := MeshInstance3D.new()
	var csph := SphereMesh.new()
	csph.radius = 0.075
	csph.height = 0.15
	cascabel.mesh = csph
	cascabel.position = Vector3(0, -0.90, 0)
	cascabel.material_override = bronze
	tube.add_child(cascabel)
	for sxn in [-0.14, 0.14]:
		var trunnion := MeshInstance3D.new()
		var trc := CylinderMesh.new()
		trc.top_radius = 0.045
		trc.bottom_radius = 0.045
		trc.height = 0.20
		trunnion.mesh = trc
		trunnion.rotation = Vector3(0, 0, PI * 0.5)
		trunnion.position = Vector3(sxn, -0.05, 0)
		trunnion.material_override = iron
		tube.add_child(trunnion)

	# the crew — detailed gunner figures clustered at the breech (the last one is the
	# rammer, who steps up to the muzzle to load). Kept as nodes so they can be animated.
	var gassets := _gunner_assets(g.team)
	for off in [Vector3(0.8, 0, -0.4), Vector3(-0.8, 0, -0.4), Vector3(0, 0, -1.4)]:
		var crew := Node3D.new()
		var cmi := MeshInstance3D.new()
		cmi.mesh = gassets[0]
		cmi.material_override = gassets[1]
		crew.add_child(cmi)
		var base := Vector3(off.x, 0.85, off.z)
		crew.position = base
		n.add_child(crew)
		g.crew.append(crew)
		g.crew_base.append(base)

	# the limber — an ammunition chest on an axle drawn by a four-horse team. Hidden
	# until the piece hooks up to move; it leads the gun in the direction of travel.
	g.limber_group = Node3D.new()
	n.add_child(g.limber_group)
	g.limber_group.visible = false
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
	var dassets := _draft_horse_assets()
	var dmesh: ArrayMesh = dassets[0]
	var dmats: Array = dassets[1]
	var hi := 0
	for hz in [3.0, 4.7]:
		for sx3 in [-0.45, 0.45]:
			var horse := MeshInstance3D.new()
			horse.mesh = dmesh
			horse.material_override = dmats[hi % dmats.size()]
			horse.position = Vector3(sx3, 0, hz)       # the mesh already faces +Z, the direction of travel
			g.limber_group.add_child(horse)
			hi += 1

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
	var node: Node3D = g.crew.pop_back()
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
		g.cmd_t = maxf(0.0, g.cmd_t - delta)         # the player's hold on the piece lapses
		g.recoil = maxf(0.0, g.recoil - delta * 3.2)
		if g.barrel:
			g.barrel.position.z = 0.25 - g.recoil   # slide back on the carriage, ease forward
		if g.player:
			_serve_player_gun(g, delta)              # YOURS — laid by your eye, fired at your word
			continue
		if g.limber_state == "deployed":
			_animate_gun_crew(g)                     # work the piece only when in battery
		# the gun is a deliberate, slow business to move: hook up the team (limber), trundle
		# to the new ground, then unhook and deploy (unlimber). It cannot fire while limbered.
		var md := Vector2(g.move_to.x - g.pos.x, g.move_to.z - g.pos.z).length()
		match g.limber_state:
			"deployed":
				# a gun in action STAYS in action: it only limbers up to relocate when it
				# has NO target where it stands (the fight has moved out of its arc). This
				# stops batteries endlessly chasing an advancing line and never firing.
				var idle: bool = _gun_target(g) == null and _nearest_enemy_cav_dist(g.pos, g.team) > CANISTER_RANGE * 1.5
				if md > ARTY_MOVE_THRESHOLD and idle:
					g.limber_state = "limbering"   # nothing to shoot here — displace to the new ground
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
						g.node.position = Vector3(g.pos.x, _gh(g.pos.x, g.pos.z), g.pos.z)
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
	scar_mm.set_instance_transform(scar_idx, Transform3D(basis, Vector3(pos.x, 0.02 + _gh(pos.x, pos.z), pos.z)))
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

# A naval gun aims at the target ship's current position with range-scaled scatter, then
# the ball flies the real arc — whether it strikes home is resolved against the ship's hull
# where she actually lies when the ball arrives (she may have sailed clear of where she was).
func _spawn_naval_shot(from: Vector3, target_ship: Dictionary, team: int) -> void:
	var aim: Vector3 = target_ship["pos"]
	var flat := aim - from
	flat.y = 0.0
	var L := flat.length()
	if L < 1.0:
		return
	var dir := flat / L
	var perp := Vector3(dir.z, 0, -dir.x)
	var spread := L * 0.05      # a long shot across a rolling sea is as likely to miss as hit
	var to: Vector3 = aim + perp * randf_range(-spread, spread) + dir * randf_range(-spread, spread)
	flat = to - from
	flat.y = 0.0
	L = flat.length()
	if L < 1.0:
		return
	dir = flat / L
	var slot := -1
	for i in range(_shots.size()):
		if not _shots[i]["active"]:
			slot = i
			break
	if slot == -1:
		if _shots.size() >= SHOT_POOL:
			return                                  # the gun-deck's iron is all in the air already
		_shots.append({ "active": false })
		slot = _shots.size() - 1
	var tof := L / SHOT_SPEED
	var vy := (to.y - from.y) / tof + 0.5 * GUN_GRAVITY * tof
	var vel := dir * SHOT_SPEED + Vector3(0, vy, 0)
	_shots[slot] = { "active": true, "pos": from, "vel": vel, "from": from,
		"dir": dir, "dist": L, "team": team, "naval": true, "target_ship": target_ship }

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
		# a ball screaming overhead the player — once per shot, as it passes near and high
		if not s.get("whooshed", false) and p.y > 2.5 and p.y < 55.0:
			if Vector2(p.x - off_pos.x, p.z - off_pos.z).length() < 22.0:
				_play_ball_over(p)
				s["whooshed"] = true
		var flat_trav := Vector2(p.x - from.x, p.z - from.z).length()
		if flat_trav >= float(s["dist"]):
			var dir: Vector3 = s["dir"]
			var impact := Vector3(p.x, 0, p.z)
			if s.get("naval", false):
				# resolve against the target ship's hull where she lies NOW — she may have
				# sailed clear of the spot the gun was aimed at when the ball left the muzzle
				var ship_t: Dictionary = s["target_ship"]
				if not ship_t.is_empty() and not ship_t.get("sinking", false) and _ship_hit_test(ship_t, impact):
					ship_t["hp"] = float(ship_t.get("hp", SHIP_HP_MAX)) - 1.0
					_emit_dirt(Vector3(p.x, _sea_y(p.x, p.z) + 1.0, p.z), dir)   # splinters where she's struck
					_play_ball_land(impact)
					if ship_t["hp"] <= 0.0:
						_sink_ship(ship_t)
				else:
					var sp := Vector3(p.x, 0, p.z)
					sp.y = _sea_y(sp.x, sp.z)
					_emit_splash(sp)
			else:
				# arrival — plough a lane through whatever stands here
				_add_scar(impact - dir * 2.0, dir)        # the furrow starts just short of impact
				_plough(impact, dir, int(s["team"]))
				_emit_dirt(Vector3(p.x, 0.1, p.z), dir)   # earth thrown up along the ball's line
				_play_ball_land(impact)                   # the roundshot strikes the ground
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
	_update_objective_marker()               # paint your battalion's order in the world
	_update_aim_reticle()                    # where your battery is laid, marked on the ground
	_update_ships(delta)                     # the shipping sails on, the sea-fight rumbles
	if authoritative:
		# the host (or single-player) runs the whole simulation
		_player_order_cd = maxf(0.0, _player_order_cd - delta)
		_update_brigades(delta)          # commanders set every AI battalion's task first
		_commander_task(delta)           # the General sends you on tasks / summons you to the push
		# SLEEP/WAKE: near the eye every battalion ticks each frame; far away they bank time
		# and tick in bursts — so ONE scene can carry a whole province of men for the cost of
		# the few around the player. (The player's own battalion never sleeps.)
		for b in battalions:
			if _sim_far(b) and not b.human:
				b._sleep_acc += delta
				b._active = b._sleep_acc >= SLEEP_TICK
				if b._active:
					b._tick_dt = b._sleep_acc
					b._sleep_acc = 0.0
			else:
				b._active = true
				b._tick_dt = delta
		for b in battalions:
			if not b._active:
				continue
			var bd := b._tick_dt
			_update_morale(b, bd)
			_update_battalion_meta(b, bd)   # fatigue, encampment rest, drill, blooding
			b.charge_cool = maxf(0.0, b.charge_cool - bd)
			b.flinch = maxf(0.0, b.flinch - bd * 2.2)
			b.melee_vis = b.melee_foe != null
			if b.state == "routing":
				b.charging = false
				b.melee_foe = null
				_sim_flee(b, bd)
			elif b.melee_foe != null:
				_sim_melee(b, bd)
			elif b.charging:
				_sim_charge(b, bd)
			elif b.parent != null:
				_sim_skirm_det(b, bd)        # a detached company screens its battalion
			elif b.human:
				_sim_player(b, bd)           # any player-led battalion
			else:
				_sim_ai(b, bd)
		for b in battalions:
			if b._active:
				_update_firing(b, b._tick_dt)
		for b in battalions:
			if not b._active:
				continue
			if b.kills_pending > 0:                 # melee removes from the contact edge
				_kill_some(b, b.kills_pending)
				b.cas_since_redress += b.kills_pending
				b.kills_pending = 0
			# firing kills men directly (per-shot rays); the NCOs dress the ranks and
			# close the gaps promptly, so re-dress after only a few have fallen. A far
			# battalion isn't drawn man-by-man, so its re-dress is skipped (it redresses
			# the moment it comes back into full view).
			if b.cas_since_redress >= 6:
				if not _sim_far(b):
					_reslot(b)
				b.cas_since_redress = 0
			_command_casualties(b, b._tick_dt)   # officer / colours / drummer can be shot away
		_update_guns(delta)
		_update_cavalry(delta)           # the horse looks for its moment
		_warn_player_cavalry(delta)      # "Cavalry! Form square!"
		_update_rally(delta)             # your presence steadies broken men
		_update_caissons(delta)          # the ammunition waggons plod up from the rear
		_update_couriers(delta)
		_update_capture(delta)           # towns change hands as forces hold them
		_update_combat(delta)            # your own sabre, pistol and mortality
		_update_prestige()               # your renown rises and falls with the butcher's bill
		_update_objective()              # has your personal objective been won?
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
# cadence is struck up when it starts moving and falls silent the moment it halts. Also
# the place a battalion's own movement is already tracked frame to frame, so the dust
# its feet throw up underfoot piggybacks on the same moved/last_pos bookkeeping.
func _update_marching_drums(delta: float) -> void:
	if cam == null:
		return
	var have_drums := not snd_marchdrum.is_empty()
	for b in battalions:
		var moved := b.pos.distance_to(b.last_pos)
		b.last_pos = b.pos
		var mp: AudioStreamPlayer3D = b.march_player
		if have_drums and mp != null:
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
		# the haze a body of marching (or routing) men kicks up underfoot
		if moved > 0.01 and not b.figs.is_empty() and cam.position.distance_to(b.pos) < DUST_RANGE \
				and randf() < delta * 5.0:
			_emit_march_dust(b)

# A few low puffs spread along a battalion's front, scaled to its strength — bigger
# units throw up more dust, small remnants barely any.
func _emit_march_dust(b: Batt) -> void:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var width := minf(float(b.figs.size()) * 0.9, 90.0)
	var n := clampi(b.figs.size() / 50, 1, 3)
	for _i in range(n):
		var p := b.pos - fwd * 1.5 + right * randf_range(-width * 0.5, width * 0.5)
		p.y = _gh(p.x, p.z) + 0.05
		_emit_dust(p, fwd)

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
# SIM-LOD: a battalion beyond this range from the eye is simulated at battalion level —
# it still marches, holds morale, and trades fire/casualties, but not man by man.
const SIM_FULL_RANGE := 1400.0
const SLEEP_TICK := 0.5            # a far (sleeping) battalion is simulated in ~half-second bursts
const PROVINCE_SIZE := 18000.0    # the tactical scene now spans the whole province (±9 km, float-safe)
const TOWN_CAPTURE_RANGE := 480.0 # men this near a town hold/take it
const TOWN_CAPTURE_TIME := 16.0   # seconds of uncontested occupation to flip a town
var field_towns: Array = []       # the province's towns, now CAPTURABLE: {name,pos,size,owner,cap_t,cap_team,disc,shipyard}
var _cap_cd := 0.0                 # throttle on the capture check
# the wider strategic furniture: every named place on the province map and the roads
# that join them. Forts & depots are each side's garrison homes (one per brigade).
var field_sites: Array = []       # all map sites incl. towns: {name,pos,kind,team}  kind: town|fort|depot
var field_roads: Array = []       # road segments between towns: [Vector3 a, Vector3 b]
var road_segs: Array = []         # ALL drawn road segments (town net + garrison spurs), for bridges/movement
var river_pts: Array = []         # the river as a polyline of Vector3 (XZ), for crossings & fording
var bridges: Array = []           # bridge crossing points (Vector3) where roads span the river
const ROAD_WIDTH := 7.0           # how near a road counts as "on the road" (march bonus)
const RIVER_HALF := 26.0          # the river's half-width — fording it off a bridge is slow
const BRIDGE_REACH := 34.0        # how near a bridge you must be to cross dry-shod
const ROAD_SPEED_MUL := 1.45      # the pace gained marching on a made road
const FORD_SPEED_MUL := 0.32      # the crawl of fording the river away from a bridge
var _team_sites: Array = [[], []] # per-team garrison positions (Vector3), one per brigade
var _map_reveal := false          # dev only: reveal the enemy on the province map

func _sim_far(b: Batt) -> bool:
	return cam != null and cam.position.distance_to(b.pos) > SIM_FULL_RANGE

# Battalion-resolution musketry for a distant unit: the WHOLE line's expected fire as one
# figure, no per-man rays. Tuned to land near the per-man result so a battle out of sight
# resolves the same as one in front of you.
func _abstract_fire(b: Batt, delta: float, moving: bool) -> void:
	if b.spent or b.state == "routing" or b.ammo <= 0.0:
		return
	var foe := _nearest_enemy_in_range(b, FIRE_RANGE)
	if foe == null:
		return
	var d := b.pos.distance_to(foe.pos)
	b.has_target = true
	if moving:
		return                                  # no firing on the march, same as the line
	var rounds := float(b.figs.size()) * 0.5 * (delta / RELOAD_TIME)   # ~half the men firing
	b.ammo = maxf(0.0, b.ammo - rounds * AMMO_PER_SHOT)
	# the distant rumble of this far fight — heard across the map, ridden toward
	b._far_audio_cd -= delta
	if b._far_audio_cd <= 0.0:
		b._far_audio_cd = randf_range(1.4, 3.2)
		_play_distant_battle(b.pos)
	var hit := clampf(_hit_chance(d) * _aim_factor(b) * _fatigue_aim_mul(b), 0.0, 0.95)
	b._far_fire_acc += rounds * hit
	var k := int(b._far_fire_acc)
	if k > 0:
		b._far_fire_acc -= float(k)
		foe.kills_pending += k
		foe.shot_from = b.pos
		foe.morale -= float(k) * MORALE_PER_CASUALTY * INDEP_MULT
		foe.calm_t = 0.0

func _update_firing(b: Batt, delta: float) -> void:
	b.has_target = false
	b.masked = false
	# a line does not fire on the move — it must halt to load and to fire
	var batt_moving := b.pos.distance_to(b.fire_pos) > 0.012
	b.fire_pos = b.pos
	# a held "Present!" tires the arms — the muskets come down after a while
	if b.presenting:
		b.present_t += delta
		if b.present_t > 14.0 or b.charging or b.melee_foe != null or b.state == "routing":
			b.presenting = false
	if b.charging or b.melee_foe != null:
		return                           # bayonet work, not musketry
	if b.formation != "line":
		b.rolling = false                # fire-by-company is a line manoeuvre
	if b.state == "routing":
		b.fire_now = false
		b.rolling = false
		return
	# SIM-LOD: beyond the full-sim range the men are not drawn individually, so we do not
	# run the per-musket loop — the battalion trades fire at BATTALION RESOLUTION instead.
	# (A firefight is always wholly near or wholly far: musket range is ~82m, this gate is
	#  1400m, so there is never a half-and-half engagement to get wrong.)
	if _sim_far(b):
		_abstract_fire(b, delta, batt_moving)
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
	# PLAYER "Present!"/"Fire!" with no enemy ahead: still bring the muskets up, and on Fire
	# deliver a volley straight to the front into the open (it strikes anything that IS there).
	var forward := (not b.has_target) and (b.presenting or b.fire_forward)
	if not b.has_target and not forward:
		b.fire_now = false
		return
	if b.ammo <= 0.0:
		b.fire_now = false
		b.rolling = false
		b.fire_forward = false
		return                           # cartridge boxes empty — no musketry left
	var tpos: Vector3
	if b.has_target:
		tpos = cav_foe.pos if aim_cav else (gun_foe.pos if aim_gun else foe.pos)
	else:
		tpos = b.pos + Vector3(sin(b.facing), 0, cos(b.facing)) * (FIRE_RANGE * 0.55)
	b.masked = _fire_masked(b, tpos)
	if b.masked:
		b.has_target = false             # friends in the lane — the muskets come up
		b.fire_now = false
		b.fire_forward = false           # don't pour a volley into your own men
		return
	# ENFILADE: fire raking down the LENGTH of an enemy line (into its flank/end) is
	# far deadlier than fire into its front — a ball that misses one man takes the
	# man behind. Measure how aligned our fire is with the target line's frontage.
	var enf_mult := 1.0
	if not aim_gun and not aim_cav and foe != null:
		var fB := Vector3(sin(foe.facing), 0, cos(foe.facing))
		var rightB := Vector3(fB.z, 0, -fB.x)        # the enemy line's length axis
		var dirh := tpos - b.pos
		dirh.y = 0.0
		if dirh.length() > 0.1:
			var enf := absf(dirh.normalized().dot(rightB))   # 0 frontal .. 1 raking the line
			enf_mult = 1.0 + enf * enf * ENFILADE_BONUS
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
	var atwill := (not b.volley_fire) and (not b.rolling) and b.has_target   # no at-will fire into the open
	var commanded := b.fire_now and (not b.rolling)
	# a HELD volley — loaded, levelled, released on the officer's word — strikes home and
	# shatters nerve. At point-blank it is the deadliest fire on the field.
	var held_close := commanded and b.volley_fire and not b.auto_volley and b.pos.distance_to(tpos) < HELD_VOLLEY_RANGE
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
	var loading := 0                 # men working the ramrod this frame (for the reload sound)
	var volley_pts: Array = []
	for f in b.figs:
		if (f["slot"] as Vector2).y < fire_band:
			continue                     # rear ranks don't fire
		var r := float(f["reload"]) - (0.0 if batt_moving else delta)   # loading pauses on the march
		if r > 0.0:
			f["reload"] = r
			loading += 1
			continue                     # still loading
		# loaded — does he fire this frame?
		var fire := false
		if batt_moving:
			fire = false                 # halt to fire — no shooting on the march
		elif b.rolling:
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
			# THIS man's own range to the enemy decides his shot, lifted by enfilade and a held volley
			var mfwd := (tpos.x - w.x) * fwd.x + (tpos.z - w.z) * fwd.z   # forward range to the enemy line
			if mfwd < 2.0:
				mfwd = Vector2(w.x - tpos.x, w.z - tpos.z).length()
			var mhc := _hit_chance(mfwd) * enf_mult * _aim_factor(b) * _fatigue_aim_mul(b)   # marksmanship & weariness
			if held_close:
				mhc *= HELD_VOLLEY_HIT
			if randf() < minf(0.97, mhc):
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
			var rmul := INDEP_RELOAD_MUL if atwill else 1.0   # at-will fire loads more raggedly
			f["reload"] = RELOAD_TIME * shaken * b.exp_mul * _fatigue_reload_mul(b) * rmul * randf_range(0.78, 1.3)
		else:
			f["reload"] = 0.0            # stand loaded, musket levelled, waiting
	b.fire_now = false
	b.fire_forward = false               # the forward volley is spent
	# the line working its ramrods — a sprinkle of reload sounds while men load near you
	b._reload_snd_cd = maxf(0.0, b._reload_snd_cd - delta)
	if vis and loading > 0 and b._reload_snd_cd <= 0.0:
		_play_reload(b.pos)
		b._reload_snd_cd = randf_range(0.4, 1.1)
	if felled > 0:
		b.xp += float(felled)            # blooding: combat hardens the fighting skills
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
		# YOUR own volley lands as a punch — bigger when you held it to point-blank
		if b.is_player:
			_shake = minf(_shake + (0.5 if held_close else 0.28), SHAKE_MAX)
			_flash_amt = minf(_flash_amt + (0.3 if held_close else 0.12), 0.6)
	if massed and GameConfig.mode == "host":
		_fx.append([FX_VOLLEY, b.idx])       # clients reproduce the volley locally
	# morale shock only lands on a battalion (gun crews and troopers just bleed men)
	if not aim_gun and not aim_cav and foe != null:
		if massed:
			# a wall of fire crashing out at once shocks far beyond the bodies it drops;
			# a held point-blank volley shatters them
			var shock_mult := HELD_VOLLEY_SHOCK if held_close else 1.0
			foe.morale -= (kills * MORALE_PER_CASUALTY * VOLLEY_CASUALTY_MULT + massed_men * VOLLEY_SHOCK) * shock_mult
			foe.flinch = minf(foe.flinch + massed_men * 0.004 + float(kills) * 0.04 + (0.8 if held_close else 0.0), 2.0)
			foe.calm_t = 0.0
			_ripple_flinch(foe, clampf(float(massed_men) / 150.0 + float(kills) * 0.06 + (0.5 if held_close else 0.0), 0.3, 1.0))
		elif kills > 0:
			# independent fire: the men just trickle down — little moral impact
			foe.morale -= kills * MORALE_PER_CASUALTY * INDEP_MULT
			foe.calm_t = 0.0
			_ripple_flinch(foe, clampf(float(kills) * 0.12, 0.15, 0.6))

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
# A volley doesn't strike a unit as one body — individual men recoil, duck and shy
# from the crash. Bump the flinch of a scattered subset so the LINE ripples, not the block.
func _ripple_flinch(b: Batt, intensity: float) -> void:
	if b.figs.is_empty():
		return
	var n := mini(b.figs.size(), int(float(b.figs.size()) * 0.35 * intensity) + 2)
	for k in range(n):
		var f: Dictionary = b.figs[randi() % b.figs.size()]
		f["flinch"] = minf(1.5, float(f.get("flinch", 0.0)) + randf_range(0.4, 1.1) * intensity)

func _hit_chance(d: float) -> float:
	if d >= FIRE_RANGE:
		return 0.0
	var t := 1.0 - d / FIRE_RANGE          # 1 at the muzzle, 0 at max range
	return HIT_POINT_BLANK * pow(t, HIT_FALLOFF)

func _update_morale(b: Batt, delta: float) -> void:
	# BROKEN is terminal: the men are past recall, streaming off the field. Nothing here
	# brings them back — they simply run (see _sim_flee), forever out of the fight.
	if b.broken:
		b.state = "routing"          # they are still running (drives flee/fire/army-break logic)
		b.morale = minf(b.morale, 8.0)
		b.cohesion = 0.0
		return
	# once the ARMY has broken, its men break with it — the rout is general and final
	if _army_broken[b.team]:
		_break_unit(b)
		return
	# casualties wear away the lasting cohesion (the structure and will of the unit)
	if b._coh_figs < 0:
		b._coh_figs = b.figs.size()
	var lost := b._coh_figs - b.figs.size()
	if lost > 0:
		b.cohesion -= float(lost) * COH_PER_CASUALTY
	b._coh_figs = b.figs.size()
	# a battalion shot to pieces is a broken remnant — it quits the field for good.
	# (a detached company is judged at company scale, not battalion scale)
	if b.figs.size() < (25 if b.parent != null else 60):
		b.spent = true
		if b.parent != null and b.parent.detachment == b:
			call_deferred("_recall_skirmishers", b.parent)   # deferred: mutates the array we iterate
		_break_unit(b)
		return
	b.calm_t += delta
	if b.calm_t > 4.0:               # NERVE returns once the fire slackens (cohesion does NOT)
		var rate := MORALE_RECOVER * (0.7 if b.state == "routing" else 1.0)
		b.morale = minf(100.0, b.morale + rate * delta)
	# DISCIPLINE tells under pressure: a steady regiment holds at a lower nerve, loses its
	# order more slowly when it does run, and tired men crack sooner
	var disc := clampf(_sk(b, "discipline") / 100.0, 0.0, 1.0)
	var fat := clampf(b.fatigue / 100.0, 0.0, 1.0)
	var rout_thr := ROUT_THRESHOLD * lerpf(1.28, 0.74, disc) * (1.0 + fat * 0.18)
	# running wears the unit out fast, and a rout that lasts too long becomes permanent
	if b.state == "routing":
		b.rout_t += delta
		b.cohesion -= COH_ROUT_RATE * lerpf(1.3, 0.72, disc) * delta
	# THE BREAK POINT: order gone, or run too long without an officer steadying them
	if b.cohesion <= COHESION_BREAK or (b.state == "routing" and b.rout_t > MAX_ROUT_TIME):
		_break_unit(b)
		return
	# state from nerve, with a one-way door out of routing: a unit only HALTS once its
	# nerve is well back AND it still has the order to re-form — and it re-forms shaken,
	# not magically steady, so it does not pour straight back into the fight
	if b.state == "routing":
		if b.morale >= ROUT_RALLY_NERVE and b.cohesion > COHESION_BREAK + RALLY_COH_MARGIN:
			b.state = "shaken"
			b.rout_t = 0.0
			b.morale = minf(b.morale, SHAKEN_THRESHOLD - 1.0)
	elif b.morale < rout_thr:
		b.state = "routing"
		b.rout_t = 0.0
	elif b.morale < SHAKEN_THRESHOLD:
		b.state = "shaken"
	else:
		b.state = "steady"

# The unit breaks for good: it gives up the fight, drops its order, and runs. There is
# no coming back from this — broken is broken.
func _break_unit(b: Batt) -> void:
	if not b.broken:
		b.broken = true
		b.charging = false
		b.melee_foe = null
		b.has_goal = false
		b.advancing = false
		if (b.is_player or b.human) and not _army_broken[b.team]:
			_send_player_despatch("[color=#ff6a5a]Your battalion is broken![/color] The men are past recall — they quit the field.", {})
	b.state = "routing"
	b.morale = minf(b.morale, 8.0)
	b.cohesion = 0.0

# The battalion's living condition: weariness builds with marching and fighting and is
# shed standing easy — far faster once encamped, where the men also drill and recover
# their nerve. The named roster is kept in step with the strength, and combat bloods them.
func _update_battalion_meta(b: Batt, delta: float) -> void:
	if b._fat_pos == Vector3.ZERO:
		b._fat_pos = b.pos
	var moved := b.pos.distance_to(b._fat_pos)
	b._fat_pos = b.pos
	var stam := clampf(_sk(b, "stamina") / 100.0, 0.0, 1.0)
	var drain := 0.0
	if b.broken or b.state == "routing":
		drain = FATIGUE_CHARGE              # running flat-out is its own exhaustion
	elif b.charging:
		drain = FATIGUE_CHARGE
	elif b.melee_foe != null:
		drain = FATIGUE_MELEE
	elif moved > 0.02:
		drain = FATIGUE_MARCH
	elif b.has_target:
		drain = FATIGUE_FIRE
	var safe := b.melee_foe == null and not b.charging and b.state == "steady" and not b.has_target
	# PATROLLING: an independent militia earns its keep just by riding the country clear
	# of the enemy — no camp, no drill, just showing the flag and watching the roads.
	if b.independent and b.is_player and not b.encamped and safe and moved > 0.02:
		_prestige_acc += moved * PRESTIGE_PATROL_RATE
		while _prestige_acc >= 1.0:
			_prestige_acc -= 1.0
			prestige += 1
	if b.encamped and _camp_safe(b):
		b.fatigue = maxf(0.0, b.fatigue - CAMP_REST_RATE * delta)
		b.morale = minf(100.0, b.morale + CAMP_REST_RATE * 0.5 * delta)
		b.calm_t = maxf(b.calm_t, 5.0)
		_train_tick(b, delta)
	elif drain > 0.0:
		b.fatigue = minf(100.0, b.fatigue + drain * lerpf(1.5, 0.55, stam) * delta)
	elif safe:
		b.fatigue = maxf(0.0, b.fatigue - REST_RATE * lerpf(0.7, 1.45, stam) * delta)
	# blooding: enemies felled harden the fighting skills a notch at a time
	if b.xp >= XP_PER_BLOOD:
		b.xp -= XP_PER_BLOOD
		_blood_skill(b)
	# keep the named roster in step with the strength (the player's battalion)
	if not b.roster.is_empty():
		_sync_roster_losses(b)

# Camp may only be made with no enemy bearing down — you cannot rest under the guns.
func _camp_safe(b: Batt) -> bool:
	for o in battalions:
		if o.team == b.team or o.figs.size() < 40:
			continue
		if b.pos.distance_to(o.pos) < CAMP_SAFE_RANGE:
			return false
	return _nearest_enemy_cav_dist(b.pos, b.team) > CAMP_SAFE_RANGE

# Drill in camp: the chosen skill creeps upward (toward a veteran ceiling), and for the
# player's battalion the gain is shared out to the named men too.
func _train_tick(b: Batt, delta: float) -> void:
	var has_batt := b.train_skill != "" and (b.train_skill in SKILL_KEYS)
	if has_batt:
		var cur := _sk(b, b.train_skill)
		if cur < 95.0:
			b.skill[b.train_skill] = minf(95.0, cur + TRAIN_RATE * delta)
			if b.train_skill == "reload":
				b.exp_mul = _reload_factor(b)
			if b.independent and b.is_player:
				_prestige_acc += PRESTIGE_TRAIN_RATE * delta   # drilling your own men earns standing
				while _prestige_acc >= 1.0:
					_prestige_acc -= 1.0
					prestige += 1
	if b.roster.is_empty():
		return
	var bump := TRAIN_RATE * delta * 1.05
	for m in b.roster:
		if not m["alive"]:
			continue
		if has_batt:
			m[b.train_skill] = clampf(float(m[b.train_skill]) + bump, 6.0, 99.0)
		# a man given personal focus drills HIS chosen skill harder still (even off the
		# battalion's drill), and it carries his rank-mates along a little
		var fc: String = m.get("focus", "")
		if fc != "" and fc in SKILL_KEYS:
			m[fc] = clampf(float(m[fc]) + bump * 1.4, 6.0, 99.0)

# Blooding raises a fighting skill (aim or bayonet) a notch; veterans learn slower.
func _blood_skill(b: Batt) -> void:
	var key := "aim" if randf() < 0.6 else "melee"
	var cur := _sk(b, key)
	var gain := lerpf(1.6, 0.3, clampf(cur / 100.0, 0.0, 1.0))
	b.skill[key] = minf(99.0, cur + gain)
	if not b.roster.is_empty():
		for m in b.roster:
			if m["alive"]:
				m[key] = clampf(float(m[key]) + gain * 0.9, 6.0, 99.0)

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
		b.cohesion -= COH_COMMAND_HIT       # the fallen colours are a lasting blow to the unit
		b.calm_t = 0.0
		_drop_dead(b.pos + right * 0.9 + fwd * (maxy + 0.8), b.team, -fwd, b.visible)
	if not b.is_player and not b.officer_down and randf() < CMD_HIT_CHANCE * 0.8:
		b.officer_down = true
		b.officer_t = randf_range(4.0, 7.0)
		b.morale -= OFFICER_SHOCK
		b.cohesion -= COH_COMMAND_HIT       # losing the commander loosens the unit's order
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
		var tgt := b.off_pos - fwd_o * FORMUP_DIST
		var dd := b.pos.distance_to(tgt)
		# ride well ahead and your men fall into a march column to catch up at speed; they
		# re-form line as they close back up on you
		if not b.skirmish:
			if dd > MARCH_DIST and b.formation != "march":
				b.formation = "march"; _reslot(b)
			elif dd < FORMUP_DIST and b.formation == "march":
				b.formation = "line"; _reslot(b)
		b.pos = b.pos.move_toward(tgt, _move_speed(b) * delta)
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
		# you can steady men who have merely lost their nerve — but not those BROKEN past
		# recall, nor a remnant shot to pieces. Some routs are beyond any officer.
		if b.team != player.team or b.spent or b.broken or b.state != "routing" or _army_broken[b.team]:
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
	var dassets := _draft_horse_assets()
	var dmesh: ArrayMesh = dassets[0]
	var dmats: Array = dassets[1]
	for sx2 in [-0.4, 0.4]:
		var horse := MeshInstance3D.new()
		horse.mesh = dmesh
		horse.material_override = dmats[(0 if sx2 < 0 else 1) % dmats.size()]
		horse.position = Vector3(sx2, 0, 1.7)   # the mesh already faces +Z, the direction of travel
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
	var wing: float = 520.0 if _inflated else 1600.0   # on the flanks of the (tighter) line
	for team in [0, 1]:
		var z := -320.0 if team == 0 else 320.0
		var face := 0.0 if team == 0 else PI
		var fwd := Vector3(sin(face), 0, cos(face))
		var rightv := Vector3(fwd.z, 0, -fwd.x)
		var ncav: int = 2 if _inflated else CAV_PER_TEAM   # a regiment on each wing
		var half := maxi(1, ncav / 2)
		var sites: Array = _team_sites[team]
		for r in range(ncav):
			var c := Cav.new()
			c.team = team
			c.idx = team * CAV_PER_TEAM + r
			var side := -1.0 if r < half else 1.0
			var rank := r % half
			if _inflated or sites.is_empty():
				c.pos = Vector3(side * (wing - float(rank) * 200.0), 0, z + float(rank) * (40.0 if team == 1 else -40.0))
			else:
				# the horse waits on the flank of a garrison, ready to ride out
				var site: Vector3 = sites[r % sites.size()]
				var sflank: float = -1.0 if r % 2 == 0 else 1.0
				c.pos = site + rightv * (sflank * 190.0) - fwd * 90.0
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
		if c.player:
			_update_player_cav(c, delta)
			continue
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

# YOUR squadron: it rallies on you and keeps with you, and when you sound the charge
# it gallops home at the enemy you pointed it at, then reins in to re-form on you.
func _update_player_cav(c: Cav, delta: float) -> void:
	if c.state == "charging":
		var tp := _cav_target_pos(c)
		if tp == Vector3.INF or c.troopers.size() < 45:
			c.state = "rallying"
			c.rally_t = CAV_RALLY_TIME * 0.5
		else:
			_cav_move(c, tp, CAV_GALLOP, delta)
			if Vector2(c.pos.x - tp.x, c.pos.z - tp.z).length() < CAV_CONTACT + 4.0:
				_cav_resolve(c)
				c.state = "rallying"         # the shock delivered — the horses are blown
				c.rally_t = CAV_RALLY_TIME
		return
	if c.state == "rallying":
		c.rally_t -= delta
		if c.rally_t <= 0.0:
			c.state = "reserve"
	# rallying / reserve / retiring: form on your officer and ride where he rides
	var anchor := off_pos - Vector3(sin(off_vis), 0, cos(off_vis)) * 9.0
	var far := off_pos.distance_to(c.pos)
	var spd := CAV_GALLOP if far > 40.0 else (CAV_TROT if far > 6.0 else 0.0)
	if spd > 0.0:
		_cav_move(c, anchor, spd, delta)
	else:
		c.facing = off_vis

func _cav_move(c: Cav, goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - c.pos
	to.y = 0.0
	if to.length() < 0.5:
		return
	c.facing = atan2(to.x, to.z)
	c.pos = c.pos.move_toward(Vector3(goal.x, 0, goal.z), speed * delta)
	# a galloping squadron tears up far more dust than one trotting to its post
	if cam != null and not c.troopers.is_empty() and cam.position.distance_to(c.pos) < DUST_RANGE \
			and randf() < delta * 4.0 * (speed / CAV_GALLOP):
		var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
		var right := Vector3(fwd.z, 0, -fwd.x)
		var width := minf(float(c.troopers.size()) * 1.2, 70.0)
		for _i in range(clampi(c.troopers.size() / 40, 1, 3)):
			var p := c.pos - fwd * 1.0 + right * randf_range(-width * 0.5, width * 0.5)
			p.y = _gh(p.x, p.z) + 0.05
			_emit_dust(p, fwd)

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
				var cgh := _gh(w.x, w.z)
				hmm.set_instance_transform(i, Transform3D(hb, Vector3(w.x, 0.92 + bob + cgh, w.z)))
				rmm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(w.x, 1.72 + bob + cgh, w.z)))
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
	dead_horse_mm.set_instance_transform(dead_horse_idx, Transform3D(basis, Vector3(pos.x, 0.34 + _gh(pos.x, pos.z), pos.z)))
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
			if b.team == team and not b.independent:
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
	# raise the divisional tier: one General over every group of brigades that share a
	# division id. The army talks to these generals; the generals talk to the brigades.
	divisions.clear()
	var dmap: Dictionary = {}
	for br in brigades:
		var key: int = br.team * 1000 + br.division
		var dv: Division = dmap.get(key, null)
		if dv == null:
			dv = Division.new()
			dv.team = br.team
			dv.idx = br.division
			dv.corps = br.corps
			dv.line2 = br.line2
			dmap[key] = dv
			divisions.append(dv)
		dv.objective = _brigade_center(br)
	for d2 in divisions:
		d2.general_pos = _division_center(d2)
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

# --- the divisional tier ---------------------------------------------------
func _division_brigades(dv) -> Array:
	var out: Array = []
	for br in brigades:
		if br.team == dv.team and br.division == dv.idx and _brigade_live(br) > 0:
			out.append(br)
	return out

func _division_center(dv) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for br in _division_brigades(dv):
		sum += _brigade_center(br)
		n += 1
	return (sum / float(n)) if n > 0 else dv.objective

func _division_for(br):
	for dv in divisions:
		if dv.team == br.team and dv.idx == br.division:
			return dv
	return null

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
			_decide_divisions(army)   # each general refines the army's intent for his own front
	for dv in divisions:
		_update_division(dv, delta)

# THE DIVISIONAL TIER. The army has handed each of its divisions a broad intent
# (read off the missions it set). The general now exercises his own initiative:
# on the main effort he names a LEADING brigade, others to SUPPORT its flanks, and
# keeps his last brigade IN HAND as a local reserve — decisions the army never made.
func _decide_divisions(army) -> void:
	var team: int = army.team
	for dv in divisions:
		if dv.team != team:
			continue
		var brs := _division_brigades(dv)
		if brs.is_empty():
			continue
		if dv.general_down:
			dv.directive = "hold"       # leaderless: the brigades fight their own duels
			continue
		# read the army's intent off the brigades it just ordered
		var any_attack := false
		var all_reserve := true
		for br in brs:
			if br.mission == "attack" or br.mission == "flank":
				any_attack = true
			if br.mission != "reserve":
				all_reserve = false
		if all_reserve:
			dv.directive = "reserve"
		elif any_attack:
			dv.directive = "main"
			_division_assault(dv, brs, army)
		else:
			dv.directive = "fix"
		dv.target = _nearest_enemy_brigade(brs[brs.size() / 2])
		dv.objective = _division_center(dv)

# The general's plan for his assaulting division: lead, supports, and a held reserve.
func _division_assault(dv, brs: Array, army) -> void:
	var tgt = army.main.mission_target if army.main != null else null
	if tgt == null or _brigade_live(tgt) == 0:
		tgt = _nearest_enemy_brigade(brs[0])
	if tgt == null:
		return
	var tc := _brigade_center(tgt)
	brs.sort_custom(func(a, b): return _brigade_center(a).distance_to(tc) < _brigade_center(b).distance_to(tc))
	for i in range(brs.size()):
		var br = brs[i]
		if i == 0:
			# the LEADING brigade keeps the army's spearhead mission (attack / flank)
			if br.mission != "flank":
				br.mission = "attack"
			br.mission_target = tgt
		elif i == brs.size() - 1 and brs.size() >= 4:
			br.mission = "reserve"          # the general holds his last brigade in hand
			br.mission_target = tgt
		else:
			br.mission = "support"          # the rest go in echeloned to support the lead
			br.mission_target = tgt

# The general rides behind his division's centre; he can be shot down, and then his
# grip lapses for a while until a brigadier steps up to the divisional command.
func _update_division(dv, delta: float) -> void:
	var brs := _division_brigades(dv)
	if brs.is_empty():
		return
	if dv.general_down:
		dv.confuse_t -= delta
		if dv.confuse_t <= 0.0:
			dv.general_down = false
	var c := _division_center(dv)
	var s := 1.0 if dv.team == 0 else -1.0
	dv.general_pos = c + Vector3(0, 0, 34.0 * s)   # well behind his brigades' line

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
	# THE STRATEGIC OBJECTIVE: the war must be won on the ground, not just against the enemy
	# army. The commander marks the best town to take, and sets each corps to campaign for
	# the contestable town nearest IT — brigades fight what's to their front, then march on
	# the town. (Value × weakness ÷ distance, biased by temperament — the campaign mind.)
	army.target_town = _pick_target_town(army, mine)
	for cpn in range(CORPS_PER_TEAM):
		var cc := Vector3.ZERO
		var cn := 0
		for br in mine:
			if br.corps == cpn:
				cc += _brigade_center(br)
				cn += 1
		if cn == 0:
			continue
		cc /= float(cn)
		var town = _nearest_contestable_town(team, cc)
		var tp: Vector3 = town["pos"] if town != null else Vector3.INF
		for br in mine:
			if br.corps == cpn:
				br.seize = tp
	if army.target_town != null and player != null and player.team == team:
		var tn := String(army.target_town["name"])
		if tn != _last_target_town:
			_last_target_town = tn
			_send_player_despatch("[color=#ffd773]The army's object:[/color] take [b]%s[/b]." % tn, {})

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
	# together rather than charging forward piecemeal. Dress on the FIGHTING line only —
	# the reserves stand well to the rear and must not drag the reference back (which
	# would read the whole first line as "ahead" and throttle it to a crawl).
	var sum := [0.0, 0.0]
	var cnt := [0, 0]
	for br in brigades:
		if _brigade_live(br) == 0 or br.line2:
			continue
		var s := 1.0 if br.team == 0 else -1.0
		sum[br.team] += _brigade_center(br).z * s
		cnt[br.team] += 1
	# if a first line has been spent away entirely, fall back to whatever still stands
	for tm in [0, 1]:
		if cnt[tm] == 0:
			for br in brigades:
				if _brigade_live(br) == 0 or br.team != tm:
					continue
				var s := 1.0 if tm == 0 else -1.0
				sum[tm] += _brigade_center(br).z * s
				cnt[tm] += 1
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
	_set_brigade_orders(br)               # put the mission into words for each battalion
	var bf := Vector3(sin(br.facing), 0, cos(br.facing))
	br.commander_pos = _brigade_center(br) - bf * 18.0
	if br.is_player:
		_maybe_order_player(br)

# Translate the brigade's mission into the plain order each battalion holds, and the
# ground it points at — for the player this is painted as a label in the 3D world.
func _set_brigade_orders(br) -> void:
	var enemy = br.enemy
	var ec: Vector3 = _brigade_center(enemy) if (enemy != null and _brigade_live(enemy) > 0) else br.objective
	var kind := "hold"
	var text := "Hold this ground"
	var opos: Vector3 = br.objective
	match br.mission:
		"attack", "flank":
			kind = "attack"; text = "Assault the enemy line"; opos = ec
		"support":
			kind = "support"; text = "Support the attack"; opos = ec
		"fix":
			kind = "fix"; text = "Pin the enemy to your front"; opos = ec
		"reserve":
			kind = "reserve"; text = "Stand in reserve"; opos = br.objective
		"refuse":
			kind = "hold"; text = "Refuse the flank — hold"; opos = br.objective
	if br.posture == "withdraw":
		kind = "withdraw"; text = "Fall back and rally"; opos = br.objective
	for b in br.battalions:
		b.obj_kind = kind
		b.obj_text = text
		b.obj_pos = opos

func _order_color(kind: String) -> Color:
	match kind:
		"attack": return Color(1.0, 0.34, 0.24)
		"support": return Color(1.0, 0.78, 0.30)
		"fix": return Color(0.95, 0.86, 0.40)
		"reserve": return Color(0.52, 0.74, 1.0)
		"withdraw": return Color(0.82, 0.52, 0.92)
	return Color(0.66, 0.92, 0.66)

# Paint the order your battalion holds onto the ground it points at: a large label
# above a coloured ring, so you can see at a glance where your commander wants you.
func _update_objective_marker() -> void:
	if player == null or player.spent or player.obj_text == "" or player_arm != "infantry":
		if _obj_label != null:
			_obj_label.visible = false
		if _obj_marker != null:
			_obj_marker.visible = false
		return
	if _obj_label == null:
		_obj_label = Label3D.new()
		_obj_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_obj_label.no_depth_test = true
		_obj_label.font_size = 320
		_obj_label.outline_size = 64
		_obj_label.outline_modulate = Color(0, 0, 0, 0.9)
		_obj_label.pixel_size = 0.06
		add_child(_obj_label)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 15.0
		tm.outer_radius = 18.0
		ring.mesh = tm
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.albedo_color = Color(1, 1, 1, 0.5)
		ring.material_override = rmat
		_obj_marker = ring
		add_child(_obj_marker)
	var col := _order_color(player.obj_kind)
	var p: Vector3 = player.obj_pos
	_obj_label.visible = true
	_obj_marker.visible = true
	_obj_label.text = player.obj_text.to_upper()
	_obj_label.modulate = col
	_obj_label.position = Vector3(p.x, 24.0, p.z)
	_obj_marker.position = Vector3(p.x, 0.35, p.z)
	var m := _obj_marker.material_override as StandardMaterial3D
	m.albedo_color = Color(col.r, col.g, col.b, 0.45 + 0.15 * sin(_t * 2.2))

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
		if g.cmd_t > 0.0 or g.player:
			continue                          # the player has this piece — leave his order be
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
		# no enemy left on the field — march on the town the army directed us to take
		var tobj := _brigade_town_objective(br)
		if tobj != Vector3.INF:
			br.posture = "advance"
			br.objective = tobj
		else:
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
	# the enemy is far off but a town is closer — take the ground rather than march miles to
	# a distant fight (this is what sends the corps campaigning across the province)
	if dfront > 1600.0:
		var tobj := _brigade_town_objective(br)
		if tobj != Vector3.INF and center.distance_to(tobj) < dfront:
			br.posture = "advance"
			br.objective = tobj
			br.facing = atan2((tobj - center).x, (tobj - center).z)
			br.fire_mission = _brigade_fire_mission(br)
			return
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
			"support":
				# echeloned a little behind the lead: close up and engage, and press home
				# only once the enemy to its front is shaken — exploiting the lead's work
				if dfront > BRIG_ENGAGE_RANGE + 50.0:
					br.posture = "advance"
					br.objective = ec - bf * (BRIG_ENGAGE_RANGE + 30.0)
				elif en_mor < BRIG_ASSAULT_MORALE and my_mor > 45.0:
					br.posture = "assault"
					br.objective = ec
				else:
					br.posture = "engage"
					br.objective = ec - bf * (BRIG_ENGAGE_RANGE + 25.0)
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
		# in contact: form line and face him
		if not b.skirmish and b.formation != "line":
			b.formation = "line"
			_reslot(b)
		var to := foe.pos - b.pos
		to.y = 0.0
		if to.length() > 0.3:
			b.facing = atan2(to.x, to.z)
		var dir := to.normalized()
		var weak := foe.state != "steady" or foe.morale < BRIG_ASSAULT_MORALE
		var dry := b.ammo <= 0.0          # no powder left — close with the bayonet
		var aggressive: bool = b.ai_posture in ["advance", "engage", "assault"]
		# CLOSE THE RANGE: a steady attacking line does not stand and trade useless
		# long-range fire — it presses forward to decisive range, firing as it comes,
		# until one side breaks or the bayonet goes in. (A defender holds his ground.)
		if b.state == "steady" and aggressive and b.melee_foe == null and foe_d > DECISIVE_RANGE:
			b.pos += dir * BATT_SPEED * 0.7 * delta
		b.off_pos = b.pos + dir * 10.0
		b.off_facing = b.facing
		# CHARGE HOME: once the enemy wavers (or your powder is spent), go in with the bayonet
		if not b.officer_down and b.charge_cool <= 0.0 and b.state == "steady" and foe_d < CHARGE_RANGE \
				and ((aggressive and weak) or dry):
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
# The pace a battalion makes, given its formation: a narrow march column travels fastest.
func _move_speed(b: Batt) -> float:
	return BATT_SPEED * (MARCH_MUL if b.formation == "march" else 1.0) * _terrain_speed_mul(b.pos)

func _ai_move_to(b: Batt, tgt: Vector3, face: float, delta: float, deploy_line: bool) -> void:
	# on a long march, steer onto a bridge if the river lies across the path
	if not bridges.is_empty() and b.pos.distance_to(tgt) > FORMUP_DIST:
		tgt = _route_via_bridge(b.pos, tgt)
	var to := tgt - b.pos
	to.y = 0.0
	var d := to.length()
	if d > FORMUP_DIST:
		# far to go: form the narrow MARCH column and make speed; closer in, the broad
		# assault column for manoeuvre; in contact, deploy to line (below)
		var want := "march" if d > MARCH_DIST else "column"
		if not b.skirmish and b.formation != want:
			b.formation = want
			_reslot(b)
		var dir := to / d
		b.facing = atan2(dir.x, dir.z)
		b.pos += dir * _move_speed(b) * delta
		b.off_pos = b.pos + dir * 14.0
		b.off_facing = b.facing
	else:
		if deploy_line and not b.skirmish and b.formation != "line":
			b.formation = "line"
			_reslot(b)
		b.facing = lerp_angle(b.facing, face, clampf(delta * 1.5, 0.0, 1.0))
		if d > 0.4:
			# dress at a half-pace only when settling in place; on the march, keep up with
			# the brigade slot (which moves at the full pace) so the line doesn't stutter
			b.pos += (to / d) * BATT_SPEED * (0.5 if deploy_line else 1.0) * delta
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
	# b's fighting power presses on the foe (morale + numbers + bayonet skill, less weariness)
	var power := (b.morale / 100.0) * sqrt(maxf(1.0, float(b.figs.size())))
	power *= _melee_factor(b) * (1.0 - clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.3)
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
	var nidx := [[0, 0, 0], [0, 0, 0]]      # near-LOD body/musket counters, per team & troop type
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
				fmm.set_instance_transform(fi6, Transform3D(Basis(Vector3.UP, b.facing), Vector3(w6.x, CAP_HALF + _gh(w6.x, w6.z), w6.z)))
				fmm.set_instance_color(fi6, b.inst_col)
				fmm.set_instance_custom_data(fi6, Color(1.0, 0.0, 0.0, 0.0))   # far men: full wear, no gait
				fgun.set_instance_transform(fi6, _zero_xf())
				fi6 += 1
			idx[b.team] = fi6
			_place_flag(b, Vector3(b.pos.x, _gh(b.pos.x, b.pos.z), b.pos.z), b.facing)   # the colours still mark him on the horizon
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
		# every infantryman draws from soldier_troop.glb through the team MultiMesh (the path
		# proven to render). Per-battalion dress + headgear shape come from the band shader.
		var mm: MultiMesh = team_mm[b.team]
		var gun: MultiMesh = musket_mm[b.team]
		var i: int = idx[b.team]
		var icap: int = MAX_PER_TEAM
		for fi in range(b.figs.size()):
			var f: Dictionary = b.figs[fi]
			var slot: Vector2 = f["slot"]
			var mfl := maxf(0.0, float(f["flinch"]) - delta * 1.6)   # this man's recoil eases off
			f["flinch"] = mfl
			var target := Vector3(b.pos.x + right.x * slot.x + fwd.x * slot.y, 0, b.pos.z + right.z * slot.x + fwd.z * slot.y)
			# the line FRAYS, not breaks as one block: a wavering man whose nerve fails
			# edges back out of the ranks before the whole battalion gives way
			if unsteady > 0.35 and float(f["nerve"]) < unsteady and b.state != "routing":
				target -= fwd * (unsteady - float(f["nerve"])) * 3.0
			# MELEE: the whole frontline surges to the seam — both units pile into each
			# other at the contact rather than grinding apart in their dressed ranks
			if b.melee_foe != null:
				target += fwd * (minf(b.pos.distance_to(b.melee_foe.pos) * 0.5, 9.0) + sin(float(f["ph"]) * 3.0) * 0.6)
			elif b.melee_vis:
				target += fwd * 3.2
			var prevw: Vector3 = f["wpos"]
			var w: Vector3 = target if snap else prevw.move_toward(target, MAN_SPEED * float(f["spd"]) * run * delta)
			f["wpos"] = w
			if fi % stride != 0:
				continue
			if i >= icap:
				break
			var to := target - w
			var moving := to.length() > 0.06
			# ease this man's gait in/out — running men swing harder (drives the leg shader)
			var march_tgt := (1.2 if run > 1.3 else 1.0) if (not snap and prevw.distance_to(w) > 0.004) else 0.0
			f["march"] = move_toward(float(f["march"]), march_tgt, delta * 5.0)
			var ph := float(f["ph"])
			# in square, each man faces his own outward direction (carried in "face");
			# in a fighting withdrawal he steps BACKWARD, musket still toward the enemy
			var yaw := (atan2(to.x, to.z) if (moving and not b.fall_back) else b.facing + float(f.get("face", 0.0)))
			var bob := (absf(sin(_t * 8.5 * float(f["spd"]) + ph)) * 0.05 if moving else 0.0)
			var swx := sin(_t * 3.4 + ph) * sway_amp     # men fidget/waver as morale drops
			var bh := float(f["bh"])
			var bw := float(f["bw"])
			var rec := recoil - fwd * (mfl * 0.35)        # he flinches back from the crash of fire
			var ox := w.x + rec.x + right.x * swx
			var oz := w.z + rec.z + right.z * swx
			var oy := CAP_HALF * bh + bob - mfl * 0.16 + _gh(ox, oz)   # his height + the rolling ground
			var in_band := slot.y >= fire_band
			var leveled := b.charging or b.melee_foe != null or b.melee_vis or (b.presenting and in_band) or (b.has_target and in_band and float(f["reload"]) <= AIM_LEAD)
			# men only work the ramrod when the battalion is actually fighting (has a target);
			# at rest they shoulder the musket. Front ranks load standing, not on the march.
			var reloading := b.has_target and in_band and float(f["reload"]) > AIM_LEAD and not moving
			var armp := 1.0 if leveled else (0.6 if reloading else 0.0)   # arm pose -> the leg/arm shader
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(bw, bh, bw)), Vector3(ox, oy, oz)))
			mm.set_instance_color(i, b.inst_col)   # rgb = facings, a = packed dress
			mm.set_instance_custom_data(i, Color(float(f["wear"]), ph / 6.28318, float(f["march"]), armp))
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
			officer_mm.set_instance_transform(off_i, Transform3D(Basis(Vector3.UP, oyaw), Vector3(ow.x, 0.85 + obob + _gh(ow.x, ow.z), ow.z)))
			_cg_dress(officer_mm, off_i, b.team, ow.distance_to(op) > 0.1, false)
			off_i += 1
		# colour-bearer: in line, the colours stand at the REAR CENTRE; in column/square
		# they ride at the head with the staff
		if bearer_i < bearer_mm.instance_count:
			var bp: Vector3 = (b.pos - fwd * (maxy + 0.6)) if b.formation == "line" else (b.pos + right * 0.9 + fwd * (maxy + 0.8))
			var bw := _cg_step(b, "bearer", bp, delta, snap)
			var byaw := fyaw
			if bw.distance_to(bp) > 0.4:
				var bmv := bp - bw
				byaw = atan2(bmv.x, bmv.z)
			if not b.colours_down:
				var bbob := absf(sin(_t * 2.4 + idn + 1.0)) * 0.04
				bearer_mm.set_instance_transform(bearer_i, Transform3D(Basis(Vector3.UP, byaw), Vector3(bw.x, 0.85 + bbob + _gh(bw.x, bw.z), bw.z)))
				_cg_dress(bearer_mm, bearer_i, b.team, bw.distance_to(bp) > 0.1, false)
				bearer_i += 1
			_place_flag(b, Vector3(bw.x, _gh(bw.x, bw.z), bw.z), fyaw)   # lays low when the colours are down
			# the COLOUR PARTY: a guard of two with half-pikes, posted at the colours
			for esc in range(2):
				if nco_i >= nco_mm.instance_count:
					break
				var ep: Vector3 = (b.pos + right * ((float(esc) * 2.0 - 1.0) * 0.75) - fwd * (maxy + 0.6)) if b.formation == "line" else (b.pos + right * (0.45 + float(esc) * 0.85) + fwd * (maxy + 0.6))
				var ew := _cg_step(b, "esc%d" % esc, ep, delta, snap)
				nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, fyaw), Vector3(ew.x, CAP_HALF + _gh(ew.x, ew.z), ew.z)))
				_cg_dress(nco_mm, nco_i, b.team, ew.distance_to(ep) > 0.1, true)
				spontoon_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, fyaw), Vector3(ew.x + right.x * 0.2, _gh(ew.x, ew.z), ew.z + right.z * 0.2)))
				nco_i += 1
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
			drummer_mm.set_instance_transform(drummer_i, Transform3D(Basis(Vector3.UP, dyaw), Vector3(dw.x, CAP_HALF + dbob + _gh(dw.x, dw.z), dw.z)))
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
				nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, syaw), Vector3(sw.x, CAP_HALF + sbob + _gh(sw.x, sw.z), sw.z)))
				_cg_dress(nco_mm, nco_i, b.team, sw.distance_to(cp) > 0.1, true)
				spontoon_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, syaw), Vector3(sw.x + right.x * 0.2, _gh(sw.x, sw.z), sw.z + right.z * 0.2)))
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
			nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, ryaw), Vector3(rw.x, CAP_HALF + rbob + _gh(rw.x, rw.z), rw.z)))
			_cg_dress(nco_mm, nco_i, b.team, rw.distance_to(rp) > 0.1, true)
			spontoon_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, ryaw), Vector3(rw.x + right.x * 0.2, _gh(rw.x, rw.z), rw.z + right.z * 0.2)))
			nco_i += 1
	for team in [0, 1]:
		var mm: MultiMesh = team_mm[team]
		var gun: MultiMesh = musket_mm[team]
		for j in range(idx[team], team_prev[team]):
			mm.set_instance_transform(j, _zero_xf())
			gun.set_instance_transform(j, _zero_xf())
		team_prev[team] = idx[team]
		mm.visible_instance_count = idx[team]      # box-man now only the far impression — skip the rest
		gun.visible_instance_count = idx[team]
		for tt in range(3):                        # draw only the men written this frame, per type
			(near_mm[team][tt] as MultiMesh).visible_instance_count = nidx[team][tt]
			(near_gun[team][tt] as MultiMesh).visible_instance_count = nidx[team][tt]
	for j in range(off_i, officer_mm.instance_count):
		officer_mm.set_instance_transform(j, _zero_xf())
	for j in range(bearer_i, bearer_mm.instance_count):
		bearer_mm.set_instance_transform(j, _zero_xf())
	for j in range(nco_i, nco_mm.instance_count):
		nco_mm.set_instance_transform(j, _zero_xf())
		spontoon_mm.set_instance_transform(j, _zero_xf())
	for j in range(drummer_i, drummer_mm.instance_count):
		drummer_mm.set_instance_transform(j, _zero_xf())
	_render_commanders()
	_render_cavalry(delta)

const MOUNT_SCALE_COMMANDER := 1.12   # brigadier's horse & rider, a notch bigger than a colonel's
const MOUNT_SCALE_GENERAL := 1.28     # the general's charger, the biggest mount on the field

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
		var s := MOUNT_SCALE_COMMANDER
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
		var seat := Vector3(pos.x, _gh(pos.x, pos.z), pos.z)
		cmd_horse_mm.set_instance_transform(i, Transform3D(basis, seat))
		cmd_rider_mm.set_instance_transform(i, Transform3D(basis, seat))
		cmd_horse_mm.set_instance_color(i, team_color(br.team))   # shabraque: the army's colour
	# the divisional generals, one rank back behind their whole division
	var dpt := CORPS_PER_TEAM * DIVISIONS_PER_CORPS
	for dv in divisions:
		var gi: int = dv.team * dpt + dv.idx
		if gi < 0 or gi >= gen_horse_mm.instance_count:
			continue
		if _division_brigades(dv).is_empty() or dv.general_down:
			gen_horse_mm.set_instance_transform(gi, _zero_xf())
			gen_rider_mm.set_instance_transform(gi, _zero_xf())
			continue
		var gp: Vector3 = dv.general_pos
		var gyaw: float = 0.0 if dv.team == 0 else PI
		var gs := MOUNT_SCALE_GENERAL
		var gbasis := Basis(Vector3.UP, gyaw).scaled(Vector3(gs, gs, gs))
		var gseat := Vector3(gp.x, _gh(gp.x, gp.z), gp.z)
		gen_horse_mm.set_instance_transform(gi, Transform3D(gbasis, gseat))
		gen_rider_mm.set_instance_transform(gi, Transform3D(gbasis, gseat))
		gen_horse_mm.set_instance_color(gi, team_color(dv.team))   # shabraque: the army's colour
	# the mounted colonels, one behind every battalion (the player rides his own)
	var cmax: int = colonel_horse_mm.instance_count
	for b in battalions:
		var ci: int = b.idx
		if ci < 0 or ci >= cmax:
			continue
		if b.spent or b.human or b.parent != null:
			colonel_horse_mm.set_instance_transform(ci, _zero_xf())
			colonel_rider_mm.set_instance_transform(ci, _zero_xf())
			continue
		var cyaw: float = b.facing
		var cfwd := Vector3(sin(cyaw), 0, cos(cyaw))
		var cpos: Vector3 = b.pos - cfwd * 13.0   # rides behind his battalion's colours
		var cbasis := Basis(Vector3.UP, cyaw)
		var cseat := Vector3(cpos.x, _gh(cpos.x, cpos.z), cpos.z)
		colonel_horse_mm.set_instance_transform(ci, Transform3D(cbasis, cseat))
		colonel_rider_mm.set_instance_transform(ci, Transform3D(cbasis, cseat))
		colonel_horse_mm.set_instance_color(ci, team_color(b.team))   # shabraque: the army's colour
		colonel_rider_mm.set_instance_color(ci, ARMY_BLUE.lightened(0.22) if b.team == 0 else ARMY_RED.lightened(0.14))

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
	return ARMY_BLUE if team == 0 else ARMY_RED

# Paint an officer/NCO instance in his battalion's coat and set his gait (the bicorne
# shader reads COLOR.rgb as the coat, CUSTOM.b as the march amount).
func _cg_dress(mm: MultiMesh, i: int, team: int, walking: bool, belts: bool) -> void:
	var c := team_color(team)
	mm.set_instance_color(i, Color(c.r, c.g, c.b, 1.0 if belts else 0.0))   # a = crossbelts flag
	mm.set_instance_custom_data(i, Color(0.95, float(i % 17) * 0.06, 1.0 if walking else 0.0, 0.0))

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
	_bake_corpse(Transform3D(basis, Vector3(pos.x, CAP_RADIUS + _gh(pos.x, pos.z), pos.z)), team)
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
	rb.global_transform = Transform3D(basis, to_global(Vector3(pos.x, CAP_HALF + 0.05 + _gh(pos.x, pos.z), pos.z)))
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
	if _rts_cam:
		return                              # in the dev RTS camera, WASD drives the camera, not you
	if _camp_on:
		return                              # managing the camp — you stand fast in the town
	if _gun_sight:
		if _sighted_gun == null or _sighted_gun.dead:
			_gun_sight = false              # the piece is lost — your eye comes off the barrel
			_sighted_gun = null
		else:
			# your eye is to the barrel — you stand at the piece, you do not ride
			officer.position = off_pos
			officer.rotation.y = off_vis
			return
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
	# AUTORUN (R): keep cantering forward — steer by looking — so you needn't hold W.
	# Tapping back (S) reins in and cancels it.
	if _autorun:
		if iv < 0.0:
			_autorun = false
		else:
			iv = maxf(iv, 1.0)
	var move := fwd * iv + right * ih
	var riding := move.length() > 0.01
	if riding:
		move = move.normalized()
		var spd := OFF_RUN if (Input.is_key_pressed(KEY_SHIFT) or _autorun) else OFF_WALK
		spd *= _terrain_speed_mul(off_pos)        # quicker on a road, a slow ford in the river
		off_pos += move * spd * delta
		off_facing = atan2(move.x, move.z)
	off_vis = lerp_angle(off_vis, off_facing, clampf(delta * 8.0, 0.0, 1.0))
	# the horse's gait: a gentle rise and fall at the walk, a rolling beat at the canter,
	# and the legs reaching out in a diagonal beat as it goes
	var bob := 0.0
	if riding:
		var gait := 8.0 if Input.is_key_pressed(KEY_SHIFT) else 4.5
		bob = absf(sin(_t * gait)) * 0.08
		for i in range(_horse_legs.size()):
			var ph := _t * gait + (PI if (i == 1 or i == 2) else 0.0)   # diagonal pairs
			_horse_legs[i].rotation.x = sin(ph) * 0.42
	else:
		for hip in _horse_legs:
			hip.rotation.x = lerp_angle(hip.rotation.x, 0.0, clampf(delta * 8.0, 0.0, 1.0))
	off_pos.y = _gh(off_pos.x, off_pos.z)        # the rider sits on the rolling ground
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
			if _arm_selectable():
				_send_player_despatch("[color=#ffd773]Choose your arm:[/color] [1] the Foot   [2] the Guns   [3] the Horse.", {})
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
	# the AI-tuning batch decides on points after a fixed span (long enough to close and
	# fight to a real decision), so a match always ends rather than dragging forever
	if _ai_batch and _t > 700.0:
		_end_at_nightfall()
		_bill_t = 0.3              # show the bill almost at once, then quit
		return
	# STRATEGIC DECISION: a side swept from every one of its towns has lost the province —
	# the campaign is decided on the ground, whatever army still stands
	if field_towns.size() >= 3:
		var tc := _town_counts()
		if tc[0] == 0 and tc[1] > 0:
			_strategic_win(1)
			return
		elif tc[1] == 0 and tc[0] > 0:
			_strategic_win(0)
			return
	# NIGHTFALL closes the day: when dusk deepens past the hour, the firing dies down
	# the length of the line and both armies draw off to count the cost
	if _time_of_day >= NIGHTFALL_HOUR and _time_of_day < 24.0:
		_end_at_nightfall()
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
	var ord := ("  [color=#cdd6e6]Your charge:[/color] %s" % _obj_text) if _obj_text != "" else ""
	_send_player_despatch("[color=#ffd773]The army advances![/color] Drums beating, colours uncased.%s" % ord, {})

# Your personal objective for the day: break the battalion opposite you.
func _set_objective() -> void:
	_obj_done = false
	_obj_text = ""
	_obj_target = null
	if player == null:
		return
	var tgt := _nearest_enemy_in_range(player, 6000.0)
	_obj_target = tgt
	_obj_text = ("Break the %s to your front." % _unit_name(tgt)) if tgt != null else "Hold the line and break the enemy before you."

func _update_objective() -> void:
	if _obj_done or _obj_target == null or player == null:
		return
	if _obj_target.spent or _obj_target.figs.is_empty() or _obj_target.state == "routing":
		_obj_done = true
		prestige += 10                   # the day's work, done
		_send_player_despatch("[color=#9fe0a0]Objective won![/color] The %s breaks before you." % _unit_name(_obj_target), {})

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

# Dusk ends the day with neither army broken: the firing dies away and both sides draw
# off. The day is judged on who held together — and the butcher's bill is presented.
func _end_at_nightfall() -> void:
	if battle_over:
		return
	_night_end = true
	battle_over = true
	_bill_t = 7.0
	_send_player_despatch("[color=#cdd6e6]Night falls.[/color] The firing dies away down the line — the day is spent. Both armies draw off to count the cost.", {})

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
	# the outcome. A rout decides the day outright; nightfall is judged on who held
	# together — the army that kept the greater part of its strength holds the field.
	var pf := float(men_now[pt]) / maxf(1.0, float(_start_strength[pt]))
	var ef := float(men_now[et]) / maxf(1.0, float(_start_strength[et]))
	var tc := _town_counts()
	var won: bool
	var title: String
	if _town_winner >= 0:
		won = player.team == _town_winner
		title = "[color=#9fe0a0]CAMPAIGN WON — THE PROVINCE IS TAKEN[/color]" if won else "[color=#ff7a6a]CAMPAIGN LOST — THE PROVINCE IS OVERRUN[/color]"
	elif _night_end and not _army_broken[pt] and not _army_broken[et]:
		# nightfall: the day goes to whoever holds the more TOWNS; strength breaks a tie
		if tc[pt] != tc[et]:
			won = tc[pt] > tc[et]
		else:
			won = pf >= ef
		if tc[pt] == tc[et] and absf(pf - ef) < 0.06:
			title = "[color=#d6c98a]NIGHTFALL — THE DAY IS DRAWN[/color]"
		elif won:
			title = "[color=#9fe0a0]NIGHTFALL — THE GROUND IS HELD[/color]"
		else:
			title = "[color=#ff7a6a]NIGHTFALL — THE GROUND IS LOST[/color]"
	else:
		won = _army_broken[et]
		title = "[color=#9fe0a0]VICTORY[/color]" if won else "[color=#ff7a6a]DEFEAT[/color]"
	var pcol := "9fe0a0" if prestige >= 0 else "ff9a8a"
	var txt := "[center][b]%s[/b]\n" % title
	txt += "[color=#6f7888]——————————————————————[/color]\n"
	var cav_start := (2 if _inflated else CAV_PER_TEAM) * CAV_MEN
	txt += "[color=#cdd6e6]Our losses[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[pt] - men_now[pt], _start_strength[pt], cav_start - horse_now[pt], guns_lost[pt]]
	txt += "[color=#cdd6e6]Theirs[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[et] - men_now[et], _start_strength[et], cav_start - horse_now[et], guns_lost[et]]
	if field_towns.size() > 0:
		txt += "[color=#cdd6e6]Towns held[/color]  [color=#9fe0a0]%d[/color] ours · [color=#ff9a8a]%d[/color] theirs · %d in contest\n" \
			% [tc[pt], tc[et], tc[2]]
	if _obj_text != "":
		var obj_stat := "[color=#9fe0a0]✓ achieved[/color]" if _obj_done else "[color=#ff9a8a]✗ unfulfilled[/color]"
		txt += "[color=#cdd6e6]Your charge[/color]  %s  %s\n" % [_obj_text, obj_stat]
	txt += "[color=#cdd6e6]Prestige banked[/color]  [color=#%s]%+d[/color]\n" % [pcol, prestige]
	txt += _regiment_bill()
	txt += "[color=#6f7888]——————————————————————\nEnter — return to the menu[/color][/center]"
	_bill_label.text = txt
	_bill_panel.visible = true
	_write_result(pt, et, won, men_now)
	# (step 8) machine-readable result line, so headless AI-vs-AI batches can be scored
	print("[RESULT] winner_team=%d our=%d/%d theirs=%d/%d prestige=%d goals=%s|%s" % [
		pt if won else et, men_now[pt], _start_strength[pt], men_now[et], _start_strength[et],
		prestige, armies[0].goal if armies.size() > 0 else "-", armies[1].goal if armies.size() > 1 else "-"])
	if _ai_batch:
		get_tree().quit()             # the batch match is scored — end it for the next run

# The casualty return for your own brigade — regiment by regiment, so you can see how
# each fared and how your own stood. (Your whole army's 100 regiments would swamp the
# page; your brigade is the command family whose day you actually shaped.)
func _regiment_bill() -> String:
	if player == null or player.brigade == null:
		return ""
	# your regiment's mettle at day's end — drilled and blooded over the fight
	var out := "[color=#6f7888]—— your regiment's mettle (%s) ——[/color]\n" % player.quality
	var prof := ""
	for key in SKILL_KEYS:
		prof += "[color=#9fb0c8]%s[/color] [color=#e8ecf5]%d[/color]   " % [SKILL_NAMES[key], int(round(_sk(player, key)))]
	out += prof + "\n"
	out += "[color=#6f7888]—— your brigade, regiment by regiment ——[/color]\n"
	for rb in player.brigade.battalions:
		var started: int = maxi(rb.start_men, rb.figs.size())
		var now: int = rb.figs.size()
		var lost: int = maxi(0, started - now)
		var pct: int = int(round(100.0 * float(lost) / maxf(1.0, float(started))))
		var status: String
		if rb.broken:
			status = "[color=#ff5a4a]broken[/color]"
		elif rb.state == "routing":
			status = "[color=#ff9a8a]running[/color]"
		elif rb.spent:
			status = "[color=#ff9a8a]shattered[/color]"
		elif rb.state == "shaken":
			status = "[color=#ffcf6e]shaken[/color]"
		else:
			status = "[color=#9fe0a0]in hand[/color]"
		var mark: String = "[color=#ffe9a8]» [/color]" if rb == player else "   "
		out += "%s[color=#cdd6e6]%s[/color]  %d/%d  [color=#ff9a8a]−%d (%d%%)[/color]  %s\n" \
			% [mark, _unit_name(rb), now, started, lost, pct, status]
	return out

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

# "GIVE FIRE!" — the officer's own word to his battalion. Instant (you are with them),
# it releases a held volley NOW; held close, it is murderous.
func _give_fire() -> void:
	if player == null or player.figs.is_empty():
		return
	if player.charging or player.melee_foe != null or player.state == "routing":
		return
	player.fire_now = true                  # _update_firing fires every loaded man as one
	player.fire_forward = true              # FIRE even with no enemy in front — into the open
	player.presenting = false               # the present is released by the volley
	_play_voice(snd_v_fire, player.off_pos)

# "PRESENT!" — the battalion brings its muskets up to the level and holds, whether or not
# there is an enemy to its front. (Press V.) The arms tire after a while and lower again.
func _present() -> void:
	if player == null or player.figs.is_empty():
		return
	if player.charging or player.melee_foe != null or player.state == "routing":
		return
	player.presenting = true
	player.present_t = 0.0
	_play_voice(snd_v_present, player.off_pos)
	_send_player_despatch("[color=#ffe9a8]Present![/color] — the battalion brings its muskets up.", {})

# Bring the nearest friendly battery up to support you: it displaces to the ground
# just behind your line and opens fire on the enemy to your front. (Press T.)
func _command_battery() -> void:
	if player == null:
		return
	var best: Gun = null
	var bd := 1400.0
	for g in guns:
		if g.team != player.team or g.dead:
			continue
		var d := off_pos.distance_to(g.pos)
		if d < bd:
			bd = d
			best = g
	if best == null:
		return
	var fwd := Vector3(sin(player.facing), 0, cos(player.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var dest := player.pos - fwd * 34.0      # behind your line, to fire over your heads
	var k := 0
	for g in guns:
		if g.team != player.team or g.dead or g.pos.distance_to(best.pos) > 110.0:
			continue                          # the cluster around the nearest piece = the battery
		g.move_to = dest + right * (float(k) - 1.5) * GUN_SPACING
		g.cmd_t = 45.0
		k += 1
	_send_player_despatch("[color=#ffd773]The guns come up![/color] Your battery displaces to the ground behind you — stand clear of the muzzles.", {})

# ========================================================= CHOOSE YOUR ARM
# At the step-off you may command the foot, the guns, or the horse — each fought
# first-hand: lay and fire your own pieces, or ride at the head of your squadron.

func _arm_selectable() -> bool:
	# a single-player choice made before the army steps off
	return GameConfig.mode == "single" and not _battle_begun and player != null

func _choose_arm(arm: String) -> void:
	if not _arm_selectable():
		return
	if arm == player_arm and _arm_chosen:
		return
	_release_player_arm()
	player_arm = arm
	_arm_chosen = true
	match arm:
		"artillery":
			# you hand your battalion to its senior major and take command of a battery
			player.human = false
			_take_battery()
			if player_guns.is_empty():
				player.human = true
				player_arm = "infantry"
				_send_player_despatch("[color=#ff9a6a]No friendly battery within reach[/color] — you keep the foot.", {})
				return
		"cavalry":
			player.human = false
			_take_squadron()
			if player_cav == null:
				player.human = true
				player_arm = "infantry"
				_send_player_despatch("[color=#ff9a6a]No squadron within reach[/color] — you keep the foot.", {})
				return
		_:
			player.human = true            # you lead your battalion in person again
	var nm: String = { "infantry": "the foot", "artillery": "the guns", "cavalry": "the horse" }.get(arm, arm)
	_send_player_despatch("[color=#ffd773]You take command of %s.[/color]" % nm, {})

func _release_player_arm() -> void:
	_gun_sight = false
	_sighted_gun = null
	for g in player_guns:
		g.player = false
	player_guns.clear()
	if player_cav != null:
		player_cav.player = false
		player_cav.state = "reserve"
		player_cav = null

# Take personal command of the friendly battery nearest you: every piece in the
# cluster becomes yours to lay and fire, and you ride to stand behind them.
func _take_battery() -> void:
	var best: Gun = null
	var bd := 4000.0
	for g in guns:
		if g.team != player.team or g.dead:
			continue
		var d := off_pos.distance_to(g.pos)
		if d < bd:
			bd = d
			best = g
	if best == null:
		return
	player_guns.clear()
	var c := Vector3.ZERO
	for g in guns:
		if g.team != player.team or g.dead or g.pos.distance_to(best.pos) > 130.0:
			continue
		g.player = true
		g.cmd_t = 0.0
		g.limber_state = "deployed"
		_set_limber_visible(g, false)
		player_guns.append(g)
		c += g.pos
	if player_guns.is_empty():
		return
	c /= float(player_guns.size())
	var face := 0.0 if player.team == 0 else PI
	off_pos = c - Vector3(sin(face), 0, cos(face)) * 7.0   # behind the muzzles, in line with the battery
	off_facing = face
	off_vis = face
	_cam_yaw = face + PI

# Take command of the nearest friendly squadron: it forms on you and charges at
# your word, and you ride at its head.
func _take_squadron() -> void:
	var best: Cav = null
	var bd := 6000.0
	for c in cavalry:
		if c.team != player.team or c.spent:
			continue
		var d := off_pos.distance_to(c.pos)
		if d < bd:
			bd = d
			best = c
	if best == null:
		return
	player_cav = best
	best.player = true
	best.state = "reserve"
	best.target = null
	best.target_kind = ""
	var face := 0.0 if player.team == 0 else PI
	off_pos = best.pos                                # ride to the head of your squadron
	off_facing = face
	off_vis = face
	_cam_yaw = face + PI

# Where you are aiming: cast your eyeline to the ground, so the guns fall where you
# look. Looking at or above the horizon throws the shot to long range along your front.
func _player_aim_point() -> Vector3:
	if cam == null:
		var f := Vector3(sin(off_vis), 0, cos(off_vis))
		return off_pos + f * 320.0
	var origin := cam.global_position
	var fwd := -cam.global_transform.basis.z
	if fwd.y < -0.02:
		var tt := origin.y / -fwd.y
		var p := origin + fwd * tt
		return Vector3(p.x, 0.0, p.z)
	var h := Vector3(fwd.x, 0.0, fwd.z)
	if h.length() < 0.001:
		h = Vector3(sin(off_vis), 0, cos(off_vis))
	return off_pos + h.normalized() * ARTY_RANGE

# Put your eye to the barrel of the nearest of your pieces (E), or take it away again.
func _toggle_gun_sight() -> void:
	if _gun_sight:
		_gun_sight = false
		_sighted_gun = null
		return
	var best: Gun = null
	var bd := 1.0e18
	for g in player_guns:
		if g.dead:
			continue
		var d := off_pos.distance_to(g.pos)
		if d < bd:
			bd = d
			best = g
	if best == null:
		_send_player_despatch("[color=#ff9a6a]No gun of yours to sight.[/color] Take a battery first ([2]).", {})
		return
	_sighted_gun = best
	_gun_sight = true
	_scoped = false
	_sight_yaw = best.facing
	_sight_pitch = deg_to_rad(-0.35)       # raise the gaze toward level for range, depress to shorten
	_send_player_despatch("[color=#ffd773]Down the sights.[/color] Mouse lays the piece · the battery follows your aim · LMB fires · E to stand off.", {})

# The ground your sighted barrel is laid on: cast the line of the piece to the turf.
# A near-level barrel reaches to the gun's range; depressing it walks the fall of shot in.
func _sight_target() -> Vector3:
	var g := _sighted_gun
	if g == null:
		return _player_aim_point()
	var look := Vector3(sin(_sight_yaw) * cos(_sight_pitch), sin(_sight_pitch), cos(_sight_yaw) * cos(_sight_pitch))
	var eye := g.pos + Vector3(0, 1.25, 0)
	var h := Vector3(sin(_sight_yaw), 0, cos(_sight_yaw))
	var rng := ARTY_RANGE
	if look.y < -0.0009:
		rng = minf(eye.y / -look.y, ARTY_RANGE)   # where the line of metal meets the ground
	return g.pos + h * maxf(rng, 6.0)

# Where the battery is laid: down your sighted barrel if you are at the gun, else where
# your eye (the free camera) falls on the ground.
func _battery_aim_point() -> Vector3:
	if _gun_sight and _sighted_gun != null and not _sighted_gun.dead:
		return _sight_target()
	return _player_aim_point()

# Serve a piece YOU command: the crew reloads, the barrel follows your eye, but it
# only speaks when you give the word (no AI target-picking, no displacing on its own).
func _serve_player_gun(g: Gun, delta: float) -> void:
	if g.limber_state != "deployed":
		g.limber_state = "deployed"
		_set_limber_visible(g, false)
	_animate_gun_crew(g)
	if not _battle_begun:
		return
	g.reload = maxf(0.0, g.reload - delta)
	if _gun_sight and g == _sighted_gun:
		g.facing = _sight_yaw                  # this is the piece at your eye — laid exactly
		if g.node:
			g.node.rotation.y = g.facing
		return
	var ap := _battery_aim_point()
	var to := ap - g.pos
	to.y = 0.0
	if to.length() > 1.0:
		g.facing = lerp_angle(g.facing, atan2(to.x, to.z), clampf(delta * 2.4, 0.0, 1.0))
		if g.node:
			g.node.rotation.y = g.facing

# Give the word: every loaded piece in your battery fires where the battery is laid.
func _fire_player_battery() -> void:
	if player_guns.is_empty() or not _battle_begun:
		return
	var ap := _battery_aim_point()
	for g in player_guns:
		if g.dead or g.limber_state != "deployed" or g.reload > 0.0:
			continue
		g.reload = ARTY_RELOAD * randf_range(0.9, 1.1)
		g.reload_max = g.reload
		_gun_fire_at(g, ap)

# Fire one piece at a ground point (your aim) rather than at an AI-chosen formation.
func _gun_fire_at(g: Gun, aim_pos: Vector3) -> void:
	var fwd := Vector3(sin(g.facing), 0, cos(g.facing))
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95, 0)
	g.recoil = 0.55
	if g.node and cam != null and cam.position.distance_to(g.pos) < LOD_VFAR:
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_fire(muzzle, fwd)
		_emit_fire(muzzle, fwd)
		for s in range(18):
			_emit_gun_smoke(muzzle + fwd * randf_range(0.0, 0.8), fwd)
		_muzzle_light(muzzle)
	_play_cannon(muzzle)
	var prox := clampf(1.0 - cam.position.distance_to(g.pos) / 160.0, 0.0, 1.0) if cam else 0.0
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.6, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * 0.14, 0.32)
	if g.pos.distance_to(aim_pos) <= CANISTER_RANGE:
		_canister(muzzle, fwd, g.team)
	else:
		_spawn_shot(muzzle, Vector3(aim_pos.x, 1.0, aim_pos.z), g.team)

# A ring on the ground where your battery is laid — so you can see the fall of shot
# before you fire. Orange within canister range, gold for roundshot.
func _update_aim_reticle() -> void:
	if player_arm != "artillery" or player_guns.is_empty() or not _battle_begun:
		if _aim_marker != null:
			_aim_marker.visible = false
		return
	if _aim_marker == null:
		_aim_marker = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 4.0
		tm.outer_radius = 5.2
		_aim_marker.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.7)
		_aim_marker.material_override = m
		add_child(_aim_marker)
	var ap := _battery_aim_point()
	var nd := 1.0e18
	for g in player_guns:
		nd = minf(nd, g.pos.distance_to(ap))
	var col := Color(1.0, 0.5, 0.2) if nd <= CANISTER_RANGE else Color(1.0, 0.85, 0.3)
	_aim_marker.visible = true
	_aim_marker.position = Vector3(ap.x, 0.4, ap.z)
	var mm := _aim_marker.material_override as StandardMaterial3D
	mm.albedo_color = Color(col.r, col.g, col.b, 0.55 + 0.2 * sin(_t * 4.0))

# Sound the charge: your squadron lowers sabres and goes at the enemy to your front,
# and you ride home with them.
func _charge_cavalry() -> void:
	if player_cav == null or player_cav.spent or not _battle_begun:
		return
	if player_cav.state == "charging":
		return
	if player_cav.state == "rallying":
		_send_player_despatch("[color=#ffd773]The horses are blown[/color] — give them a moment to re-form.", {})
		return
	var hd := Vector3(sin(off_vis), 0, cos(off_vis))
	var best = null
	var best_kind := ""
	var best_score := -1.0e18
	for b in battalions:
		if b.team == player.team or b.figs.size() < 20:
			continue
		var s := _charge_score(b.pos, hd)
		if s > best_score:
			best_score = s; best = b; best_kind = "batt"
	for g in guns:
		if g.team == player.team or g.dead:
			continue
		var s2 := _charge_score(g.pos, hd) + 30.0   # an exposed battery is a prize
		if s2 > best_score:
			best_score = s2; best = g; best_kind = "gun"
	for e in cavalry:
		if e.team == player.team or e.spent or e.state == "fled":
			continue
		var s3 := _charge_score(e.pos, hd)
		if s3 > best_score:
			best_score = s3; best = e; best_kind = "cav"
	if best == null:
		_send_player_despatch("[color=#ffd773]No enemy bears to your front to charge.[/color]", {})
		return
	player_cav.target = best
	player_cav.target_kind = best_kind
	player_cav.state = "charging"
	_play_voice(snd_v_charge, off_pos)
	_send_player_despatch("[color=#ffd773]CHARGE![/color] Sabres out — ride them down!", {})

# Favour what lies ahead of your horse and close by (a forward cone, nearer is better).
func _charge_score(p: Vector3, heading: Vector3) -> float:
	var to := p - off_pos
	to.y = 0.0
	var d := to.length()
	if d < 1.0:
		return -1.0e18
	if d > CAV_CHARGE_RANGE * 2.2:
		return -1.0e18
	var align := to.normalized().dot(heading)   # 1 = dead ahead
	if align < 0.2:
		return -1.0e18                            # behind you — not a charge
	return align * 100.0 - d * 0.3

func _update_cam(delta: float) -> void:
	if _rts_cam:
		_update_rts_cam(delta)
		return
	# down the barrel: put the eye behind the breech of the sighted gun and look along
	# the piece, the mouse laying it; the whole battery is laid on the same ground
	if _gun_sight and _sighted_gun != null and not _sighted_gun.dead:
		var g := _sighted_gun
		var look := Vector3(sin(_sight_yaw) * cos(_sight_pitch), sin(_sight_pitch), cos(_sight_yaw) * cos(_sight_pitch))
		var fwd := Vector3(sin(_sight_yaw), 0, cos(_sight_yaw))
		var eye := g.pos - fwd * 0.7 + Vector3(0, 1.25 + g.recoil * 0.12, 0)   # the piece bucks on firing
		cam.fov = lerpf(cam.fov, 42.0, clampf(delta * 8.0, 0.0, 1.0))
		if _scope_rect:
			_scope_rect.modulate.a = 0.0
		cam.position = eye
		cam.look_at(to_global(eye + look * 80.0), Vector3.UP)
		if _shake > 0.001:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.4
		return
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

# DEV free-fly camera: WASD pans the focus over the ground (relative to the look),
# Shift sprints, the wheel zooms from treetop to the whole province. Lets you fly out
# to the coast to watch the shipping and sea-fight, or sit over a sector to read the AI.
func _update_rts_cam(delta: float) -> void:
	var look_fwd := -Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))   # ground-forward, into the screen
	var right := look_fwd.cross(Vector3.UP)                       # screen-right (D pans right)
	var iv := 0.0
	var ih := 0.0
	if Input.is_key_pressed(KEY_W): iv += 1.0
	if Input.is_key_pressed(KEY_S): iv -= 1.0
	if Input.is_key_pressed(KEY_D): ih += 1.0
	if Input.is_key_pressed(KEY_A): ih -= 1.0
	var spd := _rts_dist * (2.4 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
	_rts_focus += (look_fwd * iv + right * ih) * spd * delta
	_rts_focus.x = clampf(_rts_focus.x, -9200.0, 4200.0)   # roam the land and out over the sea
	_rts_focus.z = clampf(_rts_focus.z, -9200.0, 9200.0)
	_rts_focus.y = 0.0
	var dir := Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch))
	cam.fov = lerpf(cam.fov, FOV_NORMAL, clampf(delta * 8.0, 0.0, 1.0))
	cam.position = _rts_focus + dir * _rts_dist
	cam.look_at(to_global(_rts_focus + Vector3(0, 2.0, 0)), Vector3.UP)

func _toggle_rts_cam() -> void:
	_rts_cam = not _rts_cam
	if _rts_cam:
		_rts_focus = Vector3(off_pos.x, 0, off_pos.z)
		_rts_dist = 320.0
		_cam_pitch = deg_to_rad(55.0)            # start looking well down on the field
		_send_player_despatch("[color=#ffd773]DEV: RTS camera[/color] — WASD pan · Shift sprint · wheel zoom · mouse look · F4 to return.", {})
	else:
		_cam_pitch = deg_to_rad(28.0)
		_send_player_despatch("[color=#ffd773]DEV: back to the saddle.[/color]", {})

func _update_hud() -> void:
	# zero HUD by default: read morale from the colours and your men, hear it from
	# the drums. The controls panel shows briefly on launch, then toggled with Tab.
	if help_panel:
		help_panel.visible = _help_on or _t < 9.0
	if cmd_panel:
		cmd_panel.visible = _cmd_on
		if _cmd_on:
			_refresh_cmd_panel()         # live roster + the current order page
	if _map_on:
		_update_map()                    # keep the field map live while it is open
	if _aidbg_on:
		_update_ai_debug()               # live read of the AI's appreciation
	_update_wind_hud()                   # dev weather readout (when F3 / F4 are on)
	if _camp_on:
		_refresh_camp()                  # live skill bars, fatigue and roster while encamped
	else:
		_update_location_toast()         # a discreet toast when you ride up on a named place
	_update_compass()                    # the bearing strip at the foot of the screen
	# a fresh despatch from the commander / a sergeant's report counts down and fades
	_msg_t = maxf(0.0, _msg_t - get_process_delta_time())
	if msg_panel:
		msg_panel.visible = _msg_t > 0.0
		if _msg_t > 0.0:
			msg_label.text = "[center]" + _msg_text + "[/center]"

# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured and _gun_sight:
		# laying the piece: mouse traverses the barrel and depresses/raises the gaze
		var gs := MOUSE_SENS * 0.6
		_sight_yaw -= event.relative.x * gs
		_sight_pitch = clampf(_sight_pitch - event.relative.y * gs * 0.3, deg_to_rad(-14.0), deg_to_rad(3.0))
		return
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
			if player_arm == "artillery":
				_fire_player_battery()                    # give the word — the battery speaks
			else:
				_swing_sabre()                            # cut at whatever you're facing
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _rts_cam: _rts_dist = clampf(_rts_dist * 0.85, 40.0, 6000.0)
			else: _cam_dist = maxf(4.0, _cam_dist - 3.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _rts_cam: _rts_dist = clampf(_rts_dist * 1.18, 40.0, 6000.0)
			else: _cam_dist = minf(220.0, _cam_dist + 3.0)
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
		if _camp_on:
			# the camp & roster are mouse-driven; keys are just convenience shortcuts
			if event.keycode == KEY_ESCAPE:
				if roster_panel != null and roster_panel.visible:
					_close_roster()
				else:
					_close_camp()
				return
			if roster_panel != null and roster_panel.visible:
				return                       # the roster GUI handles its own clicks/typing
			match event.keycode:
				KEY_C:
					_close_camp()
				KEY_R:
					_camp_rest()
				KEY_T:
					_camp_train()
				KEY_B:
					_camp_resupply()
				KEY_V:
					_open_roster()
				KEY_N:
					_camp_recruit()
				KEY_H:
					_camp_hire_officer()
				KEY_M:
					_camp_equip()
			return
		match event.keycode:
			KEY_ENTER:
				if battle_over and _bill_panel and _bill_panel.visible:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					if hosted:
						host_done = true     # MP host frees this battle and resumes the lobby
					else:
						get_tree().change_scene_to_file("res://menu.tscn")   # the day is done
				elif authoritative and not _battle_begun:
					_begin_battle()       # advance the step-off
			KEY_E:
				if player_arm == "artillery":
					_toggle_gun_sight()   # put your eye to the barrel of the nearest piece
				else:
					_talk()               # hail your sergeant / a nearby unit / the general
			KEY_G:
				_fire_pistol()            # one shot from the horse-pistol, point-blank
			KEY_F:
				match player_arm:
					"cavalry":   _charge_cavalry()       # sound the charge and ride home
					"artillery": _fire_player_battery()  # give the word to the battery
					_:           _give_fire()            # "FIRE!" — a volley to the front, enemy or not
			KEY_V:
				if player_arm != "cavalry" and player_arm != "artillery":
					_present()                           # "PRESENT!" — bring the muskets up
			KEY_1:
				_choose_arm("infantry")   # at the step-off, choose the arm you command
			KEY_2:
				_choose_arm("artillery")
			KEY_3:
				_choose_arm("cavalry")
			KEY_N:
				_time_of_day = fposmod(_time_of_day + 1.5, 24.0)   # push the clock forward
			KEY_M:
				_toggle_map()             # the field map: a top-down read of the whole action
			KEY_C:
				# camp & command is opened IN-WORLD, at one of your own towns
				var tn := _player_town()
				if tn.is_empty():
					_send_player_despatch("[color=#ffe9a8]No camp in open country[/color] — ride into one of your own towns to make camp and manage the battalion.", {})
				else:
					_camp_town = String(tn["name"])
					_toggle_camp()
			KEY_R:
				_autorun = not _autorun   # ride forward hands-free; steer by looking, S to rein in
				_send_player_despatch("[color=#ffe9a8]%s[/color]" % ("Autorun on — steer by looking, tap S to rein in." if _autorun else "Autorun off."), {})
			KEY_Q:
				_cmd_on = true
			KEY_T:
				_command_battery()        # bring the nearest friendly guns up to support you
			KEY_TAB:
				_help_on = not _help_on
			KEY_F3:
				_aidbg_on = not _aidbg_on   # dev: show what the AI commanders are thinking
				_map_reveal = _aidbg_on     # ...and lift the fog of the province map
				if aidbg_panel:
					aidbg_panel.visible = _aidbg_on
			KEY_F4:
				_toggle_rts_cam()           # dev: free-fly RTS camera over the whole province
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
	var shoulder := footpos + Vector3(0, 1.35 + _gh(footpos.x, footpos.z), 0) + right * 0.14
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
		return Transform3D(basis2, footpos + Vector3(0, 1.0 + _gh(footpos.x, footpos.z), 0) + fwd * 0.22 + right * 0.05)
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
	# sort back-to-front by depth, not emission index — without this, alpha-blended
	# quads in a dense, overlapping bank (a big smoke cloud especially) draw in the
	# wrong order from most angles, so the bank looks solid from the one direction
	# that happens to match index order and patchy/half-invisible from any other
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	var qm := QuadMesh.new()
	qm.size = quad
	qm.material = mat
	p.draw_pass_1 = qm
	match kind:
		0: p.process_material = _smoke_process()
		2: p.process_material = _fire_process()
		4: p.process_material = _blood_process()
		5: p.process_material = _musket_smoke_process()
		6: p.process_material = _dirt_process()
		7: p.process_material = _dust_process()
		8: p.process_material = _wake_process()
		9: p.process_material = _splash_process()
		_: p.process_material = _flash_process()
	return p

# Musket smoke: barely damped, so the discharge ROLLS forward off the muzzles and rides
# the wind once aloft — a real firing line's haze drifts steadily downwind rather than
# stagnating in place. gravity here is rewritten every frame in _update_environment() to
# track the live wind vector (see _wind), so the y component is just the powder's own
# slight buoyancy.
func _musket_smoke_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 0.012, 0)
	m.damping_min = 0.22
	m.damping_max = 0.45
	m.scale_min = 0.9
	m.scale_max = 1.8
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -8.0
	m.angular_velocity_max = 8.0
	# small-scale curling so the haze billows organically instead of scaling as a flat disc
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.6
	m.turbulence_noise_scale = 1.4
	m.turbulence_noise_speed = Vector3(0.06, 0.05, 0.04)
	m.turbulence_influence_min = 0.08
	m.turbulence_influence_max = 0.22
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
	# gravity is rewritten every frame in _update_environment() to carry the live wind
	# vector, so a cannon's smoke bank jets out, blooms, then drifts downwind as one mass
	# instead of just hanging in place; the y component below is its own slight buoyancy.
	m.gravity = Vector3(0, 0.10, 0)
	m.damping_min = 1.6                        # initial puff velocity bleeds off fast
	m.damping_max = 3.2
	m.scale_min = 1.0
	m.scale_max = 2.2
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -5.0
	m.angular_velocity_max = 5.0
	# big, slow-rolling curls — a far heavier billow than the musket's haze
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 2.4
	m.turbulence_noise_scale = 1.0
	m.turbulence_noise_speed = Vector3(0.05, 0.04, 0.03)
	m.turbulence_influence_min = 0.10
	m.turbulence_influence_max = 0.28
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

# A roundshot pitching into the ground: a hard, fast gout of earth and stones thrown
# along its line of travel, falling back almost as quickly as it went up.
func _dirt_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, -9.0, 0)            # the clods fall back hard — this isn't smoke
	m.damping_min = 1.0
	m.damping_max = 2.2
	m.scale_min = 0.6
	m.scale_max = 1.4
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -25.0
	m.angular_velocity_max = 25.0              # tumbling clods, not drifting puffs
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.25, 1.6))
	sc.add_point(Vector2(1.0, 1.0))            # the burst settles rather than keeps ballooning
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# a hard brown burst of earth, hazing to a thin dust before it's gone
	m.color_ramp = _ramp([0.0, 0.1, 0.5, 1.0], [
		Color(0.30, 0.22, 0.14, 0.0), Color(0.34, 0.25, 0.16, 0.85),
		Color(0.40, 0.32, 0.22, 0.5), Color(0.45, 0.40, 0.32, 0.0)])
	return m

# The pale haze kicked up by marching boots and galloping hooves. gravity is rewritten
# every frame in _update_environment() to carry the live wind, same as the smoke, so a
# column's dust trails away downwind instead of just hanging over the road.
func _dust_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, 0.02, 0)
	m.damping_min = 0.5
	m.damping_max = 1.1
	m.scale_min = 0.8
	m.scale_max = 1.6
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 1.2
	m.turbulence_noise_scale = 1.6
	m.turbulence_noise_speed = Vector3(0.05, 0.04, 0.03)
	m.turbulence_influence_min = 0.10
	m.turbulence_influence_max = 0.25
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.4, 1.8))
	sc.add_point(Vector2(1.0, 2.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	# thin and pale — a haze over the ranks' feet, not a smoke bank
	m.color_ramp = _ramp([0.0, 0.15, 0.6, 1.0], [
		Color(0.62, 0.56, 0.44, 0.0), Color(0.66, 0.60, 0.48, 0.30),
		Color(0.68, 0.62, 0.50, 0.16), Color(0.70, 0.64, 0.52, 0.0)])
	return m

# Foam turned over at a ship's bow as it makes way — flattens out and dissolves fast.
func _wake_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3.ZERO                   # rides the surface, doesn't fall or rise
	m.damping_min = 0.8
	m.damping_max = 1.6
	m.scale_min = 0.7
	m.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(0.3, 1.6))
	sc.add_point(Vector2(1.0, 2.4))            # spreads into the wake astern
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	m.color_ramp = _ramp([0.0, 0.15, 1.0], [
		Color(0.92, 0.95, 0.96, 0.0), Color(0.95, 0.97, 0.98, 0.55), Color(0.90, 0.93, 0.95, 0.0)])
	return m

# A roundshot pitching short or long in the sea — a hard white spout thrown up, then
# falling back under its own gravity (much harder than the bow's gentle wake).
func _splash_process() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.gravity = Vector3(0, -14.0, 0)
	m.damping_min = 0.6
	m.damping_max = 1.4
	m.scale_min = 0.7
	m.scale_max = 1.5
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.6))
	sc.add_point(Vector2(0.3, 1.8))
	sc.add_point(Vector2(1.0, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	m.scale_curve = sct
	m.color_ramp = _ramp([0.0, 0.12, 0.6, 1.0], [
		Color(0.85, 0.90, 0.93, 0.0), Color(0.93, 0.96, 0.97, 0.9),
		Color(0.80, 0.86, 0.90, 0.4), Color(0.75, 0.82, 0.87, 0.0)])
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
	# musket smoke is THROWN forward off the muzzle and rolls slowly downrange, dissipating
	# over distance (low-damping emitter). Each musket coughs out a dense little BURST, so a
	# firing line is properly wreathed in powder smoke rather than thin wisps.
	for _i in range(4):
		var jitter := Vector3(randf_range(-0.28, 0.28), randf_range(-0.10, 0.22), randf_range(-0.28, 0.28))
		var vel := fwd * randf_range(1.0, 2.4) + Vector3(0, randf_range(0.0, 0.12), 0) + _wind
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

# A roundshot striking the ground: a hard gout of earth thrown forward along its line
# of travel, with a thinner trail of dust hanging a moment after the clods fall back.
func _emit_dirt(pos: Vector3, dir: Vector3) -> void:
	for _i in range(10):
		var jitter := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
		var vel := dir * randf_range(2.0, 7.0) + Vector3(0, randf_range(2.0, 6.0), 0)
		dirt_p.emit_particle(Transform3D(Basis(), pos + jitter), vel,
			Color(0.85, 0.8, 0.7), Color.WHITE, EMIT_FLAGS)

# The haze a body of men or horses kicks up underfoot — thrown up gently behind the
# line of march, then left to drift downwind by the wind-driven process material.
func _emit_dust(pos: Vector3, fwd: Vector3) -> void:
	var vel := -fwd * randf_range(0.2, 0.6) + Vector3(0, randf_range(0.1, 0.4), 0) + _wind * 0.3
	dust_p.emit_particle(Transform3D(Basis(), pos), vel, Color(0.7, 0.64, 0.52), Color.WHITE, EMIT_FLAGS)

# The foam turned over at a ship's bow as it cuts through the water under way.
func _emit_wake(pos: Vector3, fwd: Vector3) -> void:
	var vel := -fwd * randf_range(0.3, 0.8) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	wake_p.emit_particle(Transform3D(Basis(), pos), vel, Color(0.95, 0.97, 0.98), Color.WHITE, EMIT_FLAGS)

# A roundshot pitching into the sea: a hard white spout thrown up where it strikes.
func _emit_splash(pos: Vector3) -> void:
	for _i in range(8):
		var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(5.0, 10.0), randf_range(-1.0, 1.0))
		splash_p.emit_particle(Transform3D(Basis(), pos + jitter), vel,
			Color(0.92, 0.95, 0.97), Color.WHITE, EMIT_FLAGS)

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
	blood_mm.set_instance_transform(blood_idx, Transform3D(basis, Vector3(pos.x, 0.03 + _gh(pos.x, pos.z), pos.z)))
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

# A muffled, deep boom from a fight too far to see — carries across the whole map and
# grows as you ride toward it (the source of "battles heard and come up on").
func _play_distant_battle(pos: Vector3) -> void:
	if _distant_pool.is_empty():
		return
	if cam != null and cam.position.distance_to(pos) < SIM_FULL_RANGE * 0.7:
		return                          # near enough that the true audio carries — no doubling
	var src: Array = snd_cannon_shots if (not snd_cannon_shots.is_empty() and randf() < 0.55) else snd_volley
	if src.is_empty():
		src = snd_cannon_shots if not snd_cannon_shots.is_empty() else snd_volley
	if src.is_empty():
		return
	var dp: AudioStreamPlayer3D = _distant_pool[_distant_i]
	_distant_i = (_distant_i + 1) % _distant_pool.size()
	dp.stream = src[randi() % src.size()]
	dp.global_position = to_global(pos)
	dp.pitch_scale = randf_range(0.68, 0.84)   # pitched down — a deep, distant rumble
	dp.play()

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

# the ramrod going down the barrel — a quiet sound, only heard close to the line
func _play_reload(pos: Vector3) -> void:
	if snd_reload == null or cam == null:
		return
	if cam.position.distance_to(pos) > 150.0:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_reload
	ap.global_position = to_global(pos + Vector3(0, 1.2, 0))
	ap.volume_db = 2.0
	ap.pitch_scale = randf_range(0.94, 1.08)
	ap.play()

# a roundshot striking the earth — a heavy thud that carries across the field
func _play_ball_land(pos: Vector3) -> void:
	if snd_ball_land == null:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_ball_land
	ap.global_position = to_global(pos)
	ap.volume_db = 9.0
	ap.pitch_scale = randf_range(0.9, 1.08)
	ap.play()

# the shriek of a ball passing overhead — placed at the ball so it screams past in 3D
func _play_ball_over(pos: Vector3) -> void:
	if snd_ball_over == null:
		return
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_ball_over
	ap.global_position = to_global(pos)
	ap.volume_db = 8.0
	ap.pitch_scale = randf_range(0.95, 1.06)
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
			courier_horse_mm.set_instance_transform(j, Transform3D(hbasis, Vector3(cp.x, 0.95 + _gh(cp.x, cp.z), cp.z)))
			courier_mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw), Vector3(cp.x, 1.65 + _gh(cp.x, cp.z), cp.z)))
		else:
			courier_mm.set_instance_transform(j, _zero_xf())
			courier_horse_mm.set_instance_transform(j, _zero_xf())

func _apply_order(order: Dictionary) -> void:
	_apply_net_order(player, order)

# Your brigade commander sends you his orders. You are told what is wanted — it is on
# you to carry it out (or not). The despatch never executes anything for you.
# The army commander's own despatches to you: he sends you on tasks and — before a major
# push — summons you to bring your battalion up and form on the main effort. (Deduped so
# he doesn't repeat himself; only speaks when his intent for you changes.)
func _commander_task(delta: float) -> void:
	if player == null or player.spent or not _battle_begun:
		return
	_task_cd -= delta
	if _task_cd > 0.0:
		return
	_task_cd = 15.0
	var army = null
	for a in armies:
		if a.team == player.team:
			army = a
			break
	if army == null:
		return
	var task := ""
	if army.plan == "press" and army.main != null and _brigade_live(army.main) > 0:
		var bno := int(army.main.idx % BRIGADES_PER_TEAM) + 1
		var mc := _brigade_center(army.main)
		if player.pos.distance_to(mc) > 720.0:
			task = "[color=#ffd773]The General:[/color] the army goes forward — bring the %s up and form on the %d%s Brigade for the assault." % [_unit_name(player), bno, _ord(bno)]
		else:
			task = "[color=#ffd773]The General:[/color] stand ready — the assault goes in. Press home with the main body when the drums beat the charge."
	elif army.plan == "defend":
		task = "[color=#ffd773]The General:[/color] hold the line. Stand fast and break him with your fire — give no ground."
	else:
		task = "[color=#cdd6e6]The General:[/color] advance with the line, keep dressed on your brigade, and close on the enemy."
	if task == _last_task:
		return
	_last_task = task
	_send_player_despatch(task, {})

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
			"morale": b.morale, "state": b.state, "spent": b.spent,
			"skills": b.skill.duplicate(), "fatigue": b.fatigue }   # carry the drilled/blooded profile home
		survivors.append(rec)
	_setup.result = {
		"winner": pt if won else et,   # won == the player's side held the field
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

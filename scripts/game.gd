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
const BATTS_PER_BRIGADE := 10     # EXPERIMENT: doubled — 7,000 men to a brigade (200 battalions/side)
const BRIGADES_PER_DIVISION := 5  # 17,500 men to a division
const DIVISIONS_PER_CORPS := 2    # 35,000 men to a corps (1st line + 2nd line)
const CORPS_PER_TEAM := 2         # 70,000 men to an army
const BRIGADES_PER_TEAM := CORPS_PER_TEAM * DIVISIONS_PER_CORPS * BRIGADES_PER_DIVISION
const BATT_PER_TEAM := BRIGADES_PER_TEAM * BATTS_PER_BRIGADE   # 100 battalions a side
const BRIG_BATT_SPACING := 138.0  # interval between battalions dressed in a brigade line
const BRIG_FRONT := 3             # battalions in the front line; the rest form a reserve
const RESERVE_DEPTH := 55.0       # how far the reserve line stands behind the front
const BRIG_DECIDE := 0.9          # a brigade re-reads the field this often (s)
const BRIG_TURN_RATE := 1.6       # how fast a brigade wheels its line onto a new facing (rad-ease/s) — smooths slots
const FORM_LOCK_TIME := 1.6       # after a battalion changes formation it HOLDS for this long — kills column<->line strobe
const ARMY_DECIDE := 3.5          # the army commander re-plans this often (s)
const FLANK_REACH := 120.0        # how far around an enemy flank a turning brigade swings
const BRIG_ENGAGE_RANGE := 72.0   # halt & open fire when the enemy line is in musket range
const OPERATIONAL_CONTACT := 800.0 # a brigade gives battle to an enemy brigade within this; beyond it, it pursues its strategic task
const TOWN_HOLD_RADIUS := 180.0    # how near its town a brigade must be to count as holding/garrisoning it
const BRIG_ASSAULT_MORALE := 52.0 # press the bayonet home once the enemy is this shaken
# --- cavalry: the arm of decision ---
const CAV_PER_TEAM := 24          # EXPERIMENT: doubled — regiments of horse a side (6 per arm)
const CAV_REINFORCE_HEADROOM := 3 # spare per-arm MultiMesh slots so a Stables can raise new regiments
const CAV_MEN := 120              # troopers per regiment
const CAV_SP := 1.5               # knee-to-knee interval (m)
const CAV_TROT := 3.2             # manoeuvre pace (fallback/base; each type rides its own pace — see CAV_TYPE_DATA)
const CAV_GALLOP := 6.5           # the charge home (fallback/base)
const CAV_CHARGE_RANGE := 280.0   # will launch at a target within this
const CAV_CONTACT := 10.0         # the moment of impact
const CAV_RALLY_TIME := 32.0      # blown horses must rally before charging again (base; scaled by rally_mult)
const CAV_DECIDE := 2.0           # how often a regiment looks for an opportunity
# The four arms of horse a regiment can be raised as. Each rides at its own pace, hits
# with its own weight of shock, takes losses at its own sturdiness, and scouts an
# opportunity at its own range — hussars and light dragoons are the fast scouting/
# screening horse (quick, fragile, best against routs and loose skirmishers); heavy
# dragoons are the battering-ram reserve (slow, hits hardest, best soaks losses);
# lancers trade some staying-power for a reach advantage that bites hardest on the
# first shock home. Indexed by Cav.cav_type (0..3); see _cav_rider_mesh()/_cav_rider_shader()
# for the matching models.
const CAV_TYPE_DATA := [
	{ "name": "Hussars",        "trot": 3.6, "gallop": 7.2, "rally_mult": 0.75, "shock": 0.85, "sturdy": 1.15, "scout": 1.25, "mount_scale": 0.96 },
	{ "name": "Light Dragoons", "trot": 3.4, "gallop": 6.6, "rally_mult": 0.90, "shock": 1.00, "sturdy": 1.00, "scout": 1.10, "mount_scale": 1.00 },
	{ "name": "Heavy Dragoons", "trot": 2.9, "gallop": 5.8, "rally_mult": 1.25, "shock": 1.30, "sturdy": 1.25, "scout": 0.85, "mount_scale": 1.14 },
	{ "name": "Lancers",        "trot": 3.2, "gallop": 6.6, "rally_mult": 1.00, "shock": 1.20, "sturdy": 0.90, "scout": 1.00, "mount_scale": 1.02 },
]
const SQUARE_ALERT := 150.0       # infantry forms square when a CHARGING enemy horse is this close
const SQUARE_RELAX := 230.0       # ...and re-forms line once it is well clear
const SQUARE_PANIC := 100.0       # ...or for ANY enemy horse this close, charging or not (point-blank)
const SQUARE_HOLD := 4.0          # hold the square this long after the threat clears — kills square<->line flicker
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
const LINE_HOLD_DIST := 45.0     # once formed in line a battalion HOLDS it until its slot drifts past
								 # this (a wide deadband) — stops the line↔column / facing strobe on the advance
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
# A commanded volley is STAGGERED by the battalion's DRILL: crack troops crash out almost as one,
# raw troops straggle their fire over a window. The spread (first shot → last) runs from this max at
# drill 0 down to the min at drill 100.
const VOLLEY_SPREAD_MAX := 5.0   # raw, undrilled — a ragged five seconds of fire
const VOLLEY_SPREAD_MIN := 0.18  # crack troops — a single crashing report
const VOLLEY_CRASH_MIN := 10     # men firing together in one frame for it to BOOM as a volley crash
								 # (below this it's left as the crackle of individual shots)
# --- bayonet charge & melee ---
const CHARGE_SPEED := 3.6         # the pas de charge (m/s)
const CHARGE_RANGE := 65.0        # you may order a charge within this
const MELEE_RANGE := 6.0          # contact distance
const CHARGE_SHOCK := 34.0        # morale blow the defender takes at the moment of impact
const MELEE_RATE := 18.0          # men lost per second in the press (scaled by morale)
const MELEE_MORALE := 16.0        # morale bled per second locked in melee
# --- per-man duel melee (only the men at the SEAM fight; skill sets who bleeds, numbers lap the flank) ---
const MELEE_MIN := 60            # a unit ground below this in the press is finished — the melee ends
const MELEE_DUEL_RATE := 0.05    # men lost per CONTACTING pair per second (the grind's pace) — tunable
const MELEE_FLANK_LAP := 0.4     # bonus a wider line gets for lapping the narrower one's flank
const MELEE_MORALE_SLOW := 0.16  # how fast nerve erodes in the grind (lower = longer, bloodier fights)
const MELEE_SKILL_PROTECT := 3.0 # in the press the less-skilled fall first — a good swordsman keeps his feet
const MELEE_XP_GAIN := 0.04      # melee-skill a named front-rank man hardens by, per second in the press
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
# Every firing musket gets its own report, but a shared per-frame budget caps how many distinct
# shot-voices spawn each frame so a mass volley can't starve the pool of voices/cannon/orders.
const MUSKET_SND_BUDGET := 64
var _musket_snd_left := 0
const COCK_SND_BUDGET := 40       # per-frame cap on "MusketCock" clicks (a crackle as the line presents)
var _cock_snd_left := 0
const MAX_PER_TEAM := BATT_PER_TEAM * MEN + MILITIA_MAX_MEN   # headroom for an independent militia on top of the standing OOB
const CORPSE_MAX := 24000          # per team, rolling (the oldest dead are re-used)
const RAID_CAP := 480              # team 2's render headroom — raiding parties are small war-bands, not armies
# --- artillery (the great killer of the age) ---
const BATTERIES_PER_TEAM := 16     # EXPERIMENT: doubled — 64 guns a side
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
const LOD_MID := 150.0
const LOD_FAR := 240.0            # full per-man detail out to here (pulled in for the big set-piece scale)...
const LOD_VFAR := 1150.0          # ...then a static formation IMPRESSION to here, then culled entirely
const LOD_HYST := 25.0           # dead-band around each LOD boundary so a unit at the edge doesn't
								 # strobe between detailed men and the box-man impression
# The far IMPRESSION (beyond LOD_FAR) draws only every Nth man — and that N GROWS with distance, so a
# battalion at the back of the field costs a fraction of one up close. Lower the base / cap to render
# fewer distant troops (more FPS); raise them for a denser-looking horizon. (Pure render — no sim effect.)
const LOD_IMPRESSION_STEP := 6    # every Nth man at LOD_FAR
const LOD_IMPRESSION_FALLOFF := 75.0   # +1 to the step every this-many metres further out
const LOD_IMPRESSION_MAX := 22    # never sparser than 1-in-this
const SEEN_GRACE := 0.4          # keep a just-departed unit drawn this long after it leaves the
								 # frustum, so units don't flicker out at the screen edge
# FOG OF WAR — you only know the enemy your own forces can see. Sight radii by spotter type;
# light cavalry are the eyes of the army. A spotted enemy is drawn; one only lately seen leaves a
# fading GHOST on the map at its last-known place; one never seen isn't there at all.
const SIGHT_INF := 280.0         # a battalion's pickets see out to here
const SIGHT_CAV := 620.0         # light horse range furthest — the scouts
const SIGHT_OFFICER := 320.0     # you, in the saddle (the spyglass extends it)
const SIGHT_GUN := 200.0         # a battery's own watch
const VISION_TICK := 0.3         # recompute the army's picture this often (cheap, not per-frame)
const PLAYER_SEES_ALL := true    # the PLAYER's view shows every enemy (no LoS hiding); the AI still has fog & scouts
const GHOST_FADE := 90.0         # campaign-seconds a last-known marker lingers before it's forgotten
const SCOUT_DIST := 900.0        # how far ahead light horse range to scout / picket the army's front
const SCOUT_THREAT := 230.0      # enemy horse this close turns a scouting party for home
const AI_MEMORY := 30.0          # how long a commander remembers a scouted enemy before the intel goes cold
const NET_FOG_EXPIRE := 0.7      # MP client: an enemy not streamed for this long has slipped our sight

enum Order { IDLE, FOLLOW }

class Batt:
	var team: int
	var is_player: bool = false
	var human_slot: int = -1        # the MP lobby slot commanding this battalion (-1 = AI-led)
	var independent: bool = false   # founded militia: never joins the brigade/division/corps OOB
	# authored OOB place (set from BattleSetup.BattUnit for historical battles; -1 = group procedurally)
	var oob_corps: int = -1
	var oob_division: int = -1
	var oob_brigade: int = -1
	var nation: String = "GEN"     # nationality key (FR/BR/PR/… or GEN) — drives the command AI's national doctrine
	var weapon_id: String = "brown_bess"   # weapon id → weapons/<id>.tres; resolved lazily into `wpn`
	var wpn: Weapon = null         # the resolved Weapon (range/reload/accuracy) — via _wpn(b)
	var form_lock_t: float = 0.0   # cooldown after a column<->line/march change, so the formation can't strobe
	var square_t: float = 0.0      # how much longer to hold square after the cavalry threat has passed
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
	# LEADERSHIP: the living NCO/officer cadre steadies the men. A full cadre = 1.0 (no change);
	# as sergeants and officers fall, this sinks and the battalion grows brittle (breaks at a
	# higher nerve, loses its order faster, rallies slower, holds less). Player battalion only.
	var _leadership: float = 1.0
	var _leaders0: int = 0          # leaders at full establishment — the denominator for the ratio
	var _lead_warned: bool = false  # one-shot "your sergeants are falling" warning
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
	var indep_fire: bool = false   # INDEPENDENT fire: each man presents (cocks), holds, then fires at will
	var volley_seq: float = 0.0    # the words of command run their course before the crash
	var fire_now: bool = false     # one-shot: the officer's "FIRE!" this frame
	var volley_window: float = 0.0 # >0 while a commanded volley is rippling out (staggered by drill)
	var _volley_boom_cd: float = 0.0   # throttle on the volley CRASH report (the per-shot cracks aside)
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
	var volley_cd: float = 0.0     # the line reloading between commanded full volleys (the player's "Fire!")
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
	var _seen_t: float = -100.0    # _t when last inside the view frustum (render hysteresis)
	var _lod: int = 0              # the render LOD it settled on last frame (LOD-band hysteresis)
	# FOG OF WAR (an enemy unit's state in the local player's eyes): spotted now, and where/when last seen
	var _spotted: bool = false
	var _intel_pos: Vector3 = Vector3.ZERO
	var _intel_t: float = -1000.0
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
	# --- NATIVE RAID PARTIES (team 2): a small war-band, hostile to both colonial sides,
	# that rides the existing generic AI/combat code rather than a parallel system ---
	var is_raider: bool = false
	var raid_state: String = "march"   # march (to the town) | raid (draining it) | retreat (home) | idle (resting, re-taskable)
	var raid_t: float = 0.0            # seconds spent in the current raid_state
	var raid_drain_t: float = 0.0      # accumulator that bleeds the town a point at a time
	var raid_town: Dictionary = {}     # the field_towns entry being raided
	var raid_home: Vector3 = Vector3.ZERO   # the forest the party came from — and returns to

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
	var _spotted: bool = false  # fog of war: seen by the local player's side this frame
	var _intel_t: float = -1000.0

# A brigade: several battalions and a battery under one commander, manoeuvring as a
# body to 18th-century doctrine — advance in line, soften with artillery, assault a
# shaken enemy, support a hard-pressed neighbour, refuse a threatened flank.
class Brigade:
	var team: int
	var idx: int = 0
	var nation: String = "GEN"     # dominant nationality of its battalions
	var doctrine: Dictionary = {}  # the national doctrine it fights by (DOCTRINE entry)
	var temper: Dictionary = {}    # the brigadier's temperament (TEMPERS entry)
	var terrain_anchor: Vector3 = Vector3.INF   # ground the army wants it to form on/hold (INF = none) — Phase 2
	var on_flank: int = 0          # -1 = army's left flank, +1 = right, 0 = interior (for flank anchoring)
	var hold_high: bool = false    # a defender: stand on the chosen ground, don't advance off the crest
	var obs_prev: Vector3 = Vector3.INF   # last observed centre (the enemy uses it to read this brigade's momentum)
	var battalions: Array = []     # its Batt members
	var guns: Array = []           # its attached battery
	var posture: String = "advance"   # advance | engage | assault | hold | support | withdraw
	var anchor: Vector3            # centre of the brigade's intended line
	var facing: float = 0.0        # the direction it faces (eased toward face_want so slots don't strobe)
	var face_want: float = 0.0     # the direction it WANTS to face; `facing` turns onto it smoothly
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
	# --- historical-script overrides (Waterloo): hold in place until a time, then march to a set point ---
	var hold_until: float = 0.0    # while _t < this, the brigade stands fast (reserve / not yet arrived)
	var scripted_obj: Vector3 = Vector3.ZERO   # a directed objective; cleared once reached (then normal AI)
	# --- the OPERATIONAL task: this brigade's PRIMARY directive on the dispersed map. It marches
	# to and works around a place; it only drops into the tactical battle (above) on CONTACT ---
	var task_kind: String = "screen"   # assault | defend | screen
	var task_town = null               # the field_towns entry the task concerns (or null)

# A DIVISION: 3-5 brigades under a General. The army hands the division a directive
# (make the main effort / fix the enemy / stand in reserve) and an objective; the
# general then decides FOR HIMSELF which of his brigades lead, which support on the
# flanks, and which he keeps in his own hand — initiative one tier down from the army.
class Division:
	var team: int
	var idx: int = 0
	var corps: int = 0
	var nation: String = "GEN"     # dominant nationality of its brigades
	var doctrine: Dictionary = {}  # the national doctrine (DOCTRINE entry)
	var temper: Dictionary = {}    # the divisional general's temperament (TEMPERS entry)
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
	var aggression: float = 0.5    # personality: cautious (0) .. bold (1) — derived from doctrine + temperament
	var nation: String = "GEN"     # dominant nationality of the army
	var doctrine: Dictionary = {}  # its national doctrine (DOCTRINE entry)
	var temper: Dictionary = {}    # the army commander's temperament (TEMPERS entry)
	var role: String = "meeting"   # strategic posture: attack | defend | rearguard | meeting — sets the war aim
	var threat_x: float = 0.0      # ANTICIPATION (Phase 2): lateral axis where the enemy's weight is gathering
	var threat_t: float = 0.0      # when that reading was last taken (0 = none yet)
	var threat_mass: float = 0.0   # how concentrated/committed the read threat is (0..1) — confidence
	var plan: String = "develop"   # develop | press | defend
	var main = null                # the brigade making the main effort
	# --- the appreciation: the goal this commander has DEDUCED for himself ---
	var goal: String = "develop"   # destroy | turn_left | turn_right | break_centre | bleed | delay | seize
	var goal_t: float = 0.0        # commitment: how long the present goal has stood
	var scripted_goal: String = ""  # historical script forces the army's intent (Waterloo) when set
	var play: String = ""          # the doctrine play serving the goal (e.g. grand_battery)
	var gb_pos: Vector3            # where the grand battery masses
	var intel_cd: float = 0.0      # reports arrive by courier — the picture lags reality
	var intel_left: float = 0.0    # last-REPORTED enemy frontage (for overlap judgments)
	var intel_right: float = 0.0
	var intel_fresh: bool = false
	var target_town = null         # the STRATEGIC objective: a town the army is campaigning to take

var key_points: Array = []         # future terrain goals: { pos, value, owner } (step 5 hook)

# ─────────────────────────────────────────────────────────────────────────────
# NATIONAL DOCTRINE — how each nationality's commanders prefer to fight. Resolved
# onto every army/division/brigade from its troops' `nation` tag. The knobs feed the
# command AI (aggression, attack shape, where the guns mass, how the horse is used,
# how thick the skirmish screen, whether a defender seeks a reverse slope, the tempo).
# Tuned to period reputation, not exactness — and all freely adjustable.
#   aggr        baseline boldness 0..1 (cautious..bold) before temperament
#   attack      preferred assault shape: "column" (shock) or "line" (firepower)
#   grand_bat   appetite for massing a grand battery 0..1
#   cav         cavalry doctrine: "massed" (held for one big exploiting charge) or "local" (close support)
#   skirmish    density of the light screen thrown forward 0..1
#   reverse     defends on a reverse slope / behind cover when it can
#   tempo       "brisk" | "build" | "methodical" — how fast it forces a decision
const DOCTRINE := {
	"french":    {"aggr": 0.72, "attack": "column", "grand_bat": 1.0, "cav": "massed", "skirmish": 0.9, "reverse": false, "tempo": "build"},
	"british":   {"aggr": 0.42, "attack": "line",   "grand_bat": 0.3, "cav": "local",  "skirmish": 0.5, "reverse": true,  "tempo": "build"},
	"prussian":  {"aggr": 0.66, "attack": "column", "grand_bat": 0.6, "cav": "local",  "skirmish": 0.8, "reverse": false, "tempo": "methodical"},
	"dutch":     {"aggr": 0.46, "attack": "line",   "grand_bat": 0.4, "cav": "local",  "skirmish": 0.6, "reverse": true,  "tempo": "build"},
	"brunswick": {"aggr": 0.52, "attack": "line",   "grand_bat": 0.3, "cav": "local",  "skirmish": 0.7, "reverse": true,  "tempo": "build"},
	"line":      {"aggr": 0.55, "attack": "line",   "grand_bat": 0.5, "cav": "local",  "skirmish": 0.5, "reverse": true,  "tempo": "build"},
}
# nationality key (historical.gd NAT) → doctrine group above
const NATION_DOCTRINE := {
	"FR": "french", "FL": "french", "FG": "french",
	"BR": "british", "KG": "british", "HA": "british",
	"NL": "dutch", "NA": "dutch",
	"BW": "brunswick", "PR": "prussian",
	"GEN": "line",
}
# A COMMANDER'S TEMPERAMENT — rolled per general, tunes his doctrine. The same nation
# fields different men: a bold marshal gambles where a cautious one waits. Modifiers add
# to doctrine: aggr (boldness), tempo (+ = hurries the decision), hold (+ = clings to his
# reserve longer), flank (taste for the wide manoeuvre), expose (rides forward, more at risk).
const TEMPERS := [
	{"name": "bold",       "aggr":  0.18, "tempo":  0.20, "hold": -0.15, "flank":  0.20, "expose":  0.20},
	{"name": "impetuous",  "aggr":  0.12, "tempo":  0.28, "hold": -0.22, "flank":  0.10, "expose":  0.26},
	{"name": "steady",     "aggr":  0.00, "tempo":  0.00, "hold":  0.05, "flank":  0.00, "expose":  0.00},
	{"name": "methodical", "aggr": -0.06, "tempo": -0.16, "hold":  0.12, "flank": -0.05, "expose": -0.12},
	{"name": "cautious",   "aggr": -0.18, "tempo": -0.22, "hold":  0.22, "flank": -0.12, "expose": -0.20},
]

# map a nationality key to its doctrine dict (falls back to the generic line doctrine)
func _doctrine_for(nat: String) -> Dictionary:
	return DOCTRINE[NATION_DOCTRINE.get(nat, "line")]

# An ARMY's DOCTRINE GROUP — its CHARACTER comes from the main body fighting at the start. Two
# corrections over a raw headcount: (1) tally by doctrine GROUP, so a COALITION's contingents
# combine (British + KGL + Hanoverian all count as "british") instead of splitting the vote and
# letting one big foreign bloc win; (2) weight each battalion by how forward it stands (close to
# the enemy = engaged), so a numerous but distant, late-arriving contingent (the Prussians far
# east at Waterloo) can't hijack the doctrine. Result: the Anglo-Allied army reads as British —
# it defends the ridge — not Prussian.
func _army_doctrine_group(team: int) -> String:
	var ec := Vector3.ZERO
	var en := 0
	for b in battalions:
		if b.team != team and not b.spent and not b.independent:
			ec += b.pos
			en += 1
	var tally := {}
	for b in battalions:
		if b.team != team or b.spent or b.independent:
			continue
		var grp: String = NATION_DOCTRINE.get(b.nation, "line")
		var w := float(maxi(1, b.figs.size()))
		if en > 0:
			w *= 1.0 / (1.0 + b.pos.distance_to(ec / float(en)) / 800.0)   # forward troops weigh most
		tally[grp] = float(tally.get(grp, 0.0)) + w
	var best := "line"
	var bestv := -1.0
	for g in tally:
		if float(tally[g]) > bestv:
			bestv = float(tally[g])
			best = String(g)
	return best

# the dominant nationality across a set of battalions (most men) — a formation's nation
func _dominant_nation(batts: Array) -> String:
	var tally := {}
	for b in batts:
		if b.spent:
			continue
		var n: String = b.nation
		tally[n] = int(tally.get(n, 0)) + maxi(1, b.figs.size())
	var best := "GEN"
	var bestv := -1
	for n in tally:
		if int(tally[n]) > bestv:
			bestv = int(tally[n])
			best = n
	return best

# A regiment of horse: held in reserve, loosed at an opportunity — a wavering line, a
# routing mob, an exposed battery, or the enemy's own cavalry — then blown, and must
# retire to rally before it can charge again. It breaks on a formed square.
class Cav:
	var team: int
	var idx: int = 0
	var cav_type: int = 0          # indexes CAV_TYPE_DATA — hussar/light dragoon/heavy dragoon/lancer
	var pos: Vector3
	var facing: float = 0.0
	var troopers: Array = []       # { slot: Vector2, wpos: Vector3, ph: float }
	var state: String = "reserve"  # reserve | charging | retiring | rallying | fled
	var target = null              # Batt, Gun or Cav being charged
	var target_kind: String = ""
	var rally_t: float = 0.0
	var decide_cd: float = 0.0
	var reserve_pos: Vector3
	var scout_goal: Vector3        # where a "scouting" regiment is ranging to (then it rides home)
	var scout_cd: float = 0.0      # throttle on a light regiment volunteering to scout
	var spent: bool = false
	var player: bool = false       # YOU lead this squadron — it forms on you and charges at your word
	var hoof_player: AudioStreamPlayer3D   # the thunder of the gallop
	var _spotted: bool = false     # fog of war: seen by the local player's side this frame
	var _intel_pos: Vector3 = Vector3.ZERO
	var _intel_t: float = -1000.0
	var _drawn: bool = false       # render LOD state: was this regiment drawn last frame (cull hysteresis)

var cavalry: Array[Cav] = []
var cav_horse_mm: Array = [[], []]    # cav_horse_mm[team][cav_type] — per-team-per-arm mounts
var cav_rider_mm: Array = [[], []]    # cav_rider_mm[team][cav_type] — per-team-per-arm riders
var _cav_warn_cd := 0.0                   # throttle on "form square!" warnings to you
var caissons: Array = []                  # ammunition waggons on the road: {node,pos,target,state,t,origin}
var _caisson_scan := 0.0                  # AI quartermasters check the line this often
var _gunner_mesh_cache: ArrayMesh         # shared detailed gun-crew figure (built once, lazily)
var _gunner_mats: Array = [null, null, null]  # per-team gunner ShaderMaterial, built once each
var _draft_horse_mesh_cache: ArrayMesh    # shared limber/caisson draft-horse mesh (built once)
var _draft_horse_mats: Array = []         # a couple of coat-colour variants, built once
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
const ARMY_RAID := Color(0.34, 0.24, 0.13)   # buckskin/earth — a raiding war-party, no European coat
const RIFLE_GREEN := Color(0.12, 0.20, 0.13)   # the 4th coat slot: rifle / jäger / Nassau green
const COATS_0 := [ARMY_BLUE, ARMY_BLUE, ARMY_BLUE, RIFLE_GREEN]
const COATS_1 := [ARMY_RED, ARMY_RED, ARMY_RED, RIFLE_GREEN]
const COATS_2 := [ARMY_RAID, ARMY_RAID, ARMY_RAID, RIFLE_GREEN]
# Waterloo coat palettes — 4 coats per side: France in blue (line / légère / Guard) + a green slot;
# the Allies in British red, an Allied blue (Dutch/Prussian), Brunswick black, and rifle/Nassau green.
# Each battalion picks its slot via coat_idx (the 4th, index 3, is the green for rifles & jägers).
const COATS_W0 := [Color(0.13, 0.18, 0.46), Color(0.10, 0.16, 0.40), Color(0.07, 0.11, 0.32), RIFLE_GREEN]
const COATS_W1 := [Color(0.63, 0.15, 0.13), Color(0.18, 0.28, 0.58), Color(0.10, 0.10, 0.13), RIFLE_GREEN]
const FACINGS_2 := [Color(0.78, 0.62, 0.30), Color(0.55, 0.10, 0.08), Color(0.85, 0.80, 0.72),
	Color(0.20, 0.30, 0.16), Color(0.40, 0.20, 0.10), Color(0.10, 0.10, 0.10)]

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
var team_mm: Array = [null, null, null]
var _troop_glb := false            # the living troops render the Blender vertex-coloured LOD
# TROOP-TYPE MODELS FOR ALL INFANTRY: every man is drawn from his battalion's detailed Blender
# model — line (shako), light (green plume, wings) or grenadier (bearskin) — through one MultiMesh
# per (team, troop-type). `visible_instance_count` keeps the GPU to the men actually drawn, and the
# troop shader fades the small accents (plume/belts/brass) into the coat with distance so the far
# ranks read as clean blocks rather than speckle. Only the >340 m horizon impression stays box-man.
const NEAR_CAP := 64               # near_mm currently unused (all infantry go through team_mm); keep tiny
const TROOP_GLB := ["res://models/troop_line.glb", "res://models/troop_light.glb", "res://models/troop_grenadier.glb"]
const TROOP_PLUME := [Color(0.92, 0.90, 0.86), Color(0.12, 0.42, 0.16), Color(0.80, 0.14, 0.12)]  # white / green / red
var near_mm: Array = [[null, null, null], [null, null, null], [null, null, null]]    # [team][troop_type] LOD bodies
var near_gun: Array = [[null, null, null], [null, null, null], [null, null, null]]   # [team][troop_type] their muskets
var near_prev: Array = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]                    # tail-zero watermark, per team/type
var team_prev: Array[int] = [0, 0, 0]
var musket_mm: Array = [null, null, null]      # a placeholder musket per rendered soldier
var musket_prev: Array[int] = [0, 0, 0]
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
var corpse_mm: Array = [null, null, null]       # per-team fallen (kept in team colour)
var corpse_idx: Array[int] = [0, 0, 0]
# not every man hit is killed outright — some drag themselves toward the rear
var wounded: Array = []                   # { pos, dir, t, team, ph }
var wounded_mm: Array = [null, null, null]
const WOUNDED_MAX := 110                  # crawling at once, per team
const WOUNDED_FRAC := 0.3                 # fraction of the fallen who are wounded, not killed
const WOUNDED_TIME := 26.0                # how long a man crawls before he is still
const CRAWL_SPEED := 0.35
var falling: Array = []                    # { pos, dir, t, team, yaw } — men mid-collapse, toppling before they lie still
var falling_mm: Array = [null, null, null]
const FALLING_MAX := 90                    # men toppling at once, per team
const FALL_TIME := 0.7                     # seconds to topple from struck-upright to prone
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
var _campaign_over := false         # TRUE only when the province is decided (a town sweep) — then it ends
var _day_count := 1                 # which day of the campaign we are on (persists across nights)
var _town_winner := -1              # >=0 if the day was decided by a clean sweep of the towns
const NIGHTFALL_HOUR := 20.0        # when dusk deepens to this hour, the day's fighting ends
var _army_broken := [false, false, false]
var _start_strength := [0, 0, 0]      # men each army brought to the field (index 2 unused — raiders have no army)
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
var snd_reload: AudioStream               # ramrod work — the firing line loading
var snd_cock: AudioStream                 # MusketCock — a man brings his piece to the present
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
const NET_CHUNK := 7       # entities per state packet — keeps each under ENet's MTU (~1392B) so a
						  # full-OOB snapshot isn't sent as one giant unreliable packet that drops
# AREA-OF-INTEREST: the host SIMULATES the whole field (gameplay is unaffected) but only BROADCASTS
# at full rate the units near a player's eye — anything a player can SEE. AOI_RANGE must exceed the
# render range (LOD_VFAR) so no drawable unit is ever starved. Units out of everyone's sight are still
# refreshed, just slowly (rolling over FAR_REFRESH seconds), so the wider map stays current and cheap.
const AOI_RANGE := 1700.0   # > LOD_VFAR (1400): a unit this near any player gets every-tick updates
const FAR_REFRESH := 2.0    # seconds to roll a full refresh over all the out-of-sight units
var _net_far_cursor := 0    # rotates through the far units so each gets its slow refresh in turn
const FX_VOLLEY := 0
const FX_MELEE := 1
const FX_GUN := 2          # a cannon firing — clients reproduce the muzzle blast at the given point

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
var _camp_node: Node3D = null      # the pitched bivouac (tents/fires/figures) — null when struck
var _camp_fires: Array = []        # { flame, light, seed } for the firelight flicker
var _camp_actors: Array = []       # the living men: { node, head, armL, armR, kind, ... } animated each frame
var _camp_scene_at := Vector3.ZERO # where the present camp is pitched (re-pitch if you move off)
# --- hands-on VOLLEY DRILL: present (V) then fire (F) at the butts; crisp synchronised volleys
# fired on the beat harden reload/aim/discipline. A live, scored exercise, not a menu toggle.
var _drill_on := false
var _drill_node: Node3D = null
var _drill_targets: Array = []     # { node, alive, down_t, pos } straw men at the butts
var _drill_present_t := -10.0      # _t of the last "Present!" (for cadence scoring)
var _drill_score := 50.0           # smoothed volley quality 0..100 (a running read-out)
var _drill_volleys := 0
var _drill_gain := 0.0             # total skill points earned this session (for the summary)
# --- hands-on MANOEUVRE DRILL: the drill-master calls a formation (form line/column/square);
# you must pass the order (Q ▸ Formation) and get the battalion dressed in it quickly. Smart,
# fast manoeuvres harden discipline & stamina (and the named men with them). ---
var _mdrill_on := false
var _mdrill_target := ""           # the called formation the battalion must reach
var _mdrill_call_t := 0.0          # _t when it was called (for timing the manoeuvre)
var _mdrill_await := false         # waiting for the battalion to complete the called manoeuvre
var _mdrill_next_t := 0.0          # _t at which to call the next manoeuvre (the pause between)
var _mdrill_count := 0
var _mdrill_score := 50.0
var _mdrill_gain := 0.0
var _mdrill_cycle := 0
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
var _vision_cd := 0.0              # fog-of-war recompute throttle
var _contact_cd := 0.0             # throttle on "enemy sighted" despatches
var _scope_rect: ColorRect
var _scope_mat: ShaderMaterial
var _scope_zoom := 0.45             # spyglass magnification: 0 wide .. 1 drawn fully out (mouse wheel)
var drummer_mm: MultiMesh
var snd_drum: AudioStream
var _drum_cd := 0.0
const FOV_NORMAL := 60.0
const FOV_SCOPE_WIDE := 24.0        # glass barely drawn — a wide, low-power field
const FOV_SCOPE_NARROW := 8.0       # glass drawn fully out — high magnification, a narrow field

var _setup: BattleSetup            # the seam: the world this battle was handed
var _inflated: bool = false        # this battle was inflated from a campaign engagement
var _wmap: bool = false            # the Waterloo battlefield terrain (not the campaign province)
var _arty_range: float = ARTY_RANGE  # roundshot reach — wider on a set-piece field (authentic 1m scale)
var _cav_men: int = CAV_MEN          # troopers per regiment — fuller on a set-piece field (historical scale)
var _wat_t0: float = 0.0           # battle step-off time, for the historical phase clock
var _wat_phase: int = -1           # the last historical phase that has fired
# the historical timeline (seconds after step-off → phase key); the script plays each once, in order
const WAT_PHASES := [
	[0.0, "hougoumont"], [80.0, "grand_battery"], [150.0, "derlon"],
	[270.0, "cavalry"], [400.0, "prussians"], [540.0, "guard"],
]

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
	# CONTINUE CAMPAIGN: read the save BEFORE the world is built, so the map regenerates from the
	# saved seed (towns/roads in the same places) and the hero wears the saved militia's colours.
	if GameConfig.load_requested:
		GameConfig.load_requested = false
		_loaded_save = _load_save_file()
		if _loaded_save != null:
			GameConfig.match_seed = int(_loaded_save.get("seed", GameConfig.match_seed))
			_restore_militia_config(_loaded_save)
	_wmap = (GameConfig.historical == "waterloo")   # the Waterloo battlefield, not the campaign province
	_arty_range = 880.0 if _wmap else ARTY_RANGE    # the guns bombard across the valley, not advance into it
	_cav_men = 480 if _wmap else CAV_MEN            # full-strength historical regiments, not campaign squadrons
	_build_world()
	if not hosted and not _wmap:
		_build_scenery()            # host uses the province's own woods & fields
	if GameConfig.historical == "":
		_build_ocean()              # the sea anchors the eastern flank (campaign province only)
	if not hosted:
		_build_clouds()             # a drifting cloud sheet overhead, driven by the wind
	if GameConfig.historical == "":
		_spawn_ships()              # shipping and a running sea-fight, out beyond the shore
		_build_field_settlements()  # the province's towns, spread across the wider map
		_build_province_sites()     # forts & depots: a garrison home per brigade, plus roads
	_build_homesteads()             # farmsteads, fields, fences and stock across the country
	_build_farmland()               # crop fields in varied colours, hedgerows along roads & fields
	_build_field_forests()          # province-wide forest stands, pine-biased toward the coast
	if _wmap:
		_build_waterloo()           # the ridge, the road, and the famous farms & villages
	_build_officer()
	_build_wounded_layer()
	_build_falling_layer()
	_spawn_armies()
	_build_guns()
	_spawn_cavalry()
	_assign_brigades()
	# CONTINUE CAMPAIGN: now the meshes/pools exist, replace the fresh spawn with the saved state
	if _loaded_save != null:
		_apply_save(_loaded_save)
		_send_player_despatch("[color=#9fe0a0]Campaign restored — day %d.[/color]" % _day_count, {})
		_loaded_save = null
	_set_objective()                  # your personal charge for the day
	# AI-vs-AI batch (--ai-batch): no human commander, step off at once, run flat out and
	# quit with the [RESULT] line so a script can run hundreds of matches and score the AI
	if batch:
		_ai_batch = true
		if player != null:
			player.human = false          # the player's battalion fights under the AI too
		Engine.time_scale = 12.0          # run the day fast
		_begin_battle()
	# a dedicated server has no operator at the keyboard — it just simulates and serves,
	# so it never grabs the mouse and never drives its observer anchor. The battle still steps
	# off on its own (the authoritative deploy timer in _update_battle_flow), runs at real time
	# (clients sync live), and stays up after a result instead of quitting like the AI batch.
	if GameConfig.dedicated:
		if player != null:
			player.human = false          # the whole field fights under the AI; clients drive their own
		print("[NET] dedicated server: simulating the field headless, serving clients")
	else:
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
	for team in [0, 1, 2]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true         # per-instance: r=wear  g=gait phase  b=march amount
		mm.use_colors = true              # per-instance: rgb=facings, a=packed dress (set BEFORE count)
		var team_cap: int = RAID_CAP if team == 2 else MAX_PER_TEAM
		mm.instance_count = team_cap
		if _troop_glb:
			mm.mesh = troop_mesh          # the Blender model, recoloured per region by the dress
			mmi.material_override = _soldier_glb_shader(team)
		else:
			mm.mesh = soldier_mesh
			mmi.material_override = _soldier_shader(team)
		mmi.multimesh = mm
		add_child(mmi)
		team_mm[team] = mm
		var def := Color(team_color(team), 0.0)
		for i in range(team_cap):
			mm.set_instance_transform(i, _zero_xf())
			mm.set_instance_color(i, def)
			mm.set_instance_custom_data(i, Color(1, 1, 1, 1))

	# a placeholder musket (thin box) per soldier — shouldered, levelled to fire
	for team in [0, 1, 2]:
		var gmi := MultiMeshInstance3D.new()
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		gmm.mesh = _musket_mesh()
		var gun_cap: int = RAID_CAP if team == 2 else MAX_PER_TEAM
		gmm.instance_count = gun_cap
		gmi.multimesh = gmm
		gmi.material_override = _musket_shader()
		add_child(gmi)
		musket_mm[team] = gmm
		for i in range(gun_cap):
			gmm.set_instance_transform(i, _zero_xf())

	# (near_mm is retired now that ALL infantry use the procedural soldier through team_mm;
	# these tiny buffers stay only so the struct/draw code keeps working — no Blender models.)
	var troop_lod := soldier_mesh
	var lod_musket := _musket_mesh()
	for team in [0, 1, 2]:
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
	for team in [0, 1, 2]:
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
		var cfac: Color = FACINGS_2[0]
		if team == 0:
			cfac = FACINGS_0[0]
		elif team == 1:
			cfac = FACINGS_1[0]
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

	# The three mounted-leadership tiers (brigadier / general / colonel) ride the SAME detailed
	# box-and-cylinder horse + rider as the cavalry — built in the soldiers' idiom (origin at the
	# horse's feet, facing +Z) so they read as the same stylised men, not bare capsules. Rank shows
	# by SCALE (set in _render_commanders) and coat/trim colour (painted per tier below).
	var mount_horse := _mount_horse_mesh()
	var mount_rider := _mount_rider_mesh()

	# brigade commanders — mounted generals riding behind the centre of their brigade, in a solid
	# gold coat with dark lace so the brigadier stands out.
	var bn := BRIGADES_PER_TEAM * 2 + 64   # headroom: a full historical OOB fields many more brigades than the campaign field
	var hmi := MultiMeshInstance3D.new()
	cmd_horse_mm = MultiMesh.new()
	cmd_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	cmd_horse_mm.mesh = mount_horse
	cmd_horse_mm.use_colors = true                 # the shabraque carries the army's colour
	cmd_horse_mm.instance_count = bn
	hmi.multimesh = cmd_horse_mm
	hmi.material_override = _mount_horse_shader()
	add_child(hmi)
	var rmi := MultiMeshInstance3D.new()
	cmd_rider_mm = MultiMesh.new()
	cmd_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	cmd_rider_mm.mesh = mount_rider
	cmd_rider_mm.use_colors = true                 # coat colour set per instance in _render_commanders
	cmd_rider_mm.instance_count = bn
	rmi.multimesh = cmd_rider_mm
	rmi.material_override = _mount_rider_shader(Color(0.22, 0.17, 0.10))   # dark lace for the brigadier
	add_child(rmi)
	for i in range(bn):
		cmd_horse_mm.set_instance_transform(i, _zero_xf())
		cmd_rider_mm.set_instance_transform(i, _zero_xf())

	# divisional generals — one rank up from the brigadiers: a larger charger, a rider
	# in white-and-silver, riding well behind the whole division's line.
	var dn := CORPS_PER_TEAM * DIVISIONS_PER_CORPS * 2
	var ghmi := MultiMeshInstance3D.new()
	gen_horse_mm = MultiMesh.new()
	gen_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	gen_horse_mm.mesh = mount_horse
	gen_horse_mm.use_colors = true
	gen_horse_mm.instance_count = dn
	ghmi.multimesh = gen_horse_mm
	ghmi.material_override = _mount_horse_shader()
	add_child(ghmi)
	var grmi := MultiMeshInstance3D.new()
	gen_rider_mm = MultiMesh.new()
	gen_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	gen_rider_mm.mesh = mount_rider
	gen_rider_mm.use_colors = true
	gen_rider_mm.instance_count = dn
	grmi.multimesh = gen_rider_mm
	grmi.material_override = _mount_rider_shader(Color(0.85, 0.85, 0.90))   # silver lace for the general
	add_child(grmi)
	for i in range(dn):
		gen_horse_mm.set_instance_transform(i, _zero_xf())
		gen_rider_mm.set_instance_transform(i, _zero_xf())

	# battalion colonels — one mounted field officer riding behind every battalion's
	# colours, coated in his army's facing so blue and red are told apart from afar.
	var coln := BATT_PER_TEAM * 2
	var colhmi := MultiMeshInstance3D.new()
	colonel_horse_mm = MultiMesh.new()
	colonel_horse_mm.transform_format = MultiMesh.TRANSFORM_3D
	colonel_horse_mm.mesh = mount_horse
	colonel_horse_mm.use_colors = true
	colonel_horse_mm.instance_count = coln
	colhmi.multimesh = colonel_horse_mm
	colhmi.material_override = _mount_horse_shader()
	add_child(colhmi)
	var colrmi := MultiMeshInstance3D.new()
	colonel_rider_mm = MultiMesh.new()
	colonel_rider_mm.transform_format = MultiMesh.TRANSFORM_3D
	colonel_rider_mm.use_colors = true
	colonel_rider_mm.mesh = mount_rider
	colonel_rider_mm.instance_count = coln
	colrmi.multimesh = colonel_rider_mm
	colrmi.material_override = _mount_rider_shader(Color(0.86, 0.69, 0.24))   # gold lace, the army's coat
	add_child(colrmi)
	for i in range(coln):
		colonel_horse_mm.set_instance_transform(i, _zero_xf())
		colonel_rider_mm.set_instance_transform(i, _zero_xf())

	# colour-bearers (one per battalion) — built to the company-officer standard (the same
	# mesh/shader as officer_mm), coat painted per-frame by _cg_dress; the cloth carries the colour
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
	nmi.material_override = _nco_shader()   # proper shako + sergeant's sash (not the old flat hat)
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
	snd_reload = _load_first(["MusketReload1.wav", "MusketReload.wav", "MusketReload.mp3"])
	snd_cock = _load_first(["MusketCock.wav", "MusketCock.mp3", "MusketCock1.wav"])
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

	# spyglass eyepiece — an aspect-correct circular field with a thin brass rim and a soft
	# lens vignette, drawn over the scene by a canvas shader when you raise the glass (RMB)
	_scope_rect = ColorRect.new()
	_scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_mat = ShaderMaterial.new()
	_scope_mat.shader = _scope_shader()
	_scope_mat.set_shader_parameter("amt", 0.0)
	_scope_mat.set_shader_parameter("zoom", _scope_zoom)
	_scope_rect.material = _scope_mat
	_scope_rect.visible = false
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
func _dress_packed(coat: int, idx: int, is_player: bool, belt_o: int = -1, pants_o: int = -1, hat_o: int = -1) -> float:
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
	# authored per-battalion overrides (e.g. a rifle regiment's black crossbelts) take precedence
	if belt_o >= 0:
		belt = clampi(belt_o, 0, 2)
	if pants_o >= 0:
		pants = clampi(pants_o, 0, 3)
	if hat_o >= 0:
		hat = clampi(hat_o, 0, 2)
	# coat now has 4 slots (the 4th = rifle/jäger green), so it carries 2 bits: coat + belt*4 + pants*12 + hat*48
	var packed := clampi(coat, 0, 3) + belt * 4 + pants * 12 + hat * 48
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
func _coats_for(team: int) -> Array:
	if _wmap:
		if team == 0:
			return COATS_W0
		elif team == 1:
			return COATS_W1
	if team == 0:
		return COATS_0
	elif team == 1:
		return COATS_1
	return COATS_2

func _soldier_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# --- legs: ROUNDED overalls over dark gaiters (tapered cylinders — round limbs, smooth-shaded,
	# instead of the old blocks; same y-extents so the colour bands are unchanged), with blunt shoes ---
	for sx in [-0.105, 0.105]:
		_add_cyl(st, Vector3(sx, -0.285, 0.0), 0.076, 0.088, 0.46, 6)        # overalls (vy -0.515..-0.055), thigh fuller than knee
		_add_cyl(st, Vector3(sx, -0.68, 0.0), 0.072, 0.092, 0.32, 6)         # gaiter (vy -0.84..-0.52), calf fuller than ankle
		_add_box(st, Vector3(sx, -0.86, 0.05), Vector3(0.165, 0.10, 0.24))   # shoe (kept blunt — feet read better squared off)
	# --- coat: body, short tails behind, a stand collar and a faced plastron down the breast.
	# KEPT as boxes — the crossbelt / plastron / collar colour bands are tuned to their flat faces ---
	_add_box(st, Vector3(0, 0.175, 0.0), Vector3(0.40, 0.49, 0.24))          # coat body (vy -0.07..0.42)
	_add_box(st, Vector3(0, -0.04, -0.085), Vector3(0.36, 0.22, 0.13))       # coat tails (back)
	_add_box(st, Vector3(0, 0.435, 0.0), Vector3(0.345, 0.075, 0.245))       # collar (facing)
	_add_box(st, Vector3(0, 0.20, 0.125), Vector3(0.22, 0.40, 0.035))        # plastron / lapels (front, facing)
	# --- arms: ROUNDED sleeves (tapered cylinders) with faced cuffs and bare hands; centres/extents
	# match the old blocks so the |x|>0.215 swing band and the cuff/hand colour bands still hit ---
	for sx in [-0.265, 0.265]:
		_add_cyl(st, Vector3(sx, 0.18, 0.0), 0.050, 0.063, 0.46, 6)          # sleeve (|x| ~0.21..0.33 -> swings), shoulder fuller than wrist
		_add_cyl(st, Vector3(sx, -0.03, 0.0), 0.062, 0.062, 0.075, 6)        # cuff (facing)
		var hand := SphereMesh.new()
		hand.radius = 0.050; hand.height = 0.10; hand.radial_segments = 6; hand.rings = 3
		st.append_from(hand, 0, Transform3D(Basis(), Vector3(sx, -0.13, -0.01)))   # hand (skin, |x|~0.215..0.315)
	# --- knapsack & rolled blanket slung on the back (boxes) ---
	_add_box(st, Vector3(0, 0.15, -0.185), Vector3(0.30, 0.30, 0.14))        # pack (leather)
	_add_box(st, Vector3(0, 0.31, -0.19), Vector3(0.32, 0.07, 0.12))         # rolled blanket on top
	# --- head (a smoother sphere — more segments so it reads round, not faceted) ---
	var head := SphereMesh.new()
	head.radius = 0.128; head.height = 0.236; head.radial_segments = 12; head.rings = 6
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.55, 0)))       # skin (vy 0.43..0.67)
	# --- shako: tapered cap with a brass band & front peak, surmounted by a plume. The shader
	# MORPHS this block (vy>0.655) per battalion into a round hat or a bicorne, from COLOR.a. ---
	_add_cyl(st, Vector3(0, 0.78, 0.0), 0.125, 0.150, 0.225, 12)             # shako body (vy 0.67..0.89)
	_add_box(st, Vector3(0, 0.672, 0.0), Vector3(0.27, 0.05, 0.27))          # brass band (low)
	_add_box(st, Vector3(0, 0.685, 0.16), Vector3(0.22, 0.035, 0.10))        # peak (front)
	_add_cyl(st, Vector3(0, 1.02, -0.02), 0.035, 0.018, 0.22, 8)             # plume (vy > 0.90)
	return st.commit()

func _add_box(st: SurfaceTool, c: Vector3, s: Vector3, rot: Basis = Basis()) -> void:
	var b := BoxMesh.new()
	b.size = s
	st.append_from(b, 0, Transform3D(rot, c))

# a tapered cylinder (shako body, plume) — height runs along local +Y before `rot`
# tilts it (e.g. the lancer's couched lance), centred on c
func _add_cyl(st: SurfaceTool, c: Vector3, r_bottom: float, r_top: float, h: float, sides: int, rot: Basis = Basis()) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bottom
	cm.top_radius = r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 0
	st.append_from(cm, 0, Transform3D(rot, c))

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
func _officer_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Built to the SAME position bands as `_soldier_mesh()` (legs < -0.05 swing at the hip,
	# arms |x|>0.215 swing at the shoulder) so the shared gait animation drives it unchanged —
	# but dressed as a company officer: faced lapels/collar/cuffs, a crimson waist sash, gold
	# fringed epaulettes, a gorget at the throat, and a gold-piped, plumed bicorne. No knapsack
	# or crossbelts (officers carried neither). Painted by `_officer_shader()`.
	# --- legs: breeches into tall riding boots ---
	for sx in [-0.105, 0.105]:
		_add_box(st, Vector3(sx, -0.27, 0.0), Vector3(0.16, 0.50, 0.19))     # breeches (vy -0.52..-0.02)
		_add_box(st, Vector3(sx, -0.70, 0.02), Vector3(0.175, 0.36, 0.21))   # tall boot (vy -0.88..-0.52)
		_add_box(st, Vector3(sx, -0.88, 0.06), Vector3(0.175, 0.10, 0.24))   # boot foot
	# --- coat: body, tails behind, stand collar, faced lapels down the breast ---
	_add_box(st, Vector3(0, 0.175, 0.0), Vector3(0.40, 0.49, 0.24))          # coat body (vy -0.07..0.42)
	_add_box(st, Vector3(0, -0.05, -0.085), Vector3(0.36, 0.32, 0.14))       # coat tails (back)
	_add_box(st, Vector3(0, 0.435, 0.0), Vector3(0.345, 0.075, 0.245))       # stand collar (facing)
	_add_box(st, Vector3(0, 0.20, 0.125), Vector3(0.245, 0.40, 0.035))       # lapels / plastron (facing)
	# --- crimson waist sash with a tassel at the left hip ---
	_add_box(st, Vector3(0, 0.05, 0.0), Vector3(0.41, 0.10, 0.255))          # sash around the waist
	_add_box(st, Vector3(-0.185, -0.07, 0.07), Vector3(0.07, 0.22, 0.06))    # sash tassel
	# --- arms: sleeves with faced/laced cuffs, bare hands, gold epaulettes ---
	for sx in [-0.265, 0.265]:
		_add_box(st, Vector3(sx, 0.18, 0.0), Vector3(0.115, 0.46, 0.13))     # sleeve (|x|>0.215 -> swings)
		_add_box(st, Vector3(sx, -0.03, 0.0), Vector3(0.125, 0.075, 0.145))  # cuff (facing)
		_add_box(st, Vector3(sx, -0.13, -0.01), Vector3(0.10, 0.10, 0.11))   # hand (skin)
		_add_box(st, Vector3(sx, 0.405, 0.0), Vector3(0.17, 0.06, 0.16))     # gold fringed epaulette
	# --- gorget hung at the throat (gold, front of the collar) ---
	_add_box(st, Vector3(0, 0.425, 0.135), Vector3(0.11, 0.06, 0.03))        # gorget
	# --- head (a touch bigger), matching the soldier's ---
	var head := SphereMesh.new()
	head.radius = 0.128; head.height = 0.236; head.radial_segments = 8; head.rings = 4
	st.append_from(head, 0, Transform3D(Basis(), Vector3(0, 0.55, 0)))       # skin (vy 0.43..0.67)
	# --- bicorne worn fore-and-aft, gold-piped, with a cockade and a tall plume ---
	_add_box(st, Vector3(0, 0.725, 0.0), Vector3(0.155, 0.105, 0.50))        # bicorne body (vy 0.672..0.777)
	_add_box(st, Vector3(0, 0.673, 0.0), Vector3(0.185, 0.028, 0.53))        # gold piping along the brim
	_add_box(st, Vector3(0, 0.74, 0.175), Vector3(0.055, 0.07, 0.03))        # cockade (front)
	_add_cyl(st, Vector3(0, 0.88, 0.06), 0.032, 0.012, 0.32, 8)              # plume (front, vy > 0.79)
	return st.commit()

# The officer's coat colour rides per-instance in COLOR.rgb; the bicorne is black;
# the legs swing as he paces (CUSTOM.b = march, CUSTOM.g = phase).
func _officer_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
varying float vy;
varying float vx;
varying float vz;
void vertex() {
	vy = VERTEX.y; vx = VERTEX.x; vz = VERTEX.z;     // rest-pose bands (stable as he moves)
	float march = INSTANCE_CUSTOM.b;
	float phase = INSTANCE_CUSTOM.g;
	// per-man cadence/stride jitter so officers don't keep clockwork time either
	float gait = 6.0 + (phase - 0.5) * 1.6;
	float t6 = TIME * gait + phase * 6.28318;
	float stride = 0.5 + (phase - 0.5) * 0.14;
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(t6) * march * stride * legside;
		float yy = VERTEX.y - hip;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + hip;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
	// torso rocks its weight foot-to-foot and leans into the march, carrying the head/hat
	if (VERTEX.y > hip && march > 0.001) {
		float yy = VERTEX.y - hip;
		float roll = sin(t6) * march * 0.05;
		float cr = cos(roll); float sr = sin(roll);
		float nx = VERTEX.x * cr - yy * sr;
		yy = VERTEX.x * sr + yy * cr;
		VERTEX.x = nx;
		float lean = march * (0.05 + sin(t6 * 2.0) * 0.018);
		float cl = cos(lean); float sl = sin(lean);
		VERTEX.y = yy * cl - VERTEX.z * sl + hip;
		VERTEX.z = yy * sl + VERTEX.z * cl;
	}
	// arms swing fore-and-aft on the march (an officer shoulders no musket)
	if (abs(VERTEX.x) > 0.215 && march > 0.001) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(t6) * march * 0.30 * -armside;
		float sh2 = 0.45;
		float yy = VERTEX.y - sh2;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + sh2;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
}
void fragment() {
	// A company officer: faced coat, crimson sash, gold epaulettes/gorget/lace, plumed bicorne.
	// Colour by rest-pose position bands (last write wins), the same idiom as the soldier shader.
	vec3 coat = COLOR.rgb;                                  // the battalion coat (team colour)
	vec3 facing = vec3(0.84, 0.80, 0.68);                  // buff facings (collar / lapels / cuffs)
	vec3 gold = vec3(0.86, 0.69, 0.24);
	vec3 crim = vec3(0.55, 0.05, 0.08);
	vec3 col = coat;
	if (vy < -0.06) col = (vy < -0.52) ? vec3(0.06, 0.05, 0.05) : vec3(0.80, 0.76, 0.66);  // boots / buff breeches
	if (vz > 0.11 && abs(vx) < 0.15 && vy > 0.12 && vy < 0.40) col = facing;   // faced lapels down the breast
	if (vy > -0.01 && vy < 0.11) col = crim;                                   // crimson waist sash
	if (vy > 0.40 && vy < 0.475) col = facing;                                 // stand collar (facing)
	if (abs(vx) > 0.21 && vy > -0.07 && vy < 0.02) col = facing;               // faced cuffs
	if (abs(vx) > 0.21 && vy > -0.052 && vy < -0.032) col = gold;              // gold lace ring on the cuff
	if (abs(vx) > 0.18 && vy > 0.375 && vy < 0.44) col = gold;                 // gold fringed epaulettes
	if (abs(vx) > 0.21 && vy > -0.18 && vy < -0.075) col = skin;               // bare hands below the cuff
	if (vy > 0.44 && vy < 0.66 && abs(vx) < 0.17) col = skin;                  // head / neck
	if (vz > 0.12 && abs(vx) < 0.12 && vy > 0.395 && vy < 0.452) col = gold;   // gorget at the throat
	if (vy > 0.66) col = vec3(0.05, 0.05, 0.06);                               // bicorne (black felt)
	if (vy > 0.659 && vy < 0.688) col = gold;                                  // gold piping on the brim
	if (vz > 0.15 && abs(vx) < 0.06 && vy > 0.71 && vy < 0.77) col = gold;     // gold cockade loop (front)
	if (vy > 0.79) col = vec3(0.92, 0.90, 0.86);                               // tall plume
	ALBEDO = col;
	ROUGHNESS = 0.75;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# NCOs / file-closers ride the full detailed `_soldier_mesh()` (shako, knapsack, crossbelts)
# but were being painted by the officer shader — a flat-black hat blob with no shako detail.
# This shader paints the soldier mesh properly (brass-banded shako, peak, plume, faced
# collar/cuffs, white crossbelts) AND adds the sergeant's crimson sash, so a file-closer reads
# as a proper NCO at a glance. Coat colour rides in COLOR.rgb (set per-frame by `_cg_dress`).
func _nco_shader() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 skin = vec3(0.76, 0.58, 0.46);
varying float vy;
varying float vx;
varying float vz;
varying float vnz;
void vertex() {
	vy = VERTEX.y; vx = VERTEX.x; vz = VERTEX.z; vnz = NORMAL.z;
	float phase = INSTANCE_CUSTOM.g;
	float march = INSTANCE_CUSTOM.b;
	float armp = INSTANCE_CUSTOM.a;
	float gait = 6.5 + (phase - 0.5) * 1.7;
	float t6 = TIME * gait + phase * 6.28318;
	float stride = 0.55 + (phase - 0.5) * 0.16;
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float ang = sin(t6) * march * stride * legside;
		float yy = VERTEX.y - hip;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + hip;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
	if (VERTEX.y > hip && march > 0.001) {
		float yy = VERTEX.y - hip;
		float roll = sin(t6) * march * 0.05;
		float cr = cos(roll); float sr = sin(roll);
		float nx = VERTEX.x * cr - yy * sr;
		yy = VERTEX.x * sr + yy * cr;
		VERTEX.x = nx;
		float lean = march * (0.05 + sin(t6 * 2.0) * 0.018);
		float cl = cos(lean); float sl = sin(lean);
		VERTEX.y = yy * cl - VERTEX.z * sl + hip;
		VERTEX.z = yy * sl + VERTEX.z * cl;
	}
	if (abs(VERTEX.x) > 0.215) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float swing = (march > 0.001 && armp < 0.15) ? (sin(t6) * march * 0.35 * -armside) : 0.0;
		float sh2 = 0.45;
		float yy = VERTEX.y - sh2;
		float cs = cos(swing); float sn = sin(swing);
		VERTEX.y = yy * cs - VERTEX.z * sn + sh2;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
}
void fragment() {
	vec3 coat = COLOR.rgb;                                  // the battalion coat (team colour)
	vec3 facing = vec3(0.84, 0.80, 0.68);                  // buff facings
	vec3 col = coat;
	if (vy < -0.05) col = (vy < -0.52) ? vec3(0.10, 0.10, 0.11) : vec3(0.80, 0.78, 0.72);   // gaiters / overalls
	if (vz < -0.11 && vy > -0.02 && vy < 0.36) col = (vy > 0.27) ? vec3(0.55, 0.52, 0.47) : vec3(0.31, 0.21, 0.12);  // knapsack & blanket
	if (vy > 0.40 && vy < 0.47) col = facing;                                  // collar (facing)
	if (vz > 0.10 && abs(vx) < 0.12 && vy > 0.0 && vy < 0.40) col = facing;    // plastron down the breast
	if (abs(vx) > 0.21 && vy > -0.07 && vy < 0.02) col = facing;               // faced cuffs
	if (abs(vx) > 0.21 && vy > -0.18 && vy < -0.075) col = skin;               // bare hands
	if (vy > 0.44 && vy < 0.655 && abs(vx) < 0.17) col = skin;                 // head / neck
	if (vy > 0.655 && vy < 0.695) col = vec3(0.72, 0.55, 0.20);               // brass shako band
	if (vy >= 0.695 && vy < 0.90) col = vec3(0.10, 0.10, 0.12);               // shako body (dark — NCO)
	if (vz > 0.10 && vy > 0.655 && vy < 0.715) col = vec3(0.06, 0.06, 0.07);   // shako peak (front visor)
	if (vy >= 0.90) col = vec3(0.90, 0.88, 0.84);                             // plume
	// white CROSSBELTS — an X over the breast (front faces only)
	if (abs(vx) < 0.215 && vy > -0.05 && vy < 0.42 && vnz > 0.45) {
		float u = vx / 0.21;
		float v = (vy - 0.20) / 0.27;
		if (min(abs(u - v), abs(u + v)) < 0.17) col = vec3(0.90, 0.88, 0.82);
	}
	// the sergeant's crimson sash, knotted at the waist (over the belts)
	if (vy > 0.05 && vy < 0.16 && abs(vx) < 0.205) col = vec3(0.55, 0.05, 0.08);
	ALBEDO = col;
	ROUGHNESS = 0.85;
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
	_add_box(st, Vector3(0, 2.38, 0), Vector3(0.25, 0.23, 0.25))            # head (a touch bigger)
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

# ===================================================== cavalry troopers (the four arms of horse)
# The regiments of horse themselves (cav_rider_mm/cav_horse_mm, one MultiMesh per
# team PER ARM — see _spawn_cavalry()) used to ride bare CapsuleMesh primitives, the
# one corner of the mounted arm never brought up to the soldiers'/commanders' standard.
# Troopers are enlisted men, not officers, so this mesh is the commander's
# `_mount_rider_mesh()` body stripped of the marks of rank (no waist sash, gorget,
# aiguillette or shoulder boards) — collar/lapel/cuffs only — with the headgear and
# arm swapped per `ctype` (0 hussar, 1 light dragoon, 2 heavy dragoon, 3 lancer) so
# each regiment of horse reads as its own arm of service at a glance. The shared horse
# underneath is the commanders' `_mount_horse_mesh()` (scaled per arm — see
# CAV_TYPE_DATA.mount_scale); only the rider differs.
func _cav_rider_mesh(ctype: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-0.27, 0.27]:
		_add_box(st, Vector3(sx, 1.35, 0.08), Vector3(0.16, 0.72, 0.18))    # thigh (buff breeches)
		_add_box(st, Vector3(sx, 1.02, 0.20), Vector3(0.17, 0.40, 0.19))    # riding boot
	_add_box(st, Vector3(0, 1.95, 0), Vector3(0.42, 0.62, 0.26))            # coat body
	_add_box(st, Vector3(0, 1.66, -0.16), Vector3(0.36, 0.30, 0.14))        # coat tails
	_add_box(st, Vector3(0, 2.20, 0.10), Vector3(0.30, 0.10, 0.10))         # collar (trim)
	_add_box(st, Vector3(0, 1.92, 0.14), Vector3(0.20, 0.50, 0.04))         # lapel (trim)
	_add_box(st, Vector3(0, 2.38, 0), Vector3(0.25, 0.23, 0.25))            # head (a touch bigger)
	for sx in [-0.30, 0.30]:
		_add_box(st, Vector3(sx, 1.92, 0.04), Vector3(0.13, 0.5, 0.14))        # sleeve
		_add_box(st, Vector3(sx, 1.70, 0.05), Vector3(0.15, 0.10, 0.16))       # cuff (trim)
		_add_box(st, Vector3(sx * 0.85, 1.66, 0.16), Vector3(0.08, 0.08, 0.09)) # hand (skin)
	match ctype:
		0:   # HUSSAR — fur busby with a cloth bag and a feather plume; sabre and pistol
			_add_cyl(st, Vector3(0, 2.56, -0.02), 0.20, 0.20, 0.28, 8)            # busby (fur)
			_add_box(st, Vector3(0.12, 2.50, -0.16), Vector3(0.10, 0.16, 0.07))   # bag (trim)
			_add_cyl(st, Vector3(0, 2.76, -0.02), 0.025, 0.012, 0.24, 8)          # plume
			_add_box(st, Vector3(0.34, 1.9, 0.25), Vector3(0.05, 0.05, 0.85))     # sabre
			_add_box(st, Vector3(0.34, 1.9, -0.17), Vector3(0.07, 0.07, 0.14))    # hilt (trim)
			_add_box(st, Vector3(-0.32, 1.9, 0.2), Vector3(0.05, 0.10, 0.26))     # holstered pistol
		1:   # LIGHT DRAGOON — crested leather helmet (Tarleton); sabre, pistol, slung carbine
			_add_box(st, Vector3(0, 2.50, 0.0), Vector3(0.21, 0.17, 0.22))        # helmet skull
			_add_box(st, Vector3(0, 2.42, 0.0), Vector3(0.225, 0.05, 0.235))      # turban band (trim)
			_add_box(st, Vector3(0, 2.62, -0.01), Vector3(0.05, 0.09, 0.32))      # crest comb
			_add_box(st, Vector3(0, 2.46, 0.21), Vector3(0.15, 0.03, 0.06))       # peak
			_add_box(st, Vector3(0.34, 1.9, 0.25), Vector3(0.05, 0.05, 0.85))     # sabre
			_add_box(st, Vector3(0.34, 1.9, -0.17), Vector3(0.07, 0.07, 0.14))    # hilt (trim)
			_add_box(st, Vector3(-0.32, 1.9, 0.2), Vector3(0.05, 0.10, 0.26))     # holstered pistol
			_add_box(st, Vector3(0, 1.80, -0.20), Vector3(0.08, 0.34, 0.07))      # slung carbine case
		2:   # HEAVY DRAGOON — bigger crested helmet with a horsehair tail; a heavier sabre
			_add_box(st, Vector3(0, 2.53, 0.0), Vector3(0.23, 0.19, 0.24))        # helmet skull (bigger)
			_add_box(st, Vector3(0, 2.44, 0.0), Vector3(0.245, 0.05, 0.255))      # turban band (trim)
			_add_box(st, Vector3(0, 2.68, -0.01), Vector3(0.06, 0.12, 0.42))      # crest comb (bigger)
			_add_box(st, Vector3(0, 2.32, -0.22), Vector3(0.05, 0.32, 0.07))      # horsehair tail
			_add_box(st, Vector3(0, 2.48, 0.23), Vector3(0.17, 0.035, 0.07))      # peak (bigger)
			_add_box(st, Vector3(0.34, 1.9, 0.30), Vector3(0.07, 0.07, 0.95))     # heavier sabre
			_add_box(st, Vector3(0.34, 1.9, -0.20), Vector3(0.08, 0.08, 0.16))    # hilt (trim)
			_add_box(st, Vector3(-0.32, 1.9, 0.2), Vector3(0.05, 0.10, 0.26))     # holstered pistol
		3:   # LANCER — square-topped czapka; the lance (couched, diagonal) plus a sabre
			_add_box(st, Vector3(0, 2.50, 0.0), Vector3(0.19, 0.16, 0.20))        # czapka body
			_add_box(st, Vector3(0, 2.64, 0.0), Vector3(0.27, 0.07, 0.28))        # flared square top (trim)
			_add_box(st, Vector3(0, 2.46, 0.20), Vector3(0.14, 0.03, 0.06))       # peak
			_add_cyl(st, Vector3(0, 2.72, 0.0), 0.03, 0.03, 0.10, 8)              # pompom (trim)
			_add_box(st, Vector3(0.34, 1.9, 0.25), Vector3(0.05, 0.05, 0.85))     # sabre (secondary)
			_add_box(st, Vector3(0.34, 1.9, -0.17), Vector3(0.07, 0.07, 0.14))    # hilt (trim)
			var lance_rot := Basis(Vector3.RIGHT, 1.3)        # tilts +Y forward-and-up across the horse's neck
			_add_cyl(st, Vector3(0.30, 1.95, 0.55), 0.035, 0.018, 3.2, 6, lance_rot)  # the lance itself
	return st.commit()

# Shared by all four arms (`ctype` selects the headgear/weapon palette baked into the
# mesh above); `trim` is the lace colour for that arm (gold/white metal/brass/gold —
# see _spawn_cavalry()). The coat itself reads COLOR.rgb, set per-instance to the
# army's colour exactly like the mounted commanders.
func _cav_rider_shader(trim: Color, ctype: int) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 trim;
uniform int ctype;
varying float vx;
varying float vy;
varying float vz;
void vertex() { vx = VERTEX.x; vy = VERTEX.y; vz = VERTEX.z; }
void fragment() {
	vec3 buff = vec3(0.82, 0.78, 0.65);
	vec3 boot = vec3(0.07, 0.06, 0.07);
	vec3 skin = vec3(0.72, 0.56, 0.43);
	vec3 dark = vec3(0.07, 0.07, 0.08);
	vec3 wood = vec3(0.35, 0.23, 0.12);
	vec3 col = COLOR.rgb;                                                // coat: the army's colour
	if (vy < 1.92) col = buff;                                           // buff breeches
	if (vy < 1.22) col = boot;                                           // riding boots
	if (vy > 2.15 && vy < 2.25) col = trim;                              // collar
	if (vz > 0.10 && abs(vx) < 0.12 && vy > 1.65 && vy < 2.15) col = trim;  // lapel
	if (abs(vx) > 0.22 && vy > 1.63 && vy < 1.78) col = trim;            // cuffs
	if (abs(vx) > 0.22 && vy > 1.60 && vy < 1.71) col = skin;            // bare hands
	if (vy > 2.27 && vy < 2.49) col = skin;                              // head
	// the arm-specific headgear and weapon, all above the head or out at the saddle:
	if (ctype == 0) {                                                    // hussar: fur busby
		if (vy > 2.42 && vy < 2.70) col = dark;                          // fur body
		if (vy > 2.36 && vy < 2.58 && vz < -0.08) col = trim;            // bag
		if (vy >= 2.70) col = vec3(0.90, 0.88, 0.84);                    // plume
	} else if (ctype == 1) {                                             // light dragoon: crested helmet
		if (vy > 2.37 && vy < 2.67) col = dark;                          // helmet skull / crest
		if (vy > 2.37 && vy < 2.47) col = trim;                          // turban band
		if (vy > 1.46 && vy < 2.14 && vz < -0.12) col = wood;            // slung carbine case
	} else if (ctype == 2) {                                             // heavy dragoon: bigger crested helmet
		if (vy > 2.34 && vy < 2.80) col = vec3(0.55, 0.56, 0.60);        // steel helmet / crest comb
		if (vy > 2.39 && vy < 2.49) col = trim;                         // turban band
		if (vy > 2.00 && vy < 2.64 && vz < -0.14) col = dark;           // horsehair tail
	} else if (ctype == 3) {                                             // lancer: czapka + the lance
		if (vy > 2.34 && vy < 2.71 && vz < 0.75) col = dark;             // czapka body
		if (vy > 2.57 && vy < 2.71 && vz < 0.75) col = trim;             // flared square top
		if (vy > 2.62 && vz < 0.75) col = trim;                          // pompom
		if (vz > 0.75) col = (vz > 1.65) ? trim : wood;                  // the lance: haft, pennon near the tip
	}
	if (abs(vx) > 0.28 && vy > 1.83 && vy < 1.97 && vz < 0.75) col = trim;  // sabre / pistol / hilt
	ALBEDO = col;
	ROUGHNESS = 0.75;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("trim", Vector3(trim.r, trim.g, trim.b))
	m.set_shader_parameter("ctype", ctype)
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
uniform vec3 coats[4];
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
	v_coat = p % 4; p /= 4;
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
	for c in _coats_for(team):
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
uniform vec3 coats[4];
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
	v_coat = p % 4; p /= 4;
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
	for c in _coats_for(team):
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
uniform vec3 coats[4];
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
	v_coat = p % 4; p /= 4;
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
	float armp = INSTANCE_CUSTOM.a;      // 0 at rest .. ~0.6 reloading .. 1 presenting .. >1 = firing recoil
	float recoil_kick = max(0.0, armp - 1.0);   // the overflow past 1 is the sharp kick of his own shot
	armp = min(armp, 1.0);                       // the pose logic runs on 0..1
	// IMPERFECTION: no two men keep identical time. Each man's stride CADENCE and LENGTH are
	// jittered off his phase seed (so legs no longer all swing at one clockwork frequency) —
	// the ranks ripple and break lockstep like real marching men instead of a metronome.
	float gait = 6.5 + (phase - 0.5) * 1.7;                  // per-man pace, rad/s
	float t6 = TIME * gait + phase * 6.28318;
	float stride = 0.55 + (phase - 0.5) * 0.16;             // per-man stride length
	// LEGS swing fore-and-aft as he marches
	float hip = -0.05;
	if (VERTEX.y < hip && march > 0.001) {
		float legside = (VERTEX.x < 0.0) ? 1.0 : -1.0;          // left & right out of phase
		// KNEE: the shin (below the knee) folds back as the leg lifts through its forward swing,
		// so each pace reads as a real bending leg, not a stiff plank pivoting only at the hip
		float knee = -0.50;
		if (VERTEX.y < knee) {
			float kang = max(0.0, sin(t6) * legside) * march * 0.7;   // fold most at the top of the lift
			float ky = VERTEX.y - knee;
			float kc = cos(kang); float ks = sin(kang);
			VERTEX.y = ky * kc - VERTEX.z * ks + knee;
			VERTEX.z = ky * ks + VERTEX.z * kc;
		}
		float ang = sin(t6) * march * stride * legside;          // HIP: swing the whole leg fore-and-aft
		float yy = VERTEX.y - hip;
		float cs = cos(ang); float sn = sin(ang);
		VERTEX.y = yy * cs - VERTEX.z * sn + hip;
		VERTEX.z = yy * sn + VERTEX.z * cs;
	}
	// TORSO: a marching man rocks his weight foot-to-foot and leans into the step. Everything
	// above the hip (chest, pack, head, shako AND the arms) rolls side-to-side with the stride
	// and pitches forward — so the upper body has life, not a rigid plank over swinging legs.
	if (VERTEX.y > hip && march > 0.001) {
		float yy = VERTEX.y - hip;
		float roll = sin(t6) * march * 0.05;                    // weight-shift roll (about the forward axis)
		float cr = cos(roll); float sr = sin(roll);
		float nx = VERTEX.x * cr - yy * sr;
		yy = VERTEX.x * sr + yy * cr;
		VERTEX.x = nx;
		float lean = march * (0.05 + sin(t6 * 2.0) * 0.018) - recoil_kick * 0.22;   // forward lean; the shot rocks the upper body BACK
		float cl = cos(lean); float sl = sin(lean);
		VERTEX.y = yy * cl - VERTEX.z * sl + hip;
		VERTEX.z = yy * sl + VERTEX.z * cl;
	}
	// ARMS: raise to present the musket, work the ramrod while reloading, swing on the march
	if (abs(VERTEX.x) > 0.215) {
		float armside = (VERTEX.x < 0.0) ? 1.0 : -1.0;
		float raise = -clamp(armp, 0.0, 1.0) * 1.35;                                  // FORWARD, holding it up
		// reloading: the working arm drives the ramrod down the barrel with a sharp stroke,
		// the other steadies the piece
		float ram = sin(TIME * 8.0 + phase * 6.28318);
		ram = ram * abs(ram);                                                         // sharper push than draw
		// ELBOW: the forearm (below the elbow) articulates on its own — it pumps the ramrod down the
		// barrel when loading, lifts toward the lock when presenting, and keeps a natural bend on the
		// march, so the arm is no longer one rigid rod from shoulder to hand
		float elbow = 0.13;
		if (VERTEX.y < elbow) {
			float load_e = (armp > 0.4 && armp < 0.85) ? (ram * 0.55 * (armside < 0.0 ? 1.0 : 0.25)) : 0.0;
			float present_e = clamp(armp, 0.0, 1.0) * 0.35;
			float march_e = (march > 0.001 && armp < 0.15) ? 0.16 : 0.0;
			float eang = load_e + present_e + march_e;
			float ey = VERTEX.y - elbow;
			float ec = cos(eang); float es = sin(eang);
			VERTEX.y = ey * ec - VERTEX.z * es + elbow;
			VERTEX.z = ey * es + VERTEX.z * ec;
		}
		float ramrod = (armp > 0.4 && armp < 0.85) ? (ram * 0.6 * (armside < 0.0 ? 1.0 : 0.3)) : 0.0;
		float swing = (march > 0.001 && armp < 0.15) ? (sin(t6) * march * (0.35 + (phase - 0.5) * 0.12) * -armside) : 0.0;
		float ang = raise + ramrod + swing + recoil_kick * 0.5;   // the musket kicks back into the shoulder on firing
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
	for c in _coats_for(team):
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
	var x1 := COAST_X + COAST_AMPLITUDE + 60.0   # reach the farthest-out headland, not just the mean shore
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
	if authoritative:
		_time_of_day = fposmod(_time_of_day + delta * DAY_RATE, 24.0)   # clients take the clock from the host
	var t := _time_of_day
	var u := t / 24.0
	var h := sin((t - 6.0) / 12.0 * PI)          # sun height: -1..1 (0 at 6 & 18)
	var day := clampf(h, 0.0, 1.0)
	_night = clampf(-h * 2.2 + 0.25, 0.0, 1.0)   # deep dark after dusk -> muzzle flashes blaze
	# weather is DISABLED for now — the field stays clear (M is the map, not the weather)
	_weather = "clear"
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
	var i := WEATHERS.find(_weather)
	_weather = WEATHERS[(i + 1) % WEATHERS.size()]
	_weather_timer = randf_range(90.0, 220.0)        # hold the chosen weather a while
	_send_player_despatch("[color=#bcd] Weather: %s.[/color]" % _weather, {})

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
	# The strategic map is NORTH-UP, EAST-RIGHT (standard) so it matches the compass exactly: +Z
	# (north) flies to the top, +X (east, toward the coast) to the right. ONLY the Z axis is flipped
	# (north up); flipping X as well — as a previous version did — put east on the wrong side and
	# rotated the whole map 180°, so a heading of SE on the compass read as NW here.
	var P := func(w: Vector3) -> Vector2:
		var nx := (w.x - wmin.x) / wsize.x
		var nz := 1.0 - (w.z - wmin.y) / wsize.y
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
			lbl.text = String(s["name"]) + (_town_econ_suffix(String(s["name"])) if kind == "town" else "")
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
		# FOG OF WAR on the map: your own forces always; an enemy shows where SEEN (live), or as a
		# fading GHOST at its last-known place once lost from sight, then is forgotten entirely.
		var is_enemy := player != null and b.team != player.team
		var ghost := false
		var dpos := b.pos
		if is_enemy and not reveal and not PLAYER_SEES_ALL:
			if b._spotted:
				pass                                  # in sight — live position
			elif _t - b._intel_t < GHOST_FADE:
				ghost = true
				dpos = b._intel_pos
			else:
				continue                              # never seen, or long lost — not on the map
		var sp: Vector2 = P.call(dpos)
		var dot := _map_dot(di); di += 1
		var base: Color = team_color(b.team).lightened(0.45 if b.team == 0 else (0.32 if b.team == 1 else 0.4))
		if b.broken or b.state == "routing":
			base = base.darkened(0.45)
		var is_me: bool = b == player
		dot.color = Color(1.0, 0.88, 0.3) if is_me else base
		if ghost:
			dot.color.a = clampf(0.65 * (1.0 - (_t - b._intel_t) / GHOST_FADE), 0.12, 0.65)   # fades as it ages
		var sz := Vector2(11, 5) if is_me else (Vector2(8, 4) if not b.spent else Vector2(5, 3))
		dot.size = sz
		dot.pivot_offset = sz * 0.5
		dot.position = sp - sz * 0.5
		dot.rotation = atan2(sin(b.facing), -cos(b.facing))   # north-up map: the arrow points the unit's heading
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
	# supply convoys — civilian wagon trains (yours always; the enemy's only under dev reveal).
	# A tan diamond; GOLD if it's the escort you took (Y); RED if threatened and unguarded.
	var ci := 0
	for cv in supply_convoys:
		if not reveal and player != null and int(cv["team"]) != player.team:
			continue
		var cp: Vector2 = P.call(cv["pos"] as Vector3)
		var cm: ColorRect = _map_convoy(ci); ci += 1
		var ccol := Color(0.80, 0.64, 0.38)
		if int(cv["id"]) == _escort_id:
			ccol = Color(1.0, 0.86, 0.30)
		elif _convoy_threat(cv) and not _convoy_escorted(cv):
			ccol = Color(1.0, 0.42, 0.34)
		cm.color = ccol
		var csz := Vector2(8, 8)
		cm.size = csz
		cm.pivot_offset = csz * 0.5
		cm.rotation = PI * 0.25
		cm.position = cp - csz * 0.5
		cm.visible = true
	for j2 in range(ci, _map_convoys.size()):
		(_map_convoys[j2] as ColorRect).visible = false
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
		var stores := ""
		if player != null and player.team >= 0 and player.team <= 1 and _econ_ready:
			var ms: Array = _mat_pool[player.team]
			var parts: Array = []
			for mi in range(N_MATS):
				parts.append("%s %d" % [MAT_NAMES[mi], int(ms[mi])])
			stores = "\n[color=#9fb0c8]Stores:[/color] [color=#cdd6e6]%s[/color]   [color=#9fb0c8]Units raised:[/color] [color=#ffe9a8]%d[/color]" % ["  ·  ".join(parts), _reinforced[player.team]]
		map_legend.text = "[color=#9fb0c8]Your army: [/color][color=#bcd6ff]%d steady[/color] · [color=#ff9a8a]%d broken[/color]   [color=#9fb0c8]Towns held: [/color][color=#ffe9a8]%d / %d[/color]   [color=#9fb0c8]·  %02d:%02d[/color]   [color=#ffe9a8](M to close)[/color]%s%s" % [fr_live, fr_broke, towns_mine, field_towns.size(), clk, mins, rev, stores]

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

var _map_convoys: Array = []        # pooled supply-convoy markers on the map
func _map_convoy(i: int) -> ColorRect:
	while i >= _map_convoys.size():
		var d := ColorRect.new()
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_panel.add_child(d)
		_map_convoys.append(d)
	return _map_convoys[i]

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
	var bvol := Button.new()
	bvol.text = "Volley Drill ▸"
	bvol.pressed.connect(_begin_drill)
	bar.add_child(bvol)
	var bman := Button.new()
	bman.text = "Manoeuvre Drill ▸"
	bman.pressed.connect(_begin_maneuver_drill)
	bar.add_child(bman)
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
	if _drill_on:
		_end_drill()                       # C dismisses the drill back to ordinary command
		return
	if _mdrill_on:
		_end_maneuver_drill()
		return
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
	var nlead := 0
	for m in b.roster:
		if m["alive"] and String(m["rank"]) in LEADER_RANKS:
			nlead += 1
	t += "[color=#cdd6e6]Leadership[/color]  %s  [color=#9fb0c8]%d officers & NCOs steady the line[/color]\n" % [_bar(b._leadership * 100.0, 14), nlead]
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
		var fig_base := b.figs.size() - n     # the new recruits sit at the tail of b.figs
		for i in range(n):
			var coy := b.roster.size() % b.companies
			var man := { "name": _rand_name(), "rank": "Pte.", "coy": coy,
				"xp": 0.0, "kills": 0, "alive": true, "focus": "" }
			for key in SKILL_KEYS:
				man[key] = clampf(_sk(b, key) - 14.0 + randf_range(-8.0, 8.0), 6.0, 90.0)
			b.roster.append(man)
			if fig_base + i < b.figs.size():
				b.figs[fig_base + i]["man"] = man   # link the green hand to his man on the field
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
		forest_clusters.append({ "pos": d[0] as Vector3, "radius": float(d[1]) })
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
			"cap_t": 0.0, "cap_team": -1, "disc": null })

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
		var ok := x < _coast_x(z) - 280.0   # the coast bows around COAST_X — stay inland of it
		if ok:
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
		var ok := x < _coast_x(z) - 300.0   # the coast bows around COAST_X — stay inland of it
		if ok:
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
	var bushes: Array = []
	# --- field-edge hedgerows (straight) ---
	for hl in hedge_lines:
		var a: Vector3 = hl[0]; var b: Vector3 = hl[1]
		var ln := a.distance_to(b)
		var nb := int(ln / 7.0)
		for k in range(nb):
			var pt := a.lerp(b, float(k) / float(maxi(1, nb)))
			if not river_pts.is_empty() and _in_river(pt):
				continue
			bushes.append(pt)
	# --- roadside hedgerows: low bushes lining BOTH sides of the winding lane. Sampled along
	# the shared road curve and offset by the local-tangent normal, so they hug the bends of
	# the worn track you actually see rather than a straight chord beside it. ---
	for s in road_segs:
		var ra: Vector3 = s[0]; var rb: Vector3 = s[1]
		var rln := ra.distance_to(rb)
		if rln < 1.0:
			continue
		var curve := _road_curve(ra, rb, maxi(8, int(rln / 9.0)))
		for c in range(curve.size()):
			var ctr: Vector3 = curve[c]
			var tan: Vector3 = (curve[1] - curve[0]) if c == 0 else ((curve[c] - curve[c - 1]) if c == curve.size() - 1 else (curve[c + 1] - curve[c - 1]))
			tan.y = 0.0
			if tan.length() < 1.0e-5:
				continue
			tan = tan.normalized()
			var perp := Vector3(tan.z, 0, -tan.x)
			for sidesign in [-1.0, 1.0]:
				var pt: Vector3 = ctr + perp * (9.0 * sidesign)
				if not river_pts.is_empty() and _in_river(pt):
					continue
				bushes.append(pt)
	var hedge := _make_scenery_mm(_box(1, 1, 1), Color(0.16, 0.28, 0.15), bushes.size())
	for i in range(bushes.size()):
		var pt: Vector3 = bushes[i]
		var sx := rng.randf_range(1.6, 2.6); var sy := rng.randf_range(1.6, 2.4)
		hedge.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(sx, sy, sx)), Vector3(pt.x, _gh(pt.x, pt.z) + sy * 0.5, pt.z)))

# The province's woods: big randomly-placed forest "stands" scattered across the whole
# map (not just the battle clutter near the firing lines — see _build_forests for that),
# each a dense disc of trees avoiding the towns, garrison sites, roads and the river.
# Mixes broadleaf (trunk + round canopy, same palette as the battle-scale woods) with a
# pine/conifer variant (a simple cone), the pine fraction rising toward the coast — a nod
# to the real Atlantic seaboard's run from pine barrens at the shore to hardwood inland.
func _build_field_forests() -> void:
	if _inflated or hosted:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = (GameConfig.match_seed if GameConfig.match_seed != 0 else 1) ^ 0x6a09e667
	var stand_defs: Array = []   # [center, radius]
	var wanted := 26
	var tries := 0
	while stand_defs.size() < wanted and tries < wanted * 20:
		tries += 1
		var x := rng.randf_range(-8600.0, COAST_X - 280.0)
		var z := rng.randf_range(-8400.0, 8400.0)
		var p := Vector3(x, 0, z)
		var r := rng.randf_range(350.0, 950.0)
		var ok := x < _coast_x(z) - r - 100.0   # keep the whole disc clear of the bowed coast
		if ok:
			for t in field_towns:
				if p.distance_to(t["pos"]) < r * 0.4 + 700.0 + float(t["size"]) * 150.0:
					ok = false; break
		if ok:
			for s in field_sites:
				if p.distance_to(s["pos"]) < r * 0.4 + 420.0:
					ok = false; break
		if not ok:
			continue
		stand_defs.append([p, r])
	# size every shared MultiMesh to the worst case (every stand at full budget); unused
	# slots stay invisible via _zero_xf, same trick _make_scenery_mm already relies on
	var stand_counts: Array = []
	var total := 0
	for d in stand_defs:
		var r: float = d[1]
		var n := int(r * r / 1800.0)
		stand_counts.append(n)
		total += n
	var trunk_mm := _make_scenery_mm(_cylinder(0.32, 4.0), Color(0.26, 0.18, 0.10), total)
	var leaf_mesh := SphereMesh.new()
	leaf_mesh.radius = 2.6
	leaf_mesh.height = 5.6
	leaf_mesh.radial_segments = 12
	leaf_mesh.rings = 7
	var broadleaf_mm := _make_scenery_mm(leaf_mesh, Color(0.18, 0.30, 0.15), total)
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 2.0
	cone_mesh.height = 7.0
	cone_mesh.radial_segments = 8
	var pine_mm := _make_scenery_mm(cone_mesh, Color(0.10, 0.22, 0.14), total)
	var ti := 0
	for i in range(stand_defs.size()):
		var c: Vector3 = stand_defs[i][0]
		var r: float = stand_defs[i][1]
		var n: int = stand_counts[i]
		var coast_t := clampf((c.x + 8600.0) / (COAST_X - 280.0 + 8600.0), 0.0, 1.0)
		var pine_chance := lerpf(0.12, 0.42, coast_t)
		for j in range(n):
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf()) * r
			var p := c + Vector3(cos(a) * rr, 0, sin(a) * rr)
			if p.x > _coast_x(p.z) - 60.0 or _on_road(p) or (not river_pts.is_empty() and _in_river(p)):
				continue
			var s := rng.randf_range(0.8, 1.7)
			var yaw := rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
			var tgh := _gh(p.x, p.z)
			trunk_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 2.0 * s + tgh, p.z)))
			if rng.randf() < pine_chance:
				pine_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 3.5 * s + tgh, p.z)))
			else:
				broadleaf_mm.set_instance_transform(ti, Transform3D(b, Vector3(p.x, 5.6 * s + tgh, p.z)))
			ti += 1

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

# ---- ONE shared road centreline, so the worn track, its hedgerows, its bridges and the
# march-speed corridor (_on_road) all follow the SAME rustic, winding curve (rather than the
# ribbon meandering off on its own as it used to). The wander is a perpendicular offset from
# the straight a->b line, anchored at 0 at both ends so segments meet the towns cleanly.
const ROAD_MEANDER_AMP := 19.0     # how far the lane wanders off the straight line, at most

func _road_seed(a: Vector3, b: Vector3) -> float:
	return a.x * 0.011 + a.z * 0.017 + b.x * 0.013 + b.z * 0.007   # deterministic per segment

# Perpendicular offset of the lane from the straight a->b centreline at parameter t (0..1).
func _road_meander(t: float, ln: float, seed: float) -> float:
	var env := sin(t * PI)                                      # 0 at both ends, 1 in the middle
	var bends := maxf(1.0, ln / 300.0)                          # roughly one bend per ~300 units
	var w := sin(t * TAU * bends + seed) * 0.66 + sin(t * TAU * bends * 0.45 + seed * 1.7) * 0.34
	return env * w * ROAD_MEANDER_AMP

# The lane's winding centreline a->b as a polyline of `steps`+1 points (y left flat at 0).
func _road_curve(a: Vector3, b: Vector3, steps: int) -> Array:
	var ab := b - a; ab.y = 0.0
	var ln := ab.length()
	if ln < 0.001:
		return [a, b]
	var dir := ab / ln
	var perp := Vector3(dir.z, 0.0, -dir.x)
	var seed := _road_seed(a, b)
	var pts: Array = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var c := a.lerp(b, t) + perp * _road_meander(t, ln, seed)
		pts.append(Vector3(c.x, 0.0, c.z))
	return pts

# Lay the road network into the WORLD as worn dirt tracks: the town highways (field_roads),
# plus a short access track from every fort and depot to its nearest town. Built as one flat
# ribbon mesh that winds along the shared road curve, so it reads as a rustic country lane.
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
		# The track WINDS along the shared road curve (the same one its hedgerows, bridges and
		# the march-speed corridor follow), drapes over the rolling ground, and banks its edges
		# to the local tangent so it reads as a real meandering country lane. Stepped finely
		# enough to follow both the bends and the terrain.
		var steps: int = maxi(8, int(ln / 28.0))
		var pts := _road_curve(a, b, steps)
		var pl := Vector3.ZERO
		var pr := Vector3.ZERO
		for i in range(pts.size()):
			var ctr: Vector3 = pts[i]
			var tan: Vector3 = (pts[1] - pts[0]) if i == 0 else ((pts[i] - pts[i - 1]) if i == pts.size() - 1 else (pts[i + 1] - pts[i - 1]))
			tan.y = 0.0
			if tan.length() < 1.0e-5:
				tan = Vector3(0, 0, 1)
			tan = tan.normalized()
			var perp := Vector3(tan.z, 0.0, -tan.x)
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
		Vector3(700, 0, 6400), Vector3(_coast_x(7600.0) - 60.0, 0, 7600),
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
	# drop a bridge wherever the WINDING lane crosses the river — walk the curved centreline and
	# test each little sub-segment, so the bridge lands under the road you actually see
	for rseg in road_segs:
		var ln: float = (rseg[1] - rseg[0]).length()
		var curve := _road_curve(rseg[0], rseg[1], maxi(8, int(ln / 28.0)))
		for c in range(curve.size() - 1):
			var ca: Vector3 = curve[c]
			var cb: Vector3 = curve[c + 1]
			for i in range(river_pts.size() - 1):
				var hit = _seg_xz(ca, cb, river_pts[i], river_pts[i + 1])
				if hit != null:
					var along: Vector3 = (cb - ca)
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

# The coastline isn't a straight line at COAST_X — it bows into a couple of broad bays and
# headlands along its length. Two low-frequency sine terms keep it a gentle, natural curve
# (never wilder than +/-COAST_AMPLITUDE). MUST mirror the ocean shader's copy (_build_ocean)
# so the surf line tracks the actual shore the ground/ocean meshes draw.
func _coast_x(z: float) -> float:
	return COAST_X + sin(z * 0.00045 + 0.6) * 260.0 + sin(z * 0.00112 - 1.3) * 140.0

# ---- TERRAIN HEIGHT: one shared rolling-ground field. Everything in the world drapes onto
# this (the ground mesh, the men, the scenery), and the GLSL twin in the ground shader MUST
# match. Faded to sea level near the shore so the beach and coast stay flat; beyond the local
# coastline it slopes gently down into a shallow seabed so bays sink under the ocean cleanly. ----
func _gh(x: float, z: float) -> float:
	if _wmap:
		return _gh_waterloo(x, z)
	var cx := _coast_x(z)
	var c := clampf((cx - x) / 350.0, 0.0, 1.0)   # flatten only the immediate shore
	if c <= 0.0:
		return lerpf(0.0, -6.0, clampf((x - cx) / 600.0, 0.0, 1.0))   # offshore seabed
	# hills on a BATTLEFIELD scale (wavelengths ~1–2.5 km) so the ground visibly rolls over
	# the ground a player can see — not a 14 km swell that reads as dead flat up close
	var h := sin(x * 0.0038 + 1.7) * 13.0 + sin(z * 0.0045 - 0.6) * 11.0
	h += sin((x * 0.7 + z) * 0.0026) * 8.0 + sin((x - z * 0.6) * 0.0064) * 5.0
	return h * c

func _gh3(p: Vector3) -> Vector3:
	return Vector3(p.x, _gh(p.x, p.z), p.z)

# WATERLOO terrain: the two ridges run east-west (along x), so height is mostly a function of z.
# The Anglo-Allied ridge of Mont-Saint-Jean (the higher one) lies at z≈+560 with a REVERSE SLOPE
# falling away behind it (where Wellington sheltered his line); the French ridge by La Belle Alliance
# is lower, at z≈-560; a shallow valley lies between. The ground rises into wooded country to the
# east, where the Prussians debouch. (smoothstep bumps — cheap, no exp, called per-man per-frame.)
func _gh_waterloo(x: float, z: float) -> float:
	var allied := 15.0 * _bump(z, 560.0, 360.0)                  # the Mont-Saint-Jean ridge
	var french := 9.0 * _bump(z, -560.0, 400.0)                  # the La Belle Alliance ridge
	var reverse := -6.0 * clampf((z - 700.0) / 700.0, 0.0, 1.0)  # the reverse slope behind the Allied crest
	var roll := sin(x * 0.0016 + 0.4) * 2.4 + sin(x * 0.0044 - 1.0) * 1.1 + sin(z * 0.0030) * 1.4
	var east := 5.0 * clampf((x - 1600.0) / 1500.0, 0.0, 1.0)    # rising wooded ground to the east
	return allied + french + reverse + roll + east

# a smooth 0..1 bump centred on `center`, falling to 0 at ±halfwidth (smoothstep, cheap)
func _bump(v: float, center: float, halfwidth: float) -> float:
	var t := clampf(absf(v - center) / halfwidth, 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)

# The Waterloo battlefield's landmarks: the Brussels road up the centre, and the farms & villages
# that anchored the day — La Haye Sainte and Hougoumont (the fought-over strongpoints), Papelotte on
# the Allied left, Mont-Saint-Jean behind the centre, La Belle Alliance at the French centre, and
# Plancenoit on the French right where the Prussians came in.
func _build_waterloo() -> void:
	var stone := StandardMaterial3D.new(); stone.albedo_color = Color(0.71, 0.67, 0.58); stone.roughness = 1.0
	var brick := StandardMaterial3D.new(); brick.albedo_color = Color(0.56, 0.35, 0.27); brick.roughness = 1.0
	var tile := StandardMaterial3D.new(); tile.albedo_color = Color(0.45, 0.24, 0.18); tile.roughness = 1.0
	var slate := StandardMaterial3D.new(); slate.albedo_color = Color(0.33, 0.35, 0.40); slate.roughness = 1.0
	var wallm := StandardMaterial3D.new(); wallm.albedo_color = Color(0.66, 0.62, 0.54); wallm.roughness = 1.0
	# the Brussels–Charleroi road: a pale ribbon running N–S through the centre, past La Haye Sainte
	var roadm := StandardMaterial3D.new(); roadm.albedo_color = Color(0.58, 0.54, 0.46); roadm.roughness = 1.0
	var zz := -1000.0
	while zz < 1050.0:
		var r := MeshInstance3D.new()
		r.mesh = _box(9.0, 0.14, 44.0)
		r.position = Vector3(0, _gh(0, zz) + 0.07, zz)
		r.material_override = roadm
		add_child(r)
		zz += 42.0
	_wfarm(Vector3(-20, 0, 300), 60, 46, stone, tile, wallm)     # La Haye Sainte — on the road, before the centre
	_wfarm(Vector3(-680, 0, 200), 86, 74, stone, slate, wallm)   # Hougoumont — the fortified château on the right
	_wfarm(Vector3(880, 0, 320), 54, 44, brick, tile, wallm)     # Papelotte — the farm on the left
	_wfarm(Vector3(0, 0, 820), 64, 50, stone, slate, wallm)      # Mont-Saint-Jean — behind the centre
	_wbuilding(Vector3(36, 0, -560), 24, 9, 14, stone, tile)     # La Belle Alliance — the inn at the French centre
	_wvillage(Vector3(1120, 0, -760), stone, tile)               # Plancenoit — the village on the French right

# a single building: a box with a pitched roof, planted on the slope
func _wbuilding(c: Vector3, w: float, h: float, d: float, wallmat: Material, roofmat: Material) -> void:
	var gy := _gh(c.x, c.z)
	var body := MeshInstance3D.new()
	body.mesh = _box(w, h, d)
	body.position = Vector3(c.x, gy + h * 0.5, c.z)
	body.material_override = wallmat
	add_child(body)
	var roof := MeshInstance3D.new()
	roof.mesh = _prism(w + 1.0, h * 0.6, d + 1.0)
	roof.position = Vector3(c.x, gy + h + h * 0.3, c.z)
	roof.material_override = roofmat
	add_child(roof)

# a walled farm/château complex: a perimeter wall round a yard, with buildings inside
func _wfarm(c: Vector3, w: float, d: float, wallmat: Material, roofmat: Material, fencemat: Material) -> void:
	var gy := _gh(c.x, c.z)
	var wh := 3.2
	var th := 1.2
	for zf in [d * 0.5, -d * 0.5]:                              # north & south walls
		var seg := MeshInstance3D.new()
		seg.mesh = _box(w, wh, th)
		seg.position = Vector3(c.x, gy + wh * 0.5, c.z + zf)
		seg.material_override = fencemat
		add_child(seg)
	for xf in [w * 0.5, -w * 0.5]:                              # east & west walls
		var seg := MeshInstance3D.new()
		seg.mesh = _box(th, wh, d)
		seg.position = Vector3(c.x + xf, gy + wh * 0.5, c.z)
		seg.material_override = fencemat
		add_child(seg)
	_wbuilding(Vector3(c.x - w * 0.26, 0, c.z - d * 0.30), w * 0.40, 9.0, d * 0.30, wallmat, roofmat)   # the house
	_wbuilding(Vector3(c.x + w * 0.28, 0, c.z + d * 0.26), w * 0.36, 7.5, d * 0.30, wallmat, roofmat)   # a barn
	_wbuilding(Vector3(c.x + w * 0.05, 0, c.z + d * 0.30), w * 0.28, 6.5, d * 0.22, wallmat, roofmat)   # an outbuilding

# a village: a church and a scatter of cottages
func _wvillage(c: Vector3, wallmat: Material, roofmat: Material) -> void:
	_build_church(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18150618
	for i in range(11):
		var off := Vector3(rng.randf_range(-95, 95), 0, rng.randf_range(-90, 90))
		if off.length() < 22.0:
			continue                                            # keep clear of the church
		_wbuilding(c + off, rng.randf_range(10, 16), rng.randf_range(6, 9), rng.randf_range(9, 15), wallmat, roofmat)

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
	# Distance to the WINDING lane (not the straight chord): project p onto the chord to get how
	# far along (t) and how far to the side (d_perp) it lies, then subtract the lane's sideways
	# wander at that point. Cheap and accurate enough for the march-speed corridor & avoidance.
	for s in road_segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var ab := b - a; ab.y = 0.0
		var ln := ab.length()
		if ln < 1.0:
			continue
		var dir := ab / ln
		var ap := p - a; ap.y = 0.0
		var along := ap.dot(dir)
		var t := clampf(along / ln, 0.0, 1.0)
		var perp := Vector3(dir.z, 0.0, -dir.x)
		var d_perp := ap.dot(perp) - _road_meander(t, ln, _road_seed(a, b))
		var over := maxf(maxf(-along, along - ln), 0.0)        # overrun past either end
		if Vector2(d_perp, over).length() < ROAD_WIDTH:
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
		var men := [0, 0, 0]   # raiders (index 2) never contest ownership — they drain, not capture
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
	_update_economy(tick)            # held towns produce materials; barracks raise battalions
	if changed:
		_color_towns()

# ============================================================ the WAR ECONOMY (auto-run)
# Held towns produce raw materials (one each, by the land around them); a held town with a
# production building draws the materials it needs and, over time, MUSTERS a unit that joins the
# war: Barracks -> infantry, Armory -> a battery, Stables -> a cavalry regiment, Shipyard -> a
# ship. The faction's economy runs ITSELF — the player shapes it only by which towns he holds and
# denies; his OWN force he raises with prestige. No town is self-sufficient (each yields ONE
# material, every building needs SEVERAL), so holding a SPREAD of towns is what keeps armies grown.
const MAT_GRAIN := 0
const MAT_IRON := 1
const MAT_TIMBER := 2
const MAT_HORSES := 3
const MAT_POWDER := 4
const N_MATS := 5
const MAT_NAMES := ["Grain", "Iron", "Timber", "Horses", "Powder"]
const MAT_PER_SIZE := 0.28          # raw material a town yields per tick, x its size
const BUILD_DRAW := 8.0             # how fast a building pulls from the stores (the stores throttle)
const REINFORCE_MEN := 560          # strength of a freshly-mustered battalion
const MAX_REINFORCEMENTS := 24      # cap on mustered units per side (render/headroom safety)
# cost vectors [Grain, Iron, Timber, Horses, Powder] per building type
const BUILD_COSTS := {
	"barracks": [240.0, 150.0, 0.0, 0.0, 0.0],     # Grain + Iron            -> infantry battalion
	"armory":   [0.0, 200.0, 150.0, 0.0, 120.0],   # Iron + Timber + Powder  -> a battery of guns
	"stables":  [170.0, 110.0, 0.0, 260.0, 0.0],   # Grain + Iron + Horses   -> a cavalry regiment
	"shipyard": [0.0, 220.0, 360.0, 0.0, 150.0],   # Iron + Timber + Powder  -> a ship
}
const BUILD_NAMES := { "barracks": "Barracks", "armory": "Armory", "stables": "Stables", "shipyard": "Shipyard" }
var _mat_pool := [[0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0]]   # [team][material]
var _reinforced := [0, 0]            # units mustered this campaign, per side
var _muster_cav_n := [0, 0]          # round-robins the arm of each cavalry regiment raised
var _econ_ready := false

func _assign_town_economy() -> void:
	# each town yields ONE raw material and (most) house ONE production building. The coastal
	# towns get the shipyards; the rest spread barracks/armory/stables. Assigned by index for now
	# — TODO: key off the surrounding terrain (farmland->grain, hills->iron, forest->timber...).
	var coastal: Array = []
	for i in range(field_towns.size()):
		coastal.append([float((field_towns[i]["pos"] as Vector3).x), i])
	coastal.sort_custom(func(a, c): return a[0] > c[0])   # nearest the coast first (highest x)
	var ship_towns := {}
	for k in range(mini(2, coastal.size())):
		ship_towns[int(coastal[k][1])] = true
	var blds := ["barracks", "armory", "stables"]
	var bn := 0
	for i in range(field_towns.size()):
		var t: Dictionary = field_towns[i]
		t["mat"] = i % N_MATS                       # spread the five raw materials across the towns
		t["stock"] = 0.0                            # the town's own pile of its material, awaiting a convoy
		t["build"] = [0.0, 0.0, 0.0, 0.0, 0.0]      # materials accrued toward this town's next unit
		if ship_towns.has(i):
			t["building"] = "shipyard"
		elif i % 2 == 0:                            # ~half the inland towns raise a unit type
			t["building"] = blds[bn % blds.size()]
			bn += 1
		else:
			t["building"] = ""

func _update_economy(tick: float) -> void:
	if field_towns.is_empty():
		return
	if not _econ_ready:
		_assign_town_economy()
		_econ_ready = true
	# PRODUCTION: every held town piles its raw material into its OWN local stock — it only reaches
	# the faction stores (where buildings draw it) once a WAGON CONVOY hauls it up (see _update_supply)
	for t in field_towns:
		var owner := int(t["owner"])
		if owner < 0 or owner > 1:
			continue
		t["stock"] = float(t.get("stock", 0.0)) + MAT_PER_SIZE * float(int(t["size"])) * tick
	# PRODUCTION BUILDINGS: each held building draws the materials it needs and musters its unit
	for t in field_towns:
		var bld := String(t.get("building", ""))
		if bld == "" or not BUILD_COSTS.has(bld):
			continue
		var owner := int(t["owner"])
		if owner < 0 or owner > 1 or _reinforced[owner] >= MAX_REINFORCEMENTS:
			continue
		var cost: Array = BUILD_COSTS[bld]
		var prog: Array = t["build"]
		var done := true
		for mi in range(N_MATS):
			if cost[mi] <= 0.0:
				continue
			if prog[mi] < cost[mi]:
				var draw: float = minf(minf(_mat_pool[owner][mi], cost[mi] - prog[mi]), BUILD_DRAW * tick)
				_mat_pool[owner][mi] -= draw
				prog[mi] += draw
			if prog[mi] < cost[mi]:
				done = false
		if done:
			for mi in range(N_MATS):
				prog[mi] -= cost[mi]
			_reinforced[owner] += 1
			_muster_unit(bld, owner, t)

func _muster_unit(bld: String, team: int, town: Dictionary) -> void:
	match bld:
		"barracks": _muster_battalion(team, town)
		"armory":   _muster_battery(team, town)
		"stables":  _muster_cavalry(team, town)
		"shipyard": _muster_ship(team, town)

func _nearest_brigade(pos: Vector3, team: int):
	var best = null
	var bd := 1.0e18
	for br in brigades:
		if br.team != team:
			continue
		var d: float = pos.distance_to(_brigade_center(br))
		if d < bd:
			bd = d
			best = br
	return best

# A battery founded at an armory town: GUNS_PER_BATTERY pieces roll out and join the nearest
# brigade's guns (driven by the existing artillery AI).
func _muster_battery(team: int, town: Dictionary) -> void:
	var tpos: Vector3 = town["pos"]
	var face := 0.0 if team == 0 else PI
	var fwd := Vector3(sin(face), 0, cos(face))
	var rightv := Vector3(fwd.z, 0, -fwd.x)
	var span := (GUNS_PER_BATTERY - 1) * GUN_SPACING
	var br = _nearest_brigade(tpos, team)
	for i in range(GUNS_PER_BATTERY):
		var g := Gun.new()
		g.team = team
		g.pos = tpos + rightv * (float(i) * GUN_SPACING - span * 0.5) - fwd * 60.0
		g.move_to = g.pos
		g.facing = face
		g.reload = ARTY_RELOAD * randf_range(0.2, 1.0)
		_make_gun(g)
		guns.append(g)
		if br != null:
			g.brigade = br
			br.guns.append(g)
	if player != null and team == player.team:
		_send_player_despatch("[color=#9fe0a0]A battery is founded at %s[/color] and rolls up to the guns' line." % String(town["name"]), {})

# A regiment of horse raised at a stables town: a fresh Cav joins the reserve (its arm round-
# robins through the four). Needs the per-arm cavalry MultiMesh headroom from _spawn_cavalry.
func _muster_cavalry(team: int, town: Dictionary) -> void:
	var ct: int = _muster_cav_n[team] % CAV_TYPE_DATA.size()
	_muster_cav_n[team] += 1
	if team > 1 or cav_horse_mm[team][ct] == null:
		return
	var c := Cav.new()
	c.team = team
	c.idx = CAV_PER_TEAM * 2 + 100 + cavalry.size()
	c.cav_type = ct
	var face := 0.0 if team == 0 else PI
	c.pos = (town["pos"] as Vector3) - Vector3(sin(face), 0, cos(face)) * 80.0
	c.reserve_pos = c.pos
	c.facing = face
	c.decide_cd = randf_range(0.0, CAV_DECIDE)
	var hp := AudioStreamPlayer3D.new()
	hp.max_distance = 1100.0
	hp.unit_size = 22.0
	hp.volume_db = 7.0
	add_child(hp)
	c.hoof_player = hp
	_fill_troopers(c)
	cavalry.append(c)
	if player != null and team == player.team:
		_send_player_despatch("[color=#9fe0a0]A regiment of horse is raised at %s[/color] and trots to the reserve." % String(town["name"]), {})

# A ship launched from a shipyard town: it stands out to sea and joins the patrol/sea-fight.
func _muster_ship(team: int, town: Dictionary) -> void:
	var node := _ship_node(team)
	add_child(node)
	var tz: float = (town["pos"] as Vector3).z
	var ph := 0.0 if team == 0 else PI
	ships.append({ "node": node, "pos": Vector3(COAST_X + randf_range(900.0, 2200.0), 0, tz), "heading": ph,
		"patrol_h": ph, "speed": SHIP_SPEED * randf_range(0.9, 1.1), "team": team, "fire_cd": randf_range(2.0, 6.0) })
	if player != null and team == player.team:
		_send_player_despatch("[color=#9fe0a0]A ship is launched from %s[/color] and stands out to sea." % String(town["name"]), {})

# Raise a battalion at a barracks town and send it up to reinforce — built on the proven
# mid-game spawn pattern (_spawn_raid_party), but for team 0/1 and attached to a real brigade so
# the existing AI marches and fights it.
func _muster_battalion(team: int, town: Dictionary) -> void:
	var b := Batt.new()
	b.team = team
	b.idx = BATT_PER_TEAM * 2 + 200 + battalions.size()   # synthetic id, outside the standing OOB
	var tpos: Vector3 = town["pos"]
	var spawn_pos := tpos + Vector3(randf_range(-30.0, 30.0), 0, randf_range(-30.0, 30.0))
	b.pos = spawn_pos
	b.spawn = spawn_pos
	b.last_pos = spawn_pos
	b.fire_pos = spawn_pos
	b._fat_pos = spawn_pos
	var face := 0.0 if team == 0 else PI
	b.facing = face
	b.off_facing = face
	b.off_pos = b.pos - Vector3(sin(face), 0, cos(face)) * 10.0
	b.formation = "column"            # march up in column, deploy on contact
	b.companies = 6
	b.ammo = START_ROUNDS
	b.ai_facing = face
	b.ai_posture = "advance"
	_fill_figs(b, REINFORCE_MEN)
	_assign_battalion_skills(b)
	b.rname = "%s Battalion" % String(town["name"])
	var fc := team_color(team)
	b.inst_col = Color(fc.r, fc.g, fc.b, _dress_packed(0, b.idx, false))
	b.start_men = b.figs.size()
	b.cohesion = _disc_cohesion(b)
	battalions.append(b)
	_attach_to_nearest_brigade(b)
	if player != null and team == player.team:
		_send_player_despatch("[color=#9fe0a0]A fresh battalion musters at %s[/color] and marches up to reinforce the line." % String(town["name"]), {})

func _attach_to_nearest_brigade(b: Batt) -> void:
	var best = null
	var bd := 1.0e18
	for br in brigades:
		if br.team != b.team:
			continue
		var d: float = b.pos.distance_to(_brigade_center(br))
		if d < bd:
			bd = d
			best = br
	if best != null:
		b.brigade = best
		best.battalions.append(b)

# ============================================================ SUPPLY CONVOYS (logistics)
# Civilian waggon trains physically haul a town's raw material up to the front, FEEDING the faction
# stores the production buildings draw on. The AI quartermaster despatches a convoy whenever the
# stores run short of a material a held town can supply — and OFFERS the escort as a job: ride to it
# yourself (for prestige), or, if you don't, the nearest AI unit is detached to see it through. A
# convoy with no escort bleeds its cargo to a prowling enemy — so the roads are now worth fighting over.
const CONVOY_SPEED := 7.0
const CONVOY_CARGO := 120.0
const POOL_LOW := 90.0              # stores below this for a material -> call a convoy of it
const CONVOY_COOLDOWN := 12.0       # min seconds between a faction's convoy despatches
const ESCORT_RANGE := 95.0          # a friendly unit this near counts as escorting the convoy
const THREAT_RANGE := 130.0         # an enemy this near threatens it
const CONVOY_BLEED := 10.0          # cargo lost / sec to a prowling enemy with no escort
const CONVOY_GRACE := 16.0          # seconds before the AI sends its own escort if you don't
const MAX_CONVOYS := 6              # per side
const CONVOY_ESCORT_PRESTIGE := 8   # your reward for seeing a convoy safe in
var supply_convoys: Array = []
var _convoy_cd := [0.0, 0.0]
var _convoy_next_id := 0
var _offered_id := -1               # the convoy currently offered to you (press Y to take it)
var _escort_id := -1                # the convoy you have accepted to escort

# A path of road points from a to b across the town road network (field_roads), or [] (then the
# convoy goes straight). BFS over the towns the roads link, then samples each leg's road curve.
func _nearest_town_index(pos: Vector3) -> int:
	var best := -1
	var bd := 1.0e18
	for i in range(field_towns.size()):
		var d: float = (field_towns[i]["pos"] as Vector3).distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best

func _road_path(a: Vector3, b: Vector3) -> Array:
	var ia := _nearest_town_index(a)
	var ib := _nearest_town_index(b)
	if ia < 0 or ib < 0 or ia == ib or field_roads.is_empty():
		return []
	var adj := {}
	for seg in field_roads:
		var i0 := _nearest_town_index(seg[0])
		var i1 := _nearest_town_index(seg[1])
		if i0 < 0 or i1 < 0:
			continue
		if not adj.has(i0): adj[i0] = []
		if not adj.has(i1): adj[i1] = []
		(adj[i0] as Array).append(i1)
		(adj[i1] as Array).append(i0)
	var prev := {}
	var visited := { ia: true }
	var queue := [ia]
	while not queue.is_empty():
		var cur = queue.pop_front()
		if cur == ib:
			break
		for nb in adj.get(cur, []):
			if not visited.has(nb):
				visited[nb] = true
				prev[nb] = cur
				queue.append(nb)
	if not prev.has(ib):
		return []
	var chain := [ib]
	var c = ib
	while prev.has(c):
		c = prev[c]
		chain.push_front(c)
	var pts: Array = []
	for k in range(chain.size() - 1):
		var t0: Vector3 = field_towns[chain[k]]["pos"]
		var t1: Vector3 = field_towns[chain[k + 1]]["pos"]
		for p in _road_curve(t0, t1, maxi(4, int(t0.distance_to(t1) / 60.0))):
			pts.append(p)
	return pts

# Y — take the offered convoy under your protection (a formal escort mission, double the reward).
func _accept_escort() -> void:
	if _offered_id < 0:
		return
	for cv in supply_convoys:
		if int(cv["id"]) == _offered_id:
			cv["accepted"] = true
			_escort_id = _offered_id
			_offered_id = -1
			_send_player_despatch("[color=#9fe0a0]You take the convoy under your protection.[/color] Ride with it to the front.", {})
			return
	_offered_id = -1

func _clear_convoy_refs(cv: Dictionary) -> void:
	var id := int(cv["id"])
	if id == _offered_id: _offered_id = -1
	if id == _escort_id: _escort_id = -1

func _team_center(team: int) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for b in battalions:
		if b.team == team and not b.independent and not b.spent:
			sum += b.pos
			n += 1
	return (sum / float(n)) if n > 0 else Vector3(0, 0, -360.0 if team == 0 else 360.0)

func _supply_dest(team: int) -> Vector3:
	# deliver to the held BUILDING town nearest the front; failing that, the army's centre
	var best := Vector3.INF
	var bd := 1.0e18
	var ec := _team_center(1 - team)
	for t in field_towns:
		if int(t["owner"]) != team or String(t.get("building", "")) == "":
			continue
		var d: float = (t["pos"] as Vector3).distance_to(ec)
		if d < bd:
			bd = d
			best = t["pos"]
	return best if best != Vector3.INF else _team_center(team)

func _maybe_spawn_convoy(team: int) -> void:
	if _convoy_cd[team] > 0.0:
		return
	var n_team := 0
	for cv in supply_convoys:
		if int(cv["team"]) == team:
			n_team += 1
	if n_team >= MAX_CONVOYS:
		return
	# the material the stores are shortest of that a held town can actually supply
	for mat in range(N_MATS):
		if _mat_pool[team][mat] >= POOL_LOW:
			continue
		var src = null
		var best_stock := 40.0
		for t in field_towns:
			if int(t["owner"]) != team or int(t["mat"]) != mat:
				continue
			var st: float = float(t.get("stock", 0.0))
			if st > best_stock:
				best_stock = st
				src = t
		if src != null:
			_spawn_convoy(team, src, mat)
			_convoy_cd[team] = CONVOY_COOLDOWN
			return

func _spawn_convoy(team: int, src: Dictionary, mat: int) -> void:
	var cargo: float = minf(float(src.get("stock", 0.0)), CONVOY_CARGO)
	src["stock"] = float(src.get("stock", 0.0)) - cargo
	var origin: Vector3 = src["pos"]
	var node := _make_caisson_node(team)
	node.position = Vector3(origin.x, _gh(origin.x, origin.z), origin.z)
	add_child(node)
	var dest := _supply_dest(team)
	var id := _convoy_next_id
	_convoy_next_id += 1
	supply_convoys.append({ "node": node, "pos": origin, "dest": dest, "path": _road_path(origin, dest),
		"wp": 0, "mat": mat, "cargo": cargo, "team": team, "grace": CONVOY_GRACE, "escort": null,
		"player_esc": false, "accepted": false, "id": id })
	if player != null and team == player.team:
		_offered_id = id
		_send_player_despatch("[color=#ffe9a8]Convoy:[/color] a %s train sets out from %s for the front — [color=#cfe0ff]press Y to take the escort[/color]." % [String(MAT_NAMES[mat]), String(src["name"])], {})

func _update_supply(delta: float) -> void:
	if field_towns.is_empty():
		return
	for team in [0, 1]:
		_convoy_cd[team] = maxf(0.0, _convoy_cd[team] - delta)
		_maybe_spawn_convoy(team)
	var i := 0
	while i < supply_convoys.size():
		var cv: Dictionary = supply_convoys[i]
		var team := int(cv["team"])
		var pos: Vector3 = cv["pos"]
		var node: Node3D = cv["node"]
		var path: Array = cv["path"]
		var wp := int(cv["wp"])
		# make for the next road waypoint, or — once past the road path — the final dest
		var aim: Vector3 = path[wp] if wp < path.size() else (cv["dest"] as Vector3)
		var escorted := _convoy_escorted(cv)
		var threatened := _convoy_threat(cv)
		if escorted:
			if player != null and team == player.team and off_pos.distance_to(pos) < ESCORT_RANGE:
				cv["player_esc"] = true
		else:
			cv["grace"] = float(cv["grace"]) - delta
			if threatened and float(cv["grace"]) <= 0.0 and cv["escort"] == null:
				cv["escort"] = _send_ai_escort(team, pos)
			if threatened:
				cv["cargo"] = float(cv["cargo"]) - CONVOY_BLEED * delta
		# an escorting AI unit keeps station on the convoy
		var eu = cv["escort"]
		if eu != null and is_instance_valid(eu) and not eu.spent:
			if eu is Batt:
				eu.ai_target = pos
			elif eu is Cav:
				eu.reserve_pos = pos
		# lost to the enemy?
		if float(cv["cargo"]) <= 0.0:
			if player != null and team == player.team:
				_send_player_despatch("[color=#ff9a8a]A supply convoy is lost[/color] — taken on the road, its cargo gone.", {})
			_clear_convoy_refs(cv)
			node.queue_free()
			supply_convoys.remove_at(i)
			continue
		var to := Vector3(aim.x - pos.x, 0, aim.z - pos.z)
		var step := CONVOY_SPEED * delta
		if to.length() <= maxf(step, 16.0):
			if wp < path.size():
				cv["wp"] = wp + 1                        # on to the next road waypoint
				cv["pos"] = aim
				node.position = Vector3(aim.x, _gh(aim.x, aim.z), aim.z)
				i += 1
				continue
			# reached the front — deliver to the stores
			_mat_pool[team][int(cv["mat"])] += float(cv["cargo"])
			if player != null and team == player.team:
				var bonus := ""
				if bool(cv["player_esc"]):
					var rew: int = CONVOY_ESCORT_PRESTIGE * (2 if bool(cv["accepted"]) else 1)
					prestige += rew
					bonus = "  [color=#9fe0a0](+%d prestige — escort)[/color]" % rew
				_send_player_despatch("[color=#9fe0a0]Convoy in:[/color] %s reaches the stores.%s" % [String(MAT_NAMES[int(cv["mat"])]), bonus], {})
			_clear_convoy_refs(cv)
			node.queue_free()
			supply_convoys.remove_at(i)
			continue
		var dir := to / to.length()
		pos = pos + dir * step
		cv["pos"] = pos
		node.position = Vector3(pos.x, _gh(pos.x, pos.z), pos.z)
		node.rotation.y = atan2(dir.x, dir.z)
		i += 1

func _convoy_escorted(cv: Dictionary) -> bool:
	var team := int(cv["team"])
	var pos: Vector3 = cv["pos"]
	if player != null and team == player.team and off_pos.distance_to(pos) < ESCORT_RANGE:
		return true
	for b in battalions:
		if b.team == team and not b.spent and not b.independent and b.pos.distance_to(pos) < ESCORT_RANGE:
			return true
	for c in cavalry:
		if c.team == team and not c.spent and c.pos.distance_to(pos) < ESCORT_RANGE:
			return true
	return false

func _convoy_threat(cv: Dictionary) -> bool:
	var team := int(cv["team"])
	var pos: Vector3 = cv["pos"]
	for b in battalions:
		if b.spent or b.pos.distance_to(pos) >= THREAT_RANGE:
			continue
		if b.is_raider or (b.team != team and b.team != 2 and b.figs.size() > 40):
			return true
	return false

func _send_ai_escort(team: int, pos: Vector3):
	# the quartermaster pulls the nearest steady battalion (or regiment of horse) off to see the
	# convoy through — its objective is set to the convoy; it keeps station on it (see _update_supply)
	var best = null
	var bd := 1.0e18
	for b in battalions:
		if b.team != team or b.spent or b.independent or b.is_player or b.state == "routing":
			continue
		var d: float = b.pos.distance_to(pos)
		if d < bd and d < 1400.0:
			bd = d
			best = b
	for c in cavalry:
		if c.team != team or c.spent:
			continue
		var d2: float = c.pos.distance_to(pos)
		if d2 < bd and d2 < 1400.0:
			bd = d2
			best = c
	if best != null:
		if best is Batt:
			best.ai_target = pos
		elif best is Cav:
			best.reserve_pos = pos
		if player != null and team == player.team:
			_send_player_despatch("[color=#caa15a]No escort answered[/color] — a unit is detached to see the convoy through.", {})
	return best

# The map label for a town: its raw material and (if any) its production building, e.g. "Iron · Armory".
func _town_econ_suffix(name: String) -> String:
	for t in field_towns:
		if String(t["name"]) == name and t.has("mat"):
			var s: String = "\n" + String(MAT_NAMES[int(t["mat"])])
			var bld := String(t.get("building", ""))
			if bld != "":
				s += " · " + String(BUILD_NAMES.get(bld, bld))
			return s
	return ""

# ------------------------------------------------------------------ native raid parties
# Small war-bands out of the woodland — team 2, hostile to both colonial sides alike.
# They ride the existing generic AI (_sim_ai) and combat code; this just sets their
# task each frame (where to march, when to hold and bleed a town, when to go home) and
# drains the raided town's "size" stat while they sit on it, exactly like an unrepelled
# raid would: the town is worth less to hold and sees less far, but never changes hands.
func _update_raiders(delta: float) -> void:
	raid_spawn_cd -= delta
	if raid_spawn_cd <= 0.0:
		raid_spawn_cd = RAID_SPAWN_COOLDOWN * randf_range(0.7, 1.4)
		_maybe_spawn_raid_party()
	for b in battalions:
		if b.is_raider:
			_drive_raid_party(b, delta)

# Reuse an idle war-band if one is resting in the woods; otherwise raise a fresh one,
# up to RAID_MAX_PARTIES abroad (broken bands don't count — they're done for good).
func _maybe_spawn_raid_party() -> void:
	if forest_clusters.is_empty() or field_towns.is_empty():
		return
	var idle: Batt = null
	var active := 0
	for b in battalions:
		if not b.is_raider or b.broken:
			continue
		if b.raid_state == "idle":
			if idle == null:
				idle = b
		else:
			active += 1
	if idle == null and active >= RAID_MAX_PARTIES:
		return
	var origin: Vector3 = idle.raid_home if idle != null else (forest_clusters[randi() % forest_clusters.size()]["pos"] as Vector3)
	var target := _nearest_raidable_town(origin)
	if target.is_empty():
		return
	if idle != null:
		idle.raid_town = target
		idle.raid_state = "march"
		idle.raid_t = 0.0
		idle.raid_drain_t = 0.0
	else:
		_spawn_raid_party(origin, target)

func _nearest_raidable_town(from_pos: Vector3) -> Dictionary:
	var target := {}
	var bd := 1.0e18
	for t in field_towns:
		if int(t["size"]) <= RAID_MIN_SIZE:
			continue
		var d: float = from_pos.distance_to(t["pos"])
		if d < bd:
			bd = d
			target = t
	return target

func _spawn_raid_party(origin: Vector3, target: Dictionary) -> void:
	var b := Batt.new()
	b.team = 2
	b.idx = BATT_PER_TEAM * 2 + 1 + battalions.size()   # synthetic, outside the standing OOB
	b.is_raider = true
	b.independent = true
	var spawn_pos := origin + Vector3(randf_range(-40.0, 40.0), 0, randf_range(-40.0, 40.0))
	b.pos = spawn_pos
	b.spawn = spawn_pos
	b.raid_home = origin
	b.raid_town = target
	b.raid_state = "march"
	var face := atan2((target["pos"] as Vector3).x - spawn_pos.x, (target["pos"] as Vector3).z - spawn_pos.z)
	b.facing = face
	b.formation = "column"
	b.off_facing = face
	b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
	b.companies = 4
	b.ammo = START_ROUNDS
	b.last_pos = b.pos
	b.ai_target = target["pos"]
	b.ai_facing = face
	b.ai_posture = "advance"
	var n := randi_range(RAID_PARTY_MEN[0], RAID_PARTY_MEN[1])
	_fill_figs(b, n)
	_assign_battalion_skills(b)
	b.rname = "Raiding party"
	var fc: Color = FACINGS_2[randi() % FACINGS_2.size()]
	b.inst_col = Color(fc.r, fc.g, fc.b, _dress_packed(0, b.idx, false))
	b.start_men = b.figs.size()
	battalions.append(b)

# March on the town, hold and bleed it a while, then melt back into the woods — but
# fight back exactly like any other battalion the instant a foe closes (see _sim_ai).
func _drive_raid_party(b: Batt, delta: float) -> void:
	if b.broken or b.figs.size() < 60:
		return   # a beaten war-band routs and is left alone, same as any other broken unit
	b.raid_t += delta
	match b.raid_state:
		"march":
			b.ai_posture = "advance"
			b.ai_target = b.raid_town["pos"]
			b.ai_facing = b.facing
			if b.pos.distance_to(b.raid_town["pos"] as Vector3) < TOWN_CAPTURE_RANGE * 0.7:
				b.raid_state = "raid"
				b.raid_t = 0.0
				b.raid_drain_t = 0.0
				_send_player_despatch("[color=#caa15a]%s is under raid![/color] A war-party has fallen on the town." % b.raid_town["name"], {})
		"raid":
			b.ai_posture = "hold"
			b.ai_target = b.pos
			b.ai_facing = b.facing
			b.raid_drain_t += delta
			if b.raid_drain_t >= RAID_DRAIN_TIME:
				b.raid_drain_t -= RAID_DRAIN_TIME
				var t: Dictionary = b.raid_town
				if int(t["size"]) > RAID_MIN_SIZE:
					t["size"] = int(t["size"]) - 1
			if b.raid_t >= RAID_DURATION or int(b.raid_town["size"]) <= RAID_MIN_SIZE:
				b.raid_state = "retreat"
				b.raid_t = 0.0
				_send_player_despatch("[color=#caa15a]The war-party[/color] melts back into the woods, %s plundered." % String(b.raid_town["name"]), {})
		"retreat":
			b.ai_posture = "withdraw"
			b.ai_target = b.raid_home
			b.ai_facing = b.facing
			if b.pos.distance_to(b.raid_home) < 60.0:
				b.raid_state = "idle"
				b.raid_t = 0.0
				b.morale = 100.0
				b.cohesion = _disc_cohesion(b)
				b.ammo = START_ROUNDS
		"idle":
			b.ai_posture = "hold"
			b.ai_target = b.pos
			b.ai_facing = b.facing

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
	_campaign_over = true             # the province is decided — this is the true end of the campaign
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
const COAST_X := 1650.0            # the shoreline's mean position — land to the west, open sea
									# to the east (the actual coast bends around this, see _coast_x)
const COAST_AMPLITUDE := 400.0     # the most a bay/headland can pull the shore off COAST_X
const SHIP_SPEED := 2.4            # a ship under sail makes way slowly (an accurate pace)
const SHIP_TURN := 0.09            # max turn rate (rad/s) — a big, ponderous turning circle
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
	var depth := clampf((wx - _coast_x(wz)) / 1400.0, 0.0, 1.0)
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
	// the shore bows into bays/headlands around coast_x — MUST mirror _coast_x() in GDScript
	float local_coast = coast_x + sin(p.y * 0.00045 + 0.6) * 260.0 + sin(p.y * 0.00112 - 1.3) * 140.0;
	v_depth = clamp((p.x - local_coast) / 1400.0, 0.0, 1.0);
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
	# Both reach a bit further landward than the mean COAST_X so they fully cover the deepest
	# bay (the ground's own seabed slope, see _gh, then hides under them with no gap).
	var ocean_x0 := COAST_X - COAST_AMPLITUDE
	var near := PlaneMesh.new()
	near.size = Vector2(6000.0 + COAST_AMPLITUDE, 16000)
	near.subdivide_width = 240
	near.subdivide_depth = 320
	ocean = MeshInstance3D.new()
	ocean.mesh = near
	ocean.position = Vector3(ocean_x0 + near.size.x * 0.5, SEA_BASE_Y, 0.0)
	ocean.material_override = ocean_mat
	add_child(ocean)
	var far := PlaneMesh.new()
	far.size = Vector2(40000.0 + COAST_AMPLITUDE, 40000)
	far.subdivide_width = 80
	far.subdivide_depth = 80
	var far_mi := MeshInstance3D.new()
	far_mi.mesh = far
	far_mi.position = Vector3(ocean_x0 + far.size.x * 0.5, SEA_BASE_Y - 0.3, 0.0)
	far_mi.material_override = ocean_mat
	far_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far_mi)
	# a pale ribbon of beach that follows the actual bowed shoreline, not a straight line
	var coast_pts: Array = []
	var cz := -PROVINCE_SIZE * 0.5
	while cz <= PROVINCE_SIZE * 0.5:
		coast_pts.append(Vector3(_coast_x(cz), 0.0, cz))
		cz += 200.0
	var beach_st := SurfaceTool.new(); beach_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ribbon(beach_st, coast_pts, 100.0, 0.15)
	var beach := MeshInstance3D.new()
	beach.mesh = beach_st.commit()
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.80, 0.74, 0.55)
	bmat.roughness = 1.0
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beach.material_override = bmat
	beach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

# A blocky-but-believable sloop-of-war, bow toward +Z: a tapered hull with a wale and a
# chequered gun-deck, a raised quarterdeck and forecastle, a beak and bowsprit, three
# masts crossed with yards and graduated square sails, headsails and the ensign astern.
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
	# ---- hull: a deep keel, a wider deck, a tapering bow and a tall transom ----
	_smesh(n, _box(7.5, 5.0, 40.0), Vector3(0, 2.5, -1.0), timber)            # lower hull / keel run
	_smesh(n, _box(11.5, 5.0, 42.0), Vector3(0, 6.5, -1.0), timber)           # main hull at the deck
	_smesh(n, _box(9.0, 5.0, 6.0), Vector3(0, 5.6, 21.5), timber)             # bow shoulder
	_smesh(n, _box(5.0, 4.6, 5.0), Vector3(0, 5.4, 25.5), timber)             # bow taper
	_smesh(n, _box(2.4, 3.6, 4.0), Vector3(0, 4.8, 28.5), dark)               # beakhead / stem
	_smesh(n, _box(12.4, 6.0, 4.0), Vector3(0, 8.0, -22.0), timber)           # stern transom (tall)
	_smesh(n, _box(8.0, 2.6, 0.6), Vector3(0, 9.2, -24.1), trim)              # stern gallery windows
	# the wale (a heavy rubbing strake) and the chequered gun deck with its ports
	_smesh(n, _box(12.0, 1.2, 43.0), Vector3(0, 4.6, -1.0), dark)             # wale
	_smesh(n, _box(11.8, 1.8, 41.5), Vector3(0, 7.2, -1.0), strake)          # gun strake
	for side in [-1.0, 1.0]:
		for k in range(6):
			var pz := -14.0 + float(k) * 6.0
			_smesh(n, _box(0.6, 1.1, 1.6), Vector3(side * 5.95, 7.2, pz), dark)   # gun ports
	# bulwarks + the upper decks
	_smesh(n, _box(11.6, 1.6, 42.0), Vector3(0, 9.6, -1.0), timber)           # bulwark rail
	_smesh(n, _box(10.6, 0.5, 41.0), Vector3(0, 9.3, -1.0), deckwood)         # weather deck
	_smesh(n, _box(10.5, 2.2, 13.0), Vector3(0, 10.7, -14.5), timber)         # quarterdeck (raised aft)
	_smesh(n, _box(9.0, 1.8, 8.0), Vector3(0, 10.5, 16.0), timber)            # forecastle (raised fwd)
	# a ship's wheel & binnacle hint on the quarterdeck
	_smesh(n, _box(0.4, 1.4, 0.4), Vector3(0, 11.8, -10.0), deckwood)
	# ---- bowsprit + headsails ----
	var bsB := Basis(Vector3.RIGHT, deg_to_rad(-22.0))
	_smesh(n, _box(0.8, 0.8, 16.0), Vector3(0, 11.5, 27.0), deckwood, bsB)
	_smesh(n, _box(0.1, 5.0, 7.0), Vector3(0, 12.5, 24.0), canvas, Basis(Vector3.UP, deg_to_rad(90.0)) * Basis(Vector3.RIGHT, deg_to_rad(8.0)))
	# ---- three masts: fore, main (tallest), mizzen — each crossed with yards & sails ----
	var masts := [
		{ "z": 12.0, "h": 40.0, "course": Vector2(22.0, 12.0), "top": Vector2(16.0, 9.0) },   # fore
		{ "z": -1.0, "h": 47.0, "course": Vector2(26.0, 14.0), "top": Vector2(19.0, 10.0) },  # main
		{ "z": -14.0, "h": 34.0, "course": Vector2(18.0, 10.0), "top": Vector2(13.0, 8.0) },  # mizzen
	]
	for m in masts:
		var mz: float = m["z"]
		var mh: float = m["h"]
		var mcyl := CylinderMesh.new(); mcyl.top_radius = 0.35; mcyl.bottom_radius = 0.7; mcyl.height = mh
		_smesh(n, mcyl, Vector3(0, 8.0 + mh * 0.5, mz), deckwood)
		var top := CylinderMesh.new(); top.top_radius = 0.18; top.bottom_radius = 0.35; top.height = mh * 0.5
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
				var foot := Vector3(side * 5.6, 9.5, mz + float(sh - 1) * 3.0)
				var head := Vector3(side * 0.6, 8.0 + mh * 0.7, mz)
				var mid := (foot + head) * 0.5
				var dir := head - foot
				var b := Basis.looking_at(dir.normalized(), Vector3.UP)
				var rod := _box(0.12, 0.12, dir.length())
				_smesh(n, rod, mid, rope, b)
	# the ensign at the stern staff
	var staffB := Basis(Vector3.RIGHT, deg_to_rad(-18.0))
	_smesh(n, _box(0.2, 0.2, 7.0), Vector3(0, 13.0, -24.0), deckwood, staffB)
	_smesh(n, _box(0.15, 3.2, 5.0), Vector3(0, 15.0, -27.5), trim)
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
				"speed": SHIP_SPEED * randf_range(0.9, 1.1), "team": team, "fire_cd": randf_range(2.0, 6.0) })

func _nearest_enemy_ship(s: Dictionary):
	var best = null
	var bd := 1.0e18
	for o in ships:
		if o["team"] == s["team"]:
			continue
		var d: float = (o["pos"] as Vector3).distance_to(s["pos"])
		if d < bd:
			bd = d; best = o
	return best

func _update_ships(delta: float) -> void:
	if ships.is_empty():
		return
	for s in ships:
		# CLIENT: the host owns ship movement & gunnery — just ride the synced hull on the swell
		# (pos/heading arrive via _apply_world), so every player sees the same shipping.
		if not authoritative:
			var hd0 := Vector3(sin(s["heading"]), 0, cos(s["heading"]))
			var node0: Node3D = s["node"]
			var sx0: float = s["pos"].x
			var sz0: float = s["pos"].z
			var wy0 := _sea_y(sx0, sz0)
			var up0 := _sea_normal(sx0, sz0)
			var fwd0 := (hd0 - up0 * hd0.dot(up0)).normalized()
			var right0 := up0.cross(fwd0).normalized()
			node0.transform = Transform3D(Basis(right0, up0, fwd0), Vector3(sx0, wy0 + 0.2, sz0))
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

func _ship_broadside(s: Dictionary, foe) -> void:
	var hd := Vector3(sin(s["heading"]), 0, cos(s["heading"]))
	var right := Vector3(hd.z, 0, -hd.x)
	var to_foe: Vector3 = (foe["pos"] as Vector3) - s["pos"]
	var side := right if right.dot(to_foe) > 0.0 else -right
	var base: Vector3 = s["pos"] + Vector3(0, 5.0, 0)
	# a full gun-deck speaks as one — same flash, smoke-bloom and report as the land batteries
	for k in range(9):
		var muzzle := base + hd * ((float(k) - 4.0) * 5.0) + side * 7.0
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_muzzle_bloom(muzzle, side)
		_emit_gun_smoke(muzzle + side * randf_range(0.0, 4.0), side)
		_emit_gun_smoke(muzzle + side * randf_range(2.0, 6.0), side)
	if cam != null:
		_play_cannon(base + hd * 12.0 + side * 7.0)
		_play_cannon(base - hd * 12.0 + side * 7.0)   # the report rolls down the ship's length

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
	# an encamped battalion is in bivouac, not a formation — and you cannot re-form it until you
	# break camp (the manoeuvre drill is the one exception, where re-forming IS the exercise)
	var form_word: String = "encamped" if (b.encamped and not _mdrill_on) else b.formation
	rt += "[color=#cdd6e6]%d men · [color=#%s]%s[/color] · %d rds · %s[/color]\n" % [b.figs.size(), mcol, morale_word, int(round(b.ammo)), form_word]
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
	var no_form: bool = b.encamped and not _mdrill_on    # no manoeuvring while the men bivouac
	for item in CMD_PAGES[_cmd_page]:
		if no_form and (String(item[3]) == "page:form" or String(item[3]) in ["line", "column", "square"]):
			continue
		ot += "  [color=#ffe9a8]%s[/color]  [color=#cdd6e6]%s[/color]\n" % [item[1], item[2]]
	if no_form and _cmd_page == "":
		ot += "  [color=#6f7888]Formation — break camp to re-form[/color]\n"
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
		"[color=#%s]SELF[/color]   [color=#%s]LMB[/color] sabre/fire · [color=#%s]G[/color] pistol · [color=#%s]T[/color] bring up the guns · [color=#%s]B[/color] send scouts\n" % [c, k, k, k, k] + \
		"[color=#%s]BATT[/color]   [color=#%s]1/2/3/4[/color] advance 5/15/25/50yd · [color=#%s]5[/color] halt · [color=#%s]6/7[/color] wheel L 45/90 · [color=#%s]8/9[/color] wheel R 45/90\n" % [c, k, k, k, k] + \
		"[color=#%s]FIRE[/color]   [color=#%s]V[/color] present · [color=#%s]F[/color] fire volley · [color=#%s]0[/color] independent fire (each man presents then fires)\n" % [c, k, k, k] + \
		"[color=#%s]ARM[/color]    [color=#%s]1[/color] foot · [color=#%s]2[/color] guns ([color=#%s]E[/color] sight the barrel · LMB fires) · [color=#%s]3[/color] horse (F charges) — at the step-off\n" % [c, k, k, k, k] + \
		"[color=#%s]CAMP[/color]   [color=#%s]C[/color] camp & companies — a mouse GUI [color=#6f7888](while standing in one of your towns)[/color]\n" % [c, k] + \
		"[color=#%s]WORLD[/color]  [color=#%s]N[/color] push the clock on · [color=#%s]M[/color] province map  [color=#6f7888](dusk ends the day)[/color]\n" % [c, k, k] + \
		"[color=#%s]DEV[/color]    [color=#%s]F3[/color] AI overlay + reveal map · [color=#%s]F4[/color] RTS free-fly camera\n" % [c, k, k] + \
		"[right][color=#6f7888]Tab to hide[/color][/right]"
	help_panel.add_child(rt)

func _scope_shader() -> Shader:
	# The view through a drawn-brass spyglass: a true CIRCULAR field (aspect-corrected, so it
	# never stretches to an ellipse on a wide screen), ringed by a thin brass eyepiece, with a
	# soft optical vignette that deepens as the glass is drawn out to higher magnification.
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float amt = 0.0;       // 0 glass down .. 1 fully raised (fades the whole mask in)
uniform float zoom = 0.45;     // 0 wide .. 1 drawn out (a touch more vignette when drawn out)
void fragment() {
	vec2 d = UV - vec2(0.5);
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;   // = width / height
	d.x *= aspect;                                             // correct so the field is a true circle
	float r = length(d) / 0.46;                                // r = 1 at the eyepiece edge
	vec3 brass = vec3(0.42, 0.31, 0.13);
	float vig = smoothstep(0.45, 1.0, r) * (0.22 + 0.14 * zoom);                         // soft lens darkening
	float rim = clamp(smoothstep(1.0, 1.018, r) - smoothstep(1.05, 1.072, r), 0.0, 1.0); // thin brass ring
	float wall = smoothstep(1.06, 1.095, r);                   // opaque tube wall / black surround
	vec3 col = mix(vec3(0.0), brass, rim);
	float alpha = max(max(vig, wall), rim * 0.9);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0) * amt);
}
"""
	return sh

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
const OFFICER_HERO := "res://models/officer_hero.glb"

func _build_officer() -> void:
	officer = Node3D.new()
	add_child(officer)
	# The player's mounted officer — a detailed PROCEDURAL Colonel (charger + rider), built from
	# primitives like the soldiers (no Blender import) so he matches the game's low-poly stylised
	# look. His coat takes the militia's UNIFORM colour; the collar/lapels/cuffs/cockade and the
	# saddle's shabraque take the FACING colour chosen when the force was raised.
	var coat_col: Color = GameConfig.UNIFORM_COLS[clampi(GameConfig.militia_uniform, 0, GameConfig.UNIFORM_COLS.size() - 1)]
	var facing_col: Color = GameConfig.militia_facing
	# a historical battle: the hero wears the nationality of the battalion the player chose to command
	if _wmap and GameConfig.setup != null:
		for u in GameConfig.setup.units:
			if u.human_slot == GameConfig.local_slot:
				coat_col = _coats_for(u.team)[clampi(int(u.coat_idx), 0, 3)]
				facing_col = u.facing_col
				break
	_build_horse(officer)                          # the charger (origin at its hooves, faces +Z)
	_build_officer_colonel(coat_col, facing_col)   # the Colonel in the saddle

# A small StandardMaterial3D helper for the procedural hero's many parts.
func _hero_mat(col: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m

# Add one part of the hero (a MeshInstance3D parented to `officer`), returning it so the
# caller can keep a handle (sabre / pistol get animated elsewhere).
func _hero_part(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.material_override = mat
	officer.add_child(mi)
	return mi

func _sph(radius: float) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = radius; s.height = radius * 2.0; s.radial_segments = 10; s.rings = 6; return s

func _hcyl(r_bottom: float, r_top: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new(); c.bottom_radius = r_bottom; c.top_radius = r_top; c.height = h; c.radial_segments = 8; c.rings = 0; return c

# The Colonel in the saddle: built on the mounted-rider layout (seat ≈ y1.35, head ≈ y2.38,
# bicorne ≈ y2.55), in the player's militia colours, with the full marks of a field officer —
# gorget, crimson sash, gold fringed epaulettes both shoulders, an aiguillette, and a
# gold-piped, tall-plumed bicorne. Built in the INFANTRY idiom — box body/limbs, a sphere head and
# a cylinder plume, like _soldier_mesh / _mount_rider_mesh — so the hero reads as the same stylised
# low-poly man as the troops he leads (just richer, being a single instance and not a MultiMesh).
func _build_officer_colonel(coat_col: Color, facing_col: Color) -> void:
	var coat := _hero_mat(coat_col.lightened(0.06), 0.6)
	var facing := _hero_mat(facing_col, 0.6)
	var gold := _hero_mat(Color(0.86, 0.69, 0.24), 0.35, 0.5)
	var crim := _hero_mat(Color(0.55, 0.05, 0.08), 0.7)
	var buff := _hero_mat(Color(0.82, 0.78, 0.66), 0.85)
	var boot := _hero_mat(Color(0.07, 0.06, 0.07), 0.6)
	var skin := _hero_mat(Color(0.74, 0.57, 0.44), 0.75)
	var black := _hero_mat(Color(0.05, 0.05, 0.06), 0.6)
	var plume := _hero_mat(Color(0.93, 0.91, 0.87), 0.85)
	var steel := _hero_mat(Color(0.85, 0.85, 0.90), 0.25, 0.85)
	var leather := _hero_mat(Color(0.27, 0.17, 0.09), 0.85)
	# --- the tack: a leather saddle and a gold-piped shabraque in the facing colour ---
	_hero_part(_box(0.30, 0.14, 0.46), Vector3(0, 1.32, -0.02), leather)            # saddle
	_hero_part(_box(0.50, 0.025, 0.64), Vector3(0, 1.14, -0.46), gold)              # shabraque trim
	_hero_part(_box(0.46, 0.05, 0.58), Vector3(0, 1.17, -0.46), facing)             # shabraque (facing)
	# --- legs astride: buff breeches into tall black boots (box, like the troops' legs) ---
	for sx in [-0.24, 0.24]:
		_hero_part(_box(0.17, 0.66, 0.18), Vector3(sx, 1.40, 0.08), buff)               # thigh (breeches)
		_hero_part(_box(0.17, 0.46, 0.19), Vector3(sx, 1.04, 0.20), boot)               # riding boot
	# --- torso: box coat body with longer tails behind ---
	_hero_part(_box(0.42, 0.64, 0.26), Vector3(0, 1.95, 0), coat)                         # coat body
	_hero_part(_box(0.36, 0.32, 0.14), Vector3(0, 1.66, -0.16), coat)                     # coat tails
	# --- facings: stand collar, lapels down the breast, crimson sash ---
	_hero_part(_box(0.30, 0.10, 0.10), Vector3(0, 2.20, 0.10), facing)                    # collar
	_hero_part(_box(0.20, 0.50, 0.04), Vector3(0, 1.92, 0.135), facing)                   # lapels
	_hero_part(_box(0.45, 0.11, 0.30), Vector3(0, 1.72, 0), crim)                         # waist sash
	_hero_part(_box(0.07, 0.24, 0.07), Vector3(-0.21, 1.55, 0.06), crim)                  # sash tassel
	_hero_part(_box(0.13, 0.06, 0.02), Vector3(0, 2.27, 0.135), gold)                     # gorget at the throat
	# --- arms: box sleeves, faced cuffs, box hands, gold epaulettes ---
	for sx in [-0.30, 0.30]:
		_hero_part(_box(0.15, 0.50, 0.15), Vector3(sx, 1.92, 0.04), coat)                 # sleeve
		_hero_part(_box(0.16, 0.10, 0.17), Vector3(sx, 1.70, 0.05), facing)               # cuff (facing)
		_hero_part(_box(0.10, 0.10, 0.11), Vector3(sx * 0.9, 1.63, 0.12), skin)           # hand
		_hero_part(_box(0.18, 0.05, 0.17), Vector3(sx, 2.18, 0), gold)                    # epaulette
		_hero_part(_box(0.05, 0.05, 0.17), Vector3(sx * 0.97, 2.20, 0.04), gold)          # epaulette fringe
	# --- aiguillette: gold cords looped on the right shoulder ---
	_hero_part(_box(0.03, 0.36, 0.03), Vector3(0.20, 1.97, 0.16), gold, Vector3(0, 0, -0.2))  # cord
	_hero_part(_box(0.04, 0.09, 0.04), Vector3(0.23, 1.74, 0.17), gold)                   # cord tip
	# --- head: a sphere, like the soldiers' (a touch bigger) ---
	_hero_part(_sph(0.135), Vector3(0, 2.39, 0), skin)
	# --- the bicorne: black felt, gold-piped, a facing-coloured cockade and a tall plume ---
	_hero_part(_box(0.55, 0.12, 0.22), Vector3(0, 2.56, 0), black)                        # bicorne body
	_hero_part(_box(0.58, 0.03, 0.25), Vector3(0, 2.50, 0), gold)                         # gold piping
	_hero_part(_box(0.07, 0.08, 0.03), Vector3(0, 2.58, 0.11), facing)                    # cockade (facing)
	_hero_part(_box(0.04, 0.05, 0.03), Vector3(0, 2.585, 0.115), gold)                    # cockade button
	_hero_part(_hcyl(0.045, 0.04, 0.10), Vector3(0, 2.66, -0.04), gold)                   # plume base (cylinder, like the shako plume)
	_hero_part(_hcyl(0.035, 0.015, 0.36), Vector3(0, 2.88, -0.05), plume)                 # plume (cylinder)
	# --- the sabre on the right, a horse-pistol holstered on the left ---
	sabre = _hero_part(_box(0.05, 0.05, 0.85), Vector3(0.34, 1.90, 0.25), steel)
	_hero_part(_box(0.08, 0.10, 0.14), Vector3(0.34, 1.90, -0.17), gold)                  # sabre hilt
	pistol_mesh = _hero_part(_box(0.06, 0.11, 0.26), Vector3(-0.32, 1.90, 0.20), leather) # holstered pistol

# Recolour the hero's facing-coloured parts (lapels, cuffs, collar, saddlecloth) and
# his coat to the player's militia, by glTF material name. Everything else (gold lace,
# crimson sash, leather, steel, the horse's hide) keeps the colours baked in Blender.
func _tint_officer(node: Node, facing: Color, coat: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in range(mi.mesh.get_surface_count()):
				var m := mi.mesh.surface_get_material(s)
				if m != null:
					var nm := m.resource_name
					var col := Color.BLACK
					var hit := false
					if nm.begins_with("OFac") or nm.begins_with("Shabraque"):
						col = facing; hit = true
					elif nm.begins_with("OCoat"):
						col = coat; hit = true
					if hit:
						var dup := m.duplicate()
						if dup is BaseMaterial3D:
							(dup as BaseMaterial3D).albedo_color = col
						mi.set_surface_override_material(s, dup)
	for ch in node.get_children():
		_tint_officer(ch, facing, coat)

func _build_officer_blocky() -> void:
	# the charger — a blocky dark bay built to match the soldiers (body, neck, head,
	# four legs that swing at the gait), facing forward (+Z) under the rider
	_build_horse(officer)
	# the rider: a BLOCKY officer in the saddle, in his battalion's navy (matching the line)
	var coat := StandardMaterial3D.new()
	coat.albedo_color = ARMY_BLUE.lightened(0.12)
	coat.roughness = 0.6
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.56, 0.43)
	var chest := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(0.42, 0.62, 0.26)
	chest.mesh = cb
	chest.position = Vector3(0, 1.95, 0)
	chest.material_override = coat
	officer.add_child(chest)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.22, 0.22, 0.22)
	head.mesh = hb
	head.position = Vector3(0, 2.38, 0)
	head.material_override = skin
	officer.add_child(head)
	for sx in [-0.27, 0.27]:
		var leg := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.16, 0.72, 0.18)
		leg.mesh = lb
		leg.position = Vector3(sx, 1.35, 0.08)
		leg.rotation = Vector3(0.35, 0, sx * 1.2)   # thighs astride the horse
		leg.material_override = coat
		officer.add_child(leg)
	for ax in [-0.30, 0.30]:
		var arm := MeshInstance3D.new()
		var ab := BoxMesh.new()
		ab.size = Vector3(0.13, 0.5, 0.14)
		arm.mesh = ab
		arm.position = Vector3(ax, 1.92, 0.04)
		arm.material_override = coat
		officer.add_child(arm)
	# a black bicorne, worn athwart
	var hat := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.55, 0.12, 0.22)
	hat.mesh = hm
	hat.position = Vector3(0, 2.55, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.08, 0.08, 0.10)
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

# Build a blocky charger under the rider: barrel, chest, hindquarters, an arched neck
# and head, a tail, and four legs on pivots so they can swing at the gait. Faces +Z.
func _build_horse(parent: Node3D) -> void:
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

# ------------------------------------------------------------------ armies

# In multiplayer a lobby slot is an abstract PLAYER INDEX; map it to a real battalion in the OOB —
# a brigade-lead, even index → Crown (team 0), odd → Continental (team 1) — so the players spread
# across the field on opposing sides and take their orders from the command chain like any battalion.
func _mp_player_gidx(pidx: int) -> int:
	if pidx < 0:
		return -1
	var team := pidx % 2
	var nth := pidx / 2                                    # the nth commander on that side
	var lead := (nth * BATTS_PER_BRIGADE) % BATT_PER_TEAM  # lead battalion of successive brigades
	return team * BATT_PER_TEAM + lead

# The battalion index a given slot commands: in single-player local_slot IS the index; in MP it's a
# player index that maps through _mp_player_gidx.
func _player_gidx(slot: int) -> int:
	if GameConfig.mode == "single":
		return slot
	return _mp_player_gidx(slot)

func _spawn_armies() -> void:
	if _inflated:
		_spawn_from_setup()
		return
	# which battalion indices are human-led (host knows everyone; a client only itself)
	var human_slots: Array = [GameConfig.local_slot]
	if GameConfig.mode == "host":
		human_slots = Net.human_slots()
	var humans: Array = []
	for ps in human_slots:
		humans.append(_player_gidx(int(ps)))
	var my_gidx := _player_gidx(GameConfig.local_slot)
	# a founded militia rides INDEPENDENT of the order of battle (see _spawn_independent_militia) —
	# no slot in the standard OOB is the player's, so none should be marked human/player
	if GameConfig.has_militia:
		humans = []
		my_gidx = -1
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
			b.inst_col = Color(fc.r, fc.g, fc.b, _dress_packed(coat_idx, gidx, gidx == my_gidx))
			b.spawn = b.pos
			b.facing = face
			b.formation = "column"               # advance in column, deploy on contact
			b.off_facing = face
			b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
			b.human = gidx in humans
			b.is_player = (gidx == my_gidx)
			for ps in human_slots:                # tag which lobby slot commands this battalion
				if _player_gidx(int(ps)) == gidx:
					b.human_slot = int(ps)
					break
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
				b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, _dress_packed(int(u.coat_idx), gidx, gidx == my_gidx))
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
		b.oob_corps = u.corps              # carry the authored order of battle through to the command tier
		b.oob_division = u.division
		b.oob_brigade = u.brigade
		b.nation = u.nation                # nationality → national doctrine in the command AI
		b.weapon_id = u.weapon             # weapon id → range/reload/accuracy via weapons/<id>.tres
		b.pos = u.pos
		b.spawn = b.pos
		b.facing = face
		b.formation = "line"                 # they meet already deployed for the fight
		b.off_facing = face
		b.off_pos = b.pos + Vector3(sin(face), 0, cos(face)) * 14.0
		b.human = (u.human_slot >= 0)                          # any player-commanded unit
		b.human_slot = u.human_slot                            # so the host can route this slot's orders here
		# the one THIS peer drives — guard local_slot >= 0 so a dedicated server (slot -1)
		# doesn't claim every AI unit (whose human_slot is also -1) as its own
		b.is_player = (GameConfig.local_slot >= 0 and u.human_slot == GameConfig.local_slot)
		b.companies = 6 if team == 0 else 10
		b.ammo = u.ammo
		b.morale = u.morale
		b.rname = u.name
		b.inst_col = Color(u.facing_col.r, u.facing_col.g, u.facing_col.b, _dress_packed(int(u.coat_idx), ui, b.is_player, u.belt_idx, u.pants_idx, u.hat_idx))
		b.last_pos = b.pos
		var mp := AudioStreamPlayer3D.new()
		mp.max_distance = 700.0
		mp.unit_size = 14.0
		mp.volume_db = 4.0
		add_child(mp)
		b.march_player = mp
		_fill_figs(b, maxi(1, u.men))        # the battalion's REAL strength — not capped at the campaign 700
		_assign_battalion_skills(b)
		_apply_seam_skills(b, u)             # carry the regiment's real skills from the world
		while b.figs.size() > u.men and b.figs.size() > 0:
			b.figs.pop_back()                # trim to exact strength (no-op once filled to u.men)
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

# The French colour: the tricolore (blue/white/red vertical bands) under Napoleon's gilt aigle —
# the eagle the regiment guarded above all. One Node3D per battalion (free of the affordability
# keystone, like the other flags); the cloth wrapper is `b.flag_cloth` so the existing sway animation
# drives the whole assembly.
func _make_flag_french(b: Batt) -> void:
	b.flag = Node3D.new()
	add_child(b.flag)
	var gold := Color(0.94, 0.78, 0.28)
	var goldmat := StandardMaterial3D.new()
	goldmat.albedo_color = gold
	goldmat.metallic = 0.6
	goldmat.roughness = 0.28
	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.032
	pcyl.bottom_radius = 0.040
	pcyl.height = 3.1
	pole.mesh = pcyl
	pole.position = Vector3(0, 1.65, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.22, 0.14, 0.07)
	pmat.roughness = 0.8
	pole.material_override = pmat
	b.flag.add_child(pole)
	# the eagle: a plinth, an upright body, a head, and spread wings — all gilt
	var plinth := MeshInstance3D.new()
	plinth.mesh = _box(0.17, 0.11, 0.06)
	plinth.position = Vector3(0, 3.20, 0)
	plinth.material_override = goldmat
	b.flag.add_child(plinth)
	var body := MeshInstance3D.new()
	body.mesh = _box(0.10, 0.21, 0.08)
	body.position = Vector3(0, 3.40, 0)
	body.material_override = goldmat
	b.flag.add_child(body)
	var head := MeshInstance3D.new()
	var hsph := SphereMesh.new()
	hsph.radius = 0.052
	hsph.height = 0.104
	head.mesh = hsph
	head.position = Vector3(0.03, 3.55, 0)
	head.material_override = goldmat
	b.flag.add_child(head)
	for sgn in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		wing.mesh = _box(0.17, 0.22, 0.04)
		wing.position = Vector3(sgn * 0.12, 3.43, 0)
		wing.rotation = Vector3(0, 0, sgn * 0.55)
		wing.material_override = goldmat
		b.flag.add_child(wing)
	# the cloth — three vertical bands, blue at the hoist, white, red at the fly
	var cloth := Node3D.new()
	cloth.position = Vector3(0.66, 2.50, 0)
	b.flag.add_child(cloth)
	b.flag_cloth = cloth
	var bands := [
		[Color(0.13, 0.20, 0.50), -0.467],   # hoist — blue
		[Color(0.93, 0.91, 0.85), 0.0],      # centre — white
		[Color(0.72, 0.12, 0.12), 0.467],    # fly — red
	]
	for bnd in bands:
		var seg := MeshInstance3D.new()
		seg.mesh = _box(0.466, 1.00, 0.018)
		seg.position = Vector3(bnd[1], 0, 0.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = bnd[0]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		seg.material_override = m
		cloth.add_child(seg)
	# a gold wreath device on the white centre
	var wreath := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.13
	tor.outer_radius = 0.19
	tor.rings = 16
	tor.ring_segments = 8
	wreath.mesh = tor
	wreath.rotation_degrees = Vector3(90, 0, 0)
	wreath.position = Vector3(0, 0, 0.015)
	wreath.material_override = goldmat
	cloth.add_child(wreath)
	# a gold fringe along the top and bottom edges
	for fy in [0.525, -0.525]:
		var fringe := MeshInstance3D.new()
		fringe.mesh = _box(1.41, 0.05, 0.02)
		fringe.position = Vector3(0, fy, 0)
		fringe.material_override = goldmat
		cloth.add_child(fringe)

func _make_flag(b: Batt, team: int) -> void:
	if _wmap and team == 0:
		_make_flag_french(b)            # the French carry the tricolore under a gilt eagle
		return
	b.flag = Node3D.new()
	add_child(b.flag)
	var gold := Color(0.94, 0.78, 0.28)
	var goldmat := StandardMaterial3D.new()
	goldmat.albedo_color = gold
	goldmat.metallic = 0.6
	goldmat.roughness = 0.28
	# --- the staff: a tall turned pole that carries the colours WELL above the line ---
	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.032
	pcyl.bottom_radius = 0.040
	pcyl.height = 3.1
	pole.mesh = pcyl
	pole.position = Vector3(0, 1.65, 0)        # butt near the ground, head up at ~3.2m
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.22, 0.14, 0.07)
	pmat.roughness = 0.8
	pole.material_override = pmat
	b.flag.add_child(pole)
	# --- an ornate gilt finial: a boss, a tall spearhead and a cross-bar ---
	var boss := MeshInstance3D.new()
	var bsph := SphereMesh.new()
	bsph.radius = 0.062
	bsph.height = 0.124
	boss.mesh = bsph
	boss.position = Vector3(0, 3.18, 0)
	boss.material_override = goldmat
	b.flag.add_child(boss)
	var finial := MeshInstance3D.new()
	var fcone := CylinderMesh.new()
	fcone.top_radius = 0.0
	fcone.bottom_radius = 0.07
	fcone.height = 0.36
	finial.mesh = fcone
	finial.position = Vector3(0, 3.42, 0)
	finial.material_override = goldmat
	b.flag.add_child(finial)
	var xbar := MeshInstance3D.new()
	var xb := BoxMesh.new()
	xb.size = Vector3(0.26, 0.045, 0.045)
	xbar.mesh = xb
	xbar.position = Vector3(0, 3.22, 0)
	xbar.material_override = goldmat
	b.flag.add_child(xbar)
	# --- gold cords looping down from the head, ending in heavy tassels ---
	for sgn in [-1.0, 1.0]:
		var cord := MeshInstance3D.new()
		var ccyl := CylinderMesh.new()
		ccyl.top_radius = 0.013
		ccyl.bottom_radius = 0.013
		ccyl.height = 0.52
		cord.mesh = ccyl
		cord.position = Vector3(sgn * 0.11, 2.92, 0.05)
		cord.rotation = Vector3(0, 0, sgn * 0.42)
		cord.material_override = goldmat
		b.flag.add_child(cord)
		var tass := MeshInstance3D.new()
		var tcyl := CylinderMesh.new()
		tcyl.top_radius = 0.022
		tcyl.bottom_radius = 0.055
		tcyl.height = 0.17
		tass.mesh = tcyl
		tass.position = Vector3(sgn * 0.22, 2.64, 0.05)
		tass.material_override = goldmat
		b.flag.add_child(tass)

	var nat := ARMY_BLUE if team == 0 else ARMY_RED
	if _wmap:
		nat = _coats_for(team)[int(round(b.inst_col.a * 255.0)) % 4]   # the flag field takes the nationality's coat (4-coat packing)
	var fac := Color(b.inst_col.r, b.inst_col.g, b.inst_col.b)
	# the cloth assembly: one wrapper node so the existing sway/flap animation
	# (which rotates b.flag_cloth as a whole) still drives every part together. Larger now, and
	# flown high near the head of the staff so it streams above the men's heads, not at them.
	var cloth := Node3D.new()
	cloth.position = Vector3(0.66, 2.50, 0)
	b.flag.add_child(cloth)
	b.flag_cloth = cloth
	# the field — the regiment's facing colour blended with the national one
	var field := MeshInstance3D.new()
	var cbox := BoxMesh.new()
	cbox.size = Vector3(1.40, 1.00, 0.018)
	field.mesh = cbox
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = nat.lerp(fac, 0.5)
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	field.material_override = cmat
	cloth.add_child(field)
	# a bold cross device in a cream silk, quartering the field
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color(0.94, 0.91, 0.83)
	cream.cull_mode = BaseMaterial3D.CULL_DISABLED
	var vbar := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.15, 1.00, 0.02)
	vbar.mesh = vb
	vbar.position = Vector3(0.04, 0, 0.004)
	vbar.material_override = cream
	cloth.add_child(vbar)
	var hbar := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(1.40, 0.15, 0.02)
	hbar.mesh = hb
	hbar.position = Vector3(0, 0, 0.004)
	hbar.material_override = cream
	cloth.add_child(hbar)
	# a hoist canton in the facing colour, up by the staff
	var canton := MeshInstance3D.new()
	var canbox := BoxMesh.new()
	canbox.size = Vector3(0.42, 0.40, 0.02)
	canton.mesh = canbox
	canton.position = Vector3(-0.47, 0.27, 0.007)
	var canmat := StandardMaterial3D.new()
	canmat.albedo_color = fac
	canmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canton.material_override = canmat
	cloth.add_child(canton)
	# a gilt laurel wreath ringing the central badge
	var wreath := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.14
	tor.outer_radius = 0.20
	tor.rings = 16
	tor.ring_segments = 8
	wreath.mesh = tor
	wreath.rotation_degrees = Vector3(90, 0, 0)
	wreath.position = Vector3(0.04, 0, 0.015)
	wreath.material_override = goldmat
	cloth.add_child(wreath)
	# the central roundel badge, gold-on-facing
	var roundel := MeshInstance3D.new()
	var rcyl := CylinderMesh.new()
	rcyl.top_radius = 0.125
	rcyl.bottom_radius = 0.125
	rcyl.height = 0.012
	roundel.mesh = rcyl
	roundel.rotation_degrees = Vector3(90, 0, 0)
	roundel.position = Vector3(0.04, 0, 0.013)
	var rolmat := StandardMaterial3D.new()
	rolmat.albedo_color = fac.lerp(gold, 0.45)
	rolmat.metallic = 0.35
	roundel.material_override = rolmat
	cloth.add_child(roundel)
	# a heavy gold bullion fringe all the way round
	for fr in [
		[Vector3(0, 0.525, 0), Vector3(1.47, 0.055, 0.02)],   # top edge
		[Vector3(0, -0.525, 0), Vector3(1.47, 0.055, 0.02)],  # bottom edge
		[Vector3(0.725, 0, 0), Vector3(0.055, 1.05, 0.02)],   # fly edge
	]:
		var fr_mi := MeshInstance3D.new()
		var fr_box := BoxMesh.new()
		fr_box.size = fr[1]
		fr_mi.mesh = fr_box
		fr_mi.position = fr[0]
		fr_mi.material_override = goldmat
		cloth.add_child(fr_mi)
	# heavy tassels at the two fly corners
	for cy in [0.5, -0.5]:
		var ct := MeshInstance3D.new()
		var ctc := CylinderMesh.new()
		ctc.top_radius = 0.022
		ctc.bottom_radius = 0.055
		ctc.height = 0.15
		ct.mesh = ctc
		ct.position = Vector3(0.725, cy, 0)
		ct.material_override = goldmat
		cloth.add_child(ct)

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
	_post_file_closers(b)

# File-closers: post the sergeants/corporals (and any subaltern serving in the ranks) in the
# REAR rank of a line/column — and the INTERIOR of a square — historically where NCOs stood,
# behind the firing line, shielded by the men in front from the fire that takes the front rank
# first (see _kill_some / the ray fire). Only the PLAYER's battalion carries named ranks (the
# fig→man link), so this is what keeps your trained leaders alive through a mauling. The line
# already lands them there by index; this makes it explicit and holds it true in EVERY
# formation (the square especially, where the raw layout would put low-index men on the
# exposed outer face). Swaps only POSITIONS between figs — each man keeps his identity/skill.
func _post_file_closers(b: Batt) -> void:
	if b.roster.is_empty() or b.figs.size() < 8 or b.formation == "skirmish":
		return
	var n := b.figs.size()
	var score := PackedFloat32Array()
	score.resize(n)
	for i in range(n):
		var sl: Vector2 = b.figs[i]["slot"]
		score[i] = (-sl.length()) if b.formation == "square" else (-sl.y)   # higher = safer (rear / interior)
	var ncos: Array = []
	for i in range(n):
		var man = b.figs[i].get("man", null)
		if man != null and String(man["rank"]) in ["Sgt.", "Cpl.", "C/Sgt.", "Lt."]:
			ncos.append(i)
	if ncos.is_empty():
		return
	var order: Array = range(n)
	order.sort_custom(func(a, c): return score[a] > score[c])   # safest slots first
	var want_safe := {}
	for j in range(ncos.size()):
		want_safe[int(order[j])] = true
	var need: Array = []                       # file-closers NOT already in a safe slot
	for i in ncos:
		if not want_safe.has(i):
			need.append(i)
	var ni := 0
	for j in range(ncos.size()):
		if ni >= need.size():
			break
		var safe_i := int(order[j])
		var occ = b.figs[safe_i].get("man", null)
		if occ != null and String(occ["rank"]) in ["Sgt.", "Cpl.", "C/Sgt.", "Lt."]:
			continue                           # this safe slot already holds a file-closer
		var nco_i: int = need[ni]
		if score[nco_i] >= score[safe_i]:
			continue                           # no real improvement (e.g. line ties) — leave him be
		ni += 1
		for key in ["slot", "company", "face"]:   # trade POSITIONS; the man links stay put
			var tmp = b.figs[safe_i][key]
			b.figs[safe_i][key] = b.figs[nco_i][key]
			b.figs[nco_i][key] = tmp

# =============================================================== SKILLS & ROSTER
const SKILL_KEYS := ["reload", "aim", "melee", "discipline", "stamina"]
const LEADER_RANKS := ["Cpl.", "Sgt.", "C/Sgt.", "Lt.", "Capt."]   # the cadre that steadies the men
const NCO_RANKS := ["Sgt.", "Cpl.", "C/Sgt."]                      # file-closers shown behind each company
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

# How many men a unit can bring to bear at the SEAM — its front-rank frontage (a square fights on one
# face). The melee is fought by these men, not the whole battalion, so a narrow line isn't swamped by
# a deep column's full numbers — only the overlap fights, and the wider line laps the flank.
func _contact_men(b: Batt) -> int:
	return maxi(1, int(_dims(b.figs.size(), b.formation).x))

# A man's quality in the press: his bayonet skill, steadied by morale, dulled by weariness.
func _melee_quality(b: Batt) -> float:
	return _melee_factor(b) * clampf(b.morale / 100.0, 0.15, 1.2) * (1.0 - clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.3)
# fatigue tells: tired hands fumble the cartridge and the aim wanders
func _fatigue_reload_mul(b: Batt) -> float:
	return 1.0 + clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.55
func _fatigue_aim_mul(b: Batt) -> float:
	return 1.0 - clampf(b.fatigue / 100.0, 0.0, 1.0) * 0.35
# discipline buys lasting order — a steady battalion has more cohesion to spend before it breaks
func _disc_cohesion(b: Batt) -> float:
	# the order a battalion can hold rises with discipline AND with a full leadership cadre
	return lerpf(72.0, 122.0, clampf(_sk(b, "discipline") / 100.0, 0.0, 1.0)) * lerpf(0.82, 1.0, b._leadership)

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
	var per_coy := maxi(1, int(ceil(float(n) / float(b.companies))))   # men to a company
	for i in range(n):
		var coy := mini(i / per_coy, b.companies - 1)
		var within := i - coy * per_coy        # his place within his own company
		var rank := "Pte."
		if i == 0:
			rank = "Capt."          # you, at the head of the colour company
		elif within == 0:
			rank = "Sgt."           # each company fields its OWN sergeant (a file-closer)
		elif within <= 2:
			rank = "Cpl."           # two corporals to a company
		var lift := 0.0
		if rank == "Capt.": lift = 16.0
		elif rank == "Sgt.": lift = 11.0
		elif rank == "Cpl.": lift = 5.0
		var man := { "name": _rand_name(), "rank": rank, "coy": coy, "xp": 0.0, "kills": 0, "alive": true, "focus": "" }
		for key in SKILL_KEYS:
			man[key] = clampf(_sk(b, key) + lift + randf_range(-12.0, 12.0), 6.0, 99.0)
		b.roster.append(man)
		if i > 0:
			b.figs[i]["man"] = man   # THIS named man IS this soldier on the field (the Capt is you, mounted)
	# the establishment cadre: the leaders the battalion fields at full strength (the denominator
	# the living-leader count is measured against, so the line grows brittle as they fall)
	b._leaders0 = 0
	for m in b.roster:
		if String(m["rank"]) in LEADER_RANKS:
			b._leaders0 += 1
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
	var leaders := 0
	for m in b.roster:
		if not m["alive"]:
			continue
		live += 1
		if String(m["rank"]) in LEADER_RANKS:
			leaders += 1
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
	# LEADERSHIP: the living cadre vs the establishment, scaled to current strength (so ordinary
	# losses keep it ~1.0 — it only sinks when the LEADERS themselves are cut down). Drives the
	# battalion's steadiness in _update_morale / _disc_cohesion / _update_rally.
	if b._leaders0 > 0:
		var sfrac := clampf(float(b.figs.size()) / float(maxi(1, b.start_men)), 0.0, 1.0)
		var expected := maxf(1.0, float(b._leaders0) * sfrac)
		var lead := clampf(float(leaders) / expected, 0.35, 1.0)
		if b.is_player and lead < 0.6 and not b._lead_warned:
			b._lead_warned = true
			_send_player_despatch("[color=#ff9a8a]Your sergeants and officers are falling[/color] — without the file-closers the men begin to waver.", {})
		elif lead >= 0.78:
			b._lead_warned = false        # cadre restored (promotions / recruits) — re-arm the warning
		b._leadership = lead

# Keep the named roster in step with the strength. Musketry now kills the SPECIFIC man whose
# soldier was shot (see _drop_fig, via the fig→man link), so the men who fall are whoever the
# enemy hit — a marksman can be lost. This reconciles any REMAINING shortfall (deaths through
# paths that don't carry the link, e.g. melee) by dropping the rank and file first, then always
# re-derives the battalion profile so the average tracks both casualties and battlefield blooding.
func _sync_roster_losses(b: Batt) -> void:
	if b.roster.is_empty():
		return
	var want := b.figs.size()
	var live := 0
	for m in b.roster:
		if m["alive"]:
			live += 1
	var to_kill := live - want
	if to_kill > 0:
		var order := { "Pte.": 0, "Cpl.": 1, "Sgt.": 2, "C/Sgt.": 3, "Lt.": 4, "Capt.": 5 }
		for tier in range(6):
			if to_kill <= 0:
				break
			for m in b.roster:
				if to_kill <= 0:
					break
				if m["alive"] and int(order.get(m["rank"], 0)) == tier:
					m["alive"] = false
					to_kill -= 1
	_reprofile(b)   # always: the men's average shifts as they fall AND as they blood themselves

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
		var nbat: int = (int(_setup.guns_per_team[team]) if GameConfig.historical != "" else (2 if _inflated else BATTERIES_PER_TEAM))   # historical: the OOB's batteries
		var sites: Array = _team_sites[team]
		for bi in range(nbat):
			var base: Vector3
			if GameConfig.historical != "":
				# the grand battery / massed guns deployed FORWARD, within bombarding range of the
				# enemy line across the valley (the French battery ahead of d'Erlon's corps)
				var bx2 := (float(bi) - (nbat - 1) * 0.5) * 130.0
				base = Vector3(bx2, 0, -320.0 if team == 0 else 470.0)
			elif _inflated or sites.is_empty():
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

# A detailed gun-crew figure (the artillery's own branch dress: brass/buff trim, a round
# forage cap instead of a shako, a cartridge pouch at the hip, no crossbelts or gold lace).
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

	# the crew — detailed gunner figures clustered at the breech (the last is the rammer,
	# who steps up to the muzzle to load). Each crewman is a Node3D wrapping the shared
	# mesh, so the existing per-node crew animation and casualty code keep working unchanged.
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
		if not fm.spent and fm.figs.size() >= 60 and g.pos.distance_to(fm.pos) <= _arty_range:
			return fm
	var best: Batt = null
	var best_score := 1.0e18
	for b in battalions:
		if b.team == g.team or b.figs.size() < 60:
			continue
		var d := g.pos.distance_to(b.pos)
		if d > _arty_range:
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
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95 + _gh(g.pos.x, g.pos.z), 0)
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

# The cannon's muzzle blast — flame, a bank of smoke, a stab of light, the report and the
# ground-shake. Shared by the host (firing for real) and the client (reproducing an FX_GUN event).
func _gun_muzzle_fx(muzzle: Vector3, fwd: Vector3) -> void:
	if cam != null and cam.position.distance_to(muzzle) < LOD_VFAR:
		_emit_flash(muzzle)
		_emit_flash(muzzle)
		_emit_fire(muzzle, fwd)
		_emit_fire(muzzle, fwd)
		for s in range(18):
			_emit_gun_smoke(muzzle + fwd * randf_range(0.0, 0.8), fwd)
		_muzzle_light(muzzle)
	_play_cannon(muzzle)
	var prox := clampf(1.0 - (cam.position.distance_to(muzzle) if cam != null else 1e9) / 160.0, 0.0, 1.0)
	if prox > 0.0:
		_shake = minf(_shake + prox * 0.6, SHAKE_MAX)
		_flash_amt = minf(_flash_amt + prox * 0.14, 0.32)

func _gun_fire(g: Gun, foe: Batt) -> void:
	var fwd := Vector3(sin(g.facing), 0, cos(g.facing))
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95 + _gh(g.pos.x, g.pos.z), 0)
	var d := g.pos.distance_to(foe.pos)
	# muzzle blast: a deep gout of flame and smoke, a stab of light, a heavy report
	g.recoil = 0.55
	_gun_muzzle_fx(muzzle, fwd)
	if GameConfig.mode == "host":
		_fx.append([FX_GUN, muzzle.x, muzzle.y, muzzle.z, fwd.x, fwd.z])   # clients reproduce it
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
			# arrival — plough a lane through whatever stands here
			var dir: Vector3 = s["dir"]
			var impact := Vector3(p.x, 0, p.z)
			_add_scar(impact - dir * 2.0, dir)        # the furrow starts just short of impact
			_plough(impact, dir, int(s["team"]))
			for k in range(3):
				_emit_smoke(Vector3(p.x, 0.3, p.z), Vector3.UP)   # dirt kicked up
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
		_update_raiders(delta)           # native war-bands set their own task, hostile to both sides
		# _commander_task(delta)  [removed for now] the General sends you on tasks / summons you to the push
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
		_musket_snd_left = MUSKET_SND_BUDGET   # refresh the per-frame shot-voice budget
		_cock_snd_left = COCK_SND_BUDGET
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
		_update_supply(delta)            # wagon trains haul materials up; escort missions; interdiction
		_update_combat(delta)            # your own sabre, pistol and mortality
		_update_prestige()               # your renown rises and falls with the butcher's bill
		_update_objective()              # has your personal objective been won?
		_update_battle_flow(delta)       # deployment, army collapse, victory & defeat
		_net_broadcast(delta)
	else:
		# client: no sim — battalions come from the host via _apply_state. We still
		# generate the continuous fire-at-will crackle locally from synced state.
		_musket_snd_left = MUSKET_SND_BUDGET   # refresh the per-frame shot-voice budget (client too)
		_cock_snd_left = COCK_SND_BUDGET
		for b in battalions:
			b.flinch = maxf(0.0, b.flinch - delta * 2.2)
			_client_firing_fx(b, delta)
		_net_send_input(delta)
	if player != null:
		_shake = maxf(_shake, player.flinch * 0.4)   # you FEEL your unit get hit
	_update_ragdolls(delta)
	_update_wounded(delta)
	_update_falling(delta)
	_update_camp_scene(delta)         # pitch/strike the bivouac; the firelight flickers
	_update_drill(delta)              # the volley drill: targets re-set, safety watched
	_update_maneuver_drill(delta)     # the manoeuvre drill: watch for the called formation
	_update_shots(delta)
	_update_drums(delta)
	_update_marching_drums(delta)
	_update_vision(delta)             # fog of war: what the army can see (drives the render + map)
	_render(delta)
	_decay_cinematic(delta)
	_update_cam(delta)
	_update_environment(delta)        # sky, sun, fog, weather follow the clock
	_update_hud()

# Each battalion's drummer beats the march while the unit is on the move: a random
# cadence is struck up when it starts moving and falls silent the moment it halts.
func _update_marching_drums(delta: float) -> void:
	if cam == null:
		return
	var have_drums := not snd_marchdrum.is_empty()
	for b in battalions:
		var moved := b.pos.distance_to(b.last_pos)
		b.last_pos = b.pos
		# the pale haze a marching (or routing) body of men kicks up underfoot — throttled,
		# scaled to strength, and only spawned where the camera can actually see it
		if moved > 0.01 and not b.figs.is_empty() and cam.position.distance_to(b.pos) < DUST_RANGE \
				and randf() < delta * 5.0:
			_emit_march_dust(b)
		if not have_drums:
			continue
		var mp: AudioStreamPlayer3D = b.march_player
		if mp == null:
			continue
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
# SIM-LOD: a battalion beyond this range from the eye is simulated at battalion level —
# it still marches, holds morale, and trades fire/casualties, but not man by man.
const SIM_FULL_RANGE := 1400.0
const SLEEP_TICK := 0.5            # a far (sleeping) battalion is simulated in ~half-second bursts
const PROVINCE_SIZE := 18000.0    # the tactical scene now spans the whole province (±9 km, float-safe)
const TOWN_CAPTURE_RANGE := 480.0 # men this near a town hold/take it
const TOWN_CAPTURE_TIME := 16.0   # seconds of uncontested occupation to flip a town
var field_towns: Array = []       # the province's towns, now CAPTURABLE: {name,pos,size,owner,cap_t,cap_team,disc}
var _cap_cd := 0.0                 # throttle on the capture check

# --- NATIVE RAID PARTIES: small war-bands out of the woodland, hostile to both colonial
# sides alike, that fall on the roads and the towns — a reason to keep a patrol out ---
const RAID_MAX_PARTIES := 3        # never more than this many war-bands abroad at once
const RAID_SPAWN_COOLDOWN := 150.0 # average seconds between spawn attempts (jittered)
const RAID_PARTY_MEN := [65, 120]  # band strength range (min, max) — kept above the 60-man "viable foe" floor
const RAID_DURATION := 70.0        # seconds spent raiding a town before withdrawing
const RAID_MIN_SIZE := 1           # a raided town's size never bleeds below this floor
const RAID_DRAIN_TIME := 12.0      # seconds of presence to bleed one point of a town's size
const RAID_SPEED_MUL := 0.92       # a war-band moves at a hard march, not a parade-ground pace
var raid_spawn_cd := RAID_SPAWN_COOLDOWN * 0.5   # the first band can be a while finding its feet
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
var _team_sites: Array = [[], [], []] # per-team garrison positions (Vector3), one per brigade (raiders never garrison)
var forest_clusters: Array = []   # { pos: Vector3, radius: float } — the woodland scatter, reused as raid spawn ground
var _map_reveal := false          # dev only: reveal the enemy on the province map

func _sim_far(b: Batt) -> bool:
	return cam != null and cam.position.distance_to(b.pos) > SIM_FULL_RANGE

# Battalion-resolution musketry for a distant unit: the WHOLE line's expected fire as one
# figure, no per-man rays. Tuned to land near the per-man result so a battle out of sight
# resolves the same as one in front of you.
func _abstract_fire(b: Batt, delta: float, moving: bool) -> void:
	if b.spent or b.state == "routing" or b.ammo <= 0.0:
		return
	var wpn := _wpn(b)
	var foe := _nearest_enemy_in_range(b, wpn.max_range)
	if foe == null:
		return
	var d := b.pos.distance_to(foe.pos)
	b.has_target = true
	if moving:
		return                                  # no firing on the march, same as the line
	var rounds := float(b.figs.size()) * 0.5 * (delta / wpn.reload_time)   # ~half the men firing
	b.ammo = maxf(0.0, b.ammo - rounds * AMMO_PER_SHOT)
	# the distant rumble of this far fight — heard across the map, ridden toward
	b._far_audio_cd -= delta
	if b._far_audio_cd <= 0.0:
		b._far_audio_cd = randf_range(1.4, 3.2)
		_play_distant_battle(b.pos)
	var hit := clampf(_hit_chance(d, wpn) * _aim_factor(b) * _fatigue_aim_mul(b), 0.0, 0.95)
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
	b.volley_cd = maxf(0.0, b.volley_cd - delta)   # the line reloads between commanded volleys
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
	var wpn := _wpn(b)
	if _sim_far(b):
		_abstract_fire(b, delta, batt_moving)
		return
	var foe := _nearest_enemy_in_range(b, wpn.max_range)
	# guns are targets too: if a live enemy battery is nearer than any battalion in
	# front of us, the line turns its fire on the gunners (a tactical objective)
	var gun_foe := _nearest_enemy_gun_in_range(b, wpn.max_range)
	var aim_gun := false
	if gun_foe != null and (foe == null or b.pos.distance_to(gun_foe.pos) <= b.pos.distance_to(foe.pos)):
		aim_gun = true
	# and CAVALRY: horse in musket range to the front takes priority over everything —
	# the charge must ride through the fire to reach the line
	var cav_foe := _nearest_enemy_cav_in_range(b, wpn.max_range)
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
		tpos = b.pos + Vector3(sin(b.facing), 0, cos(b.facing)) * (wpn.max_range * 0.55)
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
	# STAGGERED VOLLEY: on the officer's word the men don't all fire as one — the shots ripple out over
	# a window set by the battalion's DRILL. Each loaded front-rank man gets his own fire delay; crack
	# troops crash out almost together, raw troops straggle over up to VOLLEY_SPREAD_MAX seconds. The
	# fire_now flag is the one-frame trigger; volley_window then keeps the volley live as it plays out.
	if b.fire_now and not b.rolling and b.volley_window <= 0.0:
		var drill := _sk(b, "reload")                  # the "Drill" skill
		var spread := lerpf(VOLLEY_SPREAD_MAX, VOLLEY_SPREAD_MIN, clampf(drill / 100.0, 0.0, 1.0))
		for f0 in b.figs:
			if (f0["slot"] as Vector2).y >= fire_band:
				# weighted toward the front of the window: a crash, then trailing shots
				f0["volley_t"] = (pow(randf(), 1.6) * spread) if float(f0["reload"]) <= 0.0 else 999.0
		b.volley_window = spread + 0.12
	var commanded := (b.volley_window > 0.0) and (not b.rolling)
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
	var b_aim := _sk(b, "aim")       # the battalion's TRAINED marksmanship — the baseline each man builds on
	var fat_aim := _fatigue_aim_mul(b)   # weary hands shoot worse (a whole-battalion tell)
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
		elif atwill:
			if b.indep_fire:
				# INDEPENDENT fire: a loaded man comes to the present (cocks his lock), holds 1–2 s by
				# his DRILL, then fires — then reloads and does it all again, each man in his own time
				var pt := float(f.get("present_t", -1.0))
				if pt < 0.0:
					var dr: float = _sk(b, "reload")
					f["present_t"] = lerpf(2.0, 1.0, clampf(dr / 100.0, 0.0, 1.0)) * randf_range(0.85, 1.15)
					if vis:
						_play_cock(f["wpos"])
					fire = false
				else:
					pt -= delta
					f["present_t"] = pt
					fire = pt <= 0.0
			else:
				fire = true
		elif commanded:
			var vt := float(f.get("volley_t", 0.0)) - delta   # his place in the ragged ripple
			f["volley_t"] = vt
			fire = vt <= 0.0
		if fire:
			if _wet > 0.0 and randf() < _wet * 0.4:
				f["reload"] = RELOAD_TIME * 0.45 * randf_range(0.7, 1.2)   # damp powder — misfire, re-prime
				continue
			shots += 1
			var w: Vector3 = f["wpos"]
			var mp := w + Vector3(0, 1.35 + _gh(w.x, w.z), 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip (on the slope)
			if atwill:
				if vis:
					_emit_flash(mp)
					_emit_smoke(mp, fwd)
					_emit_muzzle_bloom(mp, fwd)
					_play_shot_line(mp)       # individual crack (budgeted)
			else:
				massed_men += 1
				if vis:
					_emit_flash(mp)
					_emit_smoke(mp, fwd)
					_emit_smoke(mp, fwd)
					_emit_muzzle_bloom(mp, fwd)
					_play_shot_line(mp)       # each musket in the volley reports too (budgeted)
					volley_pts.append(mp)
			# THIS man's own range to the enemy decides his shot, lifted by enfilade and a held volley
			var mfwd := (tpos.x - w.x) * fwd.x + (tpos.z - w.z) * fwd.z   # forward range to the enemy line
			if mfwd < 2.0:
				mfwd = Vector2(w.x - tpos.x, w.z - tpos.z).length()
			# INDIVIDUAL marksmanship. For the PLAYER's battalion every soldier IS a named man on
			# the roster (f["man"], linked in _build_roster), so he fires with HIS OWN trained aim —
			# the marksman you drilled in camp is the deadly shot here, and his battlefield hits
			# harden his eye AND show on his roster record (he becomes a marksman the hard way).
			# Other battalions' men carry a stable personal deviation (f["marks"]) instead.
			var man = f.get("man", null)
			var maim: float
			if man != null and bool(man["alive"]):
				maim = float(man["aim"])
			else:
				var pm := float(f.get("marks", 1.0e9))
				if pm > 1.0e8:
					pm = randfn(0.0, 14.0)
					f["marks"] = pm
				maim = clampf(b_aim + pm, 6.0, 99.0)
			var mhc := _hit_chance(mfwd, wpn) * enf_mult * lerpf(0.7, 1.34, maim / 100.0) * fat_aim
			if held_close:
				mhc *= HELD_VOLLEY_HIT
			var felled0 := felled
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
					var sd := _scatter_dir(fwd, wpn.yaw_sd, wpn.pitch_sd)
					var hit := _ray_hit_world(Vector3(w.x, 1.3, w.z), sd, wpn.max_range, b.team)
					if not hit.is_empty():
						kills += 1
						felled += 1
						_drop_fig(hit["b"], hit["i"], sd)
			# a telling shot hardens the man's eye and grows his tally — for a NAMED soldier it
			# shows on the camp roster, so the veterans who do the killing become your marksmen
			if felled > felled0:
				if man != null:
					man["aim"] = minf(99.0, float(man["aim"]) + 0.04)
					man["kills"] = int(man["kills"]) + 1
				else:
					f["marks"] = minf(float(f.get("marks", 0.0)) + 0.06, 30.0)
			var rmul := INDEP_RELOAD_MUL if atwill else 1.0   # at-will fire loads more raggedly
			f["reload"] = wpn.reload_time * shaken * b.exp_mul * _fatigue_reload_mul(b) * rmul * randf_range(0.78, 1.3)
			f["present_t"] = -1.0        # he's fired — reload, then come to the present again (independent fire)
			f["flinch"] = maxf(float(f["flinch"]), randf_range(0.7, 1.0))   # FIRING RECOIL: the kick of his own shot jolts him
		else:
			f["reload"] = 0.0            # stand loaded, musket levelled, waiting
	b.fire_now = false                   # the trigger is one-frame; volley_window now drives the ripple
	b.volley_window = maxf(0.0, b.volley_window - delta)
	b._volley_boom_cd = maxf(0.0, b._volley_boom_cd - delta)
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
	# the CRASH — the report, smoke-wash and screen-shake of a volley — only when a real mass fires
	# together this frame (a well-drilled, tight volley), and throttled so its handful of frames read
	# as ONE crack. A ragged volley never trips the threshold, so it's heard as the crackle of its
	# individual shots (the per-man _play_shot_line above) — exactly the loose, undrilled fire we want.
	if massed and b._volley_boom_cd <= 0.0:
		b._volley_boom_cd = 0.2
		if vis and not volley_pts.is_empty() and massed_men >= VOLLEY_CRASH_MIN:
			var sources := clampi(volley_pts.size() / 16, 3, 12)
			for k in range(sources):
				_play_volley(volley_pts[int((float(k) + 0.5) / float(sources) * volley_pts.size())])
			_volley_cinematic(b, volley_pts)
			# YOUR own volley lands as a punch — bigger when you held it to point-blank
			if b.is_player:
				_shake = minf(_shake + (0.5 if held_close else 0.28), SHAKE_MAX)
				_flash_amt = minf(_flash_amt + (0.3 if held_close else 0.12), 0.6)
		if GameConfig.mode == "host":
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

# the weapon a battalion carries — lazily resolved from its weapon_id and cached on the Batt
func _wpn(b: Batt) -> Weapon:
	if b.wpn == null:
		b.wpn = Weapon.get_weapon(b.weapon_id)
	return b.wpn

func _hit_chance(d: float, wpn: Weapon) -> float:
	if d >= wpn.max_range:
		return 0.0
	var t := 1.0 - d / wpn.max_range       # 1 at the muzzle, 0 at max range
	return wpn.hit_point_blank * pow(t, wpn.hit_falloff)

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
	# the living NCO/officer cadre steadies the men: spirits recover faster, the line gives way
	# at a lower nerve and sheds its order more slowly. As the leaders fall, all of this decays.
	var lead := b._leadership
	b.calm_t += delta
	if b.calm_t > 4.0:               # NERVE returns once the fire slackens (cohesion does NOT)
		var rate := MORALE_RECOVER * (0.7 if b.state == "routing" else 1.0) * lerpf(0.72, 1.12, lead)
		b.morale = minf(100.0, b.morale + rate * delta)
	# DISCIPLINE tells under pressure: a steady regiment holds at a lower nerve, loses its
	# order more slowly when it does run, and tired men crack sooner
	var disc := clampf(_sk(b, "discipline") / 100.0, 0.0, 1.0)
	var fat := clampf(b.fatigue / 100.0, 0.0, 1.0)
	var rout_thr := ROUT_THRESHOLD * lerpf(1.28, 0.74, disc) * lerpf(1.22, 0.95, lead) * (1.0 + fat * 0.18)
	# running wears the unit out fast, and a rout that lasts too long becomes permanent
	if b.state == "routing":
		b.rout_t += delta
		b.cohesion -= COH_ROUT_RATE * lerpf(1.3, 0.72, disc) * lerpf(1.2, 0.9, lead) * delta
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

# ============================================================ the LIVING encampment
# When the battalion makes camp (and the field is safe), a bivouac is pitched around it —
# rows of ridge tents, campfires with a cook-pot, stacked arms, supply crates, and a few men
# resting off-duty by the fires. Struck the instant camp breaks or the enemy comes near. It's
# the player's ONE battalion at ONE spot near the camera, so it's individual nodes (like the
# hero), never the affordability-keystone MultiMeshes.
func _update_camp_scene(delta: float) -> void:
	var show := player != null and player.encamped and _camp_safe(player)
	if not show:
		if _camp_node != null:
			_strike_camp_scene()
		return
	if _camp_node == null or player.pos.distance_to(_camp_scene_at) > 70.0:
		_strike_camp_scene()
		_build_camp_scene(player.pos, player.facing)
	# the fires breathe: flame height and firelight flicker, and bite harder against the dark
	for f in _camp_fires:
		var s := float(f["seed"])
		var fl := 0.80 + 0.20 * sin(_t * 9.0 + s) * sin(_t * 5.3 + s * 1.7) + randf() * 0.05
		var flame: MeshInstance3D = f["flame"]
		if is_instance_valid(flame):
			flame.scale = Vector3(0.9 + 0.1 * fl, fl, 0.9 + 0.1 * fl)
		var light: OmniLight3D = f["light"]
		if is_instance_valid(light):
			light.light_energy = (1.4 + 1.2 * fl) * (0.6 + 0.9 * _night)
	_animate_camp_actors()         # the men come to life: cooking, pacing, fetching, drilling

func _strike_camp_scene() -> void:
	if _camp_node != null:
		_camp_node.queue_free()
		_camp_node = null
	_camp_fires.clear()
	_camp_actors.clear()

func _camp_part(mesh: Mesh, gx: float, gz: float, ly: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(gx, _gh(gx, gz) + ly, gz)
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_camp_node.add_child(mi)
	return mi

func _build_camp_scene(center: Vector3, facing: float) -> void:
	_camp_node = Node3D.new()
	add_child(_camp_node)
	_camp_scene_at = center
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var coat_col: Color = GameConfig.UNIFORM_COLS[clampi(GameConfig.militia_uniform, 0, GameConfig.UNIFORM_COLS.size() - 1)]
	var canvas := _hero_mat(Color(0.80, 0.76, 0.66), 0.96)
	var canvas2 := _hero_mat(Color(0.72, 0.67, 0.57), 0.96)
	var pole := _hero_mat(Color(0.30, 0.21, 0.12), 0.9)
	var wood := _hero_mat(Color(0.34, 0.24, 0.13), 0.95)
	var ember := _hero_mat(Color(0.20, 0.09, 0.05), 1.0)
	var flame_mat := _hero_mat(Color(1.0, 0.55, 0.14), 0.5)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.52, 0.14)
	flame_mat.emission_energy_multiplier = 3.2
	var iron := _hero_mat(Color(0.11, 0.11, 0.13), 0.6, 0.4)
	var coat := _hero_mat(coat_col.lightened(0.05), 0.7)
	var skin := _hero_mat(Color(0.74, 0.57, 0.44), 0.8)
	# rows of ridge tents behind the line
	for rowi in range(2):
		var back := 26.0 + float(rowi) * 13.0
		for k in range(-2, 3):
			var tp := center - fwd * back + right * (float(k) * 9.0 + float(rowi % 2) * 4.5)
			var cm: Material = canvas if (k + rowi) % 2 == 0 else canvas2
			_camp_tent(tp.x, tp.z, facing, cm, pole)
	var gear := _hero_mat(Color(0.12, 0.12, 0.14), 0.6, 0.35)   # muskets, tools, kit
	# campfires with a cook-pot: a cook crouches and STIRS at each, a couple of men warm by it
	for k in range(-1, 2):
		var fp := center - fwd * 15.0 + right * (float(k) * 17.0)
		_camp_fire(fp.x, fp.z, wood, ember, flame_mat, iron)
		var cookp := fp - fwd * 1.5
		var cook := _camp_man(cookp.x, cookp.z, atan2(fp.x - cookp.x, fp.z - cookp.z), "cook", coat, skin, gear)
		cook["phase"] = randf() * TAU
		cook["by"] = _gh(cookp.x, cookp.z)
		_camp_actors.append(cook)
		for m in range(2):
			var ang := PI * 0.6 + PI * float(m) + float(k) * 0.5
			var mp := fp + Vector3(cos(ang), 0, sin(ang)) * 2.6
			var rest := _camp_man(mp.x, mp.z, atan2(fp.x - mp.x, fp.z - mp.z), "rest", coat, skin, gear)
			rest["phase"] = randf() * TAU
			_camp_actors.append(rest)
	# stacked arms (tripods of muskets) dressed in front of the tents
	for k in range(-2, 3):
		var sp := center - fwd * 20.0 + right * (float(k) * 9.0 + 4.5)
		_camp_stacked_arms(sp.x, sp.z, facing, iron, wood)
	# a supply dump off one flank, with men carrying wood/water to and from the fires
	var supply := center - fwd * 33.0 + right * 17.0
	for k in range(3):
		var cp := supply + right * (float(k % 2) * 2.6) - fwd * float(k) * 2.4
		_camp_part(_box(2.0, 1.5, 2.0), cp.x, cp.z, 0.75, wood, Vector3(0, randf() * 0.7, 0))
	for s in range(2):
		var fire0 := center - fwd * 15.0 + right * (float(s * 2 - 1) * 17.0)
		var fe := _camp_man(supply.x, supply.z, 0.0, "fetch", coat, skin, gear)
		fe["phase"] = randf() * TAU
		fe["a"] = Vector3(supply.x, 0, supply.z)
		fe["b"] = Vector3(fire0.x, 0, fire0.z)
		fe["face_b"] = atan2(fire0.x - supply.x, fire0.z - supply.z)
		fe["face_a"] = atan2(supply.x - fire0.x, supply.z - fire0.z)
		_camp_actors.append(fe)
	# sentries pacing a beat along the camp's front, muskets shouldered
	for s in range(2):
		var mid := center - fwd * 7.0 + right * ((float(s) * 2.0 - 1.0) * 23.0)
		var a0 := mid - right * 6.0
		var b0 := mid + right * 6.0
		var sen := _camp_man(a0.x, a0.z, 0.0, "sentry", coat, skin, gear)
		sen["phase"] = randf() * TAU
		sen["a"] = Vector3(a0.x, 0, a0.z)
		sen["b"] = Vector3(b0.x, 0, b0.z)
		sen["face_b"] = atan2(b0.x - a0.x, b0.z - a0.z)
		sen["face_a"] = atan2(a0.x - b0.x, a0.z - b0.z)
		_camp_actors.append(sen)
	# a squad at drill off one flank — present and shoulder arms in slow unison, the sergeant watching
	var dctr := center - fwd * 22.0 - right * 24.0
	for d in range(6):
		var dp := dctr + right * (float(d) * 1.5)
		var dm := _camp_man(dp.x, dp.z, facing, "drill", coat, skin, gear)
		dm["phase"] = float(d) * 0.05
		_camp_actors.append(dm)
	var sgtp := dctr - fwd * 3.0 + right * 4.0
	var sgt := _camp_man(sgtp.x, sgtp.z, atan2(dctr.x - sgtp.x, dctr.z - sgtp.z), "rest", coat, skin, gear)
	sgt["phase"] = randf() * TAU
	_camp_actors.append(sgt)

func _camp_tent(gx: float, gz: float, facing: float, canvas: Material, pole: Material) -> void:
	# a ridge tent (prism) with a guy pole at the door and a dark entrance slit
	_camp_part(_prism(4.6, 2.7, 5.2), gx, gz, 1.35, canvas, Vector3(0, facing, 0))
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var dp := Vector3(gx, 0, gz) + fwd * 2.7
	_camp_part(_box(0.10, 2.9, 0.10), dp.x, dp.z, 1.45, pole)                 # ridge pole at the door
	_camp_part(_box(1.1, 1.9, 0.08), dp.x, dp.z, 0.95, _hero_mat(Color(0.10, 0.09, 0.08), 1.0), Vector3(0, facing, 0))  # door

func _camp_fire(gx: float, gz: float, wood: Material, ember: Material, flame_mat: Material, iron: Material) -> void:
	# a ring of embers, crossed logs, a flame, a cook-pot on a tripod, and the firelight
	_camp_part(_cylm(0.95, 0.95, 0.18, 10), gx, gz, 0.06, ember)              # ash/ember ring
	for a in range(3):
		var ang := PI * float(a) / 3.0
		_camp_part(_box(1.7, 0.18, 0.18), gx, gz, 0.22, wood, Vector3(0, ang, 0.05))   # crossed logs
	var flame := _camp_part(_cylm(0.0, 0.42, 1.1, 8), gx, gz, 0.7, flame_mat)  # the flame (a cone)
	# a cook-pot slung on a tripod over the fire
	for a in range(3):
		var ang := TAU * float(a) / 3.0
		var lp := Vector3(gx, 0, gz) + Vector3(cos(ang), 0, sin(ang)) * 0.7
		_camp_part(_box(0.06, 1.9, 0.06), lp.x, lp.z, 0.9, iron, Vector3(cos(ang) * 0.5, 0, sin(ang) * 0.5))   # tripod leg
	_camp_part(_cylm(0.30, 0.38, 0.42, 10), gx, gz, 1.0, iron)                # the pot
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.66, 0.36)
	light.omni_range = 16.0
	light.light_energy = 2.0
	light.position = Vector3(gx, _gh(gx, gz) + 1.0, gz)
	_camp_node.add_child(light)
	_camp_fires.append({ "flame": flame, "light": light, "seed": randf() * TAU })

func _camp_stacked_arms(gx: float, gz: float, facing: float, iron: Material, wood: Material) -> void:
	# three muskets stood on their butts, leaning together at the muzzle — arms piled for rest
	for a in range(3):
		var ang := facing + TAU * float(a) / 3.0
		var lean := 0.22
		_camp_part(_box(0.05, 1.7, 0.05), gx + cos(ang) * 0.18, gz + sin(ang) * 0.18, 0.85, iron,
			Vector3(cos(ang) * lean, 0, sin(ang) * lean))

# An articulated camp man: a body, a head and two SHOULDER-PIVOTED arms (Node3D pivots, so the
# arms swing about the shoulder), wrapped in one Node3D so the whole man can pace/walk. Returned
# as a dict of handles the animator drives each frame by his `kind` (rest/cook/sentry/fetch/drill).
func _camp_man(gx: float, gz: float, face: float, kind: String, coat: Material, skin: Material, gear: Material) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3(gx, _gh(gx, gz), gz)
	node.rotation.y = face
	_camp_node.add_child(node)
	var crouch := kind == "cook"
	var bh := 0.66 if crouch else 0.98
	var by := 0.50 if crouch else 0.80
	var hy := 0.92 if crouch else 1.42
	var sh_y := 0.66 if crouch else 1.16
	var body := MeshInstance3D.new()
	body.mesh = _capm(0.19, bh)
	body.material_override = coat
	body.position = Vector3(0, by, 0.0)
	if crouch:
		body.rotation.x = 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = _sph(0.135)
	head.material_override = skin
	head.position = Vector3(0, hy, (0.12 if crouch else 0.0))
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(head)
	var pivs := {}
	for side in [[-0.21, "armL"], [0.21, "armR"]]:
		var piv := Node3D.new()
		piv.position = Vector3(float(side[0]), sh_y, (0.08 if crouch else 0.0))
		node.add_child(piv)
		var arm := MeshInstance3D.new()
		arm.mesh = _capm(0.057, 0.46)
		arm.material_override = coat
		arm.position = Vector3(0, -0.21, 0)
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piv.add_child(arm)
		pivs[String(side[1])] = piv
	if kind == "sentry":
		var musket := MeshInstance3D.new()
		musket.mesh = _box(0.05, 1.6, 0.05)
		musket.material_override = gear
		musket.position = Vector3(0.21, 1.0, 0.10)
		musket.rotation.z = 0.06
		musket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(musket)
	return { "node": node, "head": head, "armL": pivs["armL"], "armR": pivs["armR"], "kind": kind }

func _animate_camp_actors() -> void:
	for a in _camp_actors:
		var node = a.get("node", null)
		if node == null or not is_instance_valid(node):
			continue
		var ph := float(a.get("phase", 0.0))
		var armR = a.get("armR", null)
		var armL = a.get("armL", null)
		match String(a.get("kind", "")):
			"rest":
				node.rotation.z = sin(_t * 1.0 + ph) * 0.035            # shifts his weight, warms his hands
				if armR != null: armR.rotation.x = -0.32 + sin(_t * 0.8 + ph) * 0.12
				if armL != null: armL.rotation.x = -0.28 + sin(_t * 0.8 + ph + 1.0) * 0.10
			"cook":
				if armR != null:
					armR.rotation.x = -1.05 + sin(_t * 3.2 + ph) * 0.32  # stirring the pot
					armR.rotation.z = cos(_t * 3.2 + ph) * 0.32
				node.position.y = float(a.get("by", node.position.y)) + absf(sin(_t * 1.6 + ph)) * 0.02
			"sentry":
				_walk_actor(a, node, ph, 0.45, armR, armL)
			"fetch":
				_walk_actor(a, node, ph, 0.62, armR, armL)
			"drill":
				var lvl := clampf(sin(_t * 0.5 + ph), 0.0, 1.0)         # present .. shoulder arms, in unison
				if armR != null: armR.rotation.x = -1.45 * lvl
				if armL != null: armL.rotation.x = -1.45 * lvl

func _walk_actor(a: Dictionary, node, ph: float, speed: float, armR, armL) -> void:
	var a0: Vector3 = a["a"]
	var b0: Vector3 = a["b"]
	var arg := _t * speed + ph
	var u := 0.5 + 0.5 * sin(arg)
	var p := a0.lerp(b0, u)
	node.position = Vector3(p.x, _gh(p.x, p.z) + absf(sin(_t * 4.2 + ph)) * 0.03, p.z)
	node.rotation.y = float(a["face_b"]) if cos(arg) >= 0.0 else float(a["face_a"])   # face the way he steps
	if armR != null: armR.rotation.x = sin(_t * 5.0 + ph) * 0.3
	if armL != null: armL.rotation.x = -sin(_t * 5.0 + ph) * 0.3

# small primitive-mesh factories for the camp props (single instances, not instanced)
func _cylm(rt: float, rb: float, h: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = sides
	c.rings = 0
	return c

func _capm(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = maxf(height, radius * 2.0 + 0.01)
	c.radial_segments = 8
	c.rings = 3
	return c

func _mesh_child(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ============================================================ the VOLLEY DRILL (hands-on)
# Straw men are set up at the butts in front of the battalion; you call Present (V) and Fire
# (F) yourself. Each volley is MARKED on how many men fired together (synchronisation) and how
# well it fell on the beat (a present, then a held pause, then fire) — crisp volleys harden the
# battalion's reload/aim/discipline (and the named men with them), ragged ones earn little. The
# straw is knocked flat by good shooting and set back up after a moment so the drill runs on.
func _begin_drill() -> void:
	if player == null or player.figs.is_empty():
		return
	if not _camp_safe(player):
		_send_player_despatch("[color=#ff9a8a]The enemy stands too near to drill.[/color]", {})
		return
	_close_camp()
	_drill_on = true
	_drill_score = 50.0
	_drill_volleys = 0
	_drill_gain = 0.0
	_drill_present_t = -10.0
	_build_drill_targets()
	_send_player_despatch("[color=#ffe9a8]VOLLEY DRILL[/color] — targets at the butts. [color=#cfe0ff]Present (V)[/color], hold the beat, then [color=#cfe0ff]Fire (F)[/color]. Open camp (C) to dismiss.", {})

func _end_drill(summary := true) -> void:
	if not _drill_on:
		return
	_drill_on = false
	_clear_drill_targets()
	if summary:
		_send_player_despatch("[color=#9fe0a0]Drill dismissed.[/color]  %d volleys · drill %d/100 · +%.0f skill earned." % [_drill_volleys, int(round(_drill_score)), _drill_gain], {})

func _clear_drill_targets() -> void:
	if _drill_node != null:
		_drill_node.queue_free()
		_drill_node = null
	_drill_targets.clear()

func _build_drill_targets() -> void:
	_clear_drill_targets()
	_drill_node = Node3D.new()
	add_child(_drill_node)
	var fwd := Vector3(sin(player.facing), 0, cos(player.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var base := player.pos + fwd * 52.0
	var n := 12
	for i in range(n):
		var off := (float(i) - float(n - 1) * 0.5) * 2.3
		var p := base + right * off
		var node := _make_straw_target(p, player.facing + PI)
		_drill_targets.append({ "node": node, "alive": true, "down_t": 0.0 })

func _make_straw_target(p: Vector3, face: float) -> Node3D:
	var t := Node3D.new()
	t.position = Vector3(p.x, _gh(p.x, p.z), p.z)
	t.rotation.y = face
	_drill_node.add_child(t)
	var frame := _hero_mat(Color(0.34, 0.24, 0.13), 0.95)
	var straw := _hero_mat(Color(0.74, 0.66, 0.36), 1.0)
	var dark := _hero_mat(Color(0.30, 0.26, 0.18), 1.0)
	for sx in [-0.55, 0.55]:
		_mesh_child(t, _box(0.08, 2.0, 0.08), Vector3(sx, 1.0, 0), frame)        # frame post
	_mesh_child(t, _box(1.25, 0.08, 0.08), Vector3(0, 1.9, 0), frame)            # crossbar
	_mesh_child(t, _cylm(0.16, 0.20, 1.2, 8), Vector3(0, 1.05, 0), straw)        # straw body
	_mesh_child(t, _sph(0.18), Vector3(0, 1.82, 0), straw)                       # straw head
	_mesh_child(t, _box(0.42, 0.12, 0.30), Vector3(0, 1.2, 0), dark)             # a dark belt to aim at
	return t

func _update_drill(delta: float) -> void:
	if not _drill_on:
		return
	if player == null or player.figs.is_empty() or not _camp_safe(player):
		_end_drill()                       # broken off if the enemy comes up
		return
	# knocked-down straw men are stood back up after a moment, so the exercise can run on
	for tgt in _drill_targets:
		if not bool(tgt["alive"]):
			tgt["down_t"] = float(tgt["down_t"]) - delta
			if float(tgt["down_t"]) <= 0.0:
				tgt["alive"] = true
				var node: Node3D = tgt["node"]
				if is_instance_valid(node):
					node.rotation = Vector3(0, player.facing + PI, 0)

func _knock_targets(frac: float) -> int:
	var standing: Array = []
	for tgt in _drill_targets:
		if bool(tgt["alive"]):
			standing.append(tgt)
	standing.shuffle()
	var k: int = mini(int(round(frac * float(standing.size()))), standing.size())
	for i in range(k):
		var tgt = standing[i]
		tgt["alive"] = false
		tgt["down_t"] = randf_range(2.5, 4.5)
		var node: Node3D = tgt["node"]
		if is_instance_valid(node):
			node.rotation = Vector3(-1.3, player.facing + PI, 0)   # struck — flat on its back
	return k

func _score_drill_volley() -> void:
	var b := player
	var total := maxi(1, b.figs.size())
	var ready := 0
	var w_aim := _wpn(b).aim_lead
	for f in b.figs:
		if float(f["reload"]) <= w_aim:
			ready += 1
	var sync := float(ready) / float(total)               # the fraction loaded & firing as one
	var dt := _t - _drill_present_t
	var cadence := 0.15                                    # firing without a present is ragged
	if dt < 4.0:
		cadence = clampf(1.0 - absf(dt - 1.1) / 1.1, 0.0, 1.0)   # crispest ~1.1s after "Present!"
	var quality := clampf(sync * 0.62 + cadence * 0.38, 0.0, 1.0)
	_drill_volleys += 1
	_drill_score = lerpf(_drill_score, quality * 100.0, 0.5)
	var dr := quality * 0.9
	var dd := quality * 0.7
	var aim := _sk(b, "aim")
	var hitfrac := clampf(aim / 100.0 * 0.5 + sync * 0.5, 0.0, 1.0)
	var hits := _knock_targets(hitfrac)
	var da := quality * 0.45 + float(hits) * 0.05
	b.skill["reload"] = minf(96.0, _sk(b, "reload") + dr)
	b.skill["discipline"] = minf(96.0, _sk(b, "discipline") + dd)
	b.skill["aim"] = minf(96.0, aim + da)
	b.exp_mul = _reload_factor(b)
	_drill_gain += dr + dd + da
	if not b.roster.is_empty():
		for m in b.roster:
			if m["alive"]:
				m["reload"] = clampf(float(m["reload"]) + dr, 6.0, 99.0)
				m["discipline"] = clampf(float(m["discipline"]) + dd, 6.0, 99.0)
				m["aim"] = clampf(float(m["aim"]) + da, 6.0, 99.0)
	var word := "Ragged!" if quality < 0.45 else ("Steady." if quality < 0.72 else "Crisp volley!")
	var col := "ff9a8a" if quality < 0.45 else ("ffcf6e" if quality < 0.72 else "9fe0a0")
	_send_player_despatch("[color=#%s][Drill] %s[/color]  %d hits · drill %d/100 · +%.1f reload +%.1f aim +%.1f disc" % [col, word, hits, int(round(_drill_score)), dr, da, dd], {})

# ============================================================ the MANOEUVRE DRILL (hands-on)
# The drill-master calls a formation; you must pass the order yourself (Q ▸ Formation) and get
# the battalion dressed in it. The exercise TIMES each manoeuvre from the word to the moment
# the men are settled in the called formation — quick, clean changes harden discipline and
# stamina (and the named men with them); a sluggish one earns little. Forming square against
# a sudden cavalry alarm is the drill that saves a battalion, so it's called the hardest.
func _begin_maneuver_drill() -> void:
	if player == null or player.figs.is_empty():
		return
	if not _camp_safe(player):
		_send_player_despatch("[color=#ff9a8a]The enemy stands too near to drill.[/color]", {})
		return
	if _drill_on:
		_end_drill(false)                  # only one drill at a time
	_close_camp()
	_mdrill_on = true
	_mdrill_score = 50.0
	_mdrill_count = 0
	_mdrill_gain = 0.0
	_mdrill_cycle = 0
	_send_player_despatch("[color=#ffe9a8]MANOEUVRE DRILL[/color] — on the word, pass the order ([color=#cfe0ff]Q ▸ Formation[/color]) and get the men dressed. Open camp (C) to dismiss.", {})
	_mdrill_call()

func _mdrill_call() -> void:
	var seq := ["square", "line", "column", "line"]
	var want: String = seq[_mdrill_cycle % seq.size()]
	_mdrill_cycle += 1
	if want == player.formation:
		want = "column" if want != "column" else "line"   # never call the formation already held
	_mdrill_target = want
	_mdrill_call_t = _t
	_mdrill_await = true
	_send_player_despatch("[color=#cfe0ff]► FORM %s![/color]" % want.to_upper(), {})

func _end_maneuver_drill(summary := true) -> void:
	if not _mdrill_on:
		return
	_mdrill_on = false
	_mdrill_await = false
	if summary:
		_send_player_despatch("[color=#9fe0a0]Drill dismissed.[/color]  %d manoeuvres · drill %d/100 · +%.0f skill earned." % [_mdrill_count, int(round(_mdrill_score)), _mdrill_gain], {})

func _update_maneuver_drill(_delta: float) -> void:
	if not _mdrill_on:
		return
	if player == null or player.figs.is_empty() or not _camp_safe(player):
		_end_maneuver_drill()
		return
	if _mdrill_await:
		var elapsed := _t - _mdrill_call_t
		if player.formation == _mdrill_target and _men_settled(player):
			_mdrill_finish(elapsed, true)
		elif elapsed > 32.0:
			_mdrill_finish(elapsed, false)        # too slow — the manoeuvre is marked a failure
	elif _t >= _mdrill_next_t:
		_mdrill_call()

func _mdrill_finish(elapsed: float, ok: bool) -> void:
	_mdrill_count += 1
	_mdrill_await = false
	_mdrill_next_t = _t + 2.5                      # a breath before the next word
	var b := player
	var quality := 0.0
	if ok:
		var par := 12.0 if _mdrill_target == "square" else 8.0   # square takes longest to form
		quality = clampf(1.0 - maxf(0.0, elapsed - par) / par, 0.15, 1.0)
	_mdrill_score = lerpf(_mdrill_score, quality * 100.0, 0.5)
	var dd := quality * 1.0                        # discipline — clean drill is disciplined drill
	var ds := quality * 0.8                        # stamina — the marching about hardens the legs
	b.skill["discipline"] = minf(96.0, _sk(b, "discipline") + dd)
	b.skill["stamina"] = minf(96.0, _sk(b, "stamina") + ds)
	_mdrill_gain += dd + ds
	if not b.roster.is_empty():
		for m in b.roster:
			if m["alive"]:
				m["discipline"] = clampf(float(m["discipline"]) + dd, 6.0, 99.0)
				m["stamina"] = clampf(float(m["stamina"]) + ds, 6.0, 99.0)
	if not ok:
		_send_player_despatch("[color=#ff9a8a][Drill] Too slow — the men were caught out of formation.[/color]", {})
		return
	var word := "Sluggish." if quality < 0.45 else ("Steady." if quality < 0.72 else "Smartly done!")
	var col := "ff9a8a" if quality < 0.45 else ("ffcf6e" if quality < 0.72 else "9fe0a0")
	_send_player_despatch("[color=#%s][Drill] %s formed in %.1fs — %s[/color]  +%.1f discipline +%.1f stamina" % [col, _mdrill_target.capitalize(), elapsed, word, dd, ds], {})

# how well the battalion is dressed: the fraction of men settled at their formation slots
func _men_settled(b: Batt) -> bool:
	if b.figs.is_empty():
		return true
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var ok := 0
	for f in b.figs:
		var slot: Vector2 = f["slot"]
		var tx := b.pos.x + right.x * slot.x + fwd.x * slot.y
		var tz := b.pos.z + right.z * slot.x + fwd.z * slot.y
		var w: Vector3 = f["wpos"]
		if Vector2(w.x - tx, w.z - tz).length() < 2.5:
			ok += 1
	return float(ok) / float(b.figs.size()) > 0.85

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
	det.weapon_id = b.weapon_id        # ...and carries the regiment's weapon (skirmishing riflemen!)
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
			b.morale = minf(100.0, b.morale + RALLY_RATE * lerpf(0.7, 1.15, b._leadership) * delta)
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

# Gold lace for the hussars and lancers, white metal for the light dragoons, a duller
# brass for the heavy dragoons — same "trim" idiom the mounted commanders use, just one
# per arm of service rather than one per rank.
const CAV_TRIM_PER_TYPE := [
	Color(0.83, 0.68, 0.21), Color(0.80, 0.80, 0.82), Color(0.74, 0.62, 0.32), Color(0.83, 0.68, 0.21),
]

func _spawn_cavalry() -> void:
	var ntypes := CAV_TYPE_DATA.size()
	# decide each team's regiments and which arm each one rides BEFORE sizing any
	# MultiMesh — every regiment of a given arm on a team shares that arm's instanced
	# horse+rider (one MultiMesh per team per arm, never per-regiment: the affordability
	# keystone still holds, there are just four buckets per team instead of one).
	var types_per_team: Array = []
	for team in [0, 1]:
		var ncav: int = (int(_setup.cav_per_team[team]) if GameConfig.historical != "" else (4 if _inflated else CAV_PER_TEAM))   # historical: the OOB's regiments
		var types: Array = []
		for r in range(ncav):
			types.append(r % ntypes)
		types_per_team.append(types)
	var horse_mesh := _mount_horse_mesh()      # one shared horse, like the commanders ride
	var horse_mat := _mount_horse_shader()
	# rider mesh/material depend only on the arm, not the team — build each arm's once
	# and let both teams' buckets share it (same idiom as horse_mesh/horse_mat above).
	var rider_meshes: Array = []
	var rider_mats: Array = []
	for ct in range(ntypes):
		rider_meshes.append(_cav_rider_mesh(ct))
		rider_mats.append(_cav_rider_shader(CAV_TRIM_PER_TYPE[ct], ct))
	for team in [0, 1]:
		cav_horse_mm[team].resize(ntypes)
		cav_rider_mm[team].resize(ntypes)
		var types: Array = types_per_team[team]
		var coat := team_color(team).lightened(0.12)
		for ct in range(ntypes):
			var nreg: int = types.count(ct)
			# size EVERY arm (even one with no starting regiments) with spare slots, so a Stables
			# can raise fresh regiments of any arm mid-campaign (see _muster_cavalry)
			var n := (nreg + CAV_REINFORCE_HEADROOM) * _cav_men
			var hmi := MultiMeshInstance3D.new()
			var hmm := MultiMesh.new()
			hmm.transform_format = MultiMesh.TRANSFORM_3D
			hmm.use_colors = true
			hmm.mesh = horse_mesh
			hmm.instance_count = n
			hmi.multimesh = hmm
			hmi.material_override = horse_mat
			add_child(hmi)
			cav_horse_mm[team][ct] = hmm
			var rmi2 := MultiMeshInstance3D.new()
			var rmm := MultiMesh.new()
			rmm.transform_format = MultiMesh.TRANSFORM_3D
			rmm.use_colors = true
			rmm.mesh = rider_meshes[ct]
			rmm.instance_count = n
			rmi2.multimesh = rmm
			rmi2.material_override = rider_mats[ct]
			add_child(rmi2)
			cav_rider_mm[team][ct] = rmm
			for i in range(n):
				hmm.set_instance_transform(i, _zero_xf())
				rmm.set_instance_transform(i, _zero_xf())
				hmm.set_instance_color(i, team_color(team))   # shabraque: the army's colour
				rmm.set_instance_color(i, coat)                # coat: the army's colour
	# the regiments — massed in two wings on the army's flanks, behind the line
	var wing: float = 520.0 if _inflated else 1600.0   # on the flanks of the (tighter) line
	for team in [0, 1]:
		var z := -320.0 if team == 0 else 320.0
		var face := 0.0 if team == 0 else PI
		var fwd := Vector3(sin(face), 0, cos(face))
		var rightv := Vector3(fwd.z, 0, -fwd.x)
		var types: Array = types_per_team[team]
		var ncav: int = types.size()
		var half := maxi(1, ncav / 2)
		var sites: Array = _team_sites[team]
		for r in range(ncav):
			var c := Cav.new()
			c.team = team
			c.idx = team * CAV_PER_TEAM + r
			c.cav_type = types[r]
			var side := -1.0 if r < half else 1.0
			var rank := r % half
			if GameConfig.historical != "":
				# the cavalry reserve, ranked up in lines of 8 behind the army's centre
				var col := r % 8
				var ln := r / 8
				c.pos = Vector3((float(col) - 3.5) * 165.0, 0, z - fwd.z * (220.0 + float(ln) * 105.0))
			elif _inflated or sites.is_empty():
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
	var files := int(ceil(_cav_men / 2.0))
	var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	for i in range(_cav_men):
		var fi := i % files
		var ra := i / files
		var slot := Vector2((float(fi) - (files - 1) * 0.5) * CAV_SP + randf_range(-0.12, 0.12),
			(float(ra) - 0.5) * CAV_SP * 1.6 + randf_range(-0.15, 0.15))
		var w := c.pos + right * slot.x + fwd * slot.y
		c.troopers.append({ "slot": slot, "wpos": Vector3(w.x, 0, w.z), "ph": randf() * TAU })

# Each arm rides at its own pace and rallies on its own clock — see CAV_TYPE_DATA.
func _cav_trot(c: Cav) -> float:
	return CAV_TYPE_DATA[c.cav_type]["trot"]

func _cav_gallop(c: Cav) -> float:
	return CAV_TYPE_DATA[c.cav_type]["gallop"]

func _cav_rally_time(c: Cav) -> float:
	return CAV_RALLY_TIME * float(CAV_TYPE_DATA[c.cav_type]["rally_mult"])

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
		c.scout_cd = maxf(0.0, c.scout_cd - delta)
		match c.state:
			"reserve":
				_cav_move(c, c.reserve_pos, _cav_trot(c), delta)
				if _battle_begun and c.decide_cd <= 0.0:
					c.decide_cd = CAV_DECIDE * randf_range(0.8, 1.2)
					_cav_decide(c)
					# AUTO-PICKETS: a light regiment with no charge to make ranges forward to screen
					# the army's front, so the side isn't blind. Heavier horse stay back as the punch.
					if c.state == "reserve" and c.scout_cd <= 0.0 \
							and float(CAV_TYPE_DATA[c.cav_type]["scout"]) >= 1.05:
						c.scout_cd = randf_range(14.0, 26.0)
						_cav_begin_scout(c, c.reserve_pos + _team_front(c.team) * SCOUT_DIST)
			"scouting":
				# ride out to the scout point sweeping vision; turn for home if enemy horse closes
				if _nearest_enemy_cav_dist(c.pos, c.team) < SCOUT_THREAT:
					c.state = "retiring"
				else:
					_cav_move(c, c.scout_goal, _cav_trot(c) * 1.15, delta)
					if Vector2(c.pos.x - c.scout_goal.x, c.pos.z - c.scout_goal.z).length() < 14.0:
						c.state = "retiring"      # reached the vantage — ride back (vision swept en route)
			"charging":
				var tp := _cav_target_pos(c)
				if tp == Vector3.INF:
					c.state = "retiring"   # the target is gone
				elif c.troopers.size() < 45:
					c.state = "retiring"   # too many saddles emptied — the charge falters
				else:
					_cav_move(c, tp, _cav_gallop(c), delta)
					if Vector2(c.pos.x - tp.x, c.pos.z - tp.z).length() < CAV_CONTACT + 4.0:
						_cav_resolve(c)
						c.state = "retiring"   # the shock is delivered — peel off and re-form, don't ride through
			"retiring":
				_cav_move(c, c.reserve_pos, _cav_trot(c), delta)
				if Vector2(c.pos.x - c.reserve_pos.x, c.pos.z - c.reserve_pos.z).length() < 8.0:
					c.state = "rallying"
					c.rally_t = _cav_rally_time(c)
			"rallying":
				c.rally_t -= delta
				if c.rally_t <= 0.0:
					c.state = "reserve"
			"fled":
				var away := Vector3(c.pos.x, 0, -900.0 if c.team == 0 else 900.0)
				_cav_move(c, away, _cav_gallop(c) * 0.8, delta)

# YOUR squadron: it rallies on you and keeps with you, and when you sound the charge
# it gallops home at the enemy you pointed it at, then reins in to re-form on you.
func _update_player_cav(c: Cav, delta: float) -> void:
	if c.state == "charging":
		var tp := _cav_target_pos(c)
		if tp == Vector3.INF or c.troopers.size() < 45:
			c.state = "rallying"
			c.rally_t = _cav_rally_time(c) * 0.5
		else:
			_cav_move(c, tp, _cav_gallop(c), delta)
			if Vector2(c.pos.x - tp.x, c.pos.z - tp.z).length() < CAV_CONTACT + 4.0:
				_cav_resolve(c)
				c.state = "rallying"         # the shock delivered — the horses are blown
				c.rally_t = _cav_rally_time(c)
		return
	if c.state == "rallying":
		c.rally_t -= delta
		if c.rally_t <= 0.0:
			c.state = "reserve"
	# rallying / reserve / retiring: form on your officer and ride where he rides
	var anchor := off_pos - Vector3(sin(off_vis), 0, cos(off_vis)) * 9.0
	var far := off_pos.distance_to(c.pos)
	var spd := _cav_gallop(c) if far > 40.0 else (_cav_trot(c) if far > 6.0 else 0.0)
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
			and randf() < delta * 4.0 * (speed / _cav_gallop(c)):
		var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
		var right := Vector3(fwd.z, 0, -fwd.x)
		var width := minf(float(c.troopers.size()) * 1.2, 70.0)
		for _i in range(clampi(c.troopers.size() / 40, 1, 3)):
			var p := c.pos - fwd * 1.0 + right * randf_range(-width * 0.5, width * 0.5)
			p.y = _gh(p.x, p.z) + 0.05
			_emit_dust(p, fwd)

# the direction toward the enemy for a team (team 0 deploys at -Z facing +Z; team 1 the reverse)
func _team_front(team: int) -> Vector3:
	return Vector3(0, 0, 1) if team == 0 else Vector3(0, 0, -1)

# send a regiment ranging to a vantage point (clamped to the province), sweeping vision en route
func _cav_begin_scout(c: Cav, goal: Vector3) -> void:
	c.scout_goal = Vector3(
		clampf(goal.x, _MAP_WMIN.x, _MAP_WMAX.x), 0.0,
		clampf(goal.z, _MAP_WMIN.y, _MAP_WMAX.y))
	c.state = "scouting"

# PLAYER ORDER (B): send the nearest free light-cavalry regiment to scout toward where you look.
# Host/single does it directly; a client routes the request to the host through the net channel.
func _send_scouts() -> void:
	if player == null:
		return
	var fwd := -Vector3(sin(_cam_yaw), 0, cos(_cam_yaw))   # your line of sight, flattened
	var goal := off_pos + fwd * SCOUT_DIST
	if authoritative:
		_host_send_scouts(player.team, goal, off_pos, true)
	else:
		_pending_net_order = { "kind": "scout", "x": goal.x, "z": goal.z }   # the host carries it out

# HOST: pick the nearest free light-cav regiment of `team` to `ref_pos` and send it scouting to `goal`.
func _host_send_scouts(team: int, goal: Vector3, ref_pos: Vector3, tell: bool) -> void:
	var best: Cav = null
	var bd := 1.0e9
	for c in cavalry:
		if c.team != team or c.spent or c.player:
			continue
		if c.state != "reserve" and c.state != "rallying":
			continue
		if float(CAV_TYPE_DATA[c.cav_type]["scout"]) < 1.05:
			continue                                       # light horse only — the army's eyes
		var d := c.pos.distance_to(ref_pos)
		if d < bd:
			bd = d
			best = c
	var mine: bool = player != null and team == player.team
	if best == null:
		if tell and mine:
			_send_player_despatch("[color=#ffe9a8]No light horse free to scout.[/color]", {})
		return
	best.scout_cd = 30.0                                    # don't auto-retask it straight away
	_cav_begin_scout(best, goal)
	if tell and mine:
		_send_player_despatch("[color=#9fe0a0]%s ride out to scout ahead.[/color]" % String(CAV_TYPE_DATA[best.cav_type]["name"]), {})

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
# skirmishers, a shaken line out of square, an unsupported battery. Each arm has its
# own eye for it: hussars/light dragoons (the fast scouting horse) range further and
# relish a rout or a loose skirmish screen; heavy dragoons (the battering-ram reserve)
# look for a real fight — a steady, formed target worth their weight; lancers favour
# anything not bristling with bayonets in square, where their reach tells.
func _cav_decide(c: Cav) -> void:
	var scout: float = CAV_TYPE_DATA[c.cav_type]["scout"]
	var best = null
	var best_kind := ""
	var best_score := 0.0
	for e in cavalry:                       # countercharge enemy horse on the move
		if e.team == c.team or e.spent or e.state != "charging":
			continue
		var d := c.pos.distance_to(e.pos)
		if d < CAV_CHARGE_RANGE * 1.4 * scout:
			var s := 3.0 - d * 0.004
			if s > best_score:
				best_score = s; best = e; best_kind = "cav"
	for b in battalions:
		if b.team == c.team or b.figs.size() < 60:
			continue
		var d2 := c.pos.distance_to(b.pos)
		if d2 > CAV_CHARGE_RANGE * scout:
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
			s2 = 1.25                       # a steady LINE is charge-worthy — ride in to break it or force square
		match c.cav_type:
			0, 1:   # hussars / light dragoons: keenest on a rout or a skirmish screen
				if b.state == "routing" or b.skirmish:
					s2 *= 1.3
			2:      # heavy dragoons: the shock arm, happiest pitching into a formed fight
				if b.formation != "square" and not b.skirmish and b.state != "routing":
					s2 *= 1.2
			3:      # lancers: the reach tells against anything not yet in square
				if b.formation != "square":
					s2 *= 1.15
		s2 -= d2 * 0.003
		if s2 > best_score:
			best_score = s2; best = b; best_kind = "batt"
	for g in guns:                          # sabre an unsupported battery
		if g.team == c.team or g.dead:
			continue
		var d3 := c.pos.distance_to(g.pos)
		if d3 > CAV_CHARGE_RANGE * scout:
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

# The moment of impact. `shock` weights the blow each arm delivers (heavy dragoons and
# a lancer's couched reach hit hardest; hussars lightest); `sturdy` divides the losses
# the regiment itself takes (heavy dragoons soak it best; lancers, all reach and no
# armour once the lances are through, take it worst).
func _cav_resolve(c: Cav) -> void:
	var near := cam != null and cam.position.distance_to(c.pos) < LOD_VFAR
	var clash := c.pos + Vector3(0, 1.0, 0)
	var shock: float = CAV_TYPE_DATA[c.cav_type]["shock"]
	var sturdy: float = CAV_TYPE_DATA[c.cav_type]["sturdy"]
	match c.target_kind:
		"batt":
			var t: Batt = c.target
			if t.formation == "square" and t.state != "routing":
				# the horses refuse the wall of bayonets — the charge breaks on the square
				_cav_lose(c, int(c.troopers.size() * randf_range(0.14, 0.2) / sturdy), near)
				_client_volley(t)                       # the square's face delivers its fire
				t.morale -= 2.0
			else:
				# closing fire from the defenders, then the shock goes home. The DEFENDER'S melee
				# quality (bayonet skill × nerve) decides the exchange the same way it does on foot:
				# a steady, well-drilled line resists the sabres and bites the horse; a poor one is
				# ridden down. (resist ~1 for an average defender; >1 tough, <1 ragged.)
				var resist := clampf(_melee_quality(t) / 0.85, 0.55, 1.6)
				if t.ammo > 0.0 and t.state != "routing" and not t.skirmish:
					_client_volley(t)
					_cav_lose(c, int(c.troopers.size() * randf_range(0.06, 0.12) * resist / sturdy), near)
				var weak := t.state != "steady" or t.skirmish or t.morale < 48.0
				var frac := 0.42 if weak else 0.22
				var inf_kills := mini(int(c.troopers.size() * frac * shock / resist * randf_range(0.8, 1.2)), t.figs.size() - 1)
				t.kills_pending += inf_kills
				t.shot_from = c.pos
				t.morale -= (34.0 if weak else 22.0) * shock / resist
				t.flinch = minf(t.flinch + 1.4, 1.6)
				t.calm_t = 0.0
				if weak:
					t.morale = minf(t.morale, 22.0)     # broken under the sabres
				else:
					_cav_lose(c, int(c.troopers.size() * randf_range(0.05, 0.09) * resist / sturdy), near)
		"gun":
			var g: Gun = c.target
			while not g.dead:
				_drop_crewman(g, c.pos)                 # the gunners are sabred at their piece
		"cav":
			var e: Cav = c.target
			var e_shock: float = CAV_TYPE_DATA[e.cav_type]["shock"]
			var e_sturdy: float = CAV_TYPE_DATA[e.cav_type]["sturdy"]
			var my_p := float(c.troopers.size()) * shock
			var en_p := float(e.troopers.size()) * e_shock * (1.15 if e.state == "charging" else 0.85)
			var i_win := my_p * randf_range(0.85, 1.15) > en_p
			_cav_lose(c, int(c.troopers.size() * (0.10 if i_win else 0.22) / sturdy), near)
			_cav_lose(e, int(e.troopers.size() * (0.22 if i_win else 0.10) / e_sturdy), near)
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

# Both horse and rider are now the commanders' ground-origin mesh (built feet-at-y=0,
# like _build_horse()/_build_officer_colonel()), not bare capsules, so the seat is
# placed straight at (x, _gh(x,z), z) exactly as _render_commanders() does — no more
# manual capsule-centre y-offsets, and the same scaled basis drives both meshes so the
# rider always sits exactly on his horse. mount_scale (CAV_TYPE_DATA) makes the heavy
# dragoons' mounts visibly the biggest on the field, the hussars' the lightest.
func _render_cavalry(delta: float) -> void:
	for team in [0, 1]:
		var counts := []
		counts.resize(CAV_TYPE_DATA.size())
		counts.fill(0)
		for c in cavalry:
			if c.team != team or c.spent:
				continue
			if not PLAYER_SEES_ALL and player != null and c.team != player.team and not c._spotted:
				continue                     # fog of war: unseen enemy horse isn't drawn
			var hmm: MultiMesh = cav_horse_mm[team][c.cav_type]
			var rmm: MultiMesh = cav_rider_mm[team][c.cav_type]
			if hmm == null:
				continue
			var i: int = counts[c.cav_type]
			# DISTANCE CULLING: cavalry are far higher-poly than the foot (a horse + a rider each), so
			# cull whole regiments past the impression range and thin the ranks hard with distance —
			# a back-of-field squadron draws a fraction of its troopers. (Render only — no sim effect.)
			var cd := cam.position.distance_to(c.pos) if cam != null else 0.0
			# HYSTERESIS: a wide dead-band on the cull boundary (drop at VFAR+90, re-show at VFAR) so a
			# regiment hovering at the edge doesn't strobe in and out of existence frame to frame.
			if cd > LOD_VFAR + (90.0 if c._drawn else 0.0):
				c._drawn = false
				continue                     # too far to bother — its instances stay zeroed below
			c._drawn = true
			var cstep := 1
			if cd > LOD_FAR + LOD_HYST:
				cstep = clampi(3 + int((cd - LOD_FAR) / 70.0), 3, 14)
			elif cd > LOD_MID + LOD_HYST:
				cstep = 2
			var fwd := Vector3(sin(c.facing), 0, cos(c.facing))
			var right := Vector3(fwd.z, 0, -fwd.x)
			var galloping := c.state == "charging" or c.state == "fled"
			var spd := _cav_gallop(c) if galloping else _cav_trot(c)
			var mscale: float = CAV_TYPE_DATA[c.cav_type]["mount_scale"]
			var ti := -1
			for tr in c.troopers:
				if i >= hmm.instance_count:
					break
				ti += 1
				if ti % cstep != 0:
					continue                 # thinned out at this range
				var slot: Vector2 = tr["slot"]
				var tgt := c.pos + right * slot.x + fwd * slot.y
				var w: Vector3 = (tr["wpos"] as Vector3).move_toward(tgt, spd * 1.35 * delta)
				tr["wpos"] = w
				var mv := tgt - w
				var yaw := atan2(mv.x, mv.z) if mv.length() > 0.2 else c.facing
				var ph := float(tr["ph"])
				var bob := absf(sin(_t * (9.0 if galloping else 5.0) + ph)) * (0.14 if galloping else 0.06)
				var basis := Basis(Vector3.UP, yaw).scaled(Vector3(mscale, mscale, mscale))
				var seat := Vector3(w.x, _gh(w.x, w.z) + bob, w.z)
				var xf := Transform3D(basis, seat)
				hmm.set_instance_transform(i, xf)
				rmm.set_instance_transform(i, xf)
				i += 1
			counts[c.cav_type] = i
		for ct in range(CAV_TYPE_DATA.size()):
			var hmm: MultiMesh = cav_horse_mm[team][ct]
			var rmm: MultiMesh = cav_rider_mm[team][ct]
			if hmm == null:
				continue
			for j in range(counts[ct], hmm.instance_count):
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

# distance to the nearest enemy horse that is ACTUALLY CHARGING (a real, imminent threat — the cue
# to throw square). A regiment merely standing in reserve nearby is NOT counted, so the line doesn't
# freeze every time loose cavalry wanders past.
func _nearest_charging_cav_dist(p: Vector3, team: int) -> float:
	var bd := 1.0e9
	for c in cavalry:
		if c.team == team or c.spent or c.state != "charging":
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

# Build the brigades straight from the AUTHORED OOB indices: one Brigade per (team, oob_brigade); the
# engine "division" is a unique (corps, division) so the divisional AI commands the real divisions.
# (The army → division → brigade tiers map the OOB's army → corps/division → brigade; corps is kept on
# the brigade for reference.) So at Waterloo the formations fight as d'Erlon's I Corps, Picton's
# division, the Guard, etc., not as proximity-chunked blocks.
func _brigades_from_oob() -> void:
	var bcount := [0, 0, 0]                  # brigades placed per team -> br.idx
	var div_idx: Array = [{}, {}, {}]        # per team: (corps*1000+division) -> sequential division
	var brig_map := {}                       # team*100000 + oob_brigade -> Brigade
	for b in battalions:
		if b.independent or b.oob_brigade < 0:
			continue
		var team: int = b.team
		var bkey: int = team * 100000 + b.oob_brigade
		var br: Brigade = brig_map.get(bkey, null)
		if br == null:
			br = Brigade.new()
			br.team = team
			br.corps = b.oob_corps
			var dmap: Dictionary = div_idx[team]
			var dkey: int = b.oob_corps * 1000 + b.oob_division
			if not dmap.has(dkey):
				dmap[dkey] = dmap.size()
			br.division = int(dmap[dkey])
			br.idx = team * BRIGADES_PER_TEAM + bcount[team]
			bcount[team] += 1
			br.line2 = false
			brig_map[bkey] = br
			brigades.append(br)
		b.brigade = br
		br.battalions.append(b)
		if b.is_player:
			br.is_player = true
	for br in brigades:
		if br.battalions.is_empty():
			continue
		br.anchor = _live_center(br.battalions)
		br.objective = br.anchor
		br.facing = (br.battalions[0] as Batt).facing   # each formation keeps its authored facing (Prussians face west)
		br.face_want = br.facing

func _assign_brigades() -> void:
	_build_dead_horses()
	brigades.clear()
	# build the brigades from the AUTHORED order of battle if one was set (historical battles), so the
	# armies fight as their real corps/divisions/brigades; otherwise chunk each team's battalions in
	# spawn order (the campaign field, which reproduces the fixed-index OOB).
	var use_oob := false
	for b in battalions:
		if b.oob_brigade >= 0:
			use_oob = true
			break
	if use_oob:
		_brigades_from_oob()
	else:
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
				br.face_want = br.facing
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
	# the two army commanders
	armies.clear()
	for team in [0, 1]:
		var army := Army.new()
		army.team = team
		armies.append(army)
	# NATIONAL DOCTRINE + TEMPERAMENT + ROLE — resolve each formation's nationality to the
	# doctrine it fights by, roll its commander a temperament, then derive boldness and the
	# strategic war aim. This replaces the old single random aggression knob.
	_resolve_doctrine()
	_build_key_points()        # terrain goals: strongpoints, ridges and woods the AI deploys on and fights for

# TERRAIN KEY POINTS (Phase 2) — the ground that shapes a Napoleonic battle: strongpoints (farms,
# villages, towns) to garrison, ridge crests to hold (the reverse slope sheltering the line behind),
# and woods to rest a flank on. Built once per battle from the terrain; the command AI forms onto
# them, anchors its flanks on them, and a defender clings to the high ground.
func _build_key_points() -> void:
	key_points.clear()
	if _wmap:
		var sp := [
			[Vector3(-680, 0, 200), 1.00, "strongpoint"],   # Hougoumont — the fought-over château
			[Vector3(-20, 0, 300), 1.00, "strongpoint"],    # La Haye Sainte — the farm on the road
			[Vector3(1120, 0, -760), 0.75, "strongpoint"],  # Plancenoit — where the Prussians debouch
			[Vector3(880, 0, 320), 0.70, "strongpoint"],    # Papelotte — the Allied-left farm
			[Vector3(0, 0, 820), 0.55, "strongpoint"],      # Mont-Saint-Jean — behind the centre
			[Vector3(36, 0, -560), 0.45, "strongpoint"],    # La Belle Alliance — the French centre
		]
		for s in sp:
			key_points.append({"pos": _gh3(s[0] as Vector3), "value": float(s[1]), "kind": String(s[2]), "radius": 95.0, "owner": -1})
		# the two ridges run east–west (along x); mark crest points along each
		var kx := -1400.0
		while kx <= 1500.0:
			key_points.append({"pos": _gh3(Vector3(kx, 0, 560.0)), "value": 0.80, "kind": "ridge", "radius": 240.0, "owner": -1})   # Mont-Saint-Jean (Allied)
			key_points.append({"pos": _gh3(Vector3(kx, 0, -560.0)), "value": 0.60, "kind": "ridge", "radius": 240.0, "owner": -1})  # La Belle Alliance (French)
			kx += 350.0
	else:
		for t in field_towns:
			key_points.append({"pos": t["pos"] as Vector3, "value": clampf(0.45 + float(t["size"]) * 0.18, 0.45, 1.0), "kind": "strongpoint", "radius": 150.0, "owner": int(t["owner"])})
		for f in forest_clusters:
			key_points.append({"pos": f["pos"] as Vector3, "value": 0.45, "kind": "wood", "radius": float(f["radius"]), "owner": -1})

# the highest defensive ground within `radius` of `center` — a crest to form a line on. Samples a
# ring at two radii plus the centre (cheap; only called at the army-decision cadence, not per frame).
func _best_high_ground(center: Vector3, radius: float) -> Vector3:
	var best := center
	var bh := _gh(center.x, center.z)
	for i in range(12):
		var a := TAU * float(i) / 12.0
		for r in [radius * 0.5, radius]:
			var p := Vector3(center.x + cos(a) * r, 0.0, center.z + sin(a) * r)
			var h := _gh(p.x, p.z)
			if h > bh:
				bh = h
				best = p
	return _gh3(best)

# the nearest key point of the given kinds within max_d (kinds empty = any), or null
func _nearest_key_point(pos: Vector3, kinds: Array, max_d: float):
	var best = null
	var bd := max_d
	for kp in key_points:
		if not kinds.is_empty() and not (String(kp["kind"]) in kinds):
			continue
		var d: float = pos.distance_to(kp["pos"] as Vector3)
		if d < bd:
			bd = d
			best = kp
	return best

# Phase 2 — THE GROUND. The army commander tags each brigade's place in the line and picks the
# ground it should form on: the flank brigades rest on the nearest strongpoint or wood out to
# their open side, and a DEFENDING army forms on the best high ground (the crest, sheltering the
# reverse slope). Stored on br.terrain_anchor/hold_high and honoured GENTLY by _brigade_decide so
# it shapes where the line stands but never stops an attack going home.
func _terrain_plan(army, mine: Array, _foe: Array) -> void:
	if mine.is_empty():
		return
	var defend: bool = army.role == "defend"
	for i in range(mine.size()):
		var br = mine[i]
		br.on_flank = -1 if i == 0 else (1 if i == mine.size() - 1 else 0)
		br.hold_high = defend
		br.terrain_anchor = Vector3.INF
		var c: Vector3 = _brigade_center(br)
		var anchor := Vector3.INF
		# the flank brigades rest on the strongest terrain feature out to their open side
		if br.on_flank != 0:
			var kp = _nearest_key_point(c, ["strongpoint", "wood", "town"], 750.0)
			if kp != null:
				var kpp: Vector3 = kp["pos"]
				if signf(kpp.x - c.x) == float(br.on_flank) or absf(kpp.x - c.x) < 120.0:
					anchor = kpp
		# a defender otherwise forms on the high ground near where it stands
		if anchor == Vector3.INF and defend:
			anchor = _best_high_ground(c, 220.0)
		br.terrain_anchor = anchor

# Gently bend a brigade's objective onto the ground the army chose for it (Phase 2). Lateral
# only for a flank rest (keeps the advance going), and a depth clamp for a defender holding the
# crest — never applied to an assault, so an attack still drives home.
func _apply_terrain(br, _center: Vector3) -> void:
	var ta = br.terrain_anchor
	if ta == Vector3.INF:
		return
	# FLANK REST: once SETTLED (not while marching), ease the line laterally onto the strongpoint/
	# wood, keeping its forward depth. Skipped while advancing so it never curves a marching column.
	if br.on_flank != 0 and br.posture in ["engage", "hold"]:
		br.objective.x = lerpf(br.objective.x, ta.x, 0.25)
	# DEFENDER HOLDS THE HIGH GROUND: standing on the crest, don't advance off it into the valley
	if br.hold_high and br.posture in ["engage", "hold", "refuse", "fix"] and br.enemy != null:
		var to_foe: Vector3 = _brigade_center(br.enemy) - ta
		to_foe.y = 0.0
		if to_foe.length() > 1.0:
			to_foe = to_foe.normalized()
			var fwd: float = (br.objective - ta).dot(to_foe)   # how far forward of the crest the objective sits
			if fwd > 0.0:
				br.objective -= to_foe * fwd                   # pull it back onto the crest line

# ANTICIPATION (Phase 2) — read where the enemy's WEIGHT is gathering and how committed his advance
# is, from his observed momentum (not just his current position). Only KNOWN (scouted) enemy
# brigades count, so the read is built on the army's lagged, fogged picture — a feint or a hidden
# flank march goes unseen until cavalry sights it. `threat_x` = the lateral axis of his main effort;
# `threat_mass` = the share of his strength actually bearing down on us (0..1 confidence).
func _read_enemy_intent(army, mine: Array, foe: Array) -> void:
	if mine.is_empty() or foe.is_empty():
		return
	var our_c := Vector3.ZERO
	for b in mine:
		our_c += _brigade_center(b)
	our_c /= float(mine.size())
	var sum_w := 0.0
	var sum_wx := 0.0
	var adv_str := 0.0
	var tot_str := 0.0
	for fb in foe:
		if not _brigade_known(fb, army.team):
			continue                                   # fog: an unscouted column can't be read
		var c: Vector3 = _brigade_center(fb)
		var vel := Vector3.ZERO
		if fb.obs_prev != Vector3.INF:
			vel = c - fb.obs_prev
		fb.obs_prev = c
		var toward: Vector3 = our_c - c
		toward.y = 0.0
		var closing := 0.0
		if toward.length() > 1.0 and vel.length() > 0.01:
			closing = vel.normalized().dot(toward.normalized())
		var st := float(_brigade_strength(fb))
		tot_str += st
		if closing > 0.15:
			adv_str += st
		var w := st * (1.6 if closing > 0.15 else 0.6)   # an advancing enemy weighs more than a standing one
		sum_w += w
		sum_wx += w * c.x
	if sum_w <= 0.0:
		return
	var tx := sum_wx / sum_w
	army.threat_x = tx if army.threat_t <= 0.0 else lerpf(army.threat_x, tx, 0.4)   # smooth the lagged picture
	army.threat_mass = clampf(adv_str / maxf(1.0, tot_str), 0.0, 1.0)
	army.threat_t = _t

# Resolve doctrine + temperament onto every brigade, division and army from the troops'
# nationality, and set each army's boldness (doctrine + temper) and strategic role.
func _resolve_doctrine() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = (GameConfig.match_seed if GameConfig.match_seed != 0 else 1) ^ 0x5151d0c7
	for br in brigades:
		br.nation = _dominant_nation(br.battalions)
		br.doctrine = _doctrine_for(br.nation)
		br.temper = TEMPERS[rng.randi() % TEMPERS.size()]
	for dv in divisions:
		var dbatts: Array = []
		for dbr in _division_brigades(dv):
			dbatts.append_array(dbr.battalions)
		dv.nation = _dominant_nation(dbatts)
		dv.doctrine = _doctrine_for(dv.nation)
		dv.temper = TEMPERS[rng.randi() % TEMPERS.size()]
	for army in armies:
		army.nation = _army_doctrine_group(army.team)        # the army's doctrine GROUP (e.g. "british")
		army.doctrine = DOCTRINE.get(army.nation, DOCTRINE["line"])
		army.temper = TEMPERS[rng.randi() % TEMPERS.size()]
		army.aggression = clampf(float(army.doctrine["aggr"]) + float(army.temper["aggr"]) + rng.randf_range(-0.05, 0.05), 0.12, 0.95)
	_assign_army_roles()

# The strategic posture each army opens with. Phase 1 sets it from doctrine + boldness (a
# bold, open-field doctrine takes the initiative; a defensive, reverse-slope one stands and
# holds; otherwise a meeting engagement). Phase 2 refines this from terrain and who holds the
# ground. The war aim leans on it but isn't ruled by it, so an approximate role is fine.
func _assign_army_roles() -> void:
	for army in armies:
		var aggr := float(army.aggression)
		var reverse: bool = bool(army.doctrine.get("reverse", false))
		if aggr >= 0.66 or (aggr >= 0.55 and not reverse):
			army.role = "attack"           # a genuinely bold commander, or an aggressive doctrine, takes the initiative
		elif reverse and aggr < 0.60:
			army.role = "defend"           # a firepower / reverse-slope army stands and holds its ground
		else:
			army.role = "meeting"

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

# FOG OF WAR for the AI: a brigade is KNOWN to `by_team` only if that side has lately SEEN one of
# its battalions (b._spotted = "seen by my enemy" = seen by by_team, with AI_MEMORY of recall). So
# an unscouted column is invisible to the enemy commander — feints and flank marches go unseen.
func _brigade_known(o, by_team: int) -> bool:
	for b in o.battalions:
		if b.spent or b.figs.is_empty():
			continue
		if b._spotted or (_t - b._intel_t) < AI_MEMORY:
			return true
	return false

# The nearest enemy brigade THIS brigade actually knows about (lately scouted), not omniscient truth.
func _nearest_known_enemy_brigade(br):
	var c := _brigade_center(br)
	var best = null
	var bd := 1.0e18
	for o in brigades:
		if o.team == br.team or _brigade_live(o) == 0:
			continue
		if not _brigade_known(o, br.team):
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
		dv.target = _nearest_known_enemy_brigade(brs[brs.size() / 2])   # aim only at a scouted enemy
		dv.objective = _division_center(dv)

# The general's plan for his assaulting division: lead, supports, and a held reserve.
func _division_assault(dv, brs: Array, army) -> void:
	var tgt = army.main.mission_target if army.main != null else null
	if tgt == null or _brigade_live(tgt) == 0:
		tgt = _nearest_known_enemy_brigade(brs[0])   # the spearhead aims at a scouted enemy only
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
	_read_enemy_intent(army, mine, foe)   # ANTICIPATION: read where the enemy's weight is gathering
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
	# ANTICIPATION: refuse the flank his weight is GATHERING against (read from his momentum,
	# threat_x) — bend the flank back before he physically overlaps it, not after.
	if army.threat_t > 0.0 and army.threat_mass > 0.35:
		if army.threat_x < _brigade_center(ml).x - 60.0 and ml.mission in ["fix", "attack"]:
			ml.mission = "refuse"
		elif army.threat_x > _brigade_center(mr).x + 60.0 and mr.mission in ["fix", "attack"]:
			mr.mission = "refuse"
	# ANTICIPATION: which corps' sector the enemy's main effort is bearing down on — its reserve
	# is committed to MEET the blow, before its own first line has been bled white.
	var threat_corps := -1
	if army.threat_t > 0.0 and army.threat_mass > 0.40:
		var bestd := 1.0e18
		for cpn2 in range(CORPS_PER_TEAM):
			var cx := 0.0
			var cn := 0
			for brc in mine:
				if brc.corps == cpn2 and not brc.line2:
					cx += _brigade_center(brc).x
					cn += 1
			if cn > 0 and absf(cx / float(cn) - army.threat_x) < bestd:
				bestd = absf(cx / float(cn) - army.threat_x)
				threat_corps = cpn2
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
		var threatened: bool = cpn == threat_corps and fl_frac < 0.92   # the anticipated point — reinforce early
		if relieve or exploit or threatened:
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
	_assign_strategic_tasks(army, mine)   # give each brigade a PLACE to take or hold (its primary task)
	_terrain_plan(army, mine, foe)        # Phase 2: choose the ground — rest the flanks, hold the high ground
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
# ================= WATERLOO — the historical AI script ==================================
# A timeline overlaid on the tactical sim: Wellington holds the ridge while the French batter the
# centre, the Imperial Guard waits in reserve, and Blücher's Prussians stand off to the east until
# their hour comes — then crash onto the French right while the Guard makes its doomed last attack.
# The script issues army intents (scripted_goal), holds/releases formations (hold_until/scripted_obj)
# and narrates each phase; the underlying brigade/battalion AI fights every contact as it falls.
func _waterloo_begin() -> void:
	_wat_t0 = _t
	_wat_phase = -1
	if armies.size() >= 2:
		for a in armies:
			if a.team == 0:
				a.scripted_goal = "break_centre"   # the French press the Allied centre all day
			else:
				a.scripted_goal = "bleed"          # Wellington stands and bleeds them on the ridge
	# the Prussians (anchored far east) and the Imperial Guard (reserve) stand fast until released
	for br in brigades:
		if _wat_is_prussian(br) or _wat_is_guard(br):
			br.hold_until = 1.0e18

func _wat_is_prussian(br) -> bool:
	return br.team == 1 and br.anchor.x > 2000.0     # only the Prussians spawn that far to the east

func _wat_is_guard(br) -> bool:
	return br.team == 0 and not br.battalions.is_empty() and (br.battalions[0] as Batt).oob_division >= 97

func _waterloo_script() -> void:
	if not _battle_begun:
		return
	var bt := _t - _wat_t0
	while _wat_phase + 1 < WAT_PHASES.size() and bt >= float(WAT_PHASES[_wat_phase + 1][0]):
		_wat_phase += 1
		_wat_fire_phase(String(WAT_PHASES[_wat_phase][1]))

func _wat_fire_phase(name: String) -> void:
	# the despatch is written from the player's own side — French (team 0) or Anglo-Allied (team 1)
	var fr := (player != null and player.team == 0)
	match name:
		"hougoumont":
			if fr:
				_send_player_despatch("[color=#ffd773]11:30 — Hougoumont.[/color] The guns open and Jérôme's division goes in against the château wood on our left — the day begins.", {})
			else:
				_send_player_despatch("[color=#ffd773]11:30 — Hougoumont.[/color] Reille's guns open on the château wood; Jérôme's men storm the orchard on our right.", {})
		"grand_battery":
			if fr:
				_send_player_despatch("[color=#ffd773]The grand battery.[/color] Our guns come into line and open on the ridge — the great cannonade begins.", {})
			else:
				_send_player_despatch("[color=#ffd773]The grand battery.[/color] The massed French guns come into line and the round-shot begins to plough the ridge.", {})
		"derlon":
			if fr:
				_send_player_despatch("[color=#ffd773]Forward![/color] D'Erlon's corps advances in column against the enemy left-centre and La Haye Sainte.", {})
			else:
				_send_player_despatch("[color=#ffd773]D'Erlon attacks![/color] Great columns roll up the slope against the left-centre and La Haye Sainte.", {})
		"cavalry":
			if fr:
				_send_player_despatch("[color=#ffd773]Ney leads the horse![/color] The squadrons sweep up against the enemy centre — ride them down!", {})
			else:
				_send_player_despatch("[color=#ffd773]Cavalry![/color] Ney's squadrons come on against the centre — form square!", {})
			_wat_release_cavalry()
		"prussians":
			if fr:
				_send_player_despatch("[color=#ff9d73]Prussians on the right![/color] Bülow's corps debouches from the Bois de Paris — the right must hold at Plancenoit!", {})
			else:
				_send_player_despatch("[color=#73ff97]The Prussians![/color] Bülow's corps debouches from the Bois de Paris onto the French right — Plancenoit is threatened.", {})
			_wat_release_prussians()
		"guard":
			if fr:
				_send_player_despatch("[color=#ffd773]La Garde au feu![/color] The Emperor commits the Guard — form column and climb the slope for the last throw of the day.", {})
			else:
				_send_player_despatch("[color=#ffd773]La Garde au feu![/color] The Imperial Guard forms column and climbs the slope into the centre — hold the crest!", {})
			_wat_release_guard()

# Ney's great cavalry charges: the French horse, idle in reserve far to the rear, advances into
# charge range of the Allied centre; the Allied horse moves up to meet them. (The squadrons then
# charge / break on the squares / retire to re-form on their own AI.)
func _wat_release_cavalry() -> void:
	var fi := 0
	var ai := 0
	for c in cavalry:
		if c.player:
			continue
		if c.team == 0:
			var lane := fi % 5
			var rowf := fi / 5
			# rally close under the British ridge (~100 m off) so they're within charge range of the line
			c.reserve_pos = Vector3((float(lane) - 2.0) * 200.0, 0.0, 410.0 - float(rowf) * 55.0)
			c.state = "reserve"
			fi += 1
		else:
			var la := ai % 5
			var rowa := ai / 5
			c.reserve_pos = Vector3((float(la) - 2.0) * 200.0, 0.0, 230.0 + float(rowa) * 55.0)
			ai += 1

func _wat_release_prussians() -> void:
	var si := 0
	var ni := 0
	for br in brigades:
		if not _wat_is_prussian(br):
			continue
		br.hold_until = 0.0
		# the southern brigades drive on Plancenoit and the French right-rear; the northern ones
		# make for the junction with the Allied left at Papelotte — spread so they don't pile up.
		if br.anchor.z < 150.0:
			br.scripted_obj = Vector3(1000.0 + float(si) * 140.0, 0.0, -640.0 - float(si) * 60.0)
			si += 1
		else:
			br.scripted_obj = Vector3(820.0 + float(ni) * 140.0, 0.0, 240.0)
			ni += 1

func _wat_release_guard() -> void:
	var i := 0
	for br in brigades:
		if not _wat_is_guard(br):
			continue
		br.hold_until = 0.0
		br.scripted_obj = Vector3(-220.0 + float(i) * 150.0, 0.0, 500.0)   # column up the centre, spread across it
		i += 1

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
	# the strategic ROLE leans the war aim: an attacker presses for a decision, a defender
	# stands and bleeds them, a rearguard buys time. A meeting engagement leans neither way.
	match army.role:
		"attack":
			cands["destroy"] *= 1.35
			cands["break_centre"] *= 1.30
			cands["turn_left"] *= 1.25
			cands["turn_right"] *= 1.25
			cands["bleed"] *= 0.50
			cands["delay"] *= 0.40
		"defend":
			cands["bleed"] *= 1.50
			cands["delay"] *= 1.15
			cands["destroy"] *= 0.60
			cands["break_centre"] *= 0.70
		"rearguard":
			cands["delay"] *= 1.90
			cands["bleed"] *= 1.20
			cands["destroy"] *= 0.40
			cands["break_centre"] *= 0.40
			cands["turn_left"] *= 0.50
			cands["turn_right"] *= 0.50
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
	if army.scripted_goal != "":
		best = army.scripted_goal       # the historical script dictates the army's intent
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
		elif my_mor > 45.0 and float(army.doctrine.get("grand_bat", 0.5)) >= 0.45:
			army.play = "grand_battery"    # mass the guns at the point — doctrines that favour it (French, Prussian)

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
	if _wmap:
		_waterloo_script()
	for br in brigades:
		_update_brigade(br, delta)
	_update_brigade_couriers(delta)
	# (a per-frame inter-battalion separation push was tried here but it fought the movement AI and the
	#  formation — jittering units, and shoving the densely-packed advancing French back out of the
	#  crowd, away from the enemy. Removed. Crowding is handled by the width-aware slots in
	#  _brigade_assign_slots; deploying reserve brigades in DEPTH (line2) is the non-jittery next step.)

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
	if absf(angle_difference(br.facing, br.face_want)) > 0.05:   # DEADBAND: ignore sub-degree jitter; wheel only for a real change (no slot orbit)
		br.facing = lerp_angle(br.facing, br.face_want, clampf(delta * BRIG_TURN_RATE, 0.0, 1.0))
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
		"seize":
			kind = "attack"; text = "March on the objective"; opos = br.objective
		"garrison":
			kind = "reserve"; text = "Garrison & hold the town"; opos = br.objective
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
# THE OPERATIONAL ALLOCATION: HQ reads the whole province and gives each brigade a PLACE to
# work — DEFEND a held town under threat, or ASSAULT a contestable one — weighing each town's
# value (its size AND its economy: a barracks/armory/stables/shipyard town is worth fighting for),
# how hard it is held, and how near it lies. This is the campaign brain: brigades disperse to
# objectives instead of all merging into one line. (A brigade still gives battle on contact.)
func _assign_strategic_tasks(army, mine: Array) -> void:
	var team: int = army.team
	for br in mine:
		var center := _brigade_center(br)
		var best_kind := "screen"
		var best_town = null
		var best_sc := 0.0
		for t in field_towns:
			var tp: Vector3 = t["pos"]
			var val := float(int(t["size"])) + (3.0 if String(t.get("building", "")) != "" else 0.0) + 0.5
			var d: float = center.distance_to(tp)
			var owner := int(t["owner"])
			if owner == team:
				# DEFEND a held town that a SCOUTED enemy force is bearing down on (an unseen approach
				# can't be defended against — that's the price of failing to picket your front)
				var threat := 0
				for b in battalions:
					if b.team != team and b.team != 2 and not b.spent and b.pos.distance_to(tp) < 1600.0:
						if b._spotted or (_t - b._intel_t) < AI_MEMORY:
							threat += b.figs.size()
				if threat < 250:
					continue
				var sc := val * (1.0 + float(threat) / 2500.0) / (1.0 + d / 2500.0)
				if sc > best_sc:
					best_sc = sc
					best_kind = "defend"
					best_town = t
			else:
				# ASSAULT a contestable (enemy/neutral) town — prefer valuable, weakly held, near
				var def := 0
				for b in battalions:
					if not b.spent and b.team == owner and b.pos.distance_to(tp) < 800.0:
						def += b.figs.size()
				var weak := 1.0 / (1.0 + float(def) / 1500.0)
				var sc := val * weak / (1.0 + d / 3500.0) * lerpf(0.8, 1.3, army.aggression)
				if sc > best_sc:
					best_sc = sc
					best_kind = "assault"
					best_town = t
		br.task_kind = best_kind
		br.task_town = best_town

# Pursue the strategic task when out of contact: march to the town and take it (assault), or
# hold/garrison and PATROL its approaches while the men rest (defend). Screen brigades hold.
func _brigade_pursue_task(br, center: Vector3) -> void:
	br.enemy = null
	br.fire_mission = null
	var tt = br.task_town
	if tt == null:
		br.posture = "hold"
		br.mission = "garrison"
		br.objective = center
		return
	var tp: Vector3 = tt["pos"]
	var d := center.distance_to(tp)
	if br.task_kind == "defend" and d <= TOWN_HOLD_RADIUS:
		# garrison: hold the town, patrol its approaches at a slow walk, and let the men rest
		br.posture = "hold"
		br.mission = "garrison"
		var ang := _t * 0.18 + float(br.idx)
		br.objective = tp + Vector3(cos(ang), 0, sin(ang)) * (TOWN_HOLD_RADIUS * 0.5)
	else:
		br.posture = "advance"
		br.mission = "seize"
		br.objective = tp
	if center.distance_to(br.objective) > 1.0:
		br.face_want = atan2((br.objective - center).x, (br.objective - center).z)

func _brigade_decide(br) -> void:
	var center := _brigade_center(br)
	# historical script (Waterloo): a brigade ordered to hold stands fast; one given a scripted
	# objective marches to it, then reverts to the tactical AI once arrived.
	if br.hold_until > _t:
		br.posture = "hold"
		br.objective = br.anchor
		br.enemy = null
		br.fire_mission = null
		return
	if br.scripted_obj != Vector3.ZERO:
		if center.distance_to(br.scripted_obj) < 240.0:
			br.scripted_obj = Vector3.ZERO   # arrived — hand back to the tactical AI
		else:
			br.posture = "advance"
			br.mission = "attack"
			br.objective = br.scripted_obj
			br.face_want = atan2((br.scripted_obj - center).x, (br.scripted_obj - center).z)
			return
	if not _battle_begun:
		# the armies stand on their ground until the step-off
		br.posture = "hold"
		br.objective = br.anchor
		br.fire_mission = null
		return
	# OPERATIONAL: give battle to an enemy brigade only when it is KNOWN and in CONTACT; otherwise
	# pursue the strategic task (defend / assault / screen a town). With fog, an unscouted column
	# isn't reacted to until your own forces sight it — so feints and flank marches go unseen, and a
	# brigade can be caught on the march. The tactical battle below still runs once contact is real.
	var near_enemy = _nearest_known_enemy_brigade(br)
	var ndist: float = (_brigade_center(near_enemy).distance_to(center)) if near_enemy != null else 1.0e18
	if near_enemy == null or ndist >= OPERATIONAL_CONTACT:
		_brigade_pursue_task(br, center)
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
		br.face_want = atan2((ec - center).x, (ec - center).z)   # always face the enemy himself (eased)
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
			br.face_want = atan2((tobj - center).x, (tobj - center).z)
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
	_apply_terrain(br, center)   # Phase 2: bend the line onto the chosen ground (flank rest / hold the crest)
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
	# WIDTH-AWARE SPACING: post each battalion by its ACTUAL frontage (`_halfwidth`, which shrinks as
	# casualties mount) edge-to-edge with a small interval — not a fixed step. A full battalion gets its
	# whole width (no overlap); a mauled one closes up. The AI sees each unit's footprint, not a point.
	var gap := 8.0
	var ftot := 0.0
	for idx in range(nf):
		ftot += _halfwidth(live[idx]) * 2.0 + gap
	var fcur := -ftot * 0.5
	for idx in range(nf):
		var b: Batt = live[idx]
		var w := _halfwidth(b) * 2.0 + gap
		if not b.human:                  # the player keeps his own counsel
			b.ai_target = br.anchor + right * (fcur + w * 0.5)
			b.ai_posture = br.posture
			b.ai_facing = br.facing
		fcur += w
	var rtot := 0.0
	for ri in range(nr):
		rtot += _halfwidth(live[nf + ri]) * 2.0 + gap
	var rcur := -rtot * 0.5
	for ri in range(nr):
		var b: Batt = live[nf + ri]
		var w := _halfwidth(b) * 2.0 + gap
		if not b.human:
			b.ai_target = br.anchor - bf * RESERVE_DEPTH + right * (rcur + w * 0.5)   # second line
			b.ai_posture = rposture
			b.ai_facing = br.facing
		rcur += w

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
	# CAVALRY! The drill that saves a battalion: throw square when horse actually THREATENS — a
	# charge bearing down (SQUARE_ALERT), or any horse right on top of it (SQUARE_PANIC) — stand
	# fast inside it, and HOLD it a few seconds after the threat clears so it can't flicker square
	# <->line as loose squadrons cross the line. (Loitering reserve cavalry no longer freezes it.)
	var charge_d := _nearest_charging_cav_dist(b.pos, b.team)
	var cav_d := _nearest_enemy_cav_dist(b.pos, b.team)
	var horse_threat := (charge_d < SQUARE_ALERT or cav_d < SQUARE_PANIC) and b.melee_foe == null and not b.charging
	if horse_threat:
		if b.formation != "square":
			b.skirmish = false
			b.formation = "square"
			_reslot(b)
		b.square_t = SQUARE_HOLD            # keep refreshing the hold while the horse threatens
		return                              # stand fast — nothing else matters now
	if b.formation == "square":
		b.square_t -= delta
		if b.square_t > 0.0:
			return                          # threat just passed — hold the square a moment longer (no flicker)
		b.formation = "line"               # the horse is well clear — re-form and carry on
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
	b.form_lock_t = maxf(0.0, b.form_lock_t - delta)   # formation-change cooldown ticks down
	# on a long march, steer onto a bridge if the river lies across the path
	if not bridges.is_empty() and b.pos.distance_to(tgt) > FORMUP_DIST:
		tgt = _route_via_bridge(b.pos, tgt)
	var to := tgt - b.pos
	to.y = 0.0
	var d := to.length()
	# HYSTERESIS: break into a travelling column only to cross real ground; once formed in line, HOLD
	# it across the small drift of an advancing slot (deadband to LINE_HOLD_DIST) so the formation and
	# facing don't strobe. A line in the deadband still keeps the brigade's full pace to stay on its
	# slot — it only slows to dress when settled right on the mark.
	var break_dist := LINE_HOLD_DIST if b.formation == "line" else FORMUP_DIST
	if d > break_dist:
		# far to go: form the narrow MARCH column and make speed; closer in, the broad
		# assault column for manoeuvre; in contact, deploy to line (below)
		var want := "march" if d > MARCH_DIST else "column"
		if not b.skirmish and b.formation != want and b.form_lock_t <= 0.0:
			b.formation = want
			b.form_lock_t = FORM_LOCK_TIME
			_reslot(b)
		var dir := to / d
		b.facing = atan2(dir.x, dir.z)
		b.pos += dir * _move_speed(b) * delta
		b.off_pos = b.pos + dir * 14.0
		b.off_facing = b.facing
	else:
		if deploy_line and not b.skirmish and b.formation != "line" and b.form_lock_t <= 0.0:
			b.formation = "line"
			b.form_lock_t = FORM_LOCK_TIME
			_reslot(b)
		b.facing = lerp_angle(b.facing, face, clampf(delta * 1.5, 0.0, 1.0))
		if d > 0.4:
			# keep the brigade's full pace while there's a gap to close; only dawdle to dress when
			# settled right on the mark (else a line that fell a few metres behind never catches up)
			var dress := d < 6.0 and deploy_line
			b.pos += (to / d) * BATT_SPEED * (0.5 if dress else 1.0) * delta
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
	if foe == null or foe.figs.size() < MELEE_MIN or foe.state == "routing":
		b.melee_foe = null                   # the foe broke or is destroyed — the press is over
		b.charge_cool = CHARGE_COOL
		return
	# grind at the seam, facing the foe
	var to := foe.pos - b.pos
	to.y = 0.0
	if to.length() > 0.01:
		b.facing = atan2(to.x, to.z)
	# Only the men at the SEAM fight — the narrower frontage caps the pairings; a wider line laps the
	# flank. Each call resolves b's men pressing foe's men (the foe's own _sim_melee call handles the
	# return blow), so the SKILL gap sets the exchange ratio: the better unit bleeds the enemy faster.
	var b_front := _contact_men(b)
	var foe_front := _contact_men(foe)
	var pairs := mini(b_front, foe_front)
	if pairs <= 0:
		return
	var b_q := _melee_quality(b)
	var foe_q := _melee_quality(foe)
	var edge := b_q / maxf(0.05, b_q + foe_q)        # b's share of the casualties traded (skill-led)
	# GRINDING: a steady stream of losses, with a bit of luck per tick (upsets happen)
	var inflict := MELEE_DUEL_RATE * float(pairs) * edge * randf_range(0.7, 1.3) * delta
	if b_front > foe_front:                          # b overlaps — the surplus laps the foe's flank
		inflict *= 1.0 + minf(float(b_front - foe_front) / maxf(1.0, float(foe_front)), 1.0) * MELEE_FLANK_LAP
	foe.dmg_acc += inflict
	var k := int(foe.dmg_acc)
	if k > 0:
		foe.dmg_acc -= k
		foe.kills_pending += k                       # _kill_some drops them from the contact edge (the seam)
		foe.shot_from = b.pos                        # the press comes from b's side
		if b.is_player:
			prestige += k                            # bayonet work under your command counts
	# nerve erodes slowly — the loser is worn down over a long, bloody fight, not broken on contact
	var mr := clampf(b_q / maxf(0.2, foe_q), 0.4, 2.5)
	foe.morale -= MELEE_MORALE * mr * delta * MELEE_MORALE_SLOW
	foe.calm_t = 0.0
	# YOUR named men prove themselves in the press — the front rank hardens its bayonet work as it fights
	# (and the weaker men are the ones _kill_some takes, so a good man both survives and improves)
	if b.is_player:
		b.xp += float(pairs) * delta * 0.02
		var maxy := -1.0e9
		for f0 in b.figs:
			maxy = maxf(maxy, (f0["slot"] as Vector2).y)
		var seam := maxy - SP * 1.6
		for f0 in b.figs:
			if (f0["slot"] as Vector2).y >= seam:
				var m = f0.get("man", null)
				if m != null:
					m["melee"] = minf(99.0, float(m["melee"]) + MELEE_XP_GAIN * delta)

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
	# rank the men by distance to the incoming fire, drop the nearest k. IN THE PRESS (melee) the
	# less-skilled men in the front rank are the ones who fall — a named soldier's bayonet skill keeps
	# him on his feet, so your trained men (and only they carry individual skill) survive the longer.
	var melee := b.melee_foe != null
	var b_msk := _sk(b, "melee")
	var order: Array = []
	for i in range(b.figs.size()):
		var sl: Vector2 = b.figs[i]["slot"]
		var w := b.pos + right * sl.x + fwd * sl.y
		var score := w.distance_squared_to(from)
		if melee:
			var m = b.figs[i].get("man", null)
			var msk: float = float(m["melee"]) if m != null else b_msk
			score += (msk - 50.0) * MELEE_SKILL_PROTECT   # higher skill ranks LATER → survives
		order.append([score, i, w])
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
func _ray_hit_world(origin: Vector3, dir: Vector3, max_range: float, exclude_team: int) -> Dictionary:
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
		if b.team == exclude_team or b.spent or b.figs.is_empty():
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
	var dman = b.figs[idx].get("man", null)
	if dman != null:
		dman["alive"] = false        # this SPECIFIC named man falls — his trained skill leaves the line
	b.figs.remove_at(idx)
	b.cas_since_redress += 1

# ------------------------------------------------------------------ render + LOD

# FOG OF WAR: recompute, for BOTH armies, which enemy units that side can SEE — `_spotted` means
# "seen by my enemy army". One flag serves the local player's render/map AND each AI's knowledge
# (Phase 3). Render/knowledge only — the host still simulates the whole field, so it changes what
# each side KNOWS, never what happens.
func _update_vision(delta: float) -> void:
	if cam == null:
		return
	if not authoritative:
		_update_vision_client(delta)             # MP client: fog is host-fed; just age it out
		return
	_contact_cd = maxf(0.0, _contact_cd - delta)
	_vision_cd -= delta
	if _vision_cd > 0.0:
		return
	_vision_cd = VISION_TICK
	# each army's eyes, plus a coarse AABB (eye-spread + max sight) as a cheap broad-phase
	var eyes := [_gather_eyes(0), _gather_eyes(1)]
	var bmin := [Vector2(1e12, 1e12), Vector2(1e12, 1e12)]
	var bmax := [Vector2(-1e12, -1e12), Vector2(-1e12, -1e12)]
	for a in [0, 1]:
		for e in eyes[a]:
			var p: Vector3 = e[0]
			bmin[a] = Vector2(minf(bmin[a].x, p.x), minf(bmin[a].y, p.z))
			bmax[a] = Vector2(maxf(bmax[a].x, p.x), maxf(bmax[a].y, p.z))
		bmin[a] -= Vector2(SIGHT_CAV, SIGHT_CAV)
		bmax[a] += Vector2(SIGHT_CAV, SIGHT_CAV)
	var pteam: int = player.team if player != null else -1
	var fresh := 0
	var fresh_pos := Vector3.ZERO
	for b in battalions:
		if b.figs.is_empty():
			continue
		var saw := _vis_seen(b.pos, b.team, eyes, bmin, bmax)
		if saw and not b._spotted and b.team != pteam:
			fresh += 1                              # an enemy of the PLAYER just came into view
			fresh_pos = b.pos
		b._spotted = saw
		if saw:
			b._intel_pos = b.pos
			b._intel_t = _t
	for c in cavalry:
		if c.spent:
			continue
		var sawc := _vis_seen(c.pos, c.team, eyes, bmin, bmax)
		c._spotted = sawc
		if sawc:
			c._intel_pos = c.pos
			c._intel_t = _t
	for g in guns:
		if g.dead:
			continue
		var sawg := _vis_seen(g.pos, g.team, eyes, bmin, bmax)
		g._spotted = sawg
		if sawg:
			g._intel_t = _t
		if g.node != null and pteam >= 0:
			g.node.visible = (g.team == pteam) or sawg or PLAYER_SEES_ALL   # the player sees every gun (fog still feeds the AI via _spotted)
	# a despatch on fresh contact for the PLAYER (throttled), naming the nearest town for bearings
	if fresh > 0 and pteam >= 0 and _contact_cd <= 0.0:
		_contact_cd = 9.0
		var ti := _nearest_town_index(fresh_pos)
		var where: String = (" near %s" % String(field_towns[ti]["name"])) if ti >= 0 and ti < field_towns.size() else ""
		_send_player_despatch("[color=#ffd27f]Vedettes report enemy in the field%s.[/color]" % where, {})

# MP CLIENT fog: the host streams only the enemies our side has scouted, so a RECEIVED enemy is a
# sighting (marked in _apply_*). Here we just age those out — an enemy the host has stopped sending
# has slipped our sight, so it drops from the 3D field and lingers only as a fading map ghost.
func _update_vision_client(delta: float) -> void:
	if player == null:
		return
	_vision_cd -= delta
	if _vision_cd > 0.0:
		return
	_vision_cd = VISION_TICK
	if PLAYER_SEES_ALL:
		# the player sees everything — keep every streamed unit shown; don't let the fog tick hide it
		for b in battalions:
			b._spotted = true
		for c in cavalry:
			c._spotted = true
		for g in guns:
			g._spotted = true
			if g.node != null:
				g.node.visible = true
		return
	var pteam := player.team
	for b in battalions:
		if b.team != pteam and b._spotted and (_t - b._intel_t) > NET_FOG_EXPIRE:
			b._spotted = false
	for c in cavalry:
		if c.team != pteam and c._spotted and (_t - c._intel_t) > NET_FOG_EXPIRE:
			c._spotted = false
	for g in guns:
		if g.team != pteam and g._spotted and (_t - g._intel_t) > NET_FOG_EXPIRE:
			g._spotted = false
			if g.node != null:
				g.node.visible = false

# Build one army's sight sources: [centre, radius²]. Light cavalry range furthest; the local
# player's officer (and his spyglass) is an extra eye for his own side.
func _gather_eyes(a: int) -> Array:
	var eyes: Array = []
	for fb in battalions:
		if fb.team == a and not fb.figs.is_empty() and fb.state != "routing":
			eyes.append([fb.pos, SIGHT_INF * SIGHT_INF])
	for fc in cavalry:
		if fc.team == a and not fc.spent:
			var rr := SIGHT_CAV * float(CAV_TYPE_DATA[fc.cav_type]["scout"])
			eyes.append([fc.pos, rr * rr])
	for fg in guns:
		if fg.team == a and not fg.dead:
			eyes.append([fg.pos, SIGHT_GUN * SIGHT_GUN])
	if player != null and player.team == a:
		var osr := SIGHT_OFFICER * (1.0 + _scope_amt * 1.6)
		eyes.append([off_pos, osr * osr])
	return eyes

# Is a unit (of `team`) seen by its ENEMY army? team 0's enemy is army 1 and vice versa;
# raiders (team 2) are seen if EITHER army has eyes on them.
func _vis_seen(pos: Vector3, team: int, eyes: Array, bmin: Array, bmax: Array) -> bool:
	if team == 0:
		return _vis_army(pos, 1, eyes, bmin, bmax)
	if team == 1:
		return _vis_army(pos, 0, eyes, bmin, bmax)
	return _vis_army(pos, 0, eyes, bmin, bmax) or _vis_army(pos, 1, eyes, bmin, bmax)

func _vis_army(pos: Vector3, a: int, eyes: Array, bmin: Array, bmax: Array) -> bool:
	var lo: Vector2 = bmin[a]
	var hi: Vector2 = bmax[a]
	if pos.x < lo.x or pos.x > hi.x or pos.z < lo.y or pos.z > hi.y:
		return false                               # broad-phase: outside that army's possible-sight box
	return _vis_test(pos, eyes[a])

func _vis_test(pos: Vector3, eyes: Array) -> bool:
	for e in eyes:
		if pos.distance_squared_to(e[0] as Vector3) < float(e[1]):
			return true
	return false

# returns render stride (1/2/3/6) or 0 to skip entirely (off-screen / too far).
# Boundaries carry HYSTERESIS (a dead-band + a few-frame view grace) so units don't flicker out
# at the screen edge or strobe between detailed men and the box-man impression at a fixed range.
func _batt_lod(b: Batt) -> int:
	if not PLAYER_SEES_ALL and player != null and b.team != player.team and not b._spotted:
		return 0          # fog of war: an enemy your army hasn't sighted simply isn't drawn
	var d := cam.position.distance_to(b.pos)
	if d > LOD_VFAR + (LOD_HYST if b._lod != 0 else 0.0):
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
	if seen:
		b._seen_t = _t
	elif _t - b._seen_t > SEEN_GRACE:
		return 0          # off-screen long enough that the grace has lapsed — now safe to drop
	return _lod_band(d, b._lod)

# Distance → LOD level, holding the level it's already at across a small dead-band so a unit
# hovering at a boundary doesn't switch representation every frame.
func _lod_band(d: float, prev: int) -> int:
	match prev:
		1:
			if d < LOD_NEAR + LOD_HYST: return 1
		2:
			if d > LOD_NEAR - LOD_HYST and d < LOD_MID + LOD_HYST: return 2
		3:
			if d > LOD_MID - LOD_HYST and d < LOD_FAR + LOD_HYST: return 3
		6:
			if d > LOD_FAR - LOD_HYST: return 6
	if d < LOD_NEAR:
		return 1
	if d < LOD_MID:
		return 2
	if d < LOD_FAR:
		return 3
	return 6          # the far impression: a static mass on the horizon, stride 6

func _render(delta: float) -> void:
	var idx: Array[int] = [0, 0, 0]
	var nidx := [[0, 0, 0], [0, 0, 0], [0, 0, 0]]      # near-LOD body/musket counters, per team & troop type
	var off_i := 0
	var bearer_i := 0
	var nco_i := 0
	var drummer_i := 0
	for b in battalions:
		var prev_lod := b._lod
		var stride := _batt_lod(b)
		b._lod = stride
		if stride == 0:
			b.visible = false
			if b.flag:
				b.flag.visible = false
			continue
		var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
		var right := Vector3(fwd.z, 0, -fwd.x)
		# men march to their dressed world spots (animate only what's on screen); snap into place
		# the frame a battalion first comes into view — and ALSO the frame it drops from the far
		# box-man impression (stride 6) to detailed men, since per-man wpos froze while it was the
		# impression and would otherwise fly across the field to catch up to where the unit now is.
		var snap := (not b.visible) or (prev_lod >= 6 and stride < 6)
		b.visible = true
		# FAR IMPRESSION (beyond LOD_FAR): the battalion is drawn as a static mass —
		# every 6th man placed analytically, no per-man simulation, no muskets — so
		# the whole 5 km line of battle reads on the horizon for almost no cost
		if stride >= 6:
			var fmm: MultiMesh = team_mm[b.team]
			var fgun: MultiMesh = musket_mm[b.team]
			var fi6: int = idx[b.team]
			# the further out, the fewer men we bother placing — a back-of-field battalion is a faint
			# sketch, a near-impression one almost full. This is the main distance-culling knob.
			var fd := cam.position.distance_to(b.pos) if cam != null else LOD_FAR
			var fstep := clampi(LOD_IMPRESSION_STEP + int((fd - LOD_FAR) / LOD_IMPRESSION_FALLOFF), LOD_IMPRESSION_STEP, LOD_IMPRESSION_MAX)
			for k6 in range(0, b.figs.size(), fstep):
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
		var w_aim := _wpn(b).aim_lead              # weapon's level-before-loaded lead (rifles aim longer)
		var sway_amp := unsteady * 0.13 + b.flinch * 0.22
		# every infantryman draws from soldier_troop.glb through the team MultiMesh (the path
		# proven to render). Per-battalion dress + headgear shape come from the band shader.
		var mm: MultiMesh = team_mm[b.team]
		var gun: MultiMesh = musket_mm[b.team]
		var i: int = idx[b.team]
		var icap: int = RAID_CAP if b.team == 2 else MAX_PER_TEAM
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
			var mval := float(f["march"])
			var bob := (absf(sin(_t * 8.5 * float(f["spd"]) + ph)) * 0.05 if moving else 0.0)
			# men don't keep a ruler-straight line on the move — a faint individual weave (gated to
			# the march, so a halted firing line still dresses cleanly), plus morale fidget/waver
			var swx := sin(_t * 3.4 + ph) * sway_amp + sin(_t * 1.6 * float(f["spd"]) + ph * 1.7) * 0.035 * mval
			var bh := float(f["bh"])
			var bw := float(f["bw"])
			var rec := recoil - fwd * (mfl * 0.35)        # he flinches back from the crash of fire
			var ox := w.x + rec.x + right.x * swx
			var oz := w.z + rec.z + right.z * swx
			var oy := CAP_HALF * bh + bob - mfl * 0.16 + _gh(ox, oz)   # his height + the rolling ground
			var in_band := slot.y >= fire_band
			# in a firing posture (an enemy to the front, OR presenting / independent / commanded fire)
			# the men work the ramrod to load and level to fire; at rest they shoulder the musket.
			var fp := b.has_target or b.presenting or b.indep_fire or b.volley_fire
			var leveled := b.charging or b.melee_foe != null or b.melee_vis or (in_band and fp and float(f["reload"]) <= w_aim)
			var reloading := in_band and fp and float(f["reload"]) > w_aim and not moving
			var armp := 1.0 if leveled else (0.6 if reloading else 0.0)   # arm pose -> the leg/arm shader
			if leveled and mfl > 0.05:
				armp = 1.0 + mfl * 0.9     # FIRING RECOIL: push armp past 1 — the shader reads the overflow as the kick
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
				# 0.85 ground-origin offset (officer mesh), NOT CAP_HALF (that's for capsule-centre origins)
				bearer_mm.set_instance_transform(bearer_i, Transform3D(Basis(Vector3.UP, byaw), Vector3(bw.x, 0.85 + bbob + _gh(bw.x, bw.z), bw.z)))
				_cg_dress(bearer_mm, bearer_i, b.team, bw.distance_to(bp) > 0.1, false)
				bearer_i += 1
			_place_flag(b, Vector3(bw.x, 0, bw.z), fyaw)   # lays low when the colours are down
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
		# NCOs posted as FILE-CLOSERS behind each company. For YOUR battalion the number behind a
		# company is exactly its LIVING sergeants & corporals (from the named roster) — lose them
		# and the post stands empty; promote/recruit and they fill back in. (AI keeps no named
		# roster, so it shows one sergeant per company.) They pace the rear, half-pikes in hand.
		if b.formation == "line":
			var rearY := -maxy - 0.9
			var nco_per_coy: Array = []
			nco_per_coy.resize(b.companies)
			if b.roster.is_empty():
				for ci in range(b.companies):
					nco_per_coy[ci] = 1                  # AI: a representative sergeant per company
			else:
				for ci in range(b.companies):
					nco_per_coy[ci] = 0
				for m in b.roster:
					if m["alive"] and String(m["rank"]) in NCO_RANKS:
						var mc := int(m["coy"])
						if mc >= 0 and mc < b.companies:
							nco_per_coy[mc] = mini(int(nco_per_coy[mc]) + 1, 3)
			for c in range(b.companies):
				var ncnt := int(nco_per_coy[c])
				for s in range(ncnt):
					if nco_i >= nco_mm.instance_count:
						break
					var spread := (float(s) - float(ncnt - 1) * 0.5) * 1.5
					var ph2 := _t * 0.22 + float(c) * 1.7 + float(s) * 0.9 + idn
					var rp := b.pos + right * (_company_x(b, c) + spread + sin(ph2) * minf(hw * 0.1, 1.2)) + fwd * rearY
					var rw := _cg_step(b, "nco%d_%d" % [c, s], rp, delta, snap)
					var ryaw := along_yaw if cos(ph2) >= 0.0 else back_yaw   # faces down the line
					if rw.distance_to(rp) > 0.4:
						var rmv := rp - rw
						ryaw = atan2(rmv.x, rmv.z)                            # walking to his post
					var rbob := absf(sin(_t * 2.8 + float(c) + float(s))) * 0.05
					nco_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, ryaw), Vector3(rw.x, CAP_HALF + rbob + _gh(rw.x, rw.z), rw.z)))
					_cg_dress(nco_mm, nco_i, b.team, rw.distance_to(rp) > 0.1, true)
					spontoon_mm.set_instance_transform(nco_i, Transform3D(Basis(Vector3.UP, ryaw), Vector3(rw.x + right.x * 0.2, _gh(rw.x, rw.z), rw.z + right.z * 0.2)))
					nco_i += 1
	for team in [0, 1, 2]:
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

# The brigade commanders: mounted generals posted behind the centre of their brigade.
func _render_commanders() -> void:
	for i in range(brigades.size()):
		if i >= cmd_horse_mm.instance_count:
			break                            # never index past the brigade-commander MultiMesh
		var br = brigades[i]
		if _brigade_live(br) == 0 or br.commander_down:
			cmd_horse_mm.set_instance_transform(i, _zero_xf())   # the general is dead or down
			cmd_rider_mm.set_instance_transform(i, _zero_xf())
			continue
		var yaw: float = br.facing
		var bf := Vector3(sin(yaw), 0, cos(yaw))
		var pos := _brigade_center(br) - bf * 18.0    # rides behind the line centre
		# feet-origin box horse+rider: place at ground, face the line, scale up by rank
		var cs := 1.12
		var cbasis := Basis(Vector3.UP, yaw).scaled(Vector3(cs, cs, cs))
		var cseat := Vector3(pos.x, _gh(pos.x, pos.z), pos.z)
		cmd_horse_mm.set_instance_transform(i, Transform3D(cbasis, cseat))
		cmd_rider_mm.set_instance_transform(i, Transform3D(cbasis, cseat))
		cmd_horse_mm.set_instance_color(i, team_color(br.team))           # shabraque = army colour
		cmd_rider_mm.set_instance_color(i, Color(1.0, 0.82, 0.30))        # a gold-coated brigadier
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
		var gs := 1.24
		var gbasis := Basis(Vector3.UP, gyaw).scaled(Vector3(gs, gs, gs))
		var gseat := Vector3(gp.x, _gh(gp.x, gp.z), gp.z)
		gen_horse_mm.set_instance_transform(gi, Transform3D(gbasis, gseat))
		gen_rider_mm.set_instance_transform(gi, Transform3D(gbasis, gseat))
		gen_horse_mm.set_instance_color(gi, team_color(dv.team))
		gen_rider_mm.set_instance_color(gi, Color(0.95, 0.95, 0.98))      # white-and-silver general
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
		var cbasis := Basis(Vector3.UP, cyaw)     # colonel rides the base-size mount (rank 1.0)
		var cseat := Vector3(cpos.x, _gh(cpos.x, cpos.z), cpos.z)
		colonel_horse_mm.set_instance_transform(ci, Transform3D(cbasis, cseat))
		colonel_rider_mm.set_instance_transform(ci, Transform3D(cbasis, cseat))
		colonel_horse_mm.set_instance_color(ci, team_color(b.team))
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
	footpos.y = _gh(footpos.x, footpos.z)    # plant the colours on the slope, not at sea level
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
	if team == 0:
		return ARMY_BLUE
	elif team == 1:
		return ARMY_RED
	return ARMY_RAID

# Paint an officer/NCO instance in his battalion's coat and set his gait (the bicorne
# shader reads COLOR.rgb as the coat, CUSTOM.b as the march amount).
func _cg_dress(mm: MultiMesh, i: int, team: int, walking: bool, belts: bool) -> void:
	var c := team_color(team)
	mm.set_instance_color(i, Color(c.r, c.g, c.b, 1.0 if belts else 0.0))   # a = crossbelts flag
	mm.set_instance_custom_data(i, Color(0.95, float(i % 17) * 0.06, 1.0 if walking else 0.0, 0.0))

# A man falls: ragdoll if he's on screen and the pool has room, else a static body.
# A share of the fallen are wounded, not killed — they drag themselves rearward.
func _drop_dead(pos: Vector3, team: int, knock_dir: Vector3, seen: bool) -> void:
	pos.y = _gh(pos.x, pos.z)                 # the man falls onto the slope, not at sea level
	# the expensive theatrics (blood, ragdolls, crawling wounded) are reserved for
	# deaths NEAR the camera; the far battle still fills with corpses, cheaply
	if seen and cam != null and cam.position.distance_to(pos) > 280.0:
		seen = false
	if seen:
		_emit_blood(pos, knock_dir)          # a spray of blood at the moment of the hit
	if seen and randf() < WOUNDED_FRAC and _wounded_count(team) < WOUNDED_MAX:
		var rear_z := (-1.0 if team == 0 else 1.0) if team < 2 else (-1.0 if randf() < 0.5 else 1.0)
		var rear := Vector3(randf_range(-0.35, 0.35), 0, rear_z).normalized()
		wounded.append({ "pos": Vector3(pos.x, 0, pos.z), "dir": rear,
			"t": WOUNDED_TIME * randf_range(0.5, 1.0), "team": team, "ph": randf() * TAU })
		return
	if seen and _spawn_ragdoll(pos, team, knock_dir):
		return
	# beyond the ragdoll budget but still in view: TOPPLE him over a beat rather than pop a corpse
	if seen and falling.size() < FALLING_MAX * 2:
		var ky := atan2(knock_dir.x, knock_dir.z) if knock_dir.length() > 0.05 else randf() * TAU
		falling.append({ "pos": Vector3(pos.x, 0, pos.z), "dir": knock_dir, "t": 0.0, "team": team, "yaw": ky })
		return
	_add_corpse(pos, randf() * TAU, team)

func _wounded_count(team: int) -> int:
	var n := 0
	for w in wounded:
		if int(w["team"]) == team:
			n += 1
	return n

func _build_wounded_layer() -> void:
	for team in [0, 1, 2]:
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
	var counts := [0, 0, 0]
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
			mm.set_instance_transform(counts[team], Transform3D(basis, Vector3(p.x, CAP_RADIUS + 0.02 + _gh(p.x, p.z), p.z)))
			counts[team] += 1
		i += 1
	for team in [0, 1, 2]:
		var mm2: MultiMesh = wounded_mm[team]
		if mm2 == null:
			continue
		for j in range(counts[team], WOUNDED_MAX):
			mm2.set_instance_transform(j, _zero_xf())

func _build_falling_layer() -> void:
	for team in [0, 1, 2]:
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var cap := CapsuleMesh.new()
		cap.radius = CAP_RADIUS
		cap.height = CAP_HEIGHT
		cap.radial_segments = 6
		cap.rings = 2
		mm.mesh = cap
		mm.instance_count = FALLING_MAX
		mmi.multimesh = mm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = team_color(team).darkened(0.05)
		mat.roughness = 1.0
		mmi.material_override = mat
		add_child(mmi)
		falling_mm[team] = mm
		for i in range(FALLING_MAX):
			mm.set_instance_transform(i, _zero_xf())

# A struck man doesn't pop into a corpse — he TOPPLES: pitched off his feet in the direction of the
# ball, falling from upright to prone over a beat, then he lies still and joins the fallen. (Near the
# camera he gets a full physics ragdoll instead; this catches the deaths beyond the ragdoll budget.)
func _update_falling(delta: float) -> void:
	var counts := [0, 0, 0]
	var i := 0
	while i < falling.size():
		var fa: Dictionary = falling[i]
		var t := float(fa["t"]) + delta
		if t >= FALL_TIME:
			_add_corpse(fa["pos"], float(fa["yaw"]), int(fa["team"]))   # he is down — bake the static corpse
			falling.remove_at(i)
			continue
		fa["t"] = t
		var team := int(fa["team"])
		if counts[team] < FALLING_MAX:
			var prog := clampf(t / FALL_TIME, 0.0, 1.0)
			var fall := prog * prog * (3.0 - 2.0 * prog)        # smoothstep — slow topple, hard landing
			var pitch := fall * (PI * 0.5)                      # upright -> flat on the ground
			var basis := Basis(Vector3.UP, float(fa["yaw"])) * Basis(Vector3.RIGHT, pitch)
			var p: Vector3 = fa["pos"]
			var cy := lerpf(CAP_HEIGHT * 0.5, CAP_RADIUS + 0.02, fall) + _gh(p.x, p.z)
			var mm: MultiMesh = falling_mm[team]
			mm.set_instance_transform(counts[team], Transform3D(basis, Vector3(p.x, cy, p.z)))
			counts[team] += 1
		i += 1
	for team in [0, 1, 2]:
		var mm2: MultiMesh = falling_mm[team]
		if mm2 == null:
			continue
		for j in range(counts[team], FALLING_MAX):
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
	if _wmap:
		_waterloo_begin()
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

# THE CAMPAIGN PERSISTS: a spent day (nightfall, or even a beaten army) is NOT the end of the war —
# in the night both sides draw off, the broken survivors are rallied and re-formed, the men rest,
# and at first light the campaign goes on. Only a clean sweep of every town (_strategic_win) ends it.
func _continue_to_next_day() -> void:
	battle_over = false
	_night_end = false
	_town_winner = -1
	_bill_t = 0.0
	_army_broken = [false, false, false]
	_day_count += 1
	for b in battalions:
		if b.spent or b.figs.is_empty():
			continue
		b.broken = false
		if b.state == "routing":
			b.state = "shaken"
		b.morale = maxf(b.morale, 55.0)
		b.cohesion = maxf(b.cohesion, COHESION_BREAK + 25.0)
		b.fatigue = maxf(0.0, b.fatigue - 45.0)      # a night's rest
		b._coh_figs = b.figs.size()                  # losses are banked; the new day starts clean
	for c in cavalry:
		if not c.spent:
			c.state = "reserve"
			c.rally_t = 0.0
	_time_of_day = 6.5                                # first light
	_recompute_start_strength()                      # the new day's baseline for the next bill
	if _bill_panel != null:
		_bill_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE
	_send_player_despatch("[color=#ffe9a8]Day %d dawns.[/color] The armies re-form and the campaign goes on." % _day_count, {})
	_save_game()                                     # the campaign is auto-saved each daybreak

func _recompute_start_strength() -> void:
	_start_strength = [0, 0, 0]
	for b in battalions:
		_start_strength[b.team] += b.figs.size()

# ============================================================ SAVE / LOAD (campaign persistence)
# The whole campaign is written to ONE file: the province (towns + economy), every battalion /
# regiment / battery / ship, and the global state (prestige, time, day). The named ROSTER of your
# men is preserved (their ranks, skills, who has fallen); per-fig tactical micro re-rolls. On load
# the world is regenerated from the SAVED SEED (so the map matches), then the units are rebuilt and
# the command structure re-derived. Auto-saves at each daybreak; F5 quicksave, F9 quickload.
const SAVE_PATH := "user://commander_save.dat"
var _loaded_save = null              # the save data read at startup, applied after the spawn

static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _save_game() -> void:
	var data := {
		"version": 1, "time": _time_of_day, "day": _day_count, "prestige": prestige,
		"mat_pool": _mat_pool, "reinforced": _reinforced, "muster_cav_n": _muster_cav_n,
		"convoy_next_id": _convoy_next_id, "start_strength": _start_strength,
		"army_broken": _army_broken, "seed": GameConfig.match_seed,
		"militia": {
			"has_militia": GameConfig.has_militia, "uniform": GameConfig.militia_uniform,
			"fr": GameConfig.militia_facing.r, "fg": GameConfig.militia_facing.g, "fb": GameConfig.militia_facing.b,
			"flag": GameConfig.militia_flag, "hat": GameConfig.militia_hat, "belt": GameConfig.militia_belt,
			"pants": GameConfig.militia_pants, "name": GameConfig.militia_name, "slot": GameConfig.local_slot,
		},
		"towns": [], "battalions": [], "cavalry": [], "guns": [], "ships": [],
	}
	for t in field_towns:
		data["towns"].append({ "name": String(t["name"]), "owner": int(t["owner"]), "mat": int(t.get("mat", 0)),
			"building": String(t.get("building", "")), "stock": float(t.get("stock", 0.0)),
			"build": t.get("build", [0.0, 0.0, 0.0, 0.0, 0.0]), "size": int(t["size"]),
			"cap_t": float(t["cap_t"]), "cap_team": int(t["cap_team"]) })
	for b in battalions:
		data["battalions"].append(_save_batt(b))
	for c in cavalry:
		data["cavalry"].append({ "team": c.team, "idx": c.idx, "cav_type": c.cav_type, "x": c.pos.x, "z": c.pos.z,
			"facing": c.facing, "men": c.troopers.size(), "state": c.state, "spent": c.spent,
			"rx": c.reserve_pos.x, "rz": c.reserve_pos.z })
	for g in guns:
		data["guns"].append({ "team": g.team, "x": g.pos.x, "z": g.pos.z, "facing": g.facing, "dead": g.dead })
	for s in ships:
		var sp: Vector3 = s["pos"]
		data["ships"].append({ "team": int(s["team"]), "x": sp.x, "z": sp.z, "heading": float(s["heading"]), "speed": float(s["speed"]) })
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_send_player_despatch("[color=#ff9a8a]Could not write the save file.[/color]", {})
		return
	f.store_var(data, true)
	f.close()
	_send_player_despatch("[color=#9fe0a0]Campaign saved.[/color]  [color=#9fb0c8](day %d)[/color]" % _day_count, {})

func _save_batt(b: Batt) -> Dictionary:
	var d := {
		"team": b.team, "idx": b.idx, "x": b.pos.x, "z": b.pos.z, "facing": b.facing,
		"formation": b.formation, "companies": b.companies, "men": b.figs.size(),
		"skill": b.skill.duplicate(), "morale": b.morale, "cohesion": b.cohesion, "fatigue": b.fatigue,
		"ammo": b.ammo, "independent": b.independent, "is_player": b.is_player, "is_raider": b.is_raider,
		"human": b.human, "rname": b.rname, "quality": b.quality, "spent": b.spent, "broken": b.broken,
		"leaders0": b._leaders0, "start_men": b.start_men,
		"icr": b.inst_col.r, "icg": b.inst_col.g, "icb": b.inst_col.b, "ica": b.inst_col.a,
		"roster": b.roster,
	}
	# per-SOLDIER stats — each man's own marksmanship (marks), nerve, build and coat-wear — kept
	# for the battalions that have a named roster (yours), so individual soldiers restore exactly
	# rather than re-rolling. (AI line figs are cosmetic and skipped to keep the save lean.)
	if b.is_player or not b.roster.is_empty():
		var fs: Array = []
		for f in b.figs:
			fs.append([float(f.get("marks", 0.0)), float(f.get("nerve", 0.5)), float(f.get("wear", 1.0)),
				float(f.get("bw", 1.0)), float(f.get("bh", 1.0)), float(f.get("spd", 1.0))])
		d["figstats"] = fs
	return d

func _load_save_file():
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	var data = f.get_var(true)
	f.close()
	return data if typeof(data) == TYPE_DICTIONARY else null

func _apply_save(data: Dictionary) -> void:
	_time_of_day = float(data.get("time", _time_of_day))
	_day_count = int(data.get("day", 1))
	prestige = int(data.get("prestige", prestige))
	if data.has("mat_pool"): _mat_pool = data["mat_pool"]
	if data.has("reinforced"): _reinforced = data["reinforced"]
	if data.has("muster_cav_n"): _muster_cav_n = data["muster_cav_n"]
	_convoy_next_id = int(data.get("convoy_next_id", 0))
	if data.has("start_strength"): _start_strength = data["start_strength"]
	if data.has("army_broken"): _army_broken = data["army_broken"]
	_econ_ready = true
	for td in data.get("towns", []):
		for t in field_towns:
			if String(t["name"]) == String(td["name"]):
				t["owner"] = int(td["owner"])
				t["mat"] = int(td.get("mat", 0))
				t["building"] = String(td.get("building", ""))
				t["stock"] = float(td.get("stock", 0.0))
				t["build"] = td.get("build", [0.0, 0.0, 0.0, 0.0, 0.0])
				t["cap_t"] = float(td.get("cap_t", 0.0))
				t["cap_team"] = int(td.get("cap_team", -1))
				break
	_color_towns()
	_clear_all_units()
	for bd in data.get("battalions", []):
		_load_batt(bd)
	for cd in data.get("cavalry", []):
		_load_cav(cd)
	for gd in data.get("guns", []):
		var g := Gun.new()
		g.team = int(gd["team"])
		g.pos = Vector3(float(gd["x"]), 0, float(gd["z"]))
		g.move_to = g.pos
		g.facing = float(gd["facing"])
		g.dead = bool(gd["dead"])
		g.reload = ARTY_RELOAD * randf_range(0.2, 1.0)
		_make_gun(g)
		guns.append(g)
	for sd in data.get("ships", []):
		var node := _ship_node(int(sd["team"]))
		add_child(node)
		ships.append({ "node": node, "pos": Vector3(float(sd["x"]), 0, float(sd["z"])), "heading": float(sd["heading"]),
			"patrol_h": float(sd["heading"]), "speed": float(sd["speed"]), "team": int(sd["team"]), "fire_cd": randf_range(2.0, 6.0) })
	_assign_brigades()
	if player != null:
		off_pos = player.pos - Vector3(sin(player.facing), 0, cos(player.facing)) * 8.0
		off_facing = player.facing
		off_vis = player.facing
		_cam_yaw = player.facing + PI
	_recompute_start_strength()

func _clear_all_units() -> void:
	for b in battalions:
		if b.flag != null and is_instance_valid(b.flag):
			b.flag.queue_free()
	battalions.clear()
	for c in cavalry:
		if c.hoof_player != null and is_instance_valid(c.hoof_player):
			c.hoof_player.queue_free()
	cavalry.clear()
	for g in guns:
		if g.node != null and is_instance_valid(g.node):
			g.node.queue_free()
	guns.clear()
	for s in ships:
		var n = s["node"]
		if n != null and is_instance_valid(n):
			n.queue_free()
	ships.clear()
	supply_convoys.clear()
	brigades.clear()
	divisions.clear()
	player = null

func _load_batt(bd: Dictionary) -> void:
	var b := Batt.new()
	b.team = int(bd["team"])
	b.idx = int(bd["idx"])
	b.pos = Vector3(float(bd["x"]), 0, float(bd["z"]))
	b.spawn = b.pos
	b.last_pos = b.pos
	b.fire_pos = b.pos
	b._fat_pos = b.pos
	b.facing = float(bd["facing"])
	b.formation = String(bd["formation"])
	b.companies = int(bd["companies"])
	b.off_facing = b.facing
	b.off_pos = b.pos - Vector3(sin(b.facing), 0, cos(b.facing)) * 8.0
	b.morale = float(bd["morale"])
	b.cohesion = float(bd["cohesion"])
	b.fatigue = float(bd["fatigue"])
	b.ammo = float(bd["ammo"])
	b.independent = bool(bd["independent"])
	b.is_player = bool(bd["is_player"])
	b.is_raider = bool(bd.get("is_raider", false))
	b.human = bool(bd.get("human", false))
	b.rname = String(bd["rname"])
	b.quality = String(bd["quality"])
	b.spent = bool(bd["spent"])
	b.broken = bool(bd["broken"])
	b._leaders0 = int(bd.get("leaders0", 0))
	b.start_men = int(bd.get("start_men", int(bd["men"])))
	b.inst_col = Color(float(bd["icr"]), float(bd["icg"]), float(bd["icb"]), float(bd["ica"]))
	var sk = bd["skill"]
	for k in SKILL_KEYS:
		if sk.has(k):
			b.skill[k] = float(sk[k])
	_fill_figs(b, maxi(1, int(bd["men"])))
	b.roster = bd.get("roster", [])
	_relink_figs(b)
	# restore each soldier's own stats (marksmanship, nerve, build, wear) where they were saved
	if bd.has("figstats"):
		var fs: Array = bd["figstats"]
		for i in range(mini(b.figs.size(), fs.size())):
			var s: Array = fs[i]
			b.figs[i]["marks"] = float(s[0])
			b.figs[i]["nerve"] = float(s[1])
			b.figs[i]["wear"] = float(s[2])
			b.figs[i]["bw"] = float(s[3])
			b.figs[i]["bh"] = float(s[4])
			b.figs[i]["spd"] = float(s[5])
	b.exp_mul = _reload_factor(b)
	if not b.roster.is_empty():
		_reprofile(b)
	_make_flag(b, b.team)
	battalions.append(b)
	if b.is_player:
		player = b
		player.human = true

func _relink_figs(b: Batt) -> void:
	if b.roster.is_empty():
		return
	var living: Array = []
	for m in b.roster:
		if bool(m.get("alive", true)):
			living.append(m)
	var li := 1   # man[0] is the Capt (you, the mounted officer) — not a line fig
	for i in range(b.figs.size()):
		if li < living.size():
			b.figs[i]["man"] = living[li]
			li += 1

func _load_cav(cd: Dictionary) -> void:
	var c := Cav.new()
	c.team = int(cd["team"])
	c.idx = int(cd["idx"])
	c.cav_type = int(cd["cav_type"])
	c.pos = Vector3(float(cd["x"]), 0, float(cd["z"]))
	c.facing = float(cd["facing"])
	c.reserve_pos = Vector3(float(cd.get("rx", cd["x"])), 0, float(cd.get("rz", cd["z"])))
	c.state = String(cd.get("state", "reserve"))
	c.spent = bool(cd.get("spent", false))
	c.decide_cd = randf_range(0.0, CAV_DECIDE)
	var hp := AudioStreamPlayer3D.new()
	hp.max_distance = 1100.0
	hp.unit_size = 22.0
	hp.volume_db = 7.0
	add_child(hp)
	c.hoof_player = hp
	_fill_troopers(c)
	var want := int(cd.get("men", c.troopers.size()))
	while c.troopers.size() > want and not c.troopers.is_empty():
		c.troopers.pop_back()
	cavalry.append(c)

func _restore_militia_config(data: Dictionary) -> void:
	var m = data.get("militia", {})
	if typeof(m) != TYPE_DICTIONARY or m.is_empty():
		return
	GameConfig.has_militia = bool(m.get("has_militia", false))
	GameConfig.militia_uniform = int(m.get("uniform", 2))
	GameConfig.militia_facing = Color(float(m.get("fr", 0.82)), float(m.get("fg", 0.72)), float(m.get("fb", 0.50)))
	GameConfig.militia_flag = int(m.get("flag", 0))
	GameConfig.militia_hat = int(m.get("hat", 0))
	GameConfig.militia_belt = int(m.get("belt", 0))
	GameConfig.militia_pants = int(m.get("pants", 0))
	GameConfig.militia_name = String(m.get("name", "1st Volunteers"))
	GameConfig.local_slot = int(m.get("slot", GameConfig.local_slot))

func _show_bill() -> void:
	if _bill_panel == null or player == null:
		return
	var pt := player.team
	var et := 1 - pt
	var men_now := [0, 0, 0]   # index 2 (raiders) is summed but never displayed
	var guns_lost := [0, 0]    # raiders never field guns
	var horse_now := [0, 0]    # raiders never field cavalry
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
	var cstart_pt := (int(_setup.cav_per_team[pt]) if GameConfig.historical != "" else (4 if _inflated else CAV_PER_TEAM)) * _cav_men
	var cstart_et := (int(_setup.cav_per_team[et]) if GameConfig.historical != "" else (4 if _inflated else CAV_PER_TEAM)) * _cav_men
	txt += "[color=#cdd6e6]Our losses[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[pt] - men_now[pt], _start_strength[pt], cstart_pt - horse_now[pt], guns_lost[pt]]
	txt += "[color=#cdd6e6]Theirs[/color]  [color=#ffe9a8]%d[/color] of %d men · %d horse · %d guns silenced\n" \
		% [_start_strength[et] - men_now[et], _start_strength[et], cstart_et - horse_now[et], guns_lost[et]]
	if field_towns.size() > 0:
		txt += "[color=#cdd6e6]Towns held[/color]  [color=#9fe0a0]%d[/color] ours · [color=#ff9a8a]%d[/color] theirs · %d in contest\n" \
			% [tc[pt], tc[et], tc[2]]
	if _obj_text != "":
		var obj_stat := "[color=#9fe0a0]✓ achieved[/color]" if _obj_done else "[color=#ff9a8a]✗ unfulfilled[/color]"
		txt += "[color=#cdd6e6]Your charge[/color]  %s  %s\n" % [_obj_text, obj_stat]
	txt += "[color=#cdd6e6]Prestige banked[/color]  [color=#%s]%+d[/color]\n" % [pcol, prestige]
	txt += _regiment_bill()
	var foot := "Enter — return to the menu" if _campaign_over else "Enter — rest the night; the campaign goes on into the next day"
	txt += "[color=#6f7888]——————————————————————\n%s[/color][/center]" % foot
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
	var hit := _ray_hit_world(muzzle, sd, PISTOL_RANGE, player.team)
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
	var b := player
	b.presenting = false                    # the present is released by the volley
	# AT DRILL the volley is whatever the men actually managed to load — that IS the exercise,
	# so don't help them; just fire and mark it.
	if _drill_on:
		b.fire_now = true
		b.fire_forward = true
		_play_voice(snd_v_fire, b.off_pos)
		_score_drill_volley()
		return
	# IN THE FIELD "Give Fire!" is a COMMANDED VOLLEY — the WHOLE firing line discharges as ONE,
	# not a ragged trickle of whoever happened to be loaded. Switch to volley discipline (so the
	# men hold their fire rather than firing at will) and, once the line has reloaded since its
	# last volley, bring EVERY man in the firing ranks up to the present so they all fire together.
	# Then they must reload before the next volley — a well-drilled (or fresh) battalion sooner.
	b.volley_fire = true
	b.auto_volley = false
	b.indep_fire = false                        # a commanded volley supersedes independent fire
	b.rolling = false
	if b.volley_cd > 0.0:
		_play_voice(snd_v_present, b.off_pos)   # still reloading — the men come to the present, not yet loaded
		return
	var maxy := -1.0e9
	for f in b.figs:
		maxy = maxf(maxy, (f["slot"] as Vector2).y)
	var band := maxy - SP * 1.6
	for f in b.figs:
		if (f["slot"] as Vector2).y >= band:
			f["reload"] = 0.0               # every man in the firing ranks: loaded, levelled, ready as one
	b.fire_now = true
	b.fire_forward = true
	b.volley_cd = maxf(7.0, RELOAD_TIME * 0.6 * b.exp_mul * _fatigue_reload_mul(b))   # the reload before the next volley
	_play_voice(snd_v_fire, b.off_pos)

# "PRESENT!" — the battalion brings its muskets up to the level and holds, whether or not
# there is an enemy to its front. (Press V.) The arms tire after a while and lower again.
func _present() -> void:
	if player == null or player.figs.is_empty():
		return
	if player.charging or player.melee_foe != null or player.state == "routing":
		return
	player.presenting = true
	player.present_t = 0.0
	player.indep_fire = false               # a manual present cancels independent fire
	player.volley_fire = true               # hold at the present until "Fire!"
	if _drill_on:
		_drill_present_t = _t               # mark the beat so the volley's cadence can be judged
	_play_voice(snd_v_present, player.off_pos)
	# every man in the firing ranks cocks his piece — a crackle of locks down the line (budgeted)
	if player.visible:
		var maxy := -1.0e9
		for f in player.figs:
			maxy = maxf(maxy, (f["slot"] as Vector2).y)
		var band := maxy - SP * 1.6
		for f in player.figs:
			if (f["slot"] as Vector2).y >= band:
				_play_cock(f["wpos"])
	_send_player_despatch("[color=#ffe9a8]Present![/color] — the battalion brings its muskets up.", {})

# ---- direct battalion keybinds (no courier menu): apply the order straight to your battalion ----
func _self_order(o: Dictionary) -> void:
	if player == null or player.figs.is_empty():
		return
	if authoritative:
		_apply_net_order(player, o)
	else:
		_pending_net_order = o               # client: forward to the host

func _self_advance(yds: int) -> void:
	if player == null or player_arm == "cavalry" or player_arm == "artillery":
		return
	_self_order({ "kind": "advance_n", "yds": yds })
	_send_player_despatch("[color=#ffe9a8]Advance %d yards.[/color]" % yds, {})

func _self_halt() -> void:
	if player == null:
		return
	_self_order({ "kind": "halt", "face": off_vis })
	_send_player_despatch("[color=#ffe9a8]Halt![/color] — the line stands fast.", {})

func _self_wheel(deg: float) -> void:
	if player == null or player_arm == "cavalry" or player_arm == "artillery":
		return
	_self_order({ "kind": "wheel", "deg": deg })
	_send_player_despatch("[color=#ffe9a8]Wheel %s %d°.[/color]" % ["left" if deg > 0.0 else "right", int(absf(deg))], {})

func _independent_fire() -> void:
	if player == null or player_arm == "cavalry" or player_arm == "artillery" or player.figs.is_empty():
		return
	_self_order({ "kind": "indep_fire" })
	_send_player_despatch("[color=#ffe9a8]Fire at will![/color] — each man loads, comes to the present and fires in his own time.", {})

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
	if arm == "cavalry" and player_cav != null:
		nm = String(CAV_TYPE_DATA[player_cav.cav_type]["name"])   # name the actual arm, e.g. "the Lancers"
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
	var muzzle := g.pos + fwd * 1.5 + Vector3(0, 0.95 + _gh(g.pos.x, g.pos.z), 0)
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
	var cry := "Lances down" if player_cav.cav_type == 3 else "Sabres out"
	_send_player_despatch("[color=#ffd773]CHARGE![/color] %s — ride them down!" % cry, {})

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
			_scope_rect.visible = false
		cam.position = eye
		cam.look_at(to_global(eye + look * 80.0), Vector3.UP)
		if _shake > 0.001:
			cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.4
		return
	# spyglass: raise the glass (RMB) -> narrow the FOV and mask to a circular eyepiece. The
	# magnification is set by how far you draw the glass out (mouse wheel -> _scope_zoom).
	_scope_amt = move_toward(_scope_amt, 1.0 if _scoped else 0.0, delta * 6.0)
	var scope_fov := lerpf(FOV_SCOPE_WIDE, FOV_SCOPE_NARROW, _scope_zoom)
	cam.fov = lerpf(FOV_NORMAL, scope_fov, _scope_amt)
	if _scope_rect:
		_scope_rect.visible = _scope_amt > 0.001
		if _scope_mat:
			_scope_mat.set_shader_parameter("amt", _scope_amt)
			_scope_mat.set_shader_parameter("zoom", _scope_zoom)
	var target := off_pos + Vector3(0, 2.35, 0)   # a mounted man's eyeline — over the ranks
	# 3rd-person orbit behind you (camera height from _cam_pitch)
	var dir := Vector3(sin(_cam_yaw) * cos(_cam_pitch), sin(_cam_pitch), cos(_cam_yaw) * cos(_cam_pitch))
	var orbit_pos := target + dir * _cam_dist
	# spyglass: look FORWARD from your eyeline, freely up/down via _scope_pitch, with a gentle
	# HANDHELD sway + breathing so the glass feels held in the hand — and the wobble grows as
	# you draw it out to higher power (just as a real glass is harder to hold steady magnified).
	var sway := (0.0030 + 0.0042 * _scope_zoom) * _scope_amt
	var sway_yaw := (sin(_t * 1.7) * 0.6 + sin(_t * 0.83 + 1.3) * 0.4) * sway
	var sway_pitch := (sin(_t * 1.31 + 0.5) * 0.6 + sin(_t * 2.13) * 0.4) * sway * 0.8
	var syaw := _cam_yaw + sway_yaw
	var spitch := _scope_pitch + sway_pitch
	var hx := -sin(syaw)
	var hz := -cos(syaw)
	var look_dir := Vector3(hx * cos(spitch), sin(spitch), hz * cos(spitch))
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
	# the camp & roster are mouse-driven GUIs — while one is open the mouse drives the cursor,
	# NOT the camera look (no rotating the view behind the menu) nor the sabre/fire
	var ui_modal := _camp_on or (roster_panel != null and roster_panel.visible)
	if event is InputEventMouseMotion and _mouse_captured and _gun_sight and not ui_modal:
		# laying the piece: mouse traverses the barrel and depresses/raises the gaze
		var gs := MOUSE_SENS * 0.6
		_sight_yaw -= event.relative.x * gs
		_sight_pitch = clampf(_sight_pitch - event.relative.y * gs * 0.3, deg_to_rad(-14.0), deg_to_rad(3.0))
		return
	if event is InputEventMouseMotion and _mouse_captured and not ui_modal:
		var s := MOUSE_SENS * (1.0 - 0.65 * _scope_amt)   # finer aim through the glass
		_cam_yaw -= event.relative.x * s
		if _scoped:
			# spyglass: free look up and down (mouse up tilts the view up)
			_scope_pitch = clampf(_scope_pitch - event.relative.y * s, deg_to_rad(-55.0), deg_to_rad(70.0))
		else:
			_cam_pitch = clampf(_cam_pitch + event.relative.y * s, deg_to_rad(6.0), deg_to_rad(78.0))
	elif event is InputEventMouseButton and not ui_modal:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_scoped = event.pressed                       # hold RMB to raise the spyglass
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if player_arm == "artillery":
				_fire_player_battery()                    # give the word — the battery speaks
			else:
				_swing_sabre()                            # cut at whatever you're facing
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _scoped: _scope_zoom = clampf(_scope_zoom + 0.12, 0.0, 1.0)   # draw the glass out — magnify
			elif _rts_cam: _rts_dist = clampf(_rts_dist * 0.85, 40.0, 6000.0)
			else: _cam_dist = maxf(4.0, _cam_dist - 3.0)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _scoped: _scope_zoom = clampf(_scope_zoom - 0.12, 0.0, 1.0)   # collapse the glass — wider field
			elif _rts_cam: _rts_dist = clampf(_rts_dist * 1.18, 40.0, 6000.0)
			else: _cam_dist = minf(26.0, _cam_dist + 3.0)   # LOCKED: can pull back to the default view, no further out
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
					if player != null and player.encamped and not _mdrill_on and (act == "page:form" or act == "line" or act == "column" or act == "square"):
						_send_player_despatch("[color=#ffe9a8]The battalion is encamped[/color] — break camp before it can re-form or manoeuvre.", {})
						return
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
					if _campaign_over:
						# the province is decided — the war is over; leave the field
						Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
						if hosted:
							host_done = true     # MP host frees this battle and resumes the lobby
						else:
							get_tree().change_scene_to_file("res://menu.tscn")
					else:
						_continue_to_next_day()   # a spent day — the campaign carries on
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
			KEY_Y:
				_accept_escort()          # take the offered supply convoy under your escort
			KEY_1:
				if not _battle_begun: _choose_arm("infantry")   # step-off: choose your arm
				else: _self_advance(5)                          # in the field: a measured advance
			KEY_2:
				if not _battle_begun: _choose_arm("artillery")
				else: _self_advance(15)
			KEY_3:
				if not _battle_begun: _choose_arm("cavalry")
				else: _self_advance(25)
			KEY_4:
				_self_advance(50)
			KEY_5:
				_self_halt()                  # stop where they stand
			KEY_6:
				_self_wheel(45.0)             # wheel left 45°
			KEY_7:
				_self_wheel(90.0)             # wheel left 90°
			KEY_8:
				_self_wheel(-45.0)            # wheel right 45°
			KEY_9:
				_self_wheel(-90.0)            # wheel right 90°
			KEY_0:
				_independent_fire()           # each man loads, presents and fires in his own time
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
				pass   # courier order book removed for now (see _cmd_on)
			KEY_T:
				_command_battery()        # bring the nearest friendly guns up to support you
			KEY_B:
				_send_scouts()            # send the nearest light horse forward to scout the front
			KEY_TAB:
				_help_on = not _help_on
			KEY_F3:
				_aidbg_on = not _aidbg_on   # dev: show what the AI commanders are thinking
				_map_reveal = _aidbg_on     # ...and lift the fog of the province map
				if aidbg_panel:
					aidbg_panel.visible = _aidbg_on
			KEY_F4:
				_toggle_rts_cam()           # dev: free-fly RTS camera over the whole province
			KEY_F5:
				_save_game()                # quicksave the campaign
			KEY_F9:
				var sd = _load_save_file()  # quickload (this campaign — same map seed)
				if sd != null:
					_apply_save(sd)
					_send_player_despatch("[color=#9fe0a0]Campaign reloaded — day %d.[/color]" % _day_count, {})
				else:
					_send_player_despatch("[color=#ff9a8a]No save to load.[/color]", {})
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
		"scout":
			# a client asked for scouts — send that side's nearest light horse toward the point
			_host_send_scouts(b.team, Vector3(float(o.get("x", b.pos.x)), 0.0, float(o.get("z", b.pos.z))), b.off_pos, false)
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
		"wheel":
			# a measured wheel: positive degrees turn LEFT (+yaw → toward -x), negative turn RIGHT
			b.order = Order.IDLE
			b.wheeling = true
			b.has_goal = false
			b.advancing = false
			b.wheel_to = b.facing + deg_to_rad(float(o.get("deg", 45.0)))
		"indep_fire":
			# INDEPENDENT fire: hold no longer — every man loads, comes to the present and fires
			# in his own time (see the fire loop, which makes each man present 1–2 s by drill, then fire)
			b.indep_fire = true
			b.volley_fire = false
			b.auto_volley = false
			b.rolling = false
			b.presenting = false
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
	# These emitters live at the world origin but throw world-space particles ALL OVER the
	# province (x ≈ -8700..2100, z ≈ ±8500 — see _MAP_WMIN/_MAP_WMAX). The visibility AABB is
	# in the node's local space, so it must span the whole roamable world (+ the offshore strip
	# where ship-broadside smoke blooms, + headroom for rising smoke). A box only around origin
	# made Godot frustum-cull the ENTIRE emitter whenever the camera looked away from origin —
	# so smoke vanished unless you happened to face world centre. This box always covers wherever
	# the camera can be, so the node never wrongly culls.
	p.visibility_aabb = AABB(Vector3(-9200, -200, -9200), Vector3(12400, 800, 18400))
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
	m.gravity = Vector3(0, 0.012, 0)          # barely rises — powder smoke hangs at the line,
											  # not lofting metres into the sky over its lifetime
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
	# a Blender-baked billowy smoke puff instead of a flat radial gradient (falls back cleanly)
	m.albedo_texture = (load("res://images/smoke_puff.png") if ResourceLoader.exists("res://images/smoke_puff.png") else _radial_tex())
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

# Dust torn up by a galloping squadron — a low, earthy puff kicked up and back off the
# hooves, then carried on the wind. Reuses the musket-smoke emitter (rolls forward and
# thins out the same way) tinted to a dry-earth tan, so no extra emitter is needed.
const DUST_RANGE := 220.0        # don't spend particles on dust the camera can't see
func _emit_dust(pos: Vector3, fwd: Vector3) -> void:
	var kick := -fwd * randf_range(0.4, 1.2) + Vector3(0, randf_range(0.3, 0.8), 0) + _wind
	var jitter := Vector3(randf_range(-0.4, 0.4), 0.0, randf_range(-0.4, 0.4))
	musket_smoke_p.emit_particle(Transform3D(Basis(), pos + jitter), kick,
		Color(0.60, 0.50, 0.36), Color.WHITE, EMIT_FLAGS)

# A few low puffs spread along a battalion's front, scaled to its strength — bigger
# units throw up more dust under their boots, small remnants barely any.
func _emit_march_dust(b: Batt) -> void:
	var fwd := Vector3(sin(b.facing), 0, cos(b.facing))
	var right := Vector3(fwd.z, 0, -fwd.x)
	# the dust footprint follows the ACTUAL formation, not a fixed line-wide band: a deployed line
	# throws a WIDE, shallow haze; a marching column a NARROW, deep one; a square a compact block.
	var d := _dims(b.figs.size(), b.formation)
	var half_w := float(d.x) * SP * 0.55       # half the frontage (files across)
	var half_d := float(d.y) * SP * 0.55       # half the depth (ranks deep)
	var n := clampi(b.figs.size() / 45, 1, 4)
	for _i in range(n):
		var p := b.pos + right * randf_range(-half_w, half_w) + fwd * randf_range(-half_d, half_d)
		p.y = _gh(p.x, p.z) + 0.05
		_emit_dust(p, fwd)

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

# A line musket's report — drawn from the shared per-frame budget so a mass volley gives
# every musket a crack without exhausting the voice pool. The player's own shots bypass this.
func _play_shot_line(pos: Vector3) -> void:
	if _musket_snd_left <= 0:
		return
	_musket_snd_left -= 1
	_play_shot(pos)

# the click of a musket brought to the present (cocked) — budgeted per frame so a battalion coming
# to the present reads as a quick crackle of locks, not 700 overlapping clicks.
func _play_cock(pos: Vector3) -> void:
	if snd_cock == null or cam == null or _cock_snd_left <= 0:
		return
	if cam.position.distance_to(pos) > 150.0:
		return
	_cock_snd_left -= 1
	var ap: AudioStreamPlayer3D = _audio_pool[_audio_i]
	_audio_i = (_audio_i + 1) % AUDIO_POOL
	ap.stream = snd_cock
	ap.global_position = to_global(pos + Vector3(0, 1.3, 0))
	ap.volume_db = 0.0
	ap.pitch_scale = randf_range(0.95, 1.06)
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

# The battalion a given MP lobby slot commands — found by the human_slot tag set at spawn (works for
# both the authored OOB and the campaign field, where the slot maps to a brigade-lead gidx).
func _batt_for_slot(slot: int) -> Batt:
	for b in battalions:
		if b.human_slot == slot:
			return b
	return _batt_by_idx(_player_gidx(slot))   # fallback to the index mapping

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
	if multiplayer.multiplayer_peer == null or multiplayer.get_peers().is_empty():
		return                                   # no clients connected — don't build or send a frame
	_net_cd -= delta
	if _net_cd > 0.0:
		return
	_net_cd = 1.0 / NET_HZ
	# AREA-OF-INTEREST + FOG: the host simulates the WHOLE field but streams each team only what THAT
	# side can see — its own units near a player (AoI) and the enemy units it has SCOUTED (`_spotted`).
	# An unscouted enemy is never even SENT, so fog is host-authoritative and can't be peeked at.
	var team_pids := {}                          # team -> [peer_id,…] (a slot's team is slot % 2)
	for pid in multiplayer.get_peers():
		var t: int = int(Net.lobby.get(pid, 0)) % 2
		if not team_pids.has(t):
			team_pids[t] = []
		team_pids[t].append(pid)
	for T in team_pids:
		var pids: Array = team_pids[T]
		var eyes: Array = []                     # this team's eyes — its own officers
		for h in battalions:
			if h.human and h.team == T and not h.spent:
				eyes.append(h.off_pos)
		# battalions: own units in-AoI (+a rolling far refresh so your whole army stays on the map),
		# enemy units only where this side has scouted them
		var sel: Array = []
		var far: Array = []
		for i in range(battalions.size()):
			var b: Batt = battalions[i]
			if b.team == T:
				if b.human or _net_aoi(b.pos, eyes):
					sel.append(i)
				else:
					far.append(i)
			elif b._spotted:
				sel.append(i)
			elif PLAYER_SEES_ALL:
				far.append(i)        # reveal-all: stream unscouted enemies too (rolling far-refresh)
		if not far.is_empty():
			var per_tick := maxi(1, ceili(float(far.size()) / (FAR_REFRESH * NET_HZ)))
			for _k in range(per_tick):
				sel.append(far[_net_far_cursor % far.size()])
				_net_far_cursor += 1
		var bi := 0
		while bi < sel.size():
			var bchunk: Array = []
			for k in range(bi, mini(bi + NET_CHUNK, sel.size())):
				var i: int = sel[k]
				var b: Batt = battalions[i]
				var fm := 2 if b.rolling else (1 if b.volley_fire else 0)
				bchunk.append([i,
					b.pos.x, b.pos.z, b.facing, b.figs.size(), int(b.morale),
					_state_code(b.state), 1 if b.formation == "line" else 0,
					b.charging, b.melee_foe != null, b.flinch,
					b.off_pos.x, b.off_pos.z, b.off_facing, b.human,
					b.has_target, fm,
				])
			for pid in pids:
				rpc_id(pid, "_apply_state", bchunk)
			bi += NET_CHUNK
		# cavalry — own regiments always, enemy horse only where scouted
		var csel: Array = []
		for i in range(cavalry.size()):
			var c: Cav = cavalry[i]
			if c.spent:
				continue
			if c.team == T or c._spotted or PLAYER_SEES_ALL:
				csel.append(i)
		var ci := 0
		while ci < csel.size():
			var cchunk: Array = []
			for k in range(ci, mini(ci + NET_CHUNK, csel.size())):
				var i: int = csel[k]
				var c: Cav = cavalry[i]
				cchunk.append([i, c.pos.x, c.pos.z, c.facing, c.troopers.size(), c.state, c.spent])
			for pid in pids:
				rpc_id(pid, "_apply_cav_state", cchunk)
			ci += NET_CHUNK
		# guns — own batteries always, enemy guns only where scouted
		var gsel: Array = []
		for i in range(guns.size()):
			var g: Gun = guns[i]
			if g.dead and g.team != T:
				continue
			if g.team == T or g._spotted or PLAYER_SEES_ALL:
				gsel.append(i)
		var gi := 0
		while gi < gsel.size():
			var gchunk: Array = []
			for k in range(gi, mini(gi + NET_CHUNK, gsel.size())):
				var i: int = gsel[k]
				var g: Gun = guns[i]
				gchunk.append([i, g.pos.x, g.pos.z, g.facing, g.dead, g.crew.size(), g.limber_state, g.recoil])
			for pid in pids:
				rpc_id(pid, "_apply_gun_state", gchunk)
			gi += NET_CHUNK
	# the SHARED WORLD — clock, ships and town ownership — so every player rides the same province
	var sdata: Array = []
	for s in ships:
		var sp: Vector3 = s["pos"]
		sdata.append([sp.x, sp.z, float(s["heading"])])
	var tdata: Array = []
	for t in field_towns:
		tdata.append([int(t["owner"]), float(t["cap_t"]), int(t["cap_team"])])
	rpc("_apply_world", _time_of_day, _battle_begun, sdata, tdata)
	if not _fx.is_empty():
		rpc("_apply_fx", _fx.duplicate())
		_fx.clear()

# True if a point is within the area of interest of any of a team's eyes (its officers).
func _net_aoi(pos: Vector3, eyes: Array) -> bool:
	for e in eyes:
		if pos.distance_to(e) < AOI_RANGE:
			return true
	return false

@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_state(data: Array) -> void:
	if not _got_state:
		_got_state = true
		print("[NET] client received first state (AOI; OOB %d)" % battalions.size())
	for e in data:
		var idx := int(e[0])                     # self-indexing: each entry carries its OOB index
		if idx < 0 or idx >= battalions.size():
			continue
		var b: Batt = battalions[idx]
		b.pos = Vector3(e[1], 0.0, e[2])
		b.facing = e[3]
		b.morale = float(e[5])
		b.state = _state_name(int(e[6]))
		var form := "line" if int(e[7]) == 1 else "column"
		if b.formation != form:
			b.formation = form
			_reslot(b)
		b.charging = bool(e[8])
		b.melee_vis = bool(e[9])
		b.flinch = float(e[10])
		b.off_pos = Vector3(e[11], 0.0, e[12])
		b.off_facing = e[13]
		b.human = bool(e[14])
		b.has_target = bool(e[15])
		b.fx_firemode = int(e[16])
		_net_set_strength(b, int(e[4]))
		# CLIENT FOG: receiving an enemy unit IS the sighting (the host only sends scouted enemies) —
		# mark it spotted/fresh so it draws; the client's fog tick lets it fade if updates stop.
		if player != null and b.team != player.team:
			b._spotted = true
			b._intel_pos = b.pos
			b._intel_t = _t

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

# HOST -> clients: every regiment of horse — pos/facing/strength/state. The troopers'
# saddle positions interpolate locally toward the formation, so only the count is synced.
@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_cav_state(cdata: Array) -> void:
	for e in cdata:
		var idx := int(e[0])                         # self-indexing
		if idx < 0 or idx >= cavalry.size():
			continue
		var c: Cav = cavalry[idx]
		c.pos = Vector3(e[1], 0.0, e[2])
		c.facing = float(e[3])
		c.state = String(e[5])
		c.spent = bool(e[6])
		_net_set_troopers(c, int(e[4]))
		if player != null and c.team != player.team:
			c._spotted = true                        # client fog: a received enemy regiment is sighted
			c._intel_pos = c.pos
			c._intel_t = _t

func _net_set_troopers(c: Cav, target: int) -> void:
	while c.troopers.size() > target and not c.troopers.is_empty():
		c.troopers.pop_back()                    # saddles emptied on the host

# HOST -> clients: every gun — pos/facing/dead/crew/limber. The client doesn't run the gun
# sim, so we place the node ourselves, show the limber team when it's moving, and thin the crew.
@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_gun_state(gdata: Array) -> void:
	for e in gdata:
		var idx := int(e[0])                         # self-indexing
		if idx < 0 or idx >= guns.size():
			continue
		var g: Gun = guns[idx]
		g.pos = Vector3(e[1], 0.0, e[2])
		g.facing = float(e[3])
		g.dead = bool(e[4])
		g.limber_state = String(e[6])
		g.recoil = float(e[7])
		if g.node != null:
			g.node.position = Vector3(g.pos.x, _gh(g.pos.x, g.pos.z), g.pos.z)
			g.node.rotation.y = g.facing
			g.node.visible = true                    # a received enemy gun is, by definition, sighted
		if g.barrel != null:
			g.barrel.position.z = 0.25 - g.recoil
		_set_limber_visible(g, g.limber_state == "limbering" or g.limber_state == "moving")
		_net_set_crew(g, int(e[5]))
		if player != null and g.team != player.team:
			g._spotted = true
			g._intel_t = _t

func _net_set_crew(g: Gun, target: int) -> void:
	while g.crew.size() > target and not g.crew.is_empty():
		var node: Node3D = g.crew.pop_back()
		if not g.crew_base.is_empty():
			g.crew_base.pop_back()
		var wp: Vector3 = g.node.to_global(node.position) if g.node != null else node.position
		node.queue_free()
		_drop_dead(Vector3(wp.x, 0.0, wp.z), g.team, Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), true)

# HOST -> clients: the shared world — the day/night clock, the battle's start, the shipping's
# course and who holds each town — so every player rides the SAME living province, not a divergent
# copy. (Clients no longer advance the clock or steer ships themselves; they take it from here.)
@rpc("authority", "call_remote", "unreliable_ordered")
func _apply_world(tod: float, bbegun: bool, sdata: Array, tdata: Array) -> void:
	_time_of_day = tod
	if bbegun and not _battle_begun:
		_begin_battle()                          # step off together with the host
	for i in range(mini(sdata.size(), ships.size())):
		var sp: Vector3 = ships[i]["pos"]
		ships[i]["pos"] = Vector3(sdata[i][0], sp.y, sdata[i][1])
		ships[i]["heading"] = float(sdata[i][2])
	var recolor := false
	for i in range(mini(tdata.size(), field_towns.size())):
		var t = field_towns[i]
		if int(t["owner"]) != int(tdata[i][0]):
			recolor = true                       # a town changed hands — repaint its colours/flag
		t["owner"] = int(tdata[i][0])
		t["cap_t"] = float(tdata[i][1])
		t["cap_team"] = int(tdata[i][2])
	if recolor:
		_color_towns()

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
	var b := _batt_for_slot(slot)
	if b == null:
		return
	b.off_pos = c_off_pos
	b.off_facing = c_off_facing
	if not order.is_empty():
		_apply_net_order(b, order)

# host: a player dropped — hand his orphaned battalion to the AI so the line keeps fighting
# instead of standing frozen for want of orders. (Called by Net on peer_disconnected.)
func net_player_left(slot: int) -> void:
	var b := _batt_for_slot(slot)
	if b == null:
		return
	b.human = false
	b.human_slot = -1
	if b != player:
		b.is_player = false
	b.order = Order.IDLE
	_send_player_despatch("[color=#ffd27f]A commander has quit the field — his battalion comes under the army's hand.[/color]", {})

# client: the host vanished — there is no authority left to run the battle, so bow out.
func net_server_lost() -> void:
	GameConfig.mode = "single"
	get_tree().change_scene_to_file("res://menu.tscn")

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
			FX_GUN:
				_gun_muzzle_fx(Vector3(e[1], e[2], e[3]), Vector3(e[4], 0.0, e[5]))

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
			var mp := w + Vector3(0, 1.35 + _gh(w.x, w.z), 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip (on the slope)
			_emit_flash(mp)
			_emit_smoke(mp, fwd)
			_emit_smoke(mp, fwd)
			_emit_muzzle_bloom(mp, fwd)
			_play_shot_line(mp)       # each musket in the volley reports too (budgeted)
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
			var mp := w + Vector3(0, 1.35 + _gh(w.x, w.z), 0) + right * 0.14 + fwd * 1.1   # musket muzzle tip (on the slope)
			_emit_flash(mp)
			_emit_smoke(mp, fwd)
			_emit_muzzle_bloom(mp, fwd)
			_play_shot_line(mp)
			f["reload"] = RELOAD_TIME * randf_range(0.78, 1.3)
		else:
			f["reload"] = 0.0            # hold aimed for the volley command

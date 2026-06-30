class_name Historical
extends RefCounted

# Set-piece HISTORICAL battles, authored straight into the BattleSetup seam (game.gd spawns them via
# _spawn_from_setup). WATERLOO, 18 June 1815 — FULL battalion-level order of battle, structured
# army → corps → division → brigade → battalion, deployed on a ~Waterloo layout (1 world unit ≈ 1 m):
# the French Armée du Nord to the SOUTH (team 0, facing +Z onto the ridge), the Anglo-Allied army on
# the Mont-Saint-Jean ridge to the NORTH (team 1, facing -Z), and Blücher's Prussians (also team 1)
# marching up from the EAST. Cavalry & artillery are still spawned from counts (authoring them to the
# OOB, wiring the corps/division/brigade command structure, the authentic terrain, the historical
# AI script and the timed Prussian arrival are the planned follow-on steps).
#
# Strengths are the round figures most references converge on (battalions were badly understrength by
# 18 June). Designations are at the battalion level; correct any specifics you want exact.

const FR_LINE  := Color(0.13, 0.18, 0.46)   # French line — dark blue
const FR_LIGHT := Color(0.10, 0.16, 0.40)   # French légère — blue
const FR_GUARD := Color(0.07, 0.11, 0.32)   # the Imperial Guard — deeper blue
const BR_RED   := Color(0.63, 0.15, 0.13)   # British — red
const KGL_RED  := Color(0.70, 0.18, 0.15)   # King's German Legion — red (lighter)
const HAN_RED  := Color(0.55, 0.14, 0.14)   # Hanoverian — red (darker)
const NL_BLUE  := Color(0.18, 0.28, 0.58)   # Dutch-Belgian — blue
const BRUNS    := Color(0.10, 0.10, 0.13)   # Brunswick — black
const NASSAU   := Color(0.16, 0.30, 0.20)   # Nassau — green
const PRUSS    := Color(0.14, 0.18, 0.34)   # Prussian — dark blue

# Nationality → [coat_idx (slot into the side's 3-coat palette, COATS_W0/W1 in game.gd), facing trim
# colour (collar/cuffs/lapels)]. The coat gives the national dress; the facing the regimental/national
# distinction. France: all three slots are blues; the Allies: 0=British red, 1=Allied blue, 2=black.
# Nationality → [coat_idx (slot into COATS_W0/W1), facing trim colour, belt_idx (0 white / 1 black / 2 brown)].
# coat slot 3 is the green (rifles / jägers / Nassau). Rifle battalions are auto-detected by name in
# _brig (green coat + black belts) regardless of their brigade's nationality.
const NAT := {
	"FR": [0, Color(0.72, 0.12, 0.12), 0],   # French line — blue coat, red facings, white belts
	"FL": [1, Color(0.88, 0.78, 0.22), 0],   # French légère — blue, yellow trim
	"FG": [2, Color(0.74, 0.12, 0.12), 0],   # Imperial Guard — deep blue, red facings (gold lace)
	"BR": [0, Color(0.90, 0.86, 0.74), 0],   # British — red coat, buff facings, white belts
	"KG": [0, Color(0.13, 0.22, 0.52), 0],   # King's German Legion — red, blue facings
	"HA": [0, Color(0.90, 0.80, 0.22), 0],   # Hanoverian — red, yellow facings
	"NL": [1, Color(0.93, 0.52, 0.12), 0],   # Dutch-Belgian — blue coat, orange (House of Orange) facings
	"NA": [3, Color(0.88, 0.80, 0.20), 0],   # Nassau — GREEN coat, yellow facings
	"BW": [2, Color(0.42, 0.62, 0.86), 1],   # Brunswick — black coat, light-blue facings, BLACK belts
	"PR": [1, Color(0.80, 0.14, 0.14), 0],   # Prussian — blue coat, red facings
}

static func make(key: String) -> BattleSetup:
	match key:
		"waterloo":
			return waterloo()
	return null

static func waterloo() -> BattleSetup:
	var s := BattleSetup.new()
	s.seed_value = 18061815
	s.time_of_day = 11.5
	s.weather = "clear"
	s.historical = "waterloo"
	s.guns_per_team = [22, 16]   # BATTERIES (×4 guns ⇒ ~88 French, ~64 Allied pieces — the grand battery scale)
	s.cav_per_team = [26, 34]    # cavalry regiments at ~400 troopers each ⇒ ~10k French / ~14k Allied+Prussian horse
	_french(s)
	_allied(s)
	_prussian(s)
	# you take the field as a British battalion holding the centre of the ridge (Halkett's brigade)
	for u in s.units:
		if u.name == "33rd Foot":
			u.human_slot = 0
			break
	return s

# MULTIPLAYER: map lobby slots to real battalions. Each side offers up to 8 commandable commands
# (a brigade-lead battalion each); even slots are the Anglo-Allied side, odd slots the French — so a
# player picks a side simply by claiming an even or odd slot. Only CLAIMED slots become human-led;
# everything else stays under the AI. `claimed` is the list of lobby slot indices in play.
const MP_PER_SIDE := 8
static func assign_mp_slots(s: BattleSetup, claimed: Array) -> void:
	for u in s.units:
		u.human_slot = -1                       # clear the single-player default
	var allied: Array = []
	var french: Array = []
	var seen := {}
	for u in s.units:
		if seen.has(u.brigade):
			continue                            # one command per brigade (its lead battalion)
		seen[u.brigade] = true
		if u.team == 1:
			allied.append(u)
		else:
			french.append(u)
	for k in range(min(MP_PER_SIDE, allied.size())):
		var aslot := k * 2                       # even → Anglo-Allied
		if aslot in claimed:
			allied[k].human_slot = aslot
	for k in range(min(MP_PER_SIDE, french.size())):
		var fslot := k * 2 + 1                   # odd → French
		if fslot in claimed:
			french[k].human_slot = fslot

# =================================================================== FRENCH (team 0, facing +Z)
static func _french(s: BattleSetup) -> void:
	var f := 0.0
	# --- I CORPS (d'Erlon) — the right-centre, against the Allied left & La Haye Sainte ---
	_brig(s, 0, 1, 1, 1, Vector3(-60, 0, -560), f, "FR", 560, 1.0,  ["54e Ligne I", "54e Ligne II", "55e Ligne I", "55e Ligne II"])    # Quiot
	_brig(s, 0, 1, 1, 2, Vector3(180, 0, -560), f, "FR", 560, 1.0,  ["28e Ligne I", "28e Ligne II", "105e Ligne I", "105e Ligne II"]) # Bourgeois
	_brig(s, 0, 1, 2, 3, Vector3(360, 0, -560), f, "FL", 540, 1.0, ["13e Léger I", "13e Léger II", "17e Ligne I", "17e Ligne II"])   # Schmitz
	_brig(s, 0, 1, 2, 4, Vector3(560, 0, -560), f, "FR", 560, 1.0,  ["19e Ligne I", "19e Ligne II", "51e Ligne I", "51e Ligne II"])   # Aulard
	_brig(s, 0, 1, 3, 5, Vector3(740, 0, -560), f, "FR", 560, 1.05, ["21e Ligne I", "21e Ligne II", "46e Ligne I", "46e Ligne II"])   # Nogues
	_brig(s, 0, 1, 3, 6, Vector3(940, 0, -560), f, "FR", 560, 1.05, ["25e Ligne I", "25e Ligne II", "45e Ligne I", "45e Ligne II"])   # Grenier
	_brig(s, 0, 1, 4, 7, Vector3(1140, 0, -540), f, "FR", 560, 1.0, ["8e Ligne I", "8e Ligne II", "29e Ligne I", "29e Ligne II"])     # Pégot
	_brig(s, 0, 1, 4, 8, Vector3(1340, 0, -540), f, "FR", 560, 1.0, ["85e Ligne I", "85e Ligne II", "95e Ligne I", "95e Ligne II"])   # Brue
	# --- II CORPS (Reille) — the left, against Hougoumont ---
	_brig(s, 0, 2, 5, 9,  Vector3(-1360, 0, -560), f, "FL", 540, 1.05, ["2e Léger I", "2e Léger II", "61e Ligne I", "61e Ligne II"]) # Husson
	_brig(s, 0, 2, 5, 10, Vector3(-1160, 0, -560), f, "FR", 560, 1.05, ["72e Ligne I", "72e Ligne II", "108e Ligne I", "108e Ligne II"]) # Campy
	_brig(s, 0, 2, 9, 11, Vector3(-960, 0, -560), f, "FR", 560, 1.1, ["92e Ligne I", "92e Ligne II", "93e Ligne I", "93e Ligne II"])  # Gauthier (Foy)
	_brig(s, 0, 2, 9, 12, Vector3(-760, 0, -560), f, "FR", 560, 1.1, ["100e Ligne I", "100e Ligne II", "4e Léger I", "4e Léger II"])  # Jamin (Foy)
	_brig(s, 0, 2, 6, 13, Vector3(-560, 0, -460), f, "FL", 540, 1.05, ["1er Léger I", "1er Léger II", "3e Ligne I", "3e Ligne II"])  # Bauduin (Jérôme — Hougoumont)
	_brig(s, 0, 2, 6, 14, Vector3(-360, 0, -460), f, "FR", 560, 1.05, ["1er Ligne I", "1er Ligne II", "2e Ligne I", "2e Ligne II"])   # Soye (Jérôme)
	# --- VI CORPS (Lobau) — reserve on the French right (sent to hold Plancenoit) ---
	_brig(s, 0, 6, 19, 15, Vector3(820, 0, -900), f, "FR", 560, 1.05, ["5e Ligne", "11e Ligne", "27e Ligne", "84e Ligne"])           # Simmer
	_brig(s, 0, 6, 20, 16, Vector3(1020, 0, -900), f, "FR", 560, 1.05, ["5e Léger", "10e Ligne", "107e Ligne"])                       # Jeanin
	# --- THE IMPERIAL GUARD — the reserve, centre-rear ---
	_brig(s, 0, 0, 99, 17, Vector3(-160, 0, -1100), f, "FG", 600, 1.35, ["1er Grenadiers I", "1er Grenadiers II", "2e Grenadiers I", "2e Grenadiers II"]) # Old Guard (Friant)
	_brig(s, 0, 0, 99, 18, Vector3(80, 0, -1100), f, "FG", 600, 1.35, ["1er Chasseurs I", "1er Chasseurs II", "2e Chasseurs I", "2e Chasseurs II"])       # Old Guard (Morand)
	_brig(s, 0, 0, 98, 19, Vector3(-160, 0, -1020), f, "FG", 600, 1.25, ["3e Grenadiers", "4e Grenadiers", "3e Chasseurs", "4e Chasseurs"])               # Middle Guard (the last attack)
	_brig(s, 0, 0, 97, 20, Vector3(120, 0, -940), f, "FG", 600, 1.15, ["1er Tirailleurs", "1er Voltigeurs", "3e Tirailleurs", "3e Voltigeurs"])           # Young Guard (Duhesme — Plancenoit)
	_brig(s, 0, 0, 96, 70, Vector3(360, 0, -960), f, "FG", 560, 1.1, ["2e Tirailleurs", "2e Voltigeurs", "4e Tirailleurs", "4e Voltigeurs"])             # Young Guard (2nd, Plancenoit)
	# VI CORPS — Teste's division, sent to hold Plancenoit against the Prussians
	_brig(s, 0, 6, 21, 71, Vector3(1220, 0, -900), f, "FR", 560, 1.0, ["8e Léger", "40e Ligne", "65e Ligne", "75e Ligne"])                               # Teste (VI Corps)

# =================================================================== ANGLO-ALLIED (team 1, facing -Z)
static func _allied(s: BattleSetup) -> void:
	var f := PI
	# --- I CORPS (Prince of Orange) ---
	# 1st Division (Cooke) — the Foot Guards, holding Hougoumont, right of the line
	_brig(s, 1, 1, 1, 21, Vector3(-700, 0, 520), f, "BR", 1000, 1.3,  ["2/1st Foot Guards", "3/1st Foot Guards"])                 # Maitland
	_brig(s, 1, 1, 1, 22, Vector3(-520, 0, 520), f, "BR", 1000, 1.3,  ["2nd Coldstream Guards", "2/3rd Foot Guards"])            # Byng (Hougoumont garrison)
	# 3rd Division (Alten) — the centre, behind La Haye Sainte
	_brig(s, 1, 1, 3, 23, Vector3(-260, 0, 600), f, "BR", 620, 1.15, ["2/30th Foot", "33rd Foot", "2/69th Foot", "2/73rd Foot"]) # Halkett
	_brig(s, 1, 1, 3, 24, Vector3(-40, 0, 600), f, "KG", 520, 1.2,  ["1st Line KGL", "2nd Line KGL", "5th Line KGL", "8th Line KGL"]) # Ompteda (La Haye Sainte)
	_brig(s, 1, 1, 3, 25, Vector3(180, 0, 600), f, "HA", 620, 1.0,  ["Bremen", "Verden", "York", "Lüneburg"])                  # Kielmansegge (Hanoverian)
	# 2nd Dutch-Belgian Division (Perponcher) — the left, Papelotte
	_brig(s, 1, 1, 2, 26, Vector3(820, 0, 560), f, "NL", 580, 0.9,  ["7th Belgian Line", "27th Dutch Jagers", "5th Dutch Militia", "7th Dutch Militia"]) # Bijlandt
	_brig(s, 1, 1, 2, 27, Vector3(1040, 0, 540), f, "NA", 850, 1.0,  ["2nd Nassau (1st Bn)", "2nd Nassau (2nd Bn)", "2nd Nassau (3rd Bn)", "Orange-Nassau"]) # Saxe-Weimar (Papelotte)
	# 3rd Dutch-Belgian Division (Chassé) — reserve behind the right-centre
	_brig(s, 1, 1, 99, 28, Vector3(-300, 0, 920), f, "NL", 580, 0.95, ["35th Belgian Jagers", "2nd Dutch Line", "4th Dutch Militia", "6th Dutch Militia"]) # Detmers
	# --- II CORPS (Lord Hill) ---
	# 2nd Division (Clinton) — right rear
	_brig(s, 1, 2, 2, 29, Vector3(-1080, 0, 560), f, "BR", 620, 1.2,  ["1/52nd Light", "1/71st Highland", "2/95th Rifles", "3/95th Rifles"]) # Adam
	_brig(s, 1, 2, 2, 30, Vector3(-1280, 0, 560), f, "KG", 520, 1.15, ["1st Line KGL (2nd)", "2nd Line KGL (2nd)", "3rd Line KGL", "4th Line KGL"]) # du Plat (KGL)
	# 4th Division (Colville) — the far right (Braine-l'Alleud)
	_brig(s, 1, 2, 4, 31, Vector3(-1480, 0, 700), f, "BR", 620, 1.05, ["3/14th Foot", "1/23rd Fusiliers", "51st Light"])         # Mitchell
	# --- THE RESERVE (Wellington's own hand) ---
	# 5th Division (Picton) — the left-centre, the famous infantry stand
	_brig(s, 1, 0, 5, 32, Vector3(440, 0, 560), f, "BR", 620, 1.2,  ["28th Foot", "32nd Foot", "79th Cameron", "1/95th Rifles"]) # Kempt
	_brig(s, 1, 0, 5, 33, Vector3(640, 0, 560), f, "BR", 620, 1.25, ["3/1st Royal Scots", "42nd Black Watch", "2/44th Foot", "92nd Gordon"]) # Pack (Highlanders)
	# 6th Division (Lambert) — reserve behind the centre
	_brig(s, 1, 0, 6, 34, Vector3(260, 0, 860), f, "BR", 620, 1.2,  ["4th Foot", "27th Inniskilling", "40th Foot"])              # Lambert
	# The Brunswick Corps — reserve behind the centre
	_brig(s, 1, 0, 9, 35, Vector3(20, 0, 900), f, "BW", 520, 1.05, ["Leib-Bataillon", "1st Light Bn", "2nd Light Bn", "3rd Light Bn"]) # Brunswick light
	_brig(s, 1, 0, 9, 36, Vector3(220, 0, 980), f, "BW", 520, 1.05, ["1st Line Bn", "2nd Line Bn", "3rd Line Bn"])               # Brunswick line
	# 1st Nassau Regiment — attached, behind the left
	_brig(s, 1, 0, 10, 37, Vector3(700, 0, 920), f, "NA", 850, 1.0, ["1st Nassau (1st Bn)", "1st Nassau (2nd Bn)", "1st Nassau (3rd Bn)"]) # Kruse
	# --- THE HANOVERIAN CONTINGENT — the large German militia/Landwehr brigades ---
	_brig(s, 1, 0, 5, 53, Vector3(880, 0, 760), f, "HA", 620, 0.95, ["Hameln LW", "Gifhorn LW", "Hildesheim LW", "Peine LW"])               # Vincke (5th Div)
	_brig(s, 1, 0, 6, 54, Vector3(440, 0, 1000), f, "HA", 620, 0.95, ["Verden LW", "Osterode LW", "Münden LW", "Northeim LW"])              # Best (6th Div)
	_brig(s, 1, 2, 2, 55, Vector3(-900, 0, 760), f, "HA", 600, 1.0,  ["Bremervörde LW", "Osnabrück LW", "Quakenbrück LW", "Salzgitter LW"]) # Halkett's Hanoverians (Clinton)
	_brig(s, 1, 2, 4, 56, Vector3(-1700, 0, 820), f, "HA", 600, 0.95, ["Hoya LW", "Bentheim LW", "Nienburg LW"])                            # Hew Halkett (Colville, Hougoumont relief)
	# --- d'Aubremé's Dutch-Belgian brigade (Chassé's 2nd) — reserve behind the right-centre ---
	_brig(s, 1, 1, 99, 57, Vector3(-520, 0, 1000), f, "NL", 560, 0.9, ["3rd Dutch Line", "12th Dutch Line", "13th Dutch Militia", "36th Belgian Jagers"]) # d'Aubremé

# =================================================================== PRUSSIAN (team 1, from the EAST)
# Blücher's army marching up onto the French right; here the advance corps begin their approach.
# (The timed historical arrival — IV Corps onto Plancenoit, then I Corps onto the Allied left — is a
#  planned follow-on step; for now they start well to the east and march in.)
static func _prussian(s: BattleSetup) -> void:
	var fw := PI * 1.5   # facing west (-X) toward the French right
	# --- IV CORPS (Bülow) — the leading corps, driving on Plancenoit ---
	_brig(s, 1, 4, 15, 41, Vector3(2650, 0, -360), fw, "PR", 680, 1.05, ["18th Rgt I", "18th Rgt II", "18th Fusilier", "3rd Silesian LW", "4th Silesian LW"])   # 15th Bde (Losthin)
	_brig(s, 1, 4, 16, 42, Vector3(2650, 0, -120), fw, "PR", 680, 1.05, ["15th Rgt I", "15th Rgt II", "15th Fusilier", "1st Silesian LW", "2nd Silesian LW"])   # 16th Bde (Hiller)
	_brig(s, 1, 4, 13, 43, Vector3(2880, 0, -360), fw, "PR", 680, 1.0,  ["10th Rgt I", "10th Rgt II", "10th Fusilier", "2nd Neumark LW", "3rd Neumark LW"])      # 13th Bde (Hacke)
	_brig(s, 1, 4, 14, 44, Vector3(2880, 0, -120), fw, "PR", 680, 1.0,  ["11th Rgt I", "11th Rgt II", "11th Fusilier", "1st Pomeranian LW", "2nd Pomeranian LW"]) # 14th Bde (Ryssel)
	# --- I CORPS (Zieten) — arriving further north, onto the Allied left at Papelotte ---
	_brig(s, 1, 7, 1, 45, Vector3(2520, 0, 340), fw, "PR", 680, 1.05, ["12th Rgt I", "12th Rgt II", "24th Rgt I", "24th Rgt II", "1st Westphalian LW"])         # 1st Bde (Steinmetz)
	_brig(s, 1, 7, 2, 46, Vector3(2520, 0, 560), fw, "PR", 680, 1.05, ["6th Rgt I", "6th Rgt II", "28th Rgt I", "28th Rgt II", "2nd Westphalian LW"])           # 2nd Bde (Pirch II)
	_brig(s, 1, 7, 3, 47, Vector3(2720, 0, 340), fw, "PR", 680, 1.0,  ["7th Rgt I", "7th Rgt II", "29th Rgt I", "29th Rgt II", "3rd Westphalian LW"])           # 3rd Bde (Jagow)
	_brig(s, 1, 7, 4, 48, Vector3(2720, 0, 560), fw, "PR", 680, 1.0,  ["19th Rgt I", "19th Rgt II", "19th Fusilier", "4th Westphalian LW"])                     # 4th Bde (Donnersmarck)
	# --- II CORPS (Pirch I) — follows IV Corps to the fight at Plancenoit ---
	_brig(s, 1, 8, 5, 49, Vector3(3150, 0, -340), fw, "PR", 680, 1.0,  ["2nd Rgt I", "2nd Rgt II", "25th Rgt I", "25th Rgt II", "5th Westphalian LW"])          # 5th Bde (Tippelskirch)
	_brig(s, 1, 8, 6, 50, Vector3(3150, 0, -120), fw, "PR", 680, 1.0,  ["9th Rgt I", "9th Rgt II", "26th Rgt I", "26th Rgt II", "1st Elbe LW"])                 # 6th Bde (Krafft)
	_brig(s, 1, 8, 7, 51, Vector3(3380, 0, -340), fw, "PR", 680, 0.95, ["14th Rgt I", "14th Rgt II", "22nd Rgt I", "22nd Rgt II", "2nd Elbe LW"])              # 7th Bde (Brause)
	_brig(s, 1, 8, 8, 52, Vector3(3380, 0, -120), fw, "PR", 680, 0.95, ["21st Rgt I", "21st Rgt II", "23rd Rgt I", "23rd Rgt II", "3rd Elbe LW"])              # 8th Bde (Bose)

# author one brigade as a row of battalions strung along its frontage. The `men` figure is the
# battalion's REAL ~18-June strength — uncapped, so the genuinely large units (the British Foot
# Guards at ~1,000, the Nassau battalions at ~850) carry their true numbers, not a rounded ceiling.
static func _brig(s: BattleSetup, team: int, corps: int, division: int, brigade: int, center: Vector3, face: float, nat: String, men: int, exp: float, btns: Array) -> void:
	var fwd := Vector3(sin(face), 0, cos(face))
	var right := Vector3(fwd.z, 0, -fwd.x)
	var nd: Array = NAT[nat]
	var strength: int = men
	for i in range(btns.size()):
		var u := BattleSetup.BattUnit.new()
		u.team = team
		u.corps = corps
		u.division = division
		u.brigade = brigade
		var bn := String(btns[i])
		u.name = bn
		u.nation = nat            # carry the nationality through to the AI's national doctrine
		u.men = strength
		u.experience = exp
		u.morale = 100.0
		u.ammo = 50.0
		u.facing = face
		if "Rifle" in bn:
			# the 95th Rifles (and any rifle battalion): dark rifle green, black crossbelts, black facings,
			# and a real RIFLE — longer range, deadlier at distance, but slow to reload (see weapons/baker_rifle.tres)
			u.coat_idx = 3
			u.facing_col = Color(0.07, 0.11, 0.07)
			u.belt_idx = 1
			u.weapon = "baker_rifle"
		else:
			u.coat_idx = int(nd[0])     # national coat (slot into the side's palette)
			u.facing_col = nd[1]        # regimental/national facing trim
			u.belt_idx = int(nd[2])     # crossbelt colour (white / black / brown)
		u.pos = center + right * ((float(i) - (btns.size() - 1) * 0.5) * 46.0)
		s.units.append(u)

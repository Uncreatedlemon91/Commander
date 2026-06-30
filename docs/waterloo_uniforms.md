# Waterloo — per-battalion uniform allocation

Planning reference for a future update that dresses each battalion individually. Two columns matter:

- **Coat** — the body colour. The engine currently has **4 coat slots per side** (`coat_idx` 0–3 → `COATS_W0/W1` in `game.gd`): French blue, British red, Allied blue, black, and the new green. A future update could promote this to a per-battalion RGB (as facings already are).
- **Facing** — collar / cuffs / lapels. **Already per-battalion RGB today** (`facing_col`), so the values below can be applied immediately; only the finer coat shades wait on the coat-slot work.

Hex values are targets, not the exact current shader constants. **British, Hanoverian, Dutch, Brunswick and Prussian-Landwehr facings are regimental/provincial and well-documented; French line and Prussian line facings were largely standardised** (the French were distinguished by buttons/eagles, not facing colour), so those repeat by design.

Reference swatches — **Coats:** French blue `#20294C` · French Guard (darker) `#161D3A` · British red `#A12824` · KGL red `#A93029` · Hanoverian red `#97211F` · Dutch blue `#2D4793` · rifle/Nassau green `#1F3322` · Brunswick black `#1A1A22` · Prussian blue `#232D52`.
**Facings:** red `#B81E1E` · royal blue `#20367E` · yellow `#E2C516` · pale yellow `#EBDD6E` · buff `#D8C9A0` · grass green `#2F7D33` · dark green `#173B1E` · white `#ECECE4` · black `#14140F` · orange `#E07B12` · light blue `#6FA0DB`.

---

## FRENCH — Armée du Nord (team 0)

Coat: dark blue throughout. Line/Guard facing = **red** (collar & cuffs, white lapels); légère = **yellow** collar.

### I Corps (d'Erlon)
| Battalion | Coat | Facing |
|---|---|---|
| 54e Ligne I / II | blue | red |
| 55e Ligne I / II | blue | red |
| 28e Ligne I / II | blue | red |
| 105e Ligne I / II | blue | red |
| 13e Léger I / II | blue | yellow |
| 17e Ligne I / II | blue | red |
| 19e Ligne I / II | blue | red |
| 51e Ligne I / II | blue | red |
| 21e Ligne I / II | blue | red |
| 46e Ligne I / II | blue | red |
| 25e Ligne I / II | blue | red |
| 45e Ligne I / II | blue | red |
| 8e Ligne I / II | blue | red |
| 29e Ligne I / II | blue | red |
| 85e Ligne I / II | blue | red |
| 95e Ligne I / II | blue | red |

### II Corps (Reille)
| Battalion | Coat | Facing |
|---|---|---|
| 2e Léger I / II | blue | yellow |
| 61e Ligne I / II | blue | red |
| 72e Ligne I / II | blue | red |
| 108e Ligne I / II | blue | red |
| 92e Ligne I / II | blue | red |
| 93e Ligne I / II | blue | red |
| 100e Ligne I / II | blue | red |
| 4e Léger I / II | blue | yellow |
| 1er Léger I / II | blue | yellow |
| 3e Ligne I / II | blue | red |
| 1er Ligne I / II | blue | red |
| 2e Ligne I / II | blue | red |

### VI Corps (Lobau)
| Battalion | Coat | Facing |
|---|---|---|
| 5e Ligne · 11e Ligne · 27e Ligne · 84e Ligne | blue | red |
| 5e Léger | blue | yellow |
| 10e Ligne · 107e Ligne | blue | red |
| 8e Léger (Teste) | blue | yellow |
| 40e · 65e · 75e Ligne (Teste) | blue | red |

### Imperial Guard
| Battalion | Coat | Facing |
|---|---|---|
| 1er Grenadiers I / II | dark blue | red (white lapels, gold lace) |
| 2e Grenadiers I / II | dark blue | red |
| 1er Chasseurs I / II | dark blue | red (green lapel piping) |
| 2e Chasseurs I / II | dark blue | red |
| 3e / 4e Grenadiers (Middle) | dark blue | red |
| 3e / 4e Chasseurs (Middle) | dark blue | red |
| 1er / 3e Tirailleurs (Young) | dark blue | red (yellow trim) |
| 1er / 3e Voltigeurs (Young) | dark blue | yellow |
| 2e / 4e Tirailleurs (Young) | dark blue | red |
| 2e / 4e Voltigeurs (Young) | dark blue | yellow |

---

## ANGLO-ALLIED (team 1) — the regimental facings

### British — Foot Guards & line (each regiment its own facing)
| Battalion | Coat | Facing |
|---|---|---|
| 2/1st Foot Guards | red | royal blue |
| 3/1st Foot Guards | red | royal blue |
| 2nd Coldstream Guards | red | royal blue |
| 2/3rd Foot Guards (Scots) | red | royal blue |
| 2/30th Foot (Cambridgeshire) | red | pale yellow |
| 33rd Foot (1st West Riding) | red | **red** |
| 2/69th Foot (South Lincs.) | red | grass green |
| 2/73rd Foot | red | dark green |
| 1/52nd Light | red | buff |
| 1/71st Highland Light | red | buff |
| 28th Foot (N. Gloucestershire) | red | bright yellow |
| 32nd Foot (Cornwall) | red | white |
| 79th Cameron Highlanders | red | dark green |
| 3/1st Royal Scots | red | royal blue |
| 42nd Black Watch | red | royal blue |
| 2/44th Foot (East Essex) | red | yellow |
| 92nd Gordon Highlanders | red | yellow |
| 4th Foot (King's Own) | red | royal blue |
| 27th Inniskilling | red | buff |
| 40th Foot (2nd Somersetshire) | red | buff |
| 3/14th Foot (Buckinghamshire) | red | pale (lemon) buff |
| 1/23rd Royal Welch Fusiliers | red | royal blue |
| 51st Light (2nd Yorks W.R.) | red | grass green |

### British Rifles — green coats, black everything (auto-detected by name today)
| Battalion | Coat | Facing |
|---|---|---|
| 1/95th Rifles | rifle green | black |
| 2/95th Rifles | rifle green | black |
| 3/95th Rifles | rifle green | black |

### King's German Legion (red coats, blue facings)
| Battalion | Coat | Facing |
|---|---|---|
| 1st / 2nd / 5th / 8th Line KGL (Ompteda) | red | royal blue |
| 1st / 2nd / 3rd / 4th Line KGL (du Plat) | red | royal blue |

### Hanoverian — field battalions & Landwehr (red coats)
| Battalion | Coat | Facing |
|---|---|---|
| Bremen | red | yellow |
| Verden (field) | red | yellow |
| York | red | light blue |
| Lüneburg (light) | red | dark green |
| Hameln LW · Gifhorn LW · Hildesheim LW · Peine LW | red | white |
| Verden LW · Osterode LW · Münden LW · Northeim LW | red | white |
| Bremervörde LW · Osnabrück LW · Quakenbrück LW · Salzgitter LW | red | light blue |
| Hoya LW · Bentheim LW · Nienburg LW | red | light blue |

### Dutch-Belgian (blue coats; Jagers in green)
| Battalion | Coat | Facing |
|---|---|---|
| 7th Belgian Line | blue | white |
| 27th Dutch Jagers | green | yellow |
| 5th / 7th Dutch Militia | blue | orange |
| 35th Belgian Jagers | green | yellow |
| 2nd Dutch Line | blue | white |
| 4th / 6th Dutch Militia | blue | orange |
| 3rd / 12th Dutch Line | blue | white |
| 13th Dutch Militia | blue | orange |
| 36th Belgian Jagers | green | yellow |

### Nassau (green coats)
| Battalion | Coat | Facing |
|---|---|---|
| 2nd Nassau (1st / 2nd / 3rd Bn) | green | yellow (black collar) |
| Orange-Nassau | green | yellow |
| 1st Nassau (1st / 2nd / 3rd Bn) | green | yellow |

### Brunswick (black coats, death's-head shako)
| Battalion | Coat | Facing |
|---|---|---|
| Leib-Bataillon | black | light blue |
| 1st / 2nd / 3rd Light Bn | black | buff |
| 1st / 2nd / 3rd Line Bn | black | red |

---

## PRUSSIAN (team 1) — blue coats; line collar red, Landwehr by province

Prussian line regiments wore a **red collar/cuffs**; the regiment's seniority within a brigade showed in the **shoulder-strap** colour (white = 1st, red = 2nd, yellow = 3rd, light blue = 4th). Landwehr carried the **provincial** colour.

### IV Corps (Bülow)
| Battalion | Coat | Facing |
|---|---|---|
| 18th Rgt I / II / Fusilier (Losthin) | Prussian blue | red |
| 3rd / 4th Silesian LW | Prussian blue | yellow (Silesia) |
| 15th Rgt I / II / Fusilier (Hiller) | Prussian blue | red |
| 1st / 2nd Silesian LW | Prussian blue | yellow (Silesia) |
| 10th Rgt I / II / Fusilier (Hacke) | Prussian blue | red |
| 2nd / 3rd Neumark LW | Prussian blue | crimson (Neumark) |
| 11th Rgt I / II / Fusilier (Ryssel) | Prussian blue | red |
| 1st / 2nd Pomeranian LW | Prussian blue | white (Pomerania) |

### I Corps (Zieten)
| Battalion | Coat | Facing |
|---|---|---|
| 12th Rgt I / II · 24th Rgt I / II (Steinmetz) | Prussian blue | red |
| 1st Westphalian LW | Prussian blue | green (Westphalia) |
| 6th Rgt I / II · 28th Rgt I / II (Pirch II) | Prussian blue | red |
| 2nd Westphalian LW | Prussian blue | green (Westphalia) |
| 7th Rgt I / II · 29th Rgt I / II (Jagow) | Prussian blue | red |
| 3rd Westphalian LW | Prussian blue | green (Westphalia) |
| 19th Rgt I / II / Fusilier (Donnersmarck) | Prussian blue | red |
| 4th Westphalian LW | Prussian blue | green (Westphalia) |

### II Corps (Pirch I)
| Battalion | Coat | Facing |
|---|---|---|
| 2nd Rgt I / II · 25th Rgt I / II (Tippelskirch) | Prussian blue | red |
| 5th Westphalian LW | Prussian blue | green (Westphalia) |
| 9th Rgt I / II · 26th Rgt I / II (Krafft) | Prussian blue | red |
| 1st Elbe LW | Prussian blue | light blue (Elbe) |
| 14th Rgt I / II · 22nd Rgt I / II (Brause) | Prussian blue | red |
| 2nd Elbe LW | Prussian blue | light blue (Elbe) |
| 21st Rgt I / II · 23rd Rgt I / II (Bose) | Prussian blue | red |
| 3rd Elbe LW | Prussian blue | light blue (Elbe) |

---

### Implementation notes
- **Facings are deliverable now** — set `facing_col` per battalion (drop the per-nationality default in `_brig` and read a per-unit value). The OOB already lists every battalion individually, so this is data entry.
- **Coats** need the green/extra slots that exist (`coat_idx` 3 = green). The finer shades (Guard darker blue, Dutch vs Prussian blue, KGL vs line red) want either more coat slots or a per-battalion coat RGB — that's the model-update work this table is preparing for.
- A few values above are best-guess where period sources disagree (some Hanoverian Landwehr and Dutch militia facings); flagged loosely so they're easy to correct.

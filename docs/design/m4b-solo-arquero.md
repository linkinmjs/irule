# M4b — Solo Arquero: flechas, crafting y farming

> Diseñado por `godot-game-architect` (2026-08-12). Referencia y reemplaza
> parcialmente a `m4-arquitectura.md` (que quedó aprobado pero sin implementar
> — este delta se paga en papel, no en refactor). Registra D13 (solo arquero).

## 1. Árbol de talentos v2 — OJO / MANOS / OFICIO

Mismo motor que M4 (`TalentData` + `StatModifier`, cadenas lineales, 1 pto/rango).

| OJO (puntería) | MANOS (manejo) | OFICIO (fletchería y alquimia) |
|---|---|---|
| `ojo_certero` ×2: headshot_bonus ×1.15 | `manos_rapidas` ×2: draw_time ×0.85 | `fletcheria`: unlock **emplumada** |
| `pulso_firme`: spreads ×0.7 | `nock_veloz`: renock_time ×0.7 | `alquimia` ×2: r1 **incendiaria**, r2 **congelante** |
| `ojo_de_halcon`: distancia numérica en la guía | `paso_de_cazador`: draw_move_mult 0.55→0.7 | `mezcla_volatil` (req. alquimia): **explosiva** |
| `punto_debil`: headshot_bonus ×1.25 | `carcaj_hondo`: quiver_max +15 | `cosecha`: +1 por recolección y pájaro |
| | | `ingenio_prestado`: trap_limit +1 |

12 nodos ≈ 14 puntos ≈ 2 asedios de carrera (D6). Stats nuevos en `ArcherStats`:
`gravity` (13.0), `draw_move_mult` (0.55), `guide_level` (int).
**Los talentos desbloquean RECETAS; el material viene del farming.**
Progresión = conocimiento; economía = trabajo diario.

## 2. Catálogo de flechas v2 — recetas físicas

Materiales: **FLOR** (roja, ígnea) · **HONGO** (azul, escarcha) · **PLUMA**.
Se craftean sobre flechas normales, de a 1, en la Mesa. Cap 10 por tipo (knob).

| Flecha | Receta | Grav × | Vel × | Daño | Efecto |
|---|---|---|---|---|---|
| **Normal** | cajón: 10 × 15 oro (stock diario 40) | 1.0 | 1.0 | ×1.0 | — |
| **Emplumada** | 1 normal + 3 plumas + 2 oro | **0.7** | 1.1 | ×0.9 | Francotiradora: escalera comprimida, tiro isla-a-isla |
| **Incendiaria** | 1 normal + 2 flores + 5 oro | 1.15 | 0.95 | ×0.8 | Zona en llamas r2.5, 6 dps, 5 s |
| **Congelante** | 1 normal + 2 hongos + 5 oro | 1.15 | 0.95 | ×0.7 | Zona de escarcha r3, slow 45 %, 4 s |
| **Explosiva** | 1 normal + 1 flor + 1 hongo + 10 oro | **1.45** | 0.85 | 50 AoE r3 + empujón | El empujón tira goblins AL AGUA (kill válido — sinergia islas) |

Se descarta `pierce` (si se extraña, vuelve como talento de OJO).

## 3. Farming diurno en la isla

**Flora:** al amanecer, spawn en 6–10 de ~16 `ForageMarker_N` (bake, sesgados a
los bordes — farmear te aleja de la torre). `StaticBody3D` interactuable [E],
cruz de 2 quads PS1 (flor roja / hongo azul). +1 material, dither-out, respawn
mañana.

**Pájaros (plumas)** — sin navmesh (skill ai-navigation): steering entre
`PerchMarker_N` (árboles/almenas) y los ForageMarkers con flora activa (bajan a
TUS flores — cazar protege la cosecha). FSM 4 estados: `PERCHED` (hop 12 fps,
4–10 s) → `FLY` (seek+arrive, seno en Y = planeo) → `FEEDING` (saltitos, 5–8 s)
→ `FLEE` (disparo <6 m o player <8 m). Visual: 2 quads cruzados con flip de alas
a 12 fps; sombra solo en FEEDING. Caza: puf de plumas + pickup ×1-2 (10 s).
Posado = tiro a blanco chico; comiendo = fácil y cerca; volando = dejalo ir (v1).
Ritmo: <4 activos → spawn 1–2 cada 90–150 s de día; despawn al atardecer.
Knob futuro (off en v1): el pájaro que termina FEEDING se come la flor.

**El día tiene loop real:** reparar ↔ farmear ↔ cazar ↔ craftear ↔ (M5:
negociar) — todos compitiendo por el mismo reloj (pilar "la noche pesa").

## 4. DELTA sobre m4-arquitectura.md

**Se mantiene:** Progression completo · ArcherStats/StatModifier/recompute ·
"bases == consts" · TODO el sistema de trampas (TrapData/Anchor/System/Placer,
markers, límite) · WorldState.ammo por tipo + try_spend_ammo · save contract
(v2→v3, `.get()` + defaults) · puntos al despertar · frontera carrera/asedio ·
input actions.

**Cambia:**
- `ArrowTypeData`: fuera bundle_price/daily_stock/pierce; entran
  `recipe: Dictionary`, `gravity_mult`, `aoe_radius`, `zone {NONE,FIRE,FROST}`,
  `zone_duration`, `knockback`.
- `WorldState`: shop_stock solo para `normal`; +`materials` +
  `materials_changed` + `try_craft(arrow_id)`.
- `Catalog.talents()` v2 (12 nodos, §1). `TalentScreen` → **ArcherTableScreen**
  (2 tabs TALLER/TALENTOS, §5). `ArcherStats` +3 stats; `Arrow` lee gravity.
- Nuevos: `props/forage_node.gd`, `enemies/bird.gd`,
  `systems/wildlife_system.gd`, `effects/ground_zone.gd` (zona fuego/hielo
  compartida), markers Forage/Perch en el bake.

**Se descarta:** compra de especiales en cajón · pierce · toda referencia a
Mago/Ingeniero (GDD §7 reescribir — D13).

## 5. Mesa del Arquero (640×360, código-built, patrón HUD/DebugMenu)

Panel pergamino, 2 tabs, se abre con **T** o interactuando con la mesa física.
Mouse libre, SIN pausa (el reloj corre — presión horaria).

```
│ MESA DEL ARQUERO      [TALLER]  TALENTOS    ORO 120 │
│ ┌MORRAL──────────┐  ┌RECETAS─────────────────────┐  │
│ │ FLOR      x4   │  │ > INCENDIARIA  2 FLOR 5 ORO│  │
│ │ HONGO     x2   │  │   CONGELANTE   2 HONGO 5 O │  │
│ │ PLUMA     x7   │  │   EXPLOSIVA    1+1   10 ORO│  │
│ │ NORMAL    x22  │  │   EMPLUMADA    3 PLUMA 2 O │  │
│ └────────────────┘  │      [ CRAFTEAR +1 ]       │  │
│ CARCAJ  NORMAL 22 · INCEND 4 · CONGEL 0 · EXPL 2    │
```
Tab TALENTOS: 3 columnas OJO/MANOS/OFICIO (dorado/blanco/gris) + puntos.

## Plan por fases (cada una deja el juego corriendo)

| Fase | Contenido | Gate |
|---|---|---|
| **F0** | Balística v2 ✅ (aplicada) + **guía elegida** + memoria del tiro | A/B gunfeel 15/30/45 m — SI NO SE SIENTE BIEN, ITERAR ACÁ |
| F1 | Datos v2 + Progression + player lee stats | Boot idéntico; OJO/MANOS aprenden y persisten |
| F2 | Economía normal (sin refill, cajón vende) | Stock refresca al dormir, flechas no |
| F3 | Flora + recolección + materials + morral | 5 flores en un día; save v3 |
| F4 | Mesa (2 tabs) + crafteo + incendiaria/congelante/explosiva + ground_zone | Quemar/frenar/empujar-al-agua un empuje |
| F5 | Pájaros + plumas + emplumada | Cazar 2, craftear, sentir la escalera comprimida |
| F6 | Trampas completas (pasos 7–8 del m4) | Límite 2; `ingenio_prestado` da la 3.ª |
| F7 | Balance noches 1–3 | "La noche 3 se siente tensa y disparar es rico" |

## Riesgos

1. **F0 es el pilar entero**: caída + mapa doble sin la guía correcta = frustración; con la guía equivocada = piloto automático. Gate de playtest.
2. **El día no alcanza** (checklist ansioso): knobs duración/spawns/`cosecha`. Vigilar antes de M5.
3. **Tres monedas** = carga cognitiva: recetas máx 2 ingredientes + color 1:1. Fallback: fusionar flor+hongo.
4. **Zonas vs trampas** compiten ("pintar el corredor"): trampas = pasivo barato pre-noche; zonas = activo caro en material.
5. **Cazar con caída aumentada** puede estrangular las plumas: FEEDING fácil, drop 1-2, `cosecha`. Fallback: nidos saqueables.

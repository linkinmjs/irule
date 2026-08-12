# M4 — La Progresión: diseño de arquitectura

> Diseñado por el agente `godot-game-architect` (2026-08-12) leyendo GDD §6/§6.1/§7/§13
> y el código existente. **Estado: pendiente de aprobación de Mauri.**
> Regla de señales que ya rige el código y se mantiene: estado de un autoload →
> señal del propio autoload; eventos entre nodos de escena → EventBus.
> Consecuencia: `EventBus.arrows_changed` desaparece (la munición pasa a WorldState).

## 1. Archivos nuevos y responsabilidades

```
scripts/data/                          (carpeta nueva — datos puros, Resources en código)
  stat_modifier.gd    StatModifier     Resource: {stat: StringName, add: float, mult: float} — un ajuste atómico.
  archer_stats.gd     ArcherStats      Resource: stats FINALES tipados del arco/carcaj/trampas + recompute(mods) ADD→MULT.
  talent_data.gd      TalentData       Resource: definición de un talento (rama, requires, rangos, modifiers, unlock).
  arrow_type_data.gd  ArrowTypeData    Resource: tipo de flecha (precio, pack, stock, mults, efecto, tinte).
  trap_data.gd        TrapData         Resource: producto trampa (id, precio, tamaño del ghost).
  catalog.gd          Catalog          Estáticos que construyen los dicts id→Resource en código (sin .tres; lazy, una vez).

scripts/autoload/
  progression.gd      Progression      AUTOLOAD nuevo — la carrera del defensor (D6): puntos, talentos,
                                       ArcherStats derivado, desbloqueos; to_dict/from_dict.

scripts/props/
  trap_anchor.gd      TrapAnchor       StaticBody3D en capa 256: anclaje raycasteable en el camino;
                                       libre/ocupado; install()/clear(); anillo visual PS1.

scripts/systems/
  trap_system.gd      TrapSystem       Node: convierte markers del nivel en TrapAnchors, restaura el save,
                                       cuenta ocupados vs límite, emite trap_count_changed.

scripts/player/
  trap_placer.gd      TrapPlacer       Node hijo del Player (componente): modo colocación de día, ray 30 m,
                                       ghost verde/rojo, cobro e instalación.

scripts/ui/
  talent_screen.gd    TalentScreen     CanvasLayer código-built 640×360: árbol 3 ramas, gasto de puntos;
                                       patrón DebugMenu (mouse libre, SIN pausa — el reloj sigue: presión horaria).
```

**Modificados:** `event_bus.gd` (señales), `world_state.gd` (munición + stock),
`game_manager.gd` (wake otorga puntos, save v2, quitar refill), `main.gd` (aplicar
save nuevo + TrapSystem), `player/player.gd` (consts de arco → stats, selección de
tipo, hijo TrapPlacer), `player/bow.gd` (visibilidad/tinte de flecha nockeada),
`player/arrow.gd` (tipo, crit, burn, pierce), `enemies/goblin.gd` (`apply_burn`,
~20 líneas), `props/arrow_crate.gd` (venta con precio/stock), `props/spike_trap.gd`
(señal `depleted` + queue_free al gastarse), `ui/hud.gd`, `ui/summary_screen.gd`
(+línea de puntos), `systems/level_builder.gd` (markers de anclaje, quitar trampas
fijas), `project.godot` (autoload + input actions), **re-bake** de
`scenes/levels/outpost_01.tscn`.

**Capas de colisión:** se suma `256 = trap_anchor` a las existentes.

## 2. Custom Resources — campos

**StatModifier** — `stat: StringName`, `add := 0.0`, `mult := 1.0`.

**ArcherStats** — bases EXACTAMENTE iguales a las consts actuales de `player.gd`
(garantía de no tocar el gunfeel M1):

| Campo | Base | Campo | Base |
|---|---|---|---|
| `draw_time` | 0.65 | `base_spread` | 0.3 |
| `renock_time` | 0.35 | `move_spread` | 3.4 |
| `arrow_speed_min/max` | 16 / 42 | `air_spread` | 2.4 |
| `arrow_damage_min/max` | 18 / 55 | `low_draw_spread` | 2.2 |
| `headshot_bonus` | 1.0 | `quiver_max` | 30 |
| `trap_limit` | 2 | | |

`recompute(mods)`: resetea a bases, aplica **suma de adds → producto de mults** por
stat. `headshot_bonus` es un multiplicador EXTRA aplicado por el Arrow al pegar en
cabeza — el `HEADSHOT_MULT 2.5` del goblin queda intacto.

**TalentData** — `id`, `display_name`, `description`, `branch {PUNTERIA, CADENCIA,
FLECHAS}`, `requires` (cadena lineal v1), `max_ranks := 1`,
`modifiers: Array[StatModifier]` (por rango), `unlock_arrow: StringName`.

**Árbol v1 en `Catalog.talents()`** (9 nodos, 1 punto/rango):

| Puntería | Cadencia | Flechas especiales |
|---|---|---|
| `ojo_certero` ×2: headshot_bonus ×1.15 | `manos_rapidas` ×2: draw_time ×0.85 | `flecha_fuego`: unlock `fire` |
| `pulso_firme`: base/low_draw_spread ×0.7 | `nock_veloz`: renock_time ×0.7 | `flecha_perforante`: unlock `pierce` |
| `punto_debil`: headshot_bonus ×1.25 | `carcaj_hondo`: quiver_max +15 | `ingenio_prestado`: trap_limit +1 |

**ArrowTypeData** — `id` (`normal/fire/pierce`), `bundle_size := 10`,
`bundle_price` (20/45/40 oro placeholder), `daily_stock` (40/15/15), `damage_mult`,
`speed_mult`, `effect {NONE, BURN, PIERCE}`, `burn_dps := 8.0` + `burn_duration := 3.0`,
`pierce_count := 2` + `pierce_damage_keep := 0.65`, `tint: Color` (fletch/nocked).

**TrapData** — `id` (`spikes/barrel`), `display_name`, `price` (35/25 placeholder),
`preview_size: Vector3`. La fábrica de instalación es un `match id` dentro de
`TrapAnchor.install()`. *No hay TrapAnchorData*: la identidad persistente del
anclaje es el **nombre del nodo** (`TrapAnchor_00`…), estable para el save.

## 3. Señales nuevas y cambios a autoloads

**EventBus** (+5, −1):
```gdscript
signal arrow_type_selected(type: StringName)                       # player → HUD/bow
signal trap_placement_changed(active: bool, trap_id: StringName)   # placer → HUD hint
signal trap_installed(anchor_id: StringName, trap_id: StringName)
signal trap_removed(anchor_id: StringName, reason: String)         # "spent" | "exploded"
signal trap_count_changed(occupied: int, limit: int)               # lo emite TrapSystem
# SE ELIMINA arrows_changed (→ WorldState.ammo_changed) — tocar player/hud/crate/debug.
```

**WorldState** (~30 líneas):
```gdscript
signal ammo_changed(type: StringName, count: int)
var ammo: Dictionary = {&"normal": 30}        # tipo → cantidad
var shop_stock: Dictionary = {}               # tipo → stock diario restante (compartido entre cajones)
func ammo_count(type) -> int / add_ammo(type, n)   # clamp a Progression.stats.quiver_max
func try_spend_ammo(type, n := 1) -> bool
func try_buy_ammo(type) -> bool               # valida stock+oro, transacciona, emite
# advance_day(): refresca shop_stock desde Catalog (NO repone flechas); reset(): valores iniciales.
```

**Progression** (autoload nuevo, después de WorldState):
```gdscript
signal points_changed(points: int)
signal talent_learned(id: StringName, rank: int)
signal stats_changed
var points: int;  var talents: Dictionary   # id → rango
var stats: ArcherStats                      # SIEMPRE recomputado; los consumidores solo leen
func rank_of(id) / can_learn(id) / learn(id) -> bool
func grant_points(n) / unlocked_arrow_types() -> Array[StringName]
func to_dict() / from_dict(d) / reset()     # reset() da 1 punto inicial (día 1 es un amanecer)
```

**GameManager** (~12 líneas): en `confirm_wake()`, ANTES de `advance_day()` computar
`bonus := 1 + (1 si door_damage_tonight <= 0.0)`; luego `advance_day()` →
`Progression.grant_points(bonus)` → `_save_now()` → announcement. Quitar
`player.refill_arrows()` del save. En `restart_game(clear_save=true)`: además
`Progression.reset()` — frontera carrera/asedio: WorldState.reset() es por asedio,
Progression.reset() solo con nueva carrera (D6 sale gratis al cambiar de mapa).

**Save v2** (lectores con `.get()` y defaults ⇒ un save v1 carga solo):
```json
{ "version": 2, "day": 3, "gold": 120, "door_hp": 420.0,
  "talents": {"manos_rapidas": 2}, "talent_points": 1,
  "ammo": {"normal": 12, "fire": 4}, "shop_stock": {"normal": 25},
  "traps": [{"anchor": "TrapAnchor_02", "trap": "spikes", "uses": 12}] }
```
`main.gd`: `Progression.from_dict()` ANTES de crear el Player; ammo/stock a
WorldState; `traps` al TrapSystem después de instanciar el nivel.

**project.godot**: autoload `Progression`; input actions `talents` (T),
`arrow_cycle` (Q + rueda), `place_trap` (3), `place_cancel` (RMB/Esc).

## 4. Integración con player.gd sin dios-objeto

Decisión: **ArcherStats tipado + StatModifiers en los datos** (no StatBlock de
diccionario): los StringName viven solo en TalentData; el hot path del disparo lee
floats tipados.

- El player NO posee ni computa stats: las consts de arco → lecturas de
  `Progression.stats.X` en ~10 sitios. Las consts de movimiento no se tocan.
- La munición sale del player: se eliminan `arrows/MAX_ARROWS/refill_arrows()`;
  `_shoot()` hace `WorldState.try_spend_ammo(selected_arrow)`.
- Lo único nuevo en el player: `selected_arrow` + ciclado (Q), y el hijo componente
  `TrapPlacer` (el player solo consulta `trap_placer.active` para no disparar).
- **Arrow**: recibe `ArrowTypeData` + `headshot_bonus`. BURN → `target.apply_burn()`;
  PIERCE → aplica golpe, `damage *= keep`, acumula RID excluido y sigue.
- **Bow**: `_nocked_arrow.visible` → `_player.has_ammo()`; tiñe fletch por tipo.

## 5. Flujo de trampas (§6.1)

- `LevelBuilder._build_trap_anchor_markers()`: ~6 Marker3D `"TrapAnchorMarker_N"`
  sobre los WAYPOINTS (y=0); ELIMINA las trampas fijas de `_build_props()`.
  **Re-bake** → markers editables en el editor. `TrapSystem` escanea por prefijo y
  spawnea `TrapAnchor` por marker; fallback a consts + `push_warning` si la escena
  no se re-horneó.
- Colocación (solo de día; se auto-cancela con `phase_changed`): **3** abre modo con
  pinchos / cicla a barril, **RMB/Esc** cancela, **LMB** confirma. Ray 30 m máscara
  `1|256`. Ghost BoxMesh unshaded verde/rojo (ocupado, límite `stats.trap_limit`,
  oro insuficiente). Confirmar: `try_spend_gold` → `anchor.install(trap_id)`.
  El modo queda activo para encadenar compras.
- Liberación: SpikeTrap gana `signal depleted` (dither-out + queue_free al gastarse);
  el barril ya hace queue_free al explotar — el anchor observa `tree_exited` de su
  hijo (guardando `is_inside_tree()` para el teardown) → `clear()` → señales.
- La "mesa/mercader" del GDD §5.3 queda para M5; en M4 se paga al confirmar el ghost
  (mismo precedente diegético que la reparación de la Puerta, D10). El cajón de
  flechas es la compra de munición: `"[E] Comprar 10 flechas (20 oro) — stock 30"`.

**HUD**: `"FLECHAS [FUEGO] 12/45"` con tinte por tipo; label `"TRAMPAS 1/2"`;
hint de colocación en y≈228; si hay puntos, `"T: talentos (+N)"` junto al reloj.
**TalentScreen**: 3 columnas de Buttons (dorado aprendido / blanco disponible /
gris bloqueado), cierra con T o Esc (input as handled antes que PauseMenu).

## 6. Plan de implementación (cada paso deja el juego corriendo)

1. **Capa de datos + Progression** (nadie los consume aún). *Test:* boot + comparar stats vs consts.
2. **Player lee stats** (defaults idénticos ⇒ cero cambio de feel). *Test:* A/B gunfeel + sim nocturna 24/24.
3. **Puntos + TalentScreen + otorgamiento al despertar.** *Test:* F1 amanecer → aprender `manos_rapidas` → draw más rápido.
4. **Save v2.** *Test:* talentos persisten tras reiniciar; save v1 viejo carga sin errores.
5. **Economía de munición** (quitar refill, cajón vende, HUD por tipo). *Test:* vaciar → comprar → dormir: stock refresca, flechas NO.
6. **Flechas especiales** (burn/pierce, ciclado Q, gated por talentos). *Test:* DoT mata; pierce atraviesa 2.
7. **Anclajes visibles** (markers + re-bake + TrapSystem; fuera trampas fijas). *Test:* anillos en el camino; warning sin re-bake.
8. **TrapPlacer completo** (ghost, cobro, límite, liberación). *Test:* límite 2 rechaza la 3.ª; `ingenio_prestado` la permite.
9. **Traps en save + pase de balance** (oro inicial 60→~90 sugerido; precios/stock jugando noches 1–3). *Test:* trampas persisten con su desgaste.

## Riesgos / trade-offs

1. El paso 2 toca los sitios de disparo del gunfeel M1 (pilar sagrado) — mitigado: bases == consts exactas + A/B antes de avanzar.
2. Los anclajes dependen del re-bake de `outpost_01.tscn` — mitigado: fallback por const + warning.
3. Frontera carrera (Progression) / asedio (WorldState) nueva — probar los 3 flujos (continuar, nueva partida, muerte).
4. Sin refill gratis puede haber soft-lock sin flechas — knobs: precio/stock/oro inicial; vigilar "la noche 3 se siente tensa".
5. Pierce muta el hot path del Arrow (exclusión de RIDs) — testear contra empujes densos con `--debug-log`.

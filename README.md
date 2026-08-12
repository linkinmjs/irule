# Quest Defense (nombre placeholder)

Tower defense 3D en primera persona: **vos sos la torre**. Estética PS1 dungeon.
Diseño completo en [GDD.md](GDD.md) · assets en [assets-list.md](assets-list.md).

## Correr la maqueta

Abrir con **Godot 4.7** y dar Play (`F5`). Escena principal: `scenes/main.tscn`.
El nivel jugable es **`scenes/levels/outpost_01.tscn`** (editable); si no existe,
se genera por código con `LevelBuilder`.

## Controles

| Input | Acción |
|-------|--------|
| WASD | Moverse (feel CS: frenada seca, counter-strafe) |
| Click sostenido | Tensar el arco — soltar dispara. Quieto = preciso |
| E | Interactuar (cama, reparar Puerta, reponer flechas) |
| Ctrl | Agacharse |
| Espacio | Salto corto |
| ESC | Pausa |
| **F1** | **Menú de debug**: spawns, saltos de hora, oro, Puerta, reloj rápido, post on/off |

## El loop

De día (08:00–20:00): reparar la Puerta, reponer flechas, prepararse.
De noche (21:00–03:00): tres empujes de **goblins** (modelo animado del pack)
marchan por el camino en S hundido hacia la Puerta — defendelos desde la
superficie superior, el **istmo** entre los dos brazos del camino, o el balcón
de la torre. Los barriles explotan al dispararles. A las **03:00 el tiempo se
congela**: solo queda dormir (guarda partida). Si la Puerta llega a 0, el puesto cae.

## Editar el nivel a mano

1. Abrí `scenes/levels/outpost_01.tscn` en el editor: todos los bloques del
   terreno, muros, props (cama, barriles, trampas, antorchas) y deco son nodos
   editables — movelos, borralos o agregá más (instanciá el script del prop
   en un nodo nuevo, p. ej. `powder_barrel.gd`).
2. **`PlayerStart`** y **`SpawnPoint`** son Marker3D: movelos para cambiar
   dónde aparecés y de dónde salen los goblins.
3. Para **regenerar** el nivel procedural desde cero (pisa tus ediciones,
   deja backup en `outpost_01_backup.tscn`):
   `godot --path . --headless res://scenes/tools/bake_runner.tscn`
   El generador vive en `scripts/systems/level_builder.gd` (waypoints del
   camino, tamaños, props) — tocá ahí y re-horneá.

## Flags de debug (argumentos después de `--`)

| Flag | Efecto |
|------|--------|
| `--fast-clock` | Día a 0.5 s/hora y noche a 12 s/hora |
| `--night-secs=N` | Noche a N segundos por hora (afina la duración a gusto) |
| `--start-night` | Empieza a las 20:30 |
| `--debug-log` | Log de spawns/golpes/posiciones en consola |
| `--quit-at-freeze` | Cierra solo 8 s después de las 03:00 (tests headless) |

## Estructura

```
scenes/             main.tscn · levels/outpost_01.tscn (EDITABLE) · tools/bake_runner.tscn
scripts/autoload/   EventBus · WorldState (reloj/fases) · AudioManager · SaveManager · GameManager
scripts/player/     player.gd (movimiento CS + spread + footsteps) · bow.gd · arrow.gd
scripts/enemies/    goblin.gd (FBX animado, 22 anims; fallback primitivas) · goblin_ragdoll.gd
scripts/props/      door_gate.gd (la Puerta) · powder_barrel · spike_trap · bed · arrow_crate · torch
scripts/systems/    level_builder.gd (generador del nivel) · wave_spawner · day_night_visuals · retro_post_process
scripts/ui/         hud.gd · debug_menu.gd (F1) · summary_screen · game_over · pause
scripts/lib/        psx_materials.gd · asset_lib.gd (piezas GLB → shader PSX) · vfx.gd
scripts/tools/      bake_level_runner.gd · dump_scene_tree.gd · probe_goblin.gd
shaders/            psx_lit.gdshader (materiales) · psx_post.gdshader (niebla+dither)
assets/models/packs/  dracula/ · traps/ · goblins/ (GoblinCharacter.fbx riggeado)
assets/audio/       placeholder/ (SFX sintéticos) · footsteps/ (pack PSX)
assets/_raw/        packs comprimidos sin extraer (ignorado por Godot)
```

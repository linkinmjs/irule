# Irulé

Tower defense 3D en primera persona: **vos sos la torre** — el arquero Irulé.
Estética PS1 dungeon. El juego avanza por **rondas** (D17): cada una con su
cielo, su clima y una horda más grande.
Diseño completo en [GDD.md](GDD.md) · assets en [assets-list.md](assets-list.md).

**El proyecto Godot vive en [godot/](godot/)** (layout del pipeline de CI).

## Correr la maqueta

Abrir `godot/` con **Godot 4.7** y dar Play (`F5`). Escena principal: `scenes/main.tscn`.
El nivel jugable es **`scenes/levels/outpost_01.tscn`** (editable); si no existe,
se genera por código con `LevelBuilder`.

La imagen interna es 640×360 y se estira a la ventana (escala fraccional).
Fuente pixel pendiente: extraer `assets/_raw/1Bit_UI_pack_byBatuhan.rar`
(necesita 7-Zip/WinRAR) y avisar para integrarla al HUD.

**Plugins:** `addons/dialogue_manager` (3.10.1) instalado pero **deshabilitado**
— se activa en Proyecto → Plugins cuando arranque M5 (negociación).

## Controles

| Input | Acción |
|-------|--------|
| WASD | Moverse (feel CS: frenada seca, counter-strafe) |
| Click sostenido | Tensar el arco — soltar dispara. Quieto = preciso |
| E | Interactuar (cama, reparar Puerta, reponer flechas) |
| Ctrl | Agacharse |
| Espacio | Salto corto |
| ESC | Pausa |
| T | Mesa del Arquero (talentos) |
| **F1** | **Menú de debug**: spawns, iniciar ronda, saltar prep, respawn agua on/off, oro, Puerta, post on/off |

## El loop (D17: rondas)

**Intermedio (CLEARED):** reparar la Puerta, reponer flechas, talentos, farmear
tiro al blanco. La **cama** inicia la siguiente ronda (y guarda).
**PREP (~10 s):** el cielo y el clima de la ronda entran en fundido; countdown.
**ASALTO:** la horda completa (crece por ronda, élites al final) marcha por el
camino en S entre las islas hacia la Puerta — defendela desde tu isla, el
puente o el balcón de la torre. Los barriles explotan al dispararles. Cae el
último goblin → ronda superada. Si la Puerta llega a 0, el puesto cae.
Cada 5 rondas es **especial**: la visita el mago Calcu ([E] para conversar —
deja un regalo). El aliado Teru suelta una línea de trama por ronda.

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
| `--auto-rounds` | Encadena rondas solo (sin cama) — para tests headless |
| `--skip-prep` | PREP de 0.5 s en vez de 10 |
| `--quit-at-round=N` | Cierra al superar la ronda N (tests headless) |
| `--debug-log` | Log de rondas/spawns/golpes/posiciones en consola |

## Pipeline a itch.io

Cada push a `master`/`main` dispara [.github/workflows/deploy-to-itch.yml](.github/workflows/deploy-to-itch.yml):
importa assets con Godot 4.7, exporta el preset **Windows Desktop**
(`godot/export_presets.cfg`) y lo sube con butler al channel `windows`.
Secrets requeridos en el repo (ya configurados): `BUTLER_API_KEY`,
`ITCHIO_GAME`, `ITCHIO_USERNAME`. Export Web inviable: Forward+/Vulkan + Terrain3D.

## Estructura (dentro de godot/)

```
scenes/             main.tscn · levels/outpost_01.tscn (EDITABLE) · tools/bake_runner.tscn
scripts/autoload/   EventBus · WorldState (rondas D17) · Progression · AudioManager · SaveManager · GameManager
scripts/player/     player.gd (movimiento CS + spread + footsteps) · bow.gd · arrow.gd
scripts/enemies/    goblin.gd (FBX animado, 22 anims; fallback primitivas) · goblin_ragdoll.gd
scripts/npc/        ally_archer.gd (Teru: dispara, se queja, trama) · wizard_visitor.gd (Calcu)
scripts/props/      door_gate.gd (la Puerta) · powder_barrel · spike_trap · bed · arrow_crate · torch
scripts/systems/    level_builder.gd (generador del nivel) · wave_spawner · round_ambience · round_events · retro_post_process
scripts/ui/         hud.gd · debug_menu.gd (F1) · summary_screen · game_over · pause
scripts/lib/        psx_materials.gd · asset_lib.gd (piezas GLB → shader PSX) · vfx.gd
scripts/tools/      bake_level_runner.gd · dump_scene_tree.gd · probe_goblin.gd
shaders/            psx_lit.gdshader (materiales) · psx_post.gdshader (niebla+dither)
assets/models/packs/  dracula/ · traps/ · goblins/ (GoblinCharacter.fbx riggeado)
assets/audio/       placeholder/ (SFX sintéticos) · footsteps/ (pack PSX)
assets/_raw/        packs comprimidos sin extraer (ignorado por Godot)
```

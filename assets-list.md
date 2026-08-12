# Assets — Quest Defense

> ⚠ Revisar la licencia de cada pack de itch.io antes de uso comercial.

## ✅ Ya integrados

| Asset | Dónde vive | Qué usa |
|-------|-----------|---------|
| `Medieval_Dracula_Assets.glb` | `assets/models/packs/dracula/` | Puerta (Gate_Variant_2), antorchas, braseros, cama, barril, cajón, gárgola, obelisco, lápidas, farol, estandarte, aguja de torre |
| `Traps.glb` | `assets/models/packs/traps/` | Pinchos (Spikes_2), bola con púas deco |
| `GoblinCharacter.fbx` | `assets/models/packs/goblins/` | **El enemigo** (D9): rig de 28 huesos, 22 anims (walk/run/ataques/hits); el desarme nace de las poses de los huesos. Set de gomera disponible para un futuro goblin a distancia |
| Footsteps PSX (pack hazardpay) | `assets/audio/footsteps/` | Pasos del player por distancia recorrida |
| Shader post-proceso PS1 (aportado por Mauri) | `shaders/psx_post.gdshader` | Niebla con ruido animado + cuantización + dithering de pantalla (D12) |

## 📦 En `assets/_raw/` (comprimidos, sin integrar aún)

`psx-first-person-arms` (manos FPS — **P1, siguiente**), `weapons.zip` (arco real),
`PSX_Dungeon.zip` / `Torment` / `Medieval_Update` (kits para vestir el terreno),
`1Bit_UI_pack` (fuente/marcos HUD), `PSX Campfire`, `Calcu` (Chamán futuro),
`Pirate_Scenery`, `Individual_Assets`, `PSX_Traps` (variantes).

Las piezas se extraen con **`scripts/lib/asset_lib.gd`** (corrige orientación Z-up,
escala por pieza, asienta en y=0 y re-materializa al shader PSX del proyecto).
Para usar otra pieza del pack: agregarla a `AssetLib.PIECES` con su rotación/escala
(los tamaños salen de `scripts/tools/dump_scene_tree.gd`). Todo prop tiene fallback
de primitivas si el GLB falta.

## Pendientes de conseguir/reemplazar

## Orden de reemplazo sugerido

1. **Zombie (P1)** — desbloquea el ragdoll real con esqueleto.
2. **Manos + arco (P1)** — el viewmodel es la mitad del gunfeel.
3. **SFX (P1)** — los sintéticos marcan el timing, pero no tienen "cuerpo".
4. **Dungeon kit (P2)** — muros, piso, puerta, antorchas.
5. **Trampas y props (P2)** — barril, pinchos, cama, cajón.
6. **UI / fuente bitmap (P3)** — HUD y pergamino.

---

## Enemy — reemplaza el muñeco de piezas (`scripts/enemies/zombie.gd`)

| Pack | Uso |
|------|-----|
| https://dysfunctional-games.itch.io/psx-zombie | **P1 — el enemigo de la maqueta (D9)** |
| https://mcsteeg.itch.io/psx-animals-rats | Futuro: enemigo "Corredor" (rápido, frágil) |
| https://imaginais.itch.io/calcu-dark-sorcerer-of-chilean-folklore | Futuro: "Chamán" (buffea la horda) |
| https://maximumdamage.itch.io/farmer | Futuro: variante de grunt / NPC |
| https://mcsteeg.itch.io/goblin-faction-set | **P1 — el goblin es AHORA el enemigo del juego (D9 enmendada)**; la facción completa cubre Corredor/Chamán/Élite |

**Requisitos del goblin (imprescindible):**
- Modelo **riggeado con esqueleto humanoide** — el ragdoll (§11.2 del GDD) lo necesita.
- Formato **glTF/GLB** preferido (FBX también importa, con más fricción).
- Animaciones de **caminar** y **atacar**. Morir NO hace falta: lo resuelve el ragdoll.
- Al integrarlo: en `scripts/enemies/goblin.gd` se reemplaza `_build_body()` por el
  modelo y el ragdoll de piezas migra a `PhysicalBoneSimulator3D`. La interfaz
  `take_arrow_hit / take_explosion / take_trap_damage` no cambia — spawner, flechas
  y barriles no se tocan.
- Los SFX `goblin_growl/attack/death` se reproducen con pitch 1.3 (placeholder grave
  agudizado) — con voces goblin reales, quitar `VOICE_PITCH` de `goblin.gd`.

## Hands / Weapon — reemplaza el viewmodel (`scripts/player/bow.gd`)

| Pack | Uso |
|------|-----|
| https://drillimpact.itch.io/psx-first-person-arms-free | Manos FPS |
| https://wriks.itch.io/wrad-arms | Manos FPS (alternativa) |
| https://puszke.itch.io/psx-fps-hand-mega-pack | Manos FPS (pack grande) |
| https://comp3interactive.itch.io/retro-first-person-arms | Manos FPS |
| https://alex1197.itch.io/psx-fps-hands | Manos FPS |
| https://imaginais.itch.io/psx-fp-hands-pack-rigged | Manos FPS **riggeadas** (ideal) |
| https://puszke.itch.io/retro-psx-medieval | Armas medievales |
| https://crimsongcat.itch.io/ps1-psx-fantasy-weapons | **Arco + flechas** |

- Ideal: manos riggeadas con animación de tensar; si son estáticas, el tween actual
  de `bow.gd` (draw/kick/sway) se aplica igual sobre el modelo.
- La flecha del carcaj y la clavada usan el mismo mesh (`arrow.gd`).

## Map — reemplaza la geometría de `scripts/systems/level_builder.gd`

| Pack | Uso |
|------|-----|
| https://goblinatron.itch.io/psx-dungeon | Kit dungeon |
| https://strideh.itch.io/torment | Kit dungeon |
| https://strideh.itch.io/delven | Kit dungeon |
| https://blendervoyage.itch.io/psx-style-modular-low-poly-dungeon | **Kit modular (P2 — el más apto para el corredor)** |
| https://puszke.itch.io/psx-dungeon-interior-game-assets | Interior de la torre (cama, mesas) |
| https://wildenza.itch.io/psx-medieval-pack | Torre / almenas / puerta |
| https://kenney-assets.itch.io/retro-medieval-kit | Props medievales (CC0, licencia segura) |
| https://starkcrafts.itch.io/ps1-dark-fantasy-horror-game-assets-by-stark-crafts | Ambiente |
| https://dripsone.itch.io/rocks-psx-low-poly | Rocas / exterior |
| https://caliberuk.itch.io/psx-large-terrain-rock-pack | Rocas / exterior |
| https://elegantcrow.itch.io/psx-retro-style-tree-pack | Vegetación exterior |
| https://starkcrafts.itch.io/psx-forest-asset-collection-by-starkcrafts | Vegetación exterior |
| https://taogyre.itch.io/psxps1-style-campfire | Fuego/antorchas (`torch_light.gd`) |
| https://philip-erd.itch.io/lofi3d-pirate-scenery | Ambiente alternativo |
| https://elbolilloduro.itch.io/sewers | Ambiente alternativo (¿mapa cloacas?) |

**Al reemplazar el layout, mantener las posiciones clave** (las usan nav, spawner y player):
puerta en `z=0` · spawn en `(0, 0, -35.5)` · corredor `x∈[-3,3]` · almena `y=4` ·
navmesh del corredor (`_build_navmesh`) · parapeto ≥1.2 m (D1: el jugador no baja).

## Tramps — reemplaza `spike_trap.gd` / `powder_barrel.gd`

| Pack | Uso |
|------|-----|
| https://wildenza.itch.io/psx-traps | **Pinchos + trampas (P2)** |

- El barril necesita: mesh normal + (ideal) versión rota/escombros para la explosión.

## Audio — reemplaza `assets/audio/placeholder/*.wav` (mismo nombre = cero código)

| Pack | Uso |
|------|-----|
| https://hazardpay.itch.io/40-free-psx-crunchy-footsteps | Pasos del player (**TODO: aún sin implementar en `player.gd`**) |

**SFX a conseguir** (reemplazan 1:1 por nombre de archivo):
`bow_draw` `bow_shoot` `arrow_hit_world` `arrow_hit_flesh` `headshot` `hitmarker`
`kill_bell` `zombie_groan` `zombie_attack` `zombie_death` `barrel_explode` `spikes`
`door_hit` `door_break` `alarm_bell` `repair` `wave_horn` `ui_click`

**Falta buscar:** música ambiental de día (calma, mazmorra) y percusión tensa de noche
(GDD §10.3) — todavía no hay `MusicManager` (llega con M4/M5).

## Shader

| Pack | Uso |
|------|-----|
| https://immaculate-lift-studio.itch.io/psx-style-camera-shader-for-godot-4 | ✅ Cubierto: el post que pasó Mauri ya está integrado (`psx_post.gdshader` + `RetroPostProcess`) |

- **Materiales**: `shaders/psx_lit.gdshader` (vertex snap + affine + banding + dissolve).
- **Pantalla**: `shaders/psx_post.gdshader` (niebla con ruido + cuantización + dither),
  conectado al ciclo día/noche vía `DayNightVisuals` → grupo `retro_post`.
- ⚠ El despawn con dithering (ragdolls, escombros, retirada 03:00) depende del
  `instance uniform dissolve` de `psx_lit` — si se re-materializa un modelo,
  conservar ese shader o portar el uniform.

## UI — reemplaza estilos de `scripts/ui/*.gd`

| Pack | Uso |
|------|-----|
| https://rohhsa.itch.io/free-psx-ui | Marcos, fuente bitmap, cursores (P3) |

- Prioridad: **fuente bitmap** (el HUD usa la fuente default de Godot) y marcos
  de piedra/pergamino para el resumen del amanecer.

## General

| Pack | Uso |
|------|-----|
| https://dysfunctional-games.itch.io/psx-starter-kit | Miscelánea de arranque |

---

## Specs generales de importación (GDD §10.1)

- Texturas **≤128 px** (el shader fuerza `filter_nearest`, no hace falta tocar imports).
- Modelos low-poly (200–800 tris por enemigo).
- Los materiales de assets importados se pasan a `psx_lit.gdshader` con su textura
  como `albedo_tex` — así todo el mundo comparte wobble, banding y dissolve.

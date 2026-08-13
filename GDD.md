# Quest Defense — Game Design Document

**Versión:** 0.2 · **Fecha:** 2026-08-11 · **Motor:** Godot 4.7 (Forward+, Jolt Physics)
**Estado:** documento vivo — las secciones marcadas 🔶 son propuestas pendientes de validación.

---

## 1. Visión

**Pitch:** Tower defense 3D en primera persona con estética de mazmorra PS1. Vos **sos** la torre: defendés tu corredor a disparos mientras negociás con los representantes de las otras torres del asedio. De noche peleás; de día reparás, mejorás, comerciás… y dormís para sellar el día.

**High concept:** *Orcs Must Die!* (TD en primera persona) + gunfeel y movimiento de *Counter-Strike* + presión horaria de *Dredge* + estética de *King's Field*.

**Fantasía central:** ser el último bastión de un corredor. Tu valor no es tu movilidad ni tu espada: es tu puntería, tu posición y tus alianzas.

---

## 2. Pilares de diseño

Todo lo que entre al juego debe servir al menos a uno de estos pilares. Si los contradice, no entra.

1. **Vos sos la torre.** Poder posicional, nunca mano a mano. El jugador nunca pisa el corredor de los enemigos.
2. **Gunfeel primero.** Movimiento y disparo crisp estilo CS: respuesta inmediata, feedback en capas. Si disparar no es rico, nada más importa.
3. **La noche pesa.** El ciclo día/noche crea ritmo tensión/descanso. Dormir es un ritual, no un menú.
4. **Nadie sobrevive solo.** Los pactos con las otras torres mueven recursos y rutas enemigas *de verdad* — la negociación tiene consecuencias mecánicas visibles.
5. **PS1 tangible.** La estética no es un filtro encima: texturas low-res, vertex snapping, niebla densa y dithering construyen un mundo artesanal y opresivo. La niebla además sirve al gameplay (oculta el spawn).

---

## 3. Decisiones de diseño tomadas

Registro de decisiones cerradas (para no re-discutirlas sin motivo):

| # | Decisión | Elección | Fecha |
|---|----------|----------|-------|
| D1 | Movilidad del jugador | Movimiento libre estilo CS, con zonas restringidas: **nunca** se puede bajar al corredor de enemigos | 2026-08-11 |
| D2 | Estructura de partida | Asedio por mapa: cada mapa es un asedio de N días con jefe final | 2026-08-11 |
| D3 | Negociación | Diálogos escritos (Dialogue Manager) sobre un sistema mecánico real (recursos, reputación, pactos) | 2026-08-11 |
| D4 | Otras torres | Solo NPCs; sin multiplayer | 2026-08-11 |
| D5 | Arma del Arquero | Proyectil físico: arco con caída (skill expression, look PS1) | 2026-08-11 |
| D6 | Persistencia entre mapas | Persiste todo (clase, talentos, armas): cada mapa es un **ascenso** a un puesto de defensa más difícil | 2026-08-11 |
| D7 | Objetivo destructible | v1: los enemigos solo rompen la **Puerta** de la torre — la Puerta es la condición de derrota (más destructibles a futuro) | 2026-08-11 |
| D8 | Trampas | Sistema base para todas las clases; v1: pinchos + barril de pólvora que explota al dispararle | 2026-08-11 |
| D9 | Muerte enemiga | Ragdoll — los enemigos se "desarman" al morir; maqueta con **goblins** como único enemigo de testeo *(enmendada: originalmente zombies)* | 2026-08-11 |
| D10 | Reparación de la Puerta | La Puerta se repara de día con recursos (oro/materiales) — conecta economía y negociación | 2026-08-11 |
| D11 | Layout del nivel | Boceto de Mauri: camino curvo **hundido** para enemigos + **superficie superior** transitable por el jugador + torre de 2 pisos; la Puerta al final del camino | 2026-08-11 |
| D12 | Post-proceso PS1 | Shader screen-space (aportado por Mauri): niebla por profundidad con ruido animado + cuantización + dithering — reemplaza al fog del Environment | 2026-08-11 |
| D13 | **Solo Arquero** | No hay clases: el personaje ES arquero. Los talentos mejoran atributos de tiro o desbloquean tipos de flecha CRAFTEADOS (poción atada / plumas) con materiales farmeados en la isla (flores/hongos + caza de pájaros). Diseño: docs/design/m4b-solo-arquero.md | 2026-08-12 |
| D14 | Balística v2 + guía de tiro | Gravedad de flecha unificada con el mundo (13.0), draw mínimo "globo" (14 m/s). Guía: **escalera de pips** + **memoria del tiro** + **diana Lucky Shot** (v2): blanco flotante sobre el objetivo, elevado exactamente la caída — mira dentro = se enciende; soltar ahí = tiro perfecto (balística exacta a la cabeza, sin spread). Sin tensar, la flecha sale a cualquier lado (spread 7°) | 2026-08-12 |
| D15 | Sistema de XP | Acertar flechas da XP: blanco (dummy 1.5 < goblin 4 + kill 8) × potencia del draw × distancia × calidad (headshot ×2, tiro perfecto ×1.5). Niveles con curva creciente — en M4b alimentan puntos de talento. Farmear tiro al blanco en tiempos muertos es progresión legítima | 2026-08-12 |
| D16 | Sondas + asedio | El combate se distribuye: **sondas diurnas** chicas y anunciadas (11:00 y 16:00, 3-7 goblins sin élites — interrumpen el farmeo, dan oro/XP) + el **asedio nocturno** como pico (21:00, 23:00, 00:30 con élites). La noche conserva su identidad (pilar 3); el día deja de ser espera. Noche "luna de plata" + braseros + ojos de goblin para legibilidad | 2026-08-13 |

---

## 4. Core loop

### 4.1 Loop de un día (micro)

```
 08:00 AMANECER    Resumen de la noche (pergamino): botín, daños, bajas,
                   mensajes de las otras torres.
 08:00 DÍA         Reparar y mejorar la torre · comprar munición ·
 –20:00            elegir talentos · negociar con torres vecinas ·
                   explorar zonas permitidas · colocar utilidades.
 20:00 ATARDECER   Campana de aviso. Últimas decisiones. Se cierran
                   las rutas exteriores.
 21:00 NOCHE       Oleadas. Los enemigos avanzan por los corredores
 –03:00            hacia las Puertas. Defendés la tuya a disparos.
 03:00 CONGELACIÓN El tiempo se detiene: los enemigos restantes se
                   retiran entre la niebla. Única acción posible: la cama.
 💤 DORMIR         Guarda la partida · resuelve pactos y simulación de
                   torres NPC · aplica producción · pasa al día siguiente.
```

- El reloj del día corre en tiempo real acelerado 🔶 (propuesta: ~12 min reales de día + 8–10 min de noche; a balancear en maqueta).
- Dormir antes de las 03:00 está permitido si la noche terminó (bonus de descanso 🔶).

### 4.2 Loop de asedio (macro)

- Un mapa = un asedio de **7–10 días**, con **jefe la última noche**.
- Dificultad y composición de oleadas escalan por día; después de medianoche aparecen variantes élite.
- Sobrevivís todos los días → asedio completado → **te ascienden** a un nuevo puesto de defensa más difícil: nuevo mapa, nuevas torres vecinas, nuevos personajes.
- **Persiste todo entre puestos (D6):** clase, talentos y armas viajan con vos — tu defensor hace carrera. 🔶 Si oro/materiales también persisten se define junto con la economía (§14).
- La clase se elige al crear al defensor; los talentos se acumulan a lo largo de la carrera (ver §7).

### 4.3 Condiciones de derrota

- La **Puerta** de tu torre (portón en la base, único destructible en v1 — D7) llega a 0 → los enemigos entran y saquean: asedio perdido.
- Si *tu* vida llega a 0 de noche: no hay game over — despertás al amanecer con penalización (perdés parte del botín y la Puerta sufre daño extra por la noche sin defensor). La muerte del jugador duele, pero la partida se pierde por la Puerta. *(Aceptado en v0.2; revisable tras playtests.)*
- 🔶 A futuro: más destructibles (barricadas, posiciones de tiro) y una posible segunda fase interior cuando cae la Puerta.

---

## 5. El jugador

### 5.1 Movimiento (feel Counter-Strike)

- **Respuesta instantánea:** aceleración de suelo alta, fricción alta → frenadas secas. Counter-strafe recompensado.
- **Precisión ligada a velocidad:** disparo perfecto con velocidad ~0; moviéndote, el cono de dispersión crece. Es LA mecánica que casa CS con tower defense: te plantás, disparás, te reposicionás.
- **Velocidad ligada al arma equipada** (arco liviano > lanzador pesado del ingeniero).
- Sin sprint. Crouch para cubrirte tras almenas. Salto corto funcional (subir cajones), sin bunny hop 🔶.
- FOV estable 90–100°, head-bob mínimo, view punch sutil al disparar.

### 5.2 Zonas de juego

| Zona | Acceso | Uso |
|------|--------|-----|
| Tu torre (pisos, almenas, balcones) | Siempre | Posiciones de tiro con trade-offs (ángulo vs exposición) |
| Patios y pasarelas propias | Siempre | Circulación, cofres, mesa de mejora |
| Camino a torres vecinas | Solo de día | Negociar cara a cara, ver el estado real de la torre aliada |
| Corredor de enemigos | **Nunca** | Bloqueado por altura, rejas y barandas — el nivel lo comunica visualmente |

- De noche las rutas exteriores se cierran (puertas físicas, no muros invisibles).

### 5.3 Interacciones clave

- **La cama:** único modo de terminar el día. Ritual corto: soplás la vela → fundido → pergamino de resumen.
- **Mesa de mejora / arsenal:** comprar munición y trampas, mejorar armas, elegir talentos.
- **Campana / catalejo** 🔶: adelantar el tiempo de día (para no esperar si ya terminaste de preparar) y espiar la composición de la próxima oleada.

---

## 6. Armas y combate

- **2 slots de arma + 1 utilidad** (definidos por clase y talentos).
- Munición finita que se compra/produce de día → conecta combate con economía y negociación.
- Mezcla de hitscan y proyectil según arma; las armas de proyectil tienen caída y tiempo de vuelo — skill expression. El arco del Arquero es proyectil con caída (D5).
- Headshots con daño crítico y feedback propio (ver §11).
- Recoil determinista corto en armas rápidas (spray breve controlable, estilo CS).

### 6.1 Trampas (sistema base — D8)

Disponibles para **todas las clases**; el Ingeniero las amplía, no las monopoliza (§7).

- Se compran de día en la mesa/mercader y se colocan **sin bajar al corredor** (D1): modo colocación desde la torre — apuntás a **anclajes** marcados en el corredor y una preview fantasma (verde/rojo) confirma la posición.
- v1 — dos trampas:

| Trampa | Efecto | Diseño |
|--------|--------|--------|
| **Pinchos** | Daño leve a cada enemigo que los pisa (🔶 + ralentización breve; se desgastan tras N pisadas) | Castigo pasivo: convierten tramos del corredor en zonas de valor |
| **Barril de pólvora** | Inerte hasta que **le disparás**: explosión en área + empujón | Sinergia con la puntería — decidir *cuándo* gastarlo es el juego; lanza ragdolls por el aire (§11.2) |

- Límite de anclajes activos por defecto 🔶 (2–3); talentos y la clase Ingeniero lo suben.

---

## 7. Clases y talentos

> **⚠ SUPERSEDIDO POR D13 (2026-08-12): no hay clases — SOLO ARQUERO.** El árbol
> pasa a OJO/MANOS/OFICIO con flechas crafteadas y farming (flores/hongos +
> pájaros) — diseño completo en `docs/design/m4b-solo-arquero.md`. Esta sección
> se reescribirá al implementar M4b; se conserva como referencia histórica.

Clase elegida al crear al defensor. Cada amanecer otorga **1 punto de talento** (+ extras por desempeño nocturno 🔶). Árbol de 3 ramas por clase. **Los talentos persisten entre puestos (D6)** — tu defensor hace carrera. 🔶 Riesgo a vigilar en playtests: la curva de dificultad de cada puesto tiene que absorber esa acumulación de poder.

| Clase | Fantasía | Armas núcleo | Ramas de talento (borrador) |
|-------|----------|--------------|------------------------------|
| **Arquero** | Precisión letal, one-taps | Arco largo, ballesta de repetición | Puntería (críticos) · Cadencia · Flechas especiales (fuego, perforante) |
| **Ingeniero** | El TD clásico hecho persona | Tarro de pólvora, clavador | Torreta auxiliar · Ampliación de trampas (§6.1: más anclajes, trampas exclusivas) · Explosivos |
| **Mago** | Control de área y elementos | Bastón de proyectil, orbe AoE | Fuego (daño) · Escarcha (ralentizar) · Arcano (maná/utilidad) |

- El Ingeniero es el puente con el tower defense tradicional: sus trampas y torretas se colocan **desde** la torre hacia el corredor (lanzándolas o mediante rieles), nunca bajando.
- El Mago usa maná regenerativo en vez de munición → economía distinta, más caster.
- Clases futuras (post-maqueta): Alquimista, Sacerdote.

---

## 8. Enemigos

Los enemigos marchan por el corredor hacia la Puerta. No te persiguen a vos — con excepciones deliberadas que te obligan a cambiar el foco.

> **Enemigo de maqueta (D9, enmendada):** un único **Goblin** cubre el rol de Grunt hasta tener más tipos — hoy es un muñeco de piezas (orejas puntiagudas, voz aguda por pitch) que se desarma al morir. Cuando llegue el modelo riggeado (goblin-faction-set en assets-list.md): **esqueleto humanoide** (imprescindible para el ragdoll de §11.2), glTF/GLB con animaciones de caminar y atacar. La facción goblin completa del pack puede cubrir Corredor/Chamán/Élite a futuro.

| Tipo | Rol | Contra-juego |
|------|-----|--------------|
| Grunt | Carne, ritmo base | Volumen de disparos |
| Corredor | Rápido, frágil | Priorización, flechas rápidas |
| Tanque | Lento, escudo frontal | Daño sostenido, trampas, flanco de ángulo |
| Volador | **Ignora el corredor, sube a tu almena y te ataca a VOS** | Mirar arriba, defensa personal |
| Saqueador | Roba botín del corredor y huye | Matarlo antes de que escape |
| Chamán | Buffea/cura a la horda | Prioridad absoluta de tiro |
| Élite nocturno | Variante reforzada, aparece pasada la medianoche | Builds y pactos |
| Jefe | 1 por asedio, última noche | Mecánica única por jefe |

- Los oleadas se anuncian con audio (tambores lejanos, cuernos) antes de ser visibles — la niebla PS1 oculta el spawn.
- La presión de tu corredor depende del **mapa de rutas** del asedio: pactos y caídas de torres redistribuyen el flujo (ver §9).

---

## 9. Torres vecinas y negociación

### 9.1 Estructura

- **2–4 torres NPC** por mapa, cada una con un **representante**: personaje con nombre, personalidad, retrato low-poly y voz de texto propia.
- Cada torre cubre su propio corredor y tiene: fuerza de defensa, estado de su Puerta, recursos y personalidad negociadora (avaro, honorable, cobarde, fanático…).

### 9.2 Qué se negocia

| Recurso/Pacto | Efecto mecánico |
|---------------|------------------|
| Oro, munición, materiales | Comercio directo |
| Comida | Dormir bien → buff del día siguiente 🔶 |
| Refuerzo | Un NPC dispara desde tu almena una noche |
| Información | Ver composición exacta de la próxima oleada |
| **Desvío de ruta** | Zapadores bloquean un corredor: la marea se redistribuye hacia otras torres — **la decisión moral/estratégica central del juego** |
| Pacto de auxilio | Si su Puerta baja de X%, intervenís con recursos automáticamente (y viceversa) |

### 9.3 Reputación y consecuencias

- Reputación por torre en escala **−2…+2**: modifica precios, disposición y opciones de diálogo disponibles.
- Desviar enemigos hacia una torre te hunde la reputación con ella; ayudarla la sube.
- Torres resentidas pueden negarte todo — o traicionarte 🔶 (desviar hacia vos sin avisar).
- **Si una torre cae, su corredor queda abierto:** más presión para todos los días restantes. Dejarla caer puede convenirte a corto plazo… y condenarte en el jefe final.

### 9.4 Simulación de torres NPC

No simulamos sus disparos en detalle. Cada noche se resuelve con un **check numérico**: fuerza de la torre vs presión de su corredor, modificado por pactos y eventos. El resultado se *muestra* en el mundo: humo, grietas, campanas a lo lejos durante la noche, y el reporte del amanecer.

### 9.5 Implementación de diálogo

- Plugin **Dialogue Manager 3** (Nathan Hoad): archivos `.dialogue` con condiciones y mutaciones que leen/escriben el estado del mundo (`reputación`, `recursos`, `pactos`) vía un autoload `WorldState`.
- Los diálogos exponen la negociación: las opciones aparecen/desaparecen según reputación y recursos — el texto es la cara del sistema, nunca decorado suelto.

---

## 10. Estética y presentación (PS1 dungeon)

### 10.1 Imagen

- **Resolución interna baja** (🔶 640×360, evaluar 480×270) escalada con filtro *nearest* → pixelación auténtica.
- Texturas 64–128 px, filtrado nearest, paleta reducida y coherente (piedra fría, fuego cálido).
- Shader estilo PSX propio: **vertex snapping** + **affine texture mapping** + banding/dithering de color.
- **Niebla densa** por distancia: identidad visual + rendimiento + gameplay (no ves el fondo del corredor).
- Iluminación: antorchas cálidas puntuales sobre luz de luna fría. Forward+ nos da las luces dinámicas que este contraste necesita.
- Modelos low-poly (200–800 tris por enemigo), animaciones con snap 🔶 (baja frecuencia de keyframes, estilo PS1).

### 10.2 UI

- Diegética donde se pueda: la cama, la campana, el mostrador del mercader, el pergamino del amanecer.
- Fuentes bitmap, marcos de piedra/pergamino, sin flat design moderno.
- HUD mínimo de noche: vida, munición, vida de la Puerta, reloj. Nada más.

### 10.3 Audio

- Reverb de mazmorra en interiores; exteriores secos con viento.
- Día: ambiente calmo, martillos lejanos. Noche: percusión tensa que escala con la oleada.
- Los cuernos/tambores enemigos son información de gameplay (anuncian tipo y dirección de oleada) 🔶.

---

## 11. Game feel — especificación

El pilar 2 aterrizado. Esto se prototipa en M1 antes que cualquier sistema.

### 11.1 Disparo

- **Firma por arma:** sonido en 3 capas (mecánica + cuerpo + cola), tracer visible, partícula de impacto según material, decal, view punch propio.
- **Hitmarker sonoro sutil** (*tac*) al conectar; **crunch + tono especial** en headshot; campanita de kill confirm 🔶.
- Números de daño **opcionales** (toggle en opciones, apagados por defecto — ensucian el look PS1).
- **Micro-hitstop** (2–4 frames) solo en kills importantes (élites, headshots letales).
- Screenshake pequeño y escaso: reservado a explosiones y jefe. La cámara es sagrada.

### 11.2 Enemigos que responden

- **Stagger visible** por impacto (animación aditiva de retroceso) — cada flecha *se siente* aunque no mate.
- **Muerte = ragdoll (D9):** el enemigo se "desarma" al morir. El impulso del golpe letal se hereda en el hueso impactado (un headshot letal empuja la cabeza hacia atrás; el barril hace volar el cuerpo entero — §6.1). Tras unos segundos, despawn con **dither-out** PS1, nunca fade alfa moderno.
- Presupuesto de ragdolls 🔶: máx. 6–8 activos; al exceder, los más viejos se despawnean primero. Implementación: `PhysicalBoneSimulator3D` + `PhysicalBone3D` sobre el esqueleto del zombie (Jolt).
- El Tanque frena visiblemente al recibir trampas; el Chamán interrumpe su canto si le pegás — feedback = información táctica.

### 11.3 El mundo responde

- Puerta dañada: campanas de alarma y estados visuales por rango de vida (intacta → astillada → tambaleante, con tablones sueltos). Su estado se lee de un vistazo desde las almenas.
- Amanecer tras noche dura: humo, escombros, marcas en el corredor que persisten el resto del asedio 🔶.
- Ritual de dormir: soplar la vela (input real, no cutscene larga) → fundido → pergamino.

---

## 12. Stack técnico y plugins

### 12.1 Base

- **Godot 4.7**, Forward+, **Jolt Physics** (ya configurado), D3D12.
- GDScript con tipado estático como estándar del proyecto.

### 12.2 Plugins

| Plugin | Para qué | Cuándo |
|--------|----------|--------|
| **Dialogue Manager 3** (Nathan Hoad) | Diálogos y negociación con condiciones/mutaciones | Maqueta (M5) |
| Shaders PSX **propios** | Vertex snap + affine + dithering — cortos de escribir y controlamos el look | Maqueta (M0) |
| **LimboAI** *o* **Beehave** | Behavior trees para enemigos complejos | Post-maqueta — en maqueta alcanza FSM + `NavigationAgent3D` |
| **Phantom Camera** | Transiciones de cámara (dormir, cinemática de jefe) | Post-maqueta, opcional |
| **Debug Draw 3D** | Visualizar rutas/raycasts en desarrollo | Cuando haga falta |
| **GUT** o **gdUnit4** | Tests de sistemas numéricos (economía, simulación de torres, oleadas) | Cuando los sistemas se estabilicen |

> Nota: evaluamos **Dialogic 2** como alternativa de diálogos; se descarta por ahora — Dialogue Manager es más liviano y se integra mejor con lógica custom de negociación. La estética del balloon la hacemos nosotros (pilar PS1).

### 12.3 Sistemas custom (sin plugin)

Día/noche y reloj · oleadas y spawners · trampas y anclajes · Puerta destructible · talentos · economía · reputación y pactos · simulación de torres NPC · save/load (al dormir).

### 12.4 Autoloads previstos

`WorldState` (día, hora, recursos, pactos, reputación) · `EventBus` (señales globales tipadas) · `SaveManager` · `AudioManager`.

---

## 13. Plan de maqueta (vertical slice)

Mapa mínimo: 1 corredor, tu torre, 1 torre vecina NPC.

| Hito | Contenido | Valida | Estado |
|------|-----------|--------|--------|
| **M0** | Setup: carpetas, autoloads, viewport escalado + shader PSX básico + niebla | El look | ✅ 2026-08-11 |
| **M1** | Controller FPS feel CS + **arco con proyectil y caída** (D5) con feedback completo (§11.1) contra dummies | **El gunfeel** — hito más importante | ✅ 2026-08-11 (afinar números jugando) |
| **M2** | Camino + spawner de oleadas + **Goblin** con `NavigationAgent3D` + **ragdoll de muerte** + **Puerta con vida** | El combate | ✅ 2026-08-11 (goblin placeholder de piezas; barril y pinchos adelantados de M4) |
| **M3** | Ciclo día/noche + reloj + congelación 03:00 + cama + pergamino de resumen | El ritmo | ✅ 2026-08-11 (save al dormir incluido) |
| **M4** | Comprar munición/mejora + **anclajes de trampas elegibles** (§6.1) + 3 talentos de Arquero + reparación con materiales | La progresión | Pendiente (oro por kill y reparar con oro ya andan) |
| **M5** | Torre vecina: 1 personaje, diálogo (Dialogue Manager), 1 negociación real (refuerzo o desvío de ruta) con efecto visible | La negociación | Pendiente |

> Validado por simulación headless (2026-08-11): noche completa día 1 → 24/24 goblins
> spawneados en 3 empujes, navegación y ataques a la Puerta correctos (51 golpes → 0 HP
> sin defensor), congelación y game over sin errores. Re-validado tras el rediseño v2
> del nivel (boceto D11) y la integración de assets (Dracula/Traps packs vía AssetLib).
>
> **Post-playtest 1 (2026-08-11):** luz ruidosa → sombras off + sol discreto + flicker
> interpolado; arco invertido → corregido; apuntado incómodo → layout D11 (meseta a
> 2.5 m del camino en vez de almena a 4 m con parapeto alto).
>
> **Post-playtest 2 (2026-08-11):** texturas "estiradas" → era el warp affine sobre
> los bloques fusionados del terreno (triángulos de 20–30 m); fix: subdivisión cada
> ~2 m (como PS1 real) + uniform `affine_strength` (0.85) en `psx_lit`. Aguja "Tower"
> del pack invertida → su eje venía al revés (+90° en AssetLib). Piezas sin textura
> ahora heredan el `albedo_color` del material fuente como tint.
>
> **Sesión 2026-08-12:** nivel **v3 al doble** (70×72 m, S doble con istmo de tiro
> entre brazos — D11 ampliada) y **horneado a escena editable**
> (`scenes/levels/outpost_01.tscn` + markers; re-bake con `bake_runner.tscn`).
> **Goblin del pack integrado**: FBX riggeado (28 huesos) con 22 animaciones
> (walk/run, 4 ataques, 3 hits) — el desarme (D9) ahora nace de las poses reales
> de los huesos al morir. Menú debug F1. Footsteps PSX del player. Fix: al caer
> la Puerta los goblins se plantan a saquear (antes escapaban por el hueco).
> ⚖️ Balance a vigilar: con el camino doble, el primer contacto con la Puerta
> llega ~1 min después de las 21:00 — más tiempo de tiro (buscado), menos tiempo
> de golpeo por noche; compensar en M4 (conteos/horarios de empuje).
>
> **Rediseño de islas (2026-08-12, boceto v2 — D11 ampliada):** AGUA alrededor;
> el camino es un terraplén en S entre la isla del ALIADO (norte, con arquero
> NPC funcional que dispara — preview de M5) y NUESTRA isla (torre de
> vigilancia). Puente elevado a la plataforma del Portón (machicolación);
> muralla en ruinas que se hunde en el agua; sin muros perimetrales (niebla +
> agua limitan). D1 náutico: caer al agua devuelve al jugador a la torre; los
> goblins NO nadan — se ahogan (kill válido: empujarlos al agua con explosiones
> es táctica). Crash reportado con Terrain3D → driver D3D12 reemplazado por
> Vulkan (el recomendado por el plugin). ⚖️ Vigilar: ~9/24 goblins se ahogan
> solos en el embudo sin defensor; ajustar si molesta en partida real.

**Criterio de éxito de la maqueta:** *"la noche 3 se siente tensa y disparar es rico"* — playtest de 15 minutos, sin explicar nada al tester.

Orden deliberado: gunfeel (M1) antes que sistemas. Si M1 no se siente bien, iteramos ahí antes de avanzar.

---

## 14. Preguntas abiertas

*(Las preguntas de v0.1 se resolvieron como D5–D10 en §3.)*

1. Duración real del día y la noche en minutos — **se decide jugando M3**.
2. ¿Oro y materiales también persisten entre puestos, o solo clase/talentos/armas? (D6 cubre el build; la plata está abierta.)
4. Detalles de trampas v1: durabilidad de los pinchos y límite de anclajes activos (🔶 en §6.1).
5. Idioma de los textos (voseo/neutro/inglés con localización) — a definir más adelante.
6. Nombre final — "Quest Defense" sigue de placeholder.

---

*Documento mantenido junto a Claude (game-dev/game-designer). Cada decisión nueva se registra en §3.*

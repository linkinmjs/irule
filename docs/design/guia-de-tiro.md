# Guía de tiro — opciones de diseño

> Diseñado por `godot-game-architect` (2026-08-12). Pilar rector: **Gunfeel
> primero** — la guía debe *facilitar el cálculo*, nunca *hacer el cálculo*.
> **Estado: Mauri debe elegir una opción** (recomendación del arquitecto: D).
>
> Datos duros: balística v2 recomendada g=13, v=14–42 m/s → caída bajo la línea
> de mira: 0.83 m a 15 m, 3.3 m a 30 m, 7.5 m a 45 m. Pantalla 640×360 FOV 92 →
> ~3 px por grado: toda guía será chica y chunky (a favor del look PS1).

## Opción A — Trayectoria fantasma punteada
Al tensar, 10–14 puntos billboard marcan la parábola hasta el impacto.
- Floor bajísimo, ceiling bajo. Costo medio.
- **Riesgo gunfeel: ALTO — piloto automático** (mirás la curva, no al goblin).
- No recomendada salvo como modo tutorial del día 1.

## Opción B — Plomada de impacto
Un rombo chato de ~30 cm apoyado donde caería la flecha con el draw actual.
Sobre agua no se dibuja ("te quedás corto" se lee por ausencia). Tensar
"camina" la plomada hacia adelante.
- Floor bajo, ceiling medio (queda el lead). Costo bajo-medio.
- **Riesgo gunfeel: MEDIO-ALTO** — el ojo se va al piso; en un juego de
  headshots, entrenar a mirar el suelo es tiro en el pie.

## Opción C — Corchetes de solución
4 corchetes en L (estilo del crosshair) alrededor del torso del goblin apuntado,
que se cierran en **3 pasos discretos** (snap PS1 + tic de audio) según qué tan
cerca está TU solución (elevación + draw) de acertar. "Caliente/frío" sobre el
objetivo, no una instrucción.
- Floor medio (confirma, no guía), ceiling alto (el lead sigue siendo tuyo).
- Costo medio (fórmula cerrada, sin simulación). **Riesgo gunfeel: MEDIO-BAJO**
  — mantiene la mirada EN el goblin. Cuidado con el tic dopamínico (pasos
  gruesos, no continuo).

## Opción D — Escalera de pips + telémetro (RECOMENDADA)
El crosshair gana una escalera vertical de 3 pips bajo el centro: los holdover
exactos para **15/30/45 m a full draw** (~10/19/29 px). Un raycast mide la
distancia al goblin apuntado y **engrosa el pip correspondiente** (cuantizado a
5 m). El juego: poner el pip resaltado sobre el goblin — la puntería sigue
siendo un acto manual.
- Solo aparece al acercarse a full draw (fade dithered): tiros rápidos =
  instinto puro. **Cada tipo de flecha recalcula su escalera** (la emplumada la
  comprime, la explosiva la estira): el peso se VE en la retícula, cero texto.
- Floor medio (30 s de tutorial), ceiling alto (interpolación, lead, >45 m).
- **Costo: BAJO** (todo en `CrosshairControl._draw()` + un raycast).
- **Riesgo gunfeel: BAJO** — información, no solución (mira de tanque austera).
- Gancho de progresión: talento `ojo_de_halcon` agrega el número de distancia.

## Complemento transversal (gratis, va con cualquiera): memoria del tiro
Cada flecha que impacta deja una **X chunky de 2 s** en el punto de impacto:
la mejor guía es tu flecha anterior — walkeás el tiro como artillero. Cero
autopiloto, costo trivial (el visual clavado ya existe).

## Balística v2 (aplicada 2026-08-12)

| Config | g | v full | drop 15 m | drop 30 m | drop 45 m |
|---|---|---|---|---|---|
| Vieja | 9.8 | 42 | 0.63 m | 2.5 m | 5.6 m |
| **Base (aplicada)** | **13.0** | **42** | 0.83 m | 3.3 m | 7.5 m |
| Variante "arquero puro" (knob) | 15.0 | 40 | 1.06 m | 4.2 m | 9.5 m |

- La gravedad de la flecha unificada con la del player (13.0) — antes caía
  MENOS que el mundo y por eso se sentía floaty.
- `ARROW_SPEED_MIN` 14: el tiro sin tensar es un globo cómico — el draw ES el arma.
- El lead queda como skill intocada: goblin cruzando a 30 m ≈ 1.2 m de anticipación.
- A `ArcherStats` en F1 (con `gravity` como stat multiplicable por tipo de flecha).

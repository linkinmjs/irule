class_name ArrowTypeData
extends Resource
## Tipo de flecha (M4b §2). Las especiales se CRAFTEAN sobre normales con
## materiales del farming (recipe) — solo la normal se compra en el cajón
## (bundle/stock). El peso (gravity_mult) hace que cada tipo se sienta y se
## VEA distinto (la escalera de pips se recalcula).

enum ZoneEffect { NONE, FIRE, FROST }

@export var id: StringName
@export var display_name := ""
## Receta de crafteo: {&"normal": 1, &"flor": 2, &"oro": 5}. Vacía = no craftable.
@export var recipe: Dictionary = {}
@export var gravity_mult := 1.0
@export var speed_mult := 1.0
@export var damage_mult := 1.0
# Impacto en área (explosiva)
@export var aoe_radius := 0.0
@export var aoe_damage := 0.0
@export var knockback := 0.0
# Zona persistente en el suelo (incendiaria/congelante)
@export var zone: ZoneEffect = ZoneEffect.NONE
@export var zone_radius := 0.0
@export var zone_duration := 0.0
@export var zone_dps := 0.0
@export var zone_slow := 0.0
## Tinte del fletch/nocked y del HUD — lectura de color 1:1 material→flecha.
@export var tint := Color.WHITE
# Compra en el cajón (solo la normal)
@export var bundle_size := 0
@export var bundle_price := 0
@export var daily_stock := 0

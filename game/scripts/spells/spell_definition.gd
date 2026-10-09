class_name SpellDefinition
extends Resource
## Data describing a spell. Behaviour lives in `effect_scene`, whose root must
## implement `start(ctx: SpellContext)`. New spells need a .tres + effect scene,
## never changes to the player controller.

enum Targeting { SELF_AREA, GROUND_POINT, DIRECTIONAL }
enum Category { WHIMSICAL, ENVIRONMENTAL, UTILITY, EXPLORATION, DEFENSIVE, OFFENSIVE, ANCIENT }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.WHIMSICAL
@export var targeting: Targeting = Targeting.SELF_AREA
@export var mana_cost := 20.0
@export var cooldown := 3.0
## Seconds of gathering/gesture before the effect is released.
@export var cast_time := 1.0
## Seconds the caster is rooted after release.
@export var recovery_time := 0.6
@export var radius := 10.0
@export var max_range := 12.0
@export var allowed_indoors := false
@export var cast_animation: StringName = &"Cast"
@export var gather_color := Color(0.8, 1.0, 0.55)
@export var effect_scene: PackedScene
@export var cast_sound := "spell_gather"
@export var release_sound := "spell_release"

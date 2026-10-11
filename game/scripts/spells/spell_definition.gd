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
## Metres the caster floats off the ground while casting (0 = stays grounded).
## The effect still originates at ground level.
@export var levitate_height := 0.0
## Extra stamina the cast costs while flying (-1 = 60% of the mana cost).
@export var flight_stamina_cost := -1.0

@export_group("Staff performance")
## Authored staff clip (StaffPoses). Empty = legacy library animation only.
@export var staff_pose: StringName = &""
## The body turns so the staff points at the aim point.
@export var aim := false
## Fired over the current focus-aim pose (no pose change of its own): only a
## recoil kick. Used by the Zoltraak firing modes while RMB is held.
@export var overlay := false
## Holds at the pose's sustain point while the cast button stays down.
@export var sustained := false
## Seconds after the release before the next cast may start (cancels the
## recovery tail so repeated casts chain without returning to idle).
@export var chain_after := -1.0
## Movement allowed while casting (0 = rooted, 1 = free).
@export_range(0.0, 1.0) var move_scale := 0.0
@export var interruptible := false
## Facial expression during the cast (FaceController name), held for the whole cast.
@export var expression: StringName = &""
## Scripts with `static func create() -> Node3D`-style classes: charge visual
## (runs from the cast start until release) and the release effect.
@export_file("*.gd") var charge_script := ""
@export_file("*.gd") var effect_script := ""
## Motes drawn toward the staff head while casting.
@export var gather_particles := true
## Visual family: &"white" (modern Zoltraak) or &"black" (the original killing magic).
@export var visual: StringName = &"white"
@export var gather_color := Color(0.8, 1.0, 0.55)
@export var effect_scene: PackedScene
@export var cast_sound := "spell_gather"
@export var release_sound := "spell_release"

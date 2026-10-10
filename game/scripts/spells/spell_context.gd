class_name SpellContext
extends RefCounted
## Everything an effect needs to know about one cast.

var spell: SpellDefinition
var caster: Node3D
var origin: Vector3
var target: Vector3
var direction: Vector3
var cast_seed: int
## Where the spell leaves the staff (its head) and the direction it points.
var muzzle: Vector3
var aim: Vector3

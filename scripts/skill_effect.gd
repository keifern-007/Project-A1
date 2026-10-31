class_name SkillEffect
extends Node3D
## Base for anything a skill spawns. The caster fills these in before adding it to the world.

var damage: int = 0
var element: Element.Type = Element.Type.PHYSICAL
var direction: Vector3 = Vector3.FORWARD
var caster: Node3D ## Who cast it (the Player): dashes move it, buffs change it.

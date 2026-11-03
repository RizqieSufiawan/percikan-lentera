class_name MissionData
extends Resource
## Misi selama masa KKN.

@export var id: StringName
@export var text: String
## Penghitung yang dicek: built, trained, dialog, lit_total.
@export var counter: StringName
@export var target: int = 1
@export var reward_points: float = 3.0
@export var reward_blue: float = 0.0

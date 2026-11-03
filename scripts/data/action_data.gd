class_name ActionData
extends Resource
## Aksi pemain pada satu provinsi (panel provinsi).

enum Effect { BUILD, TRAIN, INTERNET, DIALOG }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var effect: Effect = Effect.BUILD
@export var cost_points: int = 3
@export var cost_money: int = 0
## Upgrade yang harus dimiliki agar aksi ini muncul aktif.
@export var requires_upgrade: StringName
## Besar efek (arti tergantung Effect: komunitas +, resistensi -, dst.).
@export var amount: float = 1.0

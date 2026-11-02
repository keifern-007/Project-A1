class_name BossBar
extends Control
## The big boss health bar. Appears on EventBus.boss_spawned, fades out on boss_defeated.

var _health: HealthComponent
var _boss_name: String = ""

@onready var name_label: Label = %NameLabel
@onready var bar: ProgressBar = %Bar
@onready var hp_label: Label = %HpLabel


func _ready() -> void:
	hide()
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_boss_spawned(boss: Node) -> void:
	_health = boss.get_node_or_null("HealthComponent")
	if _health == null:
		return
	_health.health_changed.connect(_on_health_changed)
	var data: EnemyData = boss.get("data") as EnemyData
	_boss_name = tr(data.name_key) if data else ""
	name_label.text = _boss_name
	if data and data.stagger_threshold > 0.0 and boss.has_signal("stagger_changed"):
		boss.connect("stagger_changed", _on_stagger_changed)
		_on_stagger_changed(0.0, false)
	_on_health_changed(_health.current, _health.max_health)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


## "Old Hoarfrost   |   Stagger 40%": in words, beside the name.
func _on_stagger_changed(fraction: float, staggered: bool) -> void:
	var gauge: String = tr("HUD_STAGGERED") if staggered else tr("HUD_STAGGER") % roundi(fraction * 100.0)
	name_label.text = "%s   |   %s" % [_boss_name, gauge]


func _on_health_changed(current: int, maximum: int) -> void:
	bar.max_value = maximum
	bar.value = current
	hp_label.text = "%d/%d" % [current, maximum]


func _on_boss_defeated(_boss: Node) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(hide)

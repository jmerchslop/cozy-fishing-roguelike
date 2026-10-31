extends Node2D

## The fishing scene: the dock, the clock, and the timing bar.
##
## A day moves through a few steps:
##   ready -> waiting for a bite -> timing bar -> short result -> ready ...
## When the clock hits zero, game_rules.gd decides the ending:
##   enough cash -> "Day cleared", then the next day with a higher quota
##   not enough  -> "Game over", and any key starts again at day 1

enum Phase { READY, WAITING, BITE, RESULT, DAY_CLEAR, GAME_OVER }

const Rules := preload("res://scripts/game_rules.gd")

# How long "Day cleared" stays up before the next day starts on its own.
const DAY_CLEAR_PAUSE := 2.2
# Where the fishing line is tied, at the end of the dock.
const LINE_START := Vector2(660, 430)

@onready var bobber: ColorRect = $World/Bobber
@onready var fishing_line: Line2D = $World/FishingLine
@onready var minigame: Control = $HUD/Minigame
@onready var bar: ColorRect = $HUD/Minigame/BarFrame/Bar
@onready var green_zone: ColorRect = $HUD/Minigame/BarFrame/Bar/GreenZone
@onready var marker: ColorRect = $HUD/Minigame/BarFrame/Bar/Marker
@onready var day_label: Label = $HUD/Panel/DayLabel
@onready var quota_label: Label = $HUD/Panel/QuotaLabel
@onready var cash_label: Label = $HUD/Panel/CashLabel
@onready var time_label: Label = $HUD/Panel/TimeLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var banner: ColorRect = $HUD/Banner
@onready var banner_title: Label = $HUD/Banner/Card/Title
@onready var banner_body: Label = $HUD/Banner/Card/Body

var phase: int = Phase.READY
var day: int = 1
var cash: int = 0
var quota: int = 0
var time_left: float = 0.0
var phase_timer: float = 0.0
var bob_time: float = 0.0
var bobber_home := Vector2.ZERO
# 0 is the left edge of the bar, 1 is the right edge. This is the marker's center.
var marker_t: float = 0.0
var marker_dir: int = 1
var green_start: float = 0.4
# Copied from game_rules at the start of each day, so the bar can get harder.
var marker_speed: float = 0.0
var green_width: float = 0.0


func _ready() -> void:
	# The bar and the bobber are visible in the editor so you can see them.
	# Hide them until the player actually casts.
	bobber_home = bobber.position
	_start_run()


func _start_run() -> void:
	day = 1
	_begin_day()


func _begin_day() -> void:
	cash = 0
	quota = Rules.quota_for_day(day)
	time_left = Rules.DAY_LENGTH
	marker_speed = Rules.marker_speed_for_day(day)
	green_width = Rules.green_width_for_day(day)
	_go_ready()


func _advance_day() -> void:
	# Ignore extra keypresses that arrive after the next day has already started.
	if phase != Phase.DAY_CLEAR:
		return
	day += 1
	_begin_day()


func _process(delta: float) -> void:
	if phase == Phase.DAY_CLEAR:
		phase_timer -= delta
		if phase_timer <= 0.0:
			_advance_day()
		return

	if phase == Phase.GAME_OVER:
		return

	# The clock keeps running while you cast, wait, and reel.
	# A bite that is still on the line when time runs out does not count.
	# A long hitch (a slow first frame, a dragged window) should not skip the day.
	delta = minf(delta, 0.05)
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		_finish_day()
		return

	if phase == Phase.WAITING:
		_bob(delta)
		phase_timer -= delta
		if phase_timer <= 0.0:
			_start_bite()
	elif phase == Phase.BITE:
		_bob(delta)
		_move_marker(delta)
	elif phase == Phase.RESULT:
		phase_timer -= delta
		if phase_timer <= 0.0:
			_go_ready()

	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.GAME_OVER and _any_key_or_click(event):
		_start_run()
		return

	if not _cast_pressed(event):
		return

	if phase == Phase.READY:
		_cast()
	elif phase == Phase.BITE:
		_resolve_bite()
	elif phase == Phase.DAY_CLEAR:
		_advance_day()


func _cast_pressed(event: InputEvent) -> bool:
	# Key repeat is ignored. Holding Space must not hook the fish
	# on the same press that threw the line.
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		return key.keycode == KEY_SPACE or key.keycode == KEY_ENTER
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	return false


func _any_key_or_click(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	return _cast_pressed(event)


func _go_ready() -> void:
	phase = Phase.READY
	_hide_tackle()
	_hide_banner()
	status_label.text = "Press Space or click to cast"
	_refresh_hud()


func _cast() -> void:
	phase = Phase.WAITING
	phase_timer = randf_range(Rules.BITE_WAIT_MIN, Rules.BITE_WAIT_MAX)
	bob_time = 0.0
	bobber.position = bobber_home
	bobber.visible = true
	fishing_line.visible = true
	_sync_line()
	status_label.text = "Waiting for a bite..."
	_refresh_hud()


func _start_bite() -> void:
	phase = Phase.BITE
	marker_t = 0.0
	marker_dir = 1
	# Keep the whole green zone on the bar, with a small margin at each end.
	green_start = randf_range(0.02, 1.0 - green_width - 0.02)
	minigame.visible = true
	_layout_bar()
	status_label.text = "Bite! Press Space when the marker is in the green"
	_refresh_hud()


func _resolve_bite() -> void:
	phase = Phase.RESULT
	phase_timer = Rules.RESULT_PAUSE
	_hide_tackle()

	if _marker_in_green():
		var fish: Dictionary = Rules.roll_fish()
		var worth := int(fish["value"])
		cash += worth
		status_label.text = "Caught a %s!  +$%d" % [str(fish["name"]), worth]
	else:
		status_label.text = "The fish got away."

	_refresh_hud()


func _finish_day() -> void:
	time_left = 0.0
	_hide_tackle()
	_refresh_hud()

	if Rules.day_is_cleared(cash, quota):
		phase = Phase.DAY_CLEAR
		phase_timer = DAY_CLEAR_PAUSE
		var upcoming: int = Rules.quota_for_day(day + 1)
		_show_banner(
			"Day cleared",
			"You brought in $%d. The quota was $%d.\nDay %d raises it to $%d.\n\nThe next day starts in a moment.\nPress Space to skip ahead." % [cash, quota, day + 1, upcoming]
		)
	else:
		phase = Phase.GAME_OVER
		_show_banner(
			"Game over",
			"You brought in $%d, and the quota was $%d.\n\nPress any key to start a new run from Day 1." % [cash, quota]
		)


func _bob(delta: float) -> void:
	bob_time += delta
	bobber.position.y = bobber_home.y + sin(bob_time * 2.6) * 7.0
	_sync_line()


func _sync_line() -> void:
	var tip := bobber.position + Vector2(bobber.size.x * 0.5, 4.0)
	fishing_line.points = PackedVector2Array([LINE_START, tip])


func _move_marker(delta: float) -> void:
	marker_t += marker_dir * marker_speed * delta
	if marker_t >= 1.0:
		marker_t = 1.0
		marker_dir = -1
	elif marker_t <= 0.0:
		marker_t = 0.0
		marker_dir = 1
	_layout_bar()


func _layout_bar() -> void:
	var width := bar.size.x
	green_zone.position = Vector2(green_start * width, 0.0)
	green_zone.size = Vector2(green_width * width, bar.size.y)
	var marker_x := marker_t * width - marker.size.x * 0.5
	marker.position = Vector2(marker_x, (bar.size.y - marker.size.y) * 0.5)


func _marker_in_green() -> bool:
	return marker_t >= green_start and marker_t <= green_start + green_width


func _hide_tackle() -> void:
	bobber.visible = false
	fishing_line.visible = false
	minigame.visible = false


func _show_banner(title: String, body: String) -> void:
	banner.visible = true
	banner_title.text = title
	banner_body.text = body
	status_label.visible = false


func _hide_banner() -> void:
	banner.visible = false
	status_label.visible = true


func _refresh_hud() -> void:
	var seconds := 0
	if time_left > 0.0:
		seconds = ceili(time_left)
	day_label.text = "Day %d" % day
	quota_label.text = "Quota  $%d" % quota
	cash_label.text = "Caught today  $%d" % cash
	time_label.text = "Time left  %ds" % seconds

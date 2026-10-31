extends SceneTree

## Checks the fishing rules without opening the game window.
##
## From the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
##
## This script is the whole program while the tests run (it extends
## SceneTree). Do not attach it to a node in the fishing scene.

var failures: Array[String] = []


func _initialize() -> void:
	_run()
	if failures.is_empty():
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print("TESTS FAILED: %d" % failures.size())
		quit(1)


func _run() -> void:
	var Rules := preload("res://scripts/game_rules.gd")
	_test_quota_growth(Rules)
	_test_day_end(Rules)
	_test_fish_rolls(Rules)
	_test_difficulty_ramp(Rules)


func expect(ok: bool, message: String) -> void:
	if ok:
		print("PASS  %s" % message)
	else:
		failures.append(message)
		print("FAIL  %s" % message)


func _test_quota_growth(Rules: GDScript) -> void:
	# Day 1 uses the starting quota. Each later day adds the same amount.
	expect(
		Rules.quota_for_day(1) == Rules.STARTING_QUOTA,
		"day 1 quota is the starting quota ($%d)" % Rules.STARTING_QUOTA
	)

	var previous: int = Rules.quota_for_day(1)
	var grew := true
	for day in range(2, 7):
		var quota: int = Rules.quota_for_day(day)
		if quota != previous + Rules.QUOTA_INCREASE:
			grew = false
		previous = quota
	expect(grew, "quota grows by $%d on each new day" % Rules.QUOTA_INCREASE)

	# Day 0 and negative days should not invent a smaller quota.
	expect(
		Rules.quota_for_day(0) == Rules.quota_for_day(1),
		"day 0 uses the day 1 quota"
	)
	expect(
		Rules.quota_for_day(-3) == Rules.quota_for_day(1),
		"a negative day uses the day 1 quota"
	)


func _test_day_end(Rules: GDScript) -> void:
	var quota: int = Rules.quota_for_day(1)
	expect(
		Rules.day_is_cleared(quota, quota),
		"cash equal to the quota clears the day"
	)
	expect(
		Rules.day_is_cleared(quota + 1, quota),
		"cash above the quota clears the day"
	)
	expect(
		not Rules.day_is_cleared(quota - 1, quota),
		"cash one dollar short fails the day"
	)
	expect(
		not Rules.day_is_cleared(0, quota),
		"no cash fails the day"
	)


func _test_fish_rolls(Rules: GDScript) -> void:
	var table: Array = Rules.fish_table()
	var known := {}
	var table_ok := table.size() >= 3 and table.size() <= 5
	for entry in table:
		var fish := entry as Dictionary
		var fish_name := str(fish["name"])
		if fish_name == "" or int(fish["value"]) <= 0 or int(fish["weight"]) <= 0:
			table_ok = false
		if known.has(fish_name):
			table_ok = false
		known[fish_name] = int(fish["value"])
	expect(table_ok, "fish table has 3 to 5 named fish with a value and a weight")

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261031
	var seen := {}
	var rolls_ok := true
	for _i in 400:
		var rolled: Dictionary = Rules.roll_fish(rng)
		var fish_name := str(rolled["name"])
		if not known.has(fish_name) or int(rolled["value"]) != int(known[fish_name]):
			rolls_ok = false
			break
		seen[fish_name] = true
	expect(rolls_ok, "every roll is a fish from the table, with that fish's value")
	expect(
		seen.size() == known.size(),
		"over 400 rolls, every fish in the table shows up at least once"
	)

	# Changing the dictionary we were given must not change the real table.
	var sample: Dictionary = Rules.roll_fish(rng)
	sample["name"] = "Not A Fish"
	sample["value"] = -50
	var still_valid := true
	for entry in Rules.fish_table():
		var fish := entry as Dictionary
		if str(fish["name"]) == "Not A Fish" or int(fish["value"]) < 0:
			still_valid = false
	var again: Dictionary = Rules.roll_fish(rng)
	if str(again["name"]) == "Not A Fish" or int(again["value"]) < 0:
		still_valid = false
	expect(still_valid, "a rolled fish is a copy, so editing it leaves the table alone")


func _test_difficulty_ramp(Rules: GDScript) -> void:
	expect(is_equal_approx(Rules.DAY_LENGTH, 45.0), "a day lasts 45 seconds")

	expect(
		is_equal_approx(Rules.marker_speed_for_day(1), Rules.MARKER_SPEED_START),
		"day 1 uses the starting marker speed"
	)
	expect(
		is_equal_approx(Rules.green_width_for_day(1), Rules.GREEN_WIDTH_START),
		"day 1 uses the starting green zone"
	)

	# The first few days should take the small step, not jump straight to the cap.
	var early_days_ok := true
	for day in range(1, 5):
		var speed_now: float = Rules.marker_speed_for_day(day)
		var speed_next: float = Rules.marker_speed_for_day(day + 1)
		var width_now: float = Rules.green_width_for_day(day)
		var width_next: float = Rules.green_width_for_day(day + 1)
		if not is_equal_approx(speed_next, speed_now + Rules.MARKER_SPEED_PER_DAY):
			early_days_ok = false
		if not is_equal_approx(width_next, width_now - Rules.GREEN_WIDTH_PER_DAY):
			early_days_ok = false
		if speed_next <= speed_now or width_next >= width_now:
			early_days_ok = false
	expect(early_days_ok, "each early day speeds the marker up a little and shrinks the green zone a little")

	expect(
		is_equal_approx(Rules.marker_speed_for_day(40), Rules.MARKER_SPEED_MAX),
		"marker speed stops at its cap"
	)
	expect(
		is_equal_approx(Rules.green_width_for_day(40), Rules.GREEN_WIDTH_MIN),
		"the green zone stops shrinking at its floor"
	)
	expect(
		Rules.marker_speed_for_day(40) >= Rules.marker_speed_for_day(1),
		"the speed cap is not slower than day 1"
	)
	expect(
		Rules.green_width_for_day(40) <= Rules.green_width_for_day(1),
		"the zone floor is not wider than day 1"
	)

	expect(
		is_equal_approx(Rules.marker_speed_for_day(0), Rules.marker_speed_for_day(1)),
		"day 0 uses the day 1 marker speed"
	)
	expect(
		is_equal_approx(Rules.green_width_for_day(-2), Rules.green_width_for_day(1)),
		"a negative day uses the day 1 green zone"
	)

	# Window length is zone width divided by marker speed: how long the
	# marker actually sits inside the green.
	var day_one_window: float = Rules.green_width_for_day(1) / Rules.marker_speed_for_day(1)
	var hardest_window: float = Rules.GREEN_WIDTH_MIN / Rules.MARKER_SPEED_MAX
	expect(day_one_window < 0.16, "day 1 leaves the marker in the green for under 0.16 seconds")
	expect(hardest_window >= 0.05, "the hardest day still leaves at least 0.05 seconds of green")
	expect(hardest_window <= day_one_window, "later days are not easier than day 1")

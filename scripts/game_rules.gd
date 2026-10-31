class_name GameRules
extends RefCounted

## Cash, fish, and the day-end check.
##
## This file does not draw anything and does not read the keyboard.
## The fishing scene asks it questions ("what is today's quota?",
## "which fish did we catch?", "did the player make enough money?").
## The test script asks the same questions, with no game window open.

## One day lasts one minute, so you can feel a full day quickly.
const DAY_LENGTH := 60.0

## Cash the player must earn on day 1.
const STARTING_QUOTA := 80

## Added to the quota every time a day is cleared.
const QUOTA_INCREASE := 50

## The whole fish table.
## weight is how many tickets that fish has in the draw.
## A bigger weight means a more common fish. Values are in dollars.
const FISH := [
	{"name": "Silver Minnow", "value": 10, "weight": 40},
	{"name": "Peach Perch", "value": 25, "weight": 30},
	{"name": "Willow Trout", "value": 45, "weight": 18},
	{"name": "Dusk Salmon", "value": 80, "weight": 8},
	{"name": "Lantern Koi", "value": 150, "weight": 4},
]


## Quota for a day number. Day 1 is $80, day 2 is $130, day 3 is $180.
## Numbers below 1 are treated as day 1 so the quota never goes backwards.
static func quota_for_day(day: int) -> int:
	var safe_day := maxi(day, 1)
	return STARTING_QUOTA + (safe_day - 1) * QUOTA_INCREASE


## The day-end rule. Meeting the quota exactly is a win.
static func day_is_cleared(cash: int, quota: int) -> bool:
	return cash >= quota


## A copy of the fish table. Callers can read it without changing the real one.
static func fish_table() -> Array:
	var copy: Array = []
	for entry in FISH:
		copy.append((entry as Dictionary).duplicate())
	return copy


## Draw one fish using the weights above.
## Pass a RandomNumberGenerator from a test if you want the same draw every time.
## Leave it empty during play and Godot picks a random ticket.
static func roll_fish(rng: Variant = null) -> Dictionary:
	# Stack the weights into one pile of tickets.
	# Minnow 40 + Perch 30 + Trout 18 + Salmon 8 + Koi 4 = 100 tickets.
	var total_tickets := 0
	for entry in FISH:
		total_tickets += int((entry as Dictionary)["weight"])

	var ticket := randi_range(1, total_tickets)
	if rng is RandomNumberGenerator:
		ticket = (rng as RandomNumberGenerator).randi_range(1, total_tickets)

	# Walk the pile. The fish that owns the drawn ticket is the catch.
	var covered := 0
	for entry in FISH:
		var fish := entry as Dictionary
		covered += int(fish["weight"])
		if ticket <= covered:
			return fish.duplicate()

	# The walk above should always return. This is only a safety net.
	return (FISH.back() as Dictionary).duplicate()

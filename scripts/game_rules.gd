class_name GameRules
extends RefCounted

## Cash, fish, the day clock, and how hard the timing bar is.
##
## This file does not draw anything and does not read the keyboard.
## The fishing scene asks it questions ("what is today's quota?",
## "which fish did we catch?", "how fast is the marker today?").
## The test script asks the same questions, with no game window open.
##
## The numbers below are the knobs. Change them here when a day feels
## too easy or too harsh.

## How long one day lasts, in seconds.
const DAY_LENGTH := 45.0

## Cash the player must earn on day 1.
const STARTING_QUOTA := 80

## Added to the quota every time a day is cleared.
const QUOTA_INCREASE := 50

## How long the line sits in the water before a bite, in seconds.
## The scene picks a random wait between these two. Longer waits mean fewer casts.
const BITE_WAIT_MIN := 0.6
const BITE_WAIT_MAX := 1.8

## How long the "caught it" or "it got away" line stays up.
## The day clock keeps running during this pause.
const RESULT_PAUSE := 0.8

## Marker speed on day 1: the fraction of the bar it covers in one second.
## Above 1 means it crosses the whole bar in less than a second.
const MARKER_SPEED_START := 1.15

## Added to the marker speed at the start of each later day.
const MARKER_SPEED_PER_DAY := 0.05

## Speed cap. Past this the marker would be a blur, so it stops rising.
const MARKER_SPEED_MAX := 1.35

## Green catch zone on day 1, as a fraction of the bar.
## 0.12 is a thin slice, about one eighth of the bar.
const GREEN_WIDTH_START := 0.12

## Taken off the green zone at the start of each later day.
const GREEN_WIDTH_PER_DAY := 0.006

## Thinnest the zone is allowed to get. Still a real target, not a pixel.
const GREEN_WIDTH_MIN := 0.09

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


## How fast the marker moves on this day. Rises a little each day, then stops at the cap.
static func marker_speed_for_day(day: int) -> float:
	var safe_day := maxi(day, 1)
	var speed := MARKER_SPEED_START + float(safe_day - 1) * MARKER_SPEED_PER_DAY
	return minf(speed, MARKER_SPEED_MAX)


## How wide the green zone is on this day. Shrinks a little each day, then stops at the floor.
static func green_width_for_day(day: int) -> float:
	var safe_day := maxi(day, 1)
	var width := GREEN_WIDTH_START - float(safe_day - 1) * GREEN_WIDTH_PER_DAY
	return maxf(width, GREEN_WIDTH_MIN)


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

# Cozy Fishing Roguelike

A small fishing game made in Godot 4. Each day lasts 45 seconds. Catch fish, earn cash, and meet the day's quota. Clear it and the next day asks for more. Miss it and the run ends.

The picture is made of plain colored shapes. There is no art pack and no sound.

This project was checked with Godot 4.7.2. Any Godot 4.7 version should open it. Use the standard Godot download, not the .NET one. The scripts are GDScript.

## Open the project and press Play

1. Install Godot 4 from [godotengine.org](https://godotengine.org/download).
2. Open Godot. In the project manager, click **Import**.
3. Choose the `project.godot` file in this folder, then click **Import & Edit**.
4. Press **F5**, or the Play button at the top right.

The game window is a small dock over the water. The cream panel in the corner is your day.

## How to play

- **Space** or **click** casts the line.
- After a short wait, a fish bites and a bar appears.
- A marker slides back and forth. Press **Space** or **click** while it is in the green zone. The zone is thin and the marker is quick. Each new day the marker speeds up a little and the zone shrinks a little, until both hit a limit so a catch is still possible.
- Hit the green and you keep a random fish. Its price is added to **Caught today**. Miss, and it gets away.
- You can let the marker bounce and wait for the next pass. The day clock keeps ticking while you wait.
- When **Time left** hits 0:
  - If your cash meets the quota, you see **Day cleared**. The next day starts on its own (or press Space to skip the wait) with a higher quota.
  - If you are short, you see **Game over**. Press any key to start a fresh run at Day 1.

Day 1 asks for $80. Each day you clear adds $50 to the quota.

The fish, from common to rare: Silver Minnow ($10), Peach Perch ($25), Willow Trout ($45), Dusk Salmon ($80), Lantern Koi ($150).

## What each file does

```
project.godot          Tells Godot the game's name and which scene to play
scenes/main.tscn       The dock, the water, and the on-screen text
scripts/main.gd        Casting, the timing bar, the clock, and the messages
scripts/game_rules.gd  The fish table, the quota, and the win/lose check
tests/run_tests.gd     Checks the rules without opening the game window
icon.svg               The little picture in the project manager
```

`game_rules.gd` does not know about the window. `main.gd` asks it for the quota, rolls a fish after a good hook, and asks whether the day was cleared. That split is what the tests check.

Inside `scenes/main.tscn` the nodes are:

```
Main
├── World
│   ├── Sky, SunGlow, Sun, Hills, Sand
│   ├── Water, DeepWater, WaveA, WaveB
│   ├── Dock, PlankLine1, PlankLine2, PlankLine3
│   ├── PostLeft, PostRight
│   └── FishingLine, Bobber
│       └── BobberShine
└── HUD
    ├── Panel
    │   └── DayLabel, QuotaLabel, CashLabel, TimeLabel
    ├── StatusPlate, StatusLabel
    ├── Minigame
    └── Banner
```

The bar starts visible in the editor so you can find it. Once you press Play, the game hides it until a fish bites.

## Check the rules from a terminal

If you have the Godot binary on your PATH:

```
godot --headless --path . --script res://tests/run_tests.gd
```

You should see a line of `PASS` results and then `ALL TESTS PASSED`. The tests cover the quota going up each day, a day passing only when the cash meets the quota, fish rolls staying inside the table, and the timing bar getting a little harder each day without becoming impossible.

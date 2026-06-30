# Skyss Animal Game

`skyss_animalgame` is a single-player `arena_lib` minigame where the player hears an animal sound, then chooses the matching animal from four answer totems.

## Arena Setup

Create and enable an arena with the usual `arena_lib` tools:

```text
/arenas create skyss_animalgame <arena_name> 1 1
/arenas edit skyss_animalgame <arena_name>
```

Build a room and add one player spawn point. At match start, the mod captures the player's position and horizontal facing, snaps the facing to the nearest room axis, places the four answer totems in a single line in front of that start point, and reuses those same positions for every question.

## Gameplay

- Each totem is two blocks tall: a base block with a clickable button on top, plus a clickable static animal icon and visible name label.
- The player starts with 10 seconds to answer.
- Each correct answer increases the score and starts a new question.
- The answer time shrinks as the score increases, down to a minimum of 4 seconds.
- A wrong answer or timeout ends the game.
- The final score is shown before `arena_lib` returns the player to the hub.

## Assets

When Mineclonia `mobs_mc` is enabled, the mod reuses its animal sounds and spawn-icon textures. If `mobs_mc` is unavailable, the minigame still loads with colored placeholder animal cubes, but the real sound quiz needs the Mineclonia animal sounds.

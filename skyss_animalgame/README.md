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
- Each question starts with a short listening moment before the countdown begins.
- The player can click the "Hear again" bell between the totems to replay the current animal sound.
- Timer, replay hints, and answer feedback are shown at the top of the screen.
- The player starts with 10 seconds to answer after the listening moment.
- Each correct answer increases the score and starts a new question.
- The answer time shrinks as the score increases, down to a minimum of 4 seconds.
- A wrong answer or timeout ends the game and shows the correct animal highlighted before the final score.
- The final score stays on screen for a few seconds before `arena_lib` returns the player to the hub.

## Assets

When Mineclonia `mobs_mc` is enabled, the mod reuses its animal sounds and spawn-icon textures. When `animalworld` is enabled, the quiz pool also includes additional animals such as bear, camel, crocodile, elephant, fox, frog, goose, hyena, koala, marmot, monkey, moose, otter, owl, seal, eagle, tapir, tiger, yak, and zebra.

When Mineclonia `mcl_bells` is enabled, the replay control uses the bell model.

The minigame requires at least four available animals from enabled source mods.

# Arena_lib

arena_lib is a library for Luanti working as a core for any arena mini-game you have in mind.  
It comes with an arena manager, an editor and a custom entrance system (signs by default). Entrances create a virtual bridge between the normal game world and your minigame arenas.  

With arena_lib, you don't have to do the boring job and you can focus exclusively on your minigame(s) :* 

<a href="https://liberapay.com/Zughy/"><img src="https://i.imgur.com/4B2PxjP.png" alt="Support my work"/></a>  

### Config

1. Install it as any other mod

2. Launch the world at least once with arena_lib enabled and then check `worlds/nameofyourworld/arena_lib` to customise it

3. Do `/arenas help` to learn how it works

### I want to make a minigame
First time? Check out the [wiki](https://gitlab.com/zughy-friends-minetest/arena_lib/-/wikis/Your-first-minigame) to create your first minigame. Otherwise, dive into the [full documentation](DOCS.md)

### Optional Dependencies and Add-ons
* (add-on) [Hub](https://gitlab.com/zughy-friends-minetest/hub) by me: use it if you're aiming for a full minigame server. It can't be set as an optional dependency, since arena_lib is a hard dependency of Hub in the first place (and MT doesn't like cross dependencies)
* (optional) [Parties](https://gitlab.com/zughy-friends-minetest/parties) by me: use it to be sure to join the same arena/team as your friends

### Known conflicts
* `Beds` or any other mod overriding the default respawn system
* `SkinsDB` or any other mod applying a 3D model onto the player, if `teams_color_overlay` is used
* `Weather` or any other mod changing players skybox at runtime (custom celestial vaults will be overridden)

#### Mods relying on arena_lib
* [Block League](https://gitlab.com/zughy-friends-minetest/block_league)
* [Murder](https://gitlab.com/giov4/minetest-murder-mod)
* [Skywars](https://gitlab.com/zughy-friends-minetest/skywars)
* ...and many more! ([full list](https://content.luanti.org/metapackages/arena_lib/))

### Want to help?
Feel free to:
* open an [issue](https://gitlab.com/zughy-friends-minetest/arena_lib/-/issues)
* check [Weblate](https://translate.codeberg.org/projects/zughy-friends-minetest/arena_lib/) for translations
* submit a merge request. In this case, PLEASE, do follow milestones and my [coding guidelines](https://cryptpad.fr/pad/#/2/pad/view/-l75iHl3x54py20u2Y5OSAX4iruQBdeQXcO7PGTtGew/embed/)

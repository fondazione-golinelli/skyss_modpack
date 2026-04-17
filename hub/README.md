# Hub

A hub for your mini-games Luanti server  

<a href="https://liberapay.com/Zughy/"><img src="https://i.imgur.com/4B2PxjP.png" alt="Support my work"/></a>

### Dependencies
* [arena_lib](https://gitlab.com/zughy-friends-minetest/arena_lib/) by me
* (bundled by arena_lib) [ChatCMDBuilder](https://gitlab.com/rubenwardy/ChatCmdBuilder) by rubenwardy
* [panel_lib](https://gitlab.com/zughy-friends-minetest/panel_lib) by me

Optional dependencies (not real dependencies, but since you're going for a minigame hub kind of server, these are a great addition)
* [Magic Compass](https://gitlab.com/zughy-friends-minetest/magic-compass) by me
* [Parties](https://gitlab.com/zughy-friends-minetest/parties) by me


### Structure
* `hub`: mandatory
* `hub_metrics`: understand which minigames are the most played. It uses Grafana
* `playerlist`: display the list of online players by pressing one key (by default `E`)

### Customisation
1. be sure the world has been launched at least once with Hub Manager active
2. go to `your world folder/hub`
3. edit the files inside

### Want to help?
Feel free to:
* open an [issue](https://gitlab.com/zughy-friends-minetest/hub-manager/-/issues)
* submit a merge request. In this case, PLEASE, do follow milestones and my [coding guidelines](https://cryptpad.fr/pad/#/2/pad/view/-l75iHl3x54py20u2Y5OSAX4iruQBdeQXcO7PGTtGew/embed/). I won't merge features for milestones that are different from the upcoming one (if it's declared), nor messy code
* contact me on Matrix, on my server [dev room](https://matrix.to/#/!viLipqDNOHxQJqQRGI:matrix.org)

### Credits
Images by me, under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

# Magic Compass

Teleport system for Minetest

<a href="https://liberapay.com/Zughy/"><img src="https://i.imgur.com/4B2PxjP.png" alt="Support my work"/></a>

<img src="https://content.minetest.net/uploads/b680bef95d.png"/>

### How to use it
Look for the "Magic Compass" item in your creative inventory, put it in your hand and left click it to open the locations menu

### Customisation
1. be sure the world has been launched at least once with Magic Compass active
2. go to `your world folder/magic_compass`
3. open an existing `.yml` file or create a new one (Magic Compass can read multiple locations from multiple files)
4. follow the template down below, where ID is an actual number
```yml
ID:
  description:
  icon:
  teleport_to: X, Y, Z
  rotation: # (optional, horizontal rotation of the player in degrees. If declared, vertical rotation is set to 0 when teleporting; otherwise is not touched. Default `nil`)
  cooldown: # (optional, in seconds. Default `nil`)
  requires: # (optional privileges required to use the teleport: separate them with `, `, default `nil`)
  hidden_by_default: # (optional, default `nil`; put `true` to hide the icon to players who don't have the required privileges)
```
For more information, check out the `instructions.txt` file inside that folder.

For using the API, check out the [DOCS](/DOCS.md).

### Want to help?
Feel free to:
* open an [issue](https://gitlab.com/zughy-friends-minetest/magic-compass/-/issues)
* check [Weblate](https://translate.codeberg.org/projects/zughy-friends-minetest/magic-compass/) for translations
* submit a merge request. In this case, PLEASE, do follow milestones and my [coding guidelines](https://cryptpad.fr/pad/#/2/pad/view/-l75iHl3x54py20u2Y5OSAX4iruQBdeQXcO7PGTtGew/embed/)

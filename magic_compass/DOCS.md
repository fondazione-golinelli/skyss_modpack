# Magic Compass DOCS

### Callbacks
If you want to run additional code from an external mod of yours, there a few callbacks coming in handy:
* `magic_compass.register_on_use(function(player, ID, item_name, pos))`: use it to run more checks BEFORE being teleported. If it returns nil or false, the action is cancelled. If true, it keeps going
* `magic_compass.register_on_after_use(function(player, ID, item_name, pos))`: use it to run additional code AFTER having been teleported

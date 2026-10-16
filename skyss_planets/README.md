# skyss_planets

Moon and Mars class worlds (instance templates `moon` and `mars`). The
`skyss_planet` setting in the world's `luanti.conf` picks the body; without it
the mod does nothing.

| | Moon | Mars |
| --- | --- | --- |
| Gravity | 1.62 m/s² (×0.165) | 3.71 m/s² (×0.378) |
| Day sky | black, stars visible | butterscotch, haze |
| Sunrise/sunset | none | blue glow around the sun |
| Night sky | stars, the Earth (blue, 3.7× the Moon's size) | stars, Phobos (small) |
| Sun | normal size | two thirds |
| Clouds | none | faint ice clouds |
| Ground | light highlands, dark basalt "sea", craters, bright fresh craters, boulders | red dust over sandstone, coloured layers on canyon and mesa walls, shield volcano with caldera, dark dunes, craters with ice under the floor, basalt rocks |

- **Gravity** is a playerphysics factor, so it multiplies with Mineclonia's own
  effects. Jumps are about 6× (Moon) and 2.6× (Mars) higher. Fall damage is
  computed by the engine from the landing speed, so it shrinks by itself.
  Items and mobs keep Earth gravity.
- **Sky**: Mineclonia repaints the sky every few seconds from weather and
  biome; the mod replaces `mcl_weather.skycolor.update_sky_color` for players
  in the overworld. The weather is kept clear.
- **Mobs**: no natural spawning in the overworld (`mcl_mobs.spawn_cycle` is
  wrapped), even when the classroom settings turn mob spawning on; spawn eggs
  still work.
- **Terrain**: a Lua generator on the `singlenode` mapgen
  (`mcl_levelgen.conf` keeps Mineclonia's own singlenode generator off). The
  templates ship the area -512..511 pregenerated (for the world map); chunks
  further out are generated the same way while playing. A flat landing site
  around 0,0 is kept free of craters and holds the spawn.

The mod registers no nodes, items or media: class worlds share the `instance`
media pool, so it uses Mineclonia nodes and built-in textures (`moon.png`,
`sunrisebg.png` with colour modifiers) only. Keep it that way, or load the mod
on every pool member.

Regenerate the templates with `luanti-tools/templategen/templategen.sh`.

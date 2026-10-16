# skyss_lobby

Impostazioni globali del mondo hub (lobby). Va abilitata solo nel mondo del lobby.

- **Ora fissa**: il sole resta a mezzogiorno. La mod rimette l'ora del giorno ogni 5 secondi; con `time_speed = 0` in `luanti.conf` il tempo non scorre proprio.
- **Cielo sereno**: niente pioggia, neve o temporali. La mod riporta il meteo di Mineclonia a "sereno" se cambia; `mcl_doWeatherCycle = false` evita che cambi da solo.
- **Giocatori più veloci**: velocità ×1,3 sia camminando sia correndo. Il fattore passa da `playerphysics` di Mineclonia, quindi si moltiplica con lo sprint e gli altri effetti. Viene messo all'ingresso e tolto all'uscita, così non resta nei dati del giocatore.

## Impostazioni (`luanti.conf`)

| Chiave | Predefinito | Significato |
| --- | --- | --- |
| `skyss_lobby_time_of_day` | `0.5` | ora del giorno da 0 a 1 (0,5 = mezzogiorno); `-1` lascia scorrere il tempo |
| `skyss_lobby_clear_weather` | `true` | cielo sempre sereno |
| `skyss_lobby_speed` | `1.3` | fattore di velocità dei giocatori (1 = normale) |

Insieme vanno messi `time_speed = 0` e `mcl_doWeatherCycle = false`: hubgen li scrive già nel `luanti.conf` del modello del lobby.

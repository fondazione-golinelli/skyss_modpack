# Fai rinascere la foresta

Minigioco cooperativo per `skyss_minigames`, nell'isola della foresta abbattuta del lobby (arena `dead_forest`, launcher nel padiglione degli alberi). La squadra riporta in vita la foresta: il terreno è brullo, va concimato e annaffiato; sull'erba sana si fanno crescere erba e fiori e si piantano alberi. Non si possono rompere né piazzare blocchi: si lavora solo con gli strumenti del gioco.

## Come si gioca

All'avvio ogni giocatore riceve quattro strumenti (slot 1-4). Ogni strumento si usa con clic sinistro o destro sul blocco; quando lo prendi in mano, sopra la hotbar compare cosa fa.

| Strumento | Su cosa | Effetto |
| --- | --- | --- |
| **Concime** | terreno spoglio: terra grossolana, podzol, terra, erba secca | diventa *terreno concimato* (area 3×3) |
| **Annaffiatoio** | terreno concimato | diventa erba sana, verde (area 3×3) |
| | alberello piantato | l'alberello cresce in un albero dopo 6 secondi |
| | barile dell'acqua piovana, acqua | lo riempie (15 annaffiate) |
| **Semi di prato fiorito** | erba ripristinata dalla squadra | spuntano fino a 5 tra erba alta e fiori intorno |
| **Alberelli** | erba ripristinata dalla squadra, con spazio sopra e nessun albero a meno di 2 blocchi | pianta un alberello (quercia, betulla o abete) |

Gli alberi sono quelli veri di Mineclonia, con le foglie colorate come il resto dell'isola. L'erba naturale ai bordi dell'isola non conta: erba, fiori e alberi valgono solo sul terreno ripristinato durante la partita.

All'inizio della partita il gioco mette 8 **barili dell'acqua piovana**: 2 accanto al punto di arrivo e 6 in cerchio a circa 28 blocchi. Quando l'annaffiatoio è vuoto, un indicatore porta al barile più vicino.

**Vittoria**: quando la squadra raggiunge i tre obiettivi (terreno sano, erba e fiori, alberi). Seguono fuochi d'artificio e 15 secondi per passeggiare nella foresta. La classifica è a tempo (più veloce = meglio). Allo scadere del tempo la partita finisce senza vittoria e la chat dice quanto mancava.

L'HUD in alto a destra mostra il cronometro, i tre obiettivi con la barra di avanzamento, l'acqua nell'annaffiatoio, il record e il lavoro del singolo giocatore. A fine partita la chat nomina i tre migliori giardinieri.

## Obiettivi e numero di giocatori

Gli obiettivi crescono con il numero di giocatori, così la partita dura più o meno lo stesso tempo da soli e con una classe intera:

obiettivo = obiettivo per un giocatore × giocatori^0,9

L'esponente 0,9 (un po' meno che proporzionale) tiene conto del fatto che in tanti ci si intralcia.

| Giocatori | Terreno sano | Erba e fiori | Alberi |
| --- | --- | --- | --- |
| 1 | 45 | 15 | 3 |
| 5 | 192 | 64 | 13 |
| 10 | 358 | 120 | 24 |
| 20 | 668 | 223 | 45 |
| 30 | 961 | 321 | 65 |

Il terreno non supera il 70% di quello spoglio disponibile nell'arena, e gli alberi non superano uno ogni 12 blocchi di terreno (servono spazio per crescere). Chi entra a partita in corso riceve gli strumenti, ma gli obiettivi restano quelli calcolati all'avvio.

I valori si cambiano in cima a `init.lua` (`SOLO_GOALS`, `GROUP_EXPONENT`, `CAN_CAPACITY`, `TREE_GROW_TIME`, …). Il tempo limite è quello di `skyss_minigames` (3 minuti, modificabile dall'editor o dal docente).

## Parametri dell'arena

Nel campo `params` dell'arena in `arenas.json` (tutti facoltativi):

- `soil_goal`, `plants_goal`, `trees_goal`: obiettivi fissi al posto di quelli automatici;
- `barrels`: posizioni dei barili, `[[x, y, z], …]`; la `y` viene ricalcolata sul terreno. Senza, i barili vanno in cerchio intorno ai punti di spawn.

L'area viene salvata prima della partita e ripristinata dopo da `skyss_minigames`: terreno, piante, alberi e barili spariscono alla fine.

## Lingue

Tutti i testi (HUD, chat, suggerimenti, nomi degli oggetti) seguono la lingua del client: italiano, spagnolo, francese, tedesco, polacco e ungherese, inglese per le altre. Le chiavi sono le stringhe inglesi passate a `S()` in `init.lua`; le traduzioni sono in `locale/skyss_treegame.<lingua>.tr`. Se aggiungi una stringa nel codice, aggiungila al template e a ogni file `.tr`.

## Asset

Tutte le texture (icone degli strumenti 32×32, icone dell'HUD, barile, terreno concimato, particelle, icona del launcher) sono generate da `tools/gen_assets.py` (Python 3 + Pillow):

```bash
python3 tools/gen_assets.py
```

Il terreno concimato è `default_dirt.png` di Mineclonia con sopra `skyss_treegame_fertile_overlay.png`. I suoni vengono da Mineclonia.

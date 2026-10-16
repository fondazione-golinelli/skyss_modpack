# Eco-CleanUp

Minigioco cooperativo `arena_lib` per Luanti/Mineclonia. All'avvio la squadra trova l'arena (terrestre, subacquea o mista) disseminata di rifiuti 3D: bottiglie di plastica, bottiglie di vetro, lattine, sacchi dell'immondizia e bidoni arrugginiti. La squadra li raccoglie con il forcone e li differenzia nei cassonetti giusti. Vince quando il 100% dei rifiuti è stato conferito; conta il tempo, compresi gli errori.

## Come si gioca

- **Raccolta**: colpisci un rifiuto con il **Forcone Eco-CleanUp** (slot 1, portata 6 blocchi). Il rifiuto sparisce e finisce nell'inventario. Ogni giocatore può portarne al massimo 8 alla volta.
- **Smaltimento differenziato**: tieni in mano il rifiuto (rotella del mouse o tasti numerici) e fai clic destro sul cassonetto:
  | Cassonetto | Colore | Accetta |
  | --- | --- | --- |
  | Plastica e Metalli | giallo | bottiglie di plastica, lattine |
  | Vetro | verde | bottiglie di vetro |
  | Indifferenziata | grigio | sacchi dell'immondizia, bidoni vecchi |
- **Errori**: un rifiuto messo nel cassonetto sbagliato viene rifiutato. La squadra prende **+10 secondi** e il giocatore riceve la spiegazione corretta.
- **Vittoria**: quando l'ultimo rifiuto è conferito partono i fuochi d'artificio. Il tempo finale (cronometro + penalità) viene confrontato con il record dell'arena.
- Quando a terra resta un quarto dei rifiuti o meno (almeno 3), compaiono indicatori con la distanza verso ciascuno di quelli rimasti.
- Alla prima raccolta di ogni tipo il giocatore riceve in chat una curiosità ambientale ("Lo sapevi?").

L'HUD in alto a destra (lontano dalla chat) mostra il cronometro, la barra di avanzamento della squadra, quanti rifiuti restano a terra o nei sacchi, il contenuto del proprio sacco diviso per cassonetto, gli errori e il record.

## Preparazione dell'arena

1. Abilita `skyss_cleanup` insieme ad `arena_lib`.
2. Crea l'arena: `/arenas create skyss_cleanup <nome> 1 16`, poi `/arenas edit skyss_cleanup <nome>`. Definisci la regione (`pos1`/`pos2`) e almeno un punto di spawn.
3. Colloca **almeno un cassonetto per tipo** dentro la regione: `skyss_cleanup:bin_plastic`, `skyss_cleanup:bin_glass`, `skyss_cleanup:bin_general`. Il lato con l'icona guarda verso chi li piazza. Sopra ogni cassonetto, durante la partita, compare un'etichetta colorata.
4. *(Consigliato)* Distribuisci i punti di comparsa: `skyss_cleanup:land_marker` (cerchio arancione) sul terreno, `skyss_cleanup:water_marker` (cerchio blu) sul fondale. All'avvio la mod li nasconde (i marcatori subacquei tornano acqua), ne sceglie a caso quanti servono e li ripristina a fine partita.
   Senza marcatori la mod sparge i rifiuti sulla superficie più alta di colonne casuali, sia a terra sia sul fondale, evitando alberi e cassonetti. I marcatori sono comunque preferibili nelle arene al chiuso o con tetti.
5. Salva la mappa e abilita l'arena.

Quantità di rifiuti: cresce con il numero di giocatori (fino a 30), da 14 per un giocatore a 100 per 30. La formula è 14 × giocatori^0,58, con un massimo di 100 rifiuti per non appesantire il server, ed è limitata dal numero di marcatori disponibili. Con tanti giocatori ognuno raccoglie quindi meno rifiuti che da solo.

| Giocatori | 1 | 2 | 5 | 10 | 15 | 20 | 30 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Rifiuti | 14 | 21 | 36 | 54 | 68 | 80 | 100 |

Oltre gli 80 rifiuti il luccichio intorno a ciascuno è più leggero, per non appesantire i computer dei giocatori. I valori si cambiano in cima a `init.lua` (`WASTE_SOLO`, `GROUP_EXPONENT`, `WASTE_MAX`). Per fissare la quantità, imposta il parametro d'arena `waste_amount` (0 = automatico).

Se mancano cassonetti o non ci sono punti utilizzabili, la partita termina subito con un messaggio in chat e un avviso nel log del server.

## Dettagli tecnici

- I rifiuti sono entità con mesh OBJ in `models/` (il corrispettivo Luanti del *Custom Model Data* di Minecraft). Sono legati alla partita da un token: quelli rimasti dopo un crash si autoeliminano alla riattivazione.
- Gli oggetti nell'inventario portano lo stesso token, quindi non valgono in altre partite. Non si possono gettare. Alla morte restano al giocatore e tornano al respawn. Se un giocatore abbandona, ciò che portava ricompare nell'arena.
- Respiro sempre pieno e niente danni da annegamento o caduta, così le zone sommerse sono giocabili senza equipaggiamento.
- È possibile entrare a partita in corso: il nuovo giocatore riceve forcone e HUD.
- Suoni e particelle usano gli asset di Mineclonia quando sono presenti.

## Lingue

Tutti i testi visibili ai giocatori (HUD, chat, nomi degli oggetti, etichette dei cassonetti, infotext) seguono la lingua del client Luanti di ciascun giocatore. Traduzioni incluse: italiano, spagnolo, tedesco, polacco e ungherese. Per le altre lingue si usa l'inglese.

I nomi dei cassonetti seguono lo schema europeo: giallo per imballaggi in plastica e metallo, verde per il vetro, grigio per il resto (es. *Gelbe Tonne* / *Restmüll*, *Plastik i metale* / *Zmieszane*).

Le chiavi sono le stringhe inglesi passate a `S()` in `init.lua`. Le traduzioni si modificano direttamente in `locale/skyss_cleanup.<lingua>.tr`. Per aggiungere una lingua, copia `locale/template.txt` in `skyss_cleanup.<codice>.tr` e compila le righe dopo `=`. Se aggiungi una stringa nel codice, aggiungila anche al template e a ogni file `.tr`.

## Asset

Modelli e texture sono generati da `tools/gen_assets.py` (Python 3 + Pillow):

```bash
python3 tools/gen_assets.py
```

Lo script genera i modelli `models/*.obj` e le loro texture, poi renderizza ogni modello in un'icona d'inventario 32×32 in pixel art (`skyss_cleanup_<tipo>.png`). Così sprite e oggetti 3D coincidono. Genera anche cassonetti, marcatori e particelle. L'unico file disegnato a mano è l'icona del forcone.

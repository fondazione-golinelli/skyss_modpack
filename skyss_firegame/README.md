# Squadra antincendio

Minigioco cooperativo per `skyss_minigames`, sull'isola del fuoco del lobby (arena `fire_forest`, launcher nel padiglione del fuoco). Nel bosco scoppia un incendio: la squadra deve spegnere tutte le fiamme e portare in salvo gli animali in pericolo prima che il fuoco bruci troppo bosco. Non si possono rompere né piazzare blocchi: si lavora solo con gli strumenti del gioco, che sono quelli veri delle squadre antincendio boschivo.

## Come si gioca

All'avvio ogni giocatore riceve quattro strumenti (slot 1-4). Ognuno si usa con clic sinistro o destro; quando lo prendi in mano, sopra la hotbar compare cosa fa.

| Strumento | Portata | Effetto |
| --- | --- | --- |
| **Flabello** (battifuoco) | 4 blocchi | spegne la fiamma colpita; illimitato |
| **Pompa a spalla** | 12 blocchi | spegne le fiamme in un'area 3×3 e bagna il terreno (per 25 secondi non prende fuoco); 13 spruzzi, si riempie alle cisterne rosse o all'acqua del lago |
| **Rastro antincendio** | 5 blocchi | toglie l'erba su una fila di 3 blocchi di traverso: il sentiero che resta è una fascia tagliafuoco che il fuoco non supera |
| **Trasportino** | 4 blocchi | prende un animale in pericolo (uno alla volta); entrando nella zona sicura lo si libera |

**Il fuoco** parte da alcuni focolai lontani dalla piazzola d'arrivo e si propaga sull'erba e sul sottobosco (ogni 3 secondi ogni fiamma ha il 15% di probabilità di accenderne una vicina). Non attraversa sentieri, ghiaia, sabbia, acqua, le fasce tagliafuoco e il terreno appena bagnato. Una fiamma lasciata bruciare si spegne da sola dopo 45-70 secondi, ma lascia **terreno bruciato** e annerisce gli alberi vicini (tronchi carbonizzati, chioma che perde foglie). Ogni blocco bruciato conta nel contatore "Bosco bruciato".

**Gli animali** (conigli, lepri, volpi) sono intrappolati vicino ai focolai, con un punto esclamativo sopra la testa. Se le fiamme arrivano troppo vicino scappano di qualche blocco. Portati nella zona sicura restano lì al riparo.

**Vittoria**: nessuna fiamma accesa e tutti gli animali in salvo. Seguono fuochi d'artificio e la classifica a tempo (più veloce = meglio). **Sconfitta**: il bosco bruciato raggiunge il limite, oppure scade il tempo. In tutti i casi la chat riassume fiamme spente, animali salvati e bosco bruciato, e nomina i tre migliori pompieri.

**Trovare i fuochi**: sopra ogni zona che brucia sale una colonna di fumo scuro che supera le chiome e si vede da lontano, e sullo schermo ci sono sempre gli indicatori delle 4 zone in fiamme più vicine, con distanza e numero di fiamme ("Fuoco (12)"). Le fiamme sono raggruppate su una griglia di 10×10 blocchi.

Gli altri indicatori portano alla zona sicura quando si trasporta un animale, alla cisterna più vicina quando la pompa è vuota e agli ultimi animali da salvare (un quarto o meno, almeno 2).

L'HUD in alto a destra mostra il cronometro, i fuochi accesi, gli animali salvati, il bosco bruciato rispetto al limite (diventa rosso al 75%), l'acqua della pompa, l'animale trasportato, il record e il lavoro del singolo giocatore.

## La zona sicura: il centro recupero fauna

Tra la piazzola d'arrivo e il lago c'è il **centro recupero fauna**: una radura recintata in piano, con una rampa di terra tutto intorno, due ingressi (verso la piazzola e verso il lago), una tettoia con fieno, un abbeveratoio, due cisterne d'acqua, lanterne all'ingresso e un cartello. Il fuoco non entra mai nella zona sicura e nel suo bordo.

Le foglie rimaste senza tronco dopo la costruzione (alberi tagliati dalla radura) vengono rimosse.

Il centro fa parte dell'isola, non della partita. Lo costruisce la mod stessa all'avvio del server, nel punto indicato dal parametro `safe_zone` dell'arena, quando non trova il cartello. Così ricompare da solo anche dopo una rigenerazione della mappa con hubgen. hubgen lascia libera dagli alberi la radura (`FIRE_SAFE`, `FIRE_SAFE_R`).

## Bosco percorribile

Una sola volta per mappa, all'avvio del server, la mod pota sull'isola tutte le foglie a meno di 3 blocchi dal terreno (`CLEARANCE`), così sotto le chiome si passa sempre. Sulla mappa attuale sono circa 5000 blocchi di foglie. Il segno che è già stato fatto resta nel mod storage (`trim:<arena>`).

## Obiettivi e numero di giocatori

Focolai e animali crescono con il numero di giocatori, un po' meno che in proporzione (in tanti ci si intralcia). Con più focolai crescono anche il numero massimo di fiamme accese insieme e il limite di bosco bruciato.

| Giocatori | Focolai | Animali | Fiamme al massimo | Limite bosco bruciato |
| --- | --- | --- | --- | --- |
| 1 | 2 | 2 | 54 | 60 |
| 5 | 5 | 7 | 90 | 150 |
| 10 | 8 | 11 | 126 | 240 |
| 20 | 11 | 18 | 162 | 330 |
| 30 | 12 | 24 | 174 | 360 |

Formule: focolai = 2 × giocatori^0,55 (massimo 12), animali = 2 × giocatori^0,73 (massimo 24). Nella prova senza nessuno che spegne, con 4 giocatori, il bosco bruciato arriva al limite in circa 2 minuti e mezzo: la partita è persa se la squadra non interviene.

I valori si cambiano in cima a `init.lua` (`FRONTS_*`, `ANIMALS_*`, `SPREAD_CHANCE`, `BURN_TIME_*`, `PUMP_CAPACITY`, …). Il tempo limite è quello di `skyss_minigames` (3 minuti, modificabile dall'editor o dal docente).

## Parametri dell'arena

Nel campo `params` dell'arena in `arenas.json`:

- `safe_zone`: `{"pos": [x, y, z], "radius": 7}`, il centro della zona sicura (la `y` viene ricalcolata sul terreno). Senza, il gioco parte senza animali;
- `fronts`, `animals`: quantità fisse al posto di quelle automatiche.

L'area di gioco scende fino a y=-10, così si può nuotare fino al fondo del lago (a y=-7).

A ogni partita il gioco mette 12 cisterne lungo le 4 vie principali che si incrociano alla piazzola: 3 per via, a 16, 32 e 48 blocchi, sul bordo del sentiero e alternando i lati. Ognuna ha intorno un anello di terra battuta, così il fuoco non la nasconde. L'area viene salvata prima della partita e ripristinata dopo da `skyss_minigames`, quindi fiamme, terreno bruciato, tronchi carbonizzati e tagliafuoco spariscono alla fine.

## Carico sul server

- Le fiamme sono un nodo della mod, non il fuoco di Mineclonia: si propagano solo con le regole qui sopra, al massimo 174 alla volta.
- Fumo e scintille partono solo da 14 fiamme a caso ogni 3 secondi; il crepitio si sente solo vicino alle fiamme.
- Gli animali sono al massimo 24 entità.
- L'HUD invia ai client solo i valori cambiati.
- Durante la partita l'isola resta caricata in memoria, perché i focolai lontani dai giocatori continuino a bruciare.
- Le fiamme rimaste nella mappa dopo un crash si spengono da sole quando la loro zona viene caricata.

## Lingue

Tutti i testi seguono la lingua del client: italiano, spagnolo, francese, tedesco, polacco e ungherese, inglese per le altre. Le chiavi sono le stringhe inglesi passate a `S()` in `init.lua`; le traduzioni sono in `locale/skyss_firegame.<lingua>.tr`. Se aggiungi una stringa nel codice, aggiungila al template e a ogni file `.tr`.

## Asset

Tutte le texture (strumenti, icone dell'HUD, terreno bruciato, tronco carbonizzato, cisterna, cartello, particelle, icona del launcher) sono generate da `tools/gen_assets.py` (Python 3 + Pillow):

```bash
python3 tools/gen_assets.py
```

Le fiamme usano la texture animata del fuoco di Mineclonia, gli animali i modelli di `mobs_mc` (coniglio) e di `animalworld` (lepre, volpe) quando sono installati.

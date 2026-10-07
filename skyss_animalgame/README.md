# Versi degli animali

Minigioco `arena_lib` per un giocatore su Luanti/Mineclonia. Davanti al giocatore compare un palco con quattro podi colorati (rosso, blu, giallo, verde). Su ogni podio c'è un animale 3D con il suo nome. Si sente il verso di uno dei quattro: il giocatore deve cliccare l'animale giusto prima che scada il tempo.

## Come si gioca

- **Ascolta**: ogni turno inizia con un breve momento di ascolto. Il verso parte da solo e dalla campana al centro del palco escono delle note musicali.
- **Scegli**: clic destro o sinistro sull'animale (o sul suo podio). Si può rispondere anche durante l'ascolto.
- **Riascolta**: clicca la campana ("Riascolta") per sentire di nuovo il verso, quante volte vuoi.
- **Tempo**: all'inizio ci sono 10 secondi per rispondere. Ogni 2 punti si perde un secondo, fino a un minimo di 4. La barra nell'HUD passa da verde a giallo a rosso, e negli ultimi 3 secondi si sente un ticchettio.
- **Vite**: si parte con 3 cuori. Una risposta sbagliata o un tempo scaduto costano un cuore. L'animale giusto viene evidenziato in verde, saltella e fa di nuovo il suo verso, poi si passa al turno successivo.
- **Fine**: quando i cuori finiscono, la partita termina con il punteggio finale. Se è un nuovo record dell'arena partono i fuochi d'artificio.
- Gli animali escono da un mazzo mescolato: tutti compaiono prima di ripetersi, e mai due volte di fila.

L'HUD in alto a destra (lontano dalla chat) mostra il turno, il punteggio, i cuori, la serie di risposte giuste consecutive, la barra del tempo, il record dell'arena e la serie migliore.

## Preparazione dell'arena

1. Abilita `skyss_animalgame` insieme ad `arena_lib`. Per gli animali servono `mobs_mc` (Mineclonia) e/o `animalworld`.
2. Crea l'arena: `/arenas create skyss_animalgame <nome> 1 1`, poi `/arenas edit skyss_animalgame <nome>`.
3. Definisci la regione (`pos1`/`pos2`, obbligatoria perché la mappa viene ripristinata) e **un punto di spawn**. Guarda nella direzione in cui vuoi il palco quando salvi lo spawn.
4. Lascia libero lo spazio davanti allo spawn: il palco viene costruito a **5 blocchi** di distanza, largo 11 blocchi (podi a -5, -2, +2, +5 dal centro, campana al centro), all'altezza dei piedi del giocatore.
5. Salva la mappa e abilita l'arena.

La direzione dello spawn viene arrotondata all'asse più vicino. Il palco resta uguale per tutta la partita, cambiano solo gli animali. Alla fine i blocchi originali vengono ripristinati.

Se mancano gli animali (meno di 4 disponibili) o lo spawn, la partita termina subito con un messaggio in chat e un avviso nel log del server.

## Animali

- Con `mobs_mc`: maiale, mucca, pecora, gallina, cavallo, gatto, lupo.
- Con `animalworld`: orso, cinghiale, cammello, coccodrillo, elefante, volpe, rana, oca, iena, koala, marmotta, scimmia, alce, lontra, gufo, foca, aquila di mare di Steller, tapiro, tigre, yak, zebra.

Modello, texture e animazione vengono letti dalla registrazione del mob. Gli animali hanno la loro grandezza naturale. Quelli più alti di 1,3 blocchi (elefante, cammello, alce, zebra) vengono rimpiccioliti. Quelli più bassi di 0,45 blocchi (rana, lontra, marmotta) vengono ingranditi fino a 2 volte, per restare visibili e cliccabili. Se il modello non è disponibile si usa l'icona piatta dell'uovo spawner.

Le collisionbox di `animalworld` sono spesso molto più piccole del modello (il koala dichiara 0,2 blocchi ma è alto 0,74). Per questo ogni animale di `animalworld` ha nella tabella `ANIMALS` un campo `height` con l'altezza reale misurata sul modello `.b3d`. Il comando è `python3 tools/measure_models.py <modello.b3d>`, che dà il risultato in decimi di blocco. Per i mob di Mineclonia basta la collisionbox.

Per aggiungere un animale basta una riga nella tabella `ANIMALS` di `init.lua` (entità, suono, icona e, se serve, `height`) e il nome nei file di traduzione.

## Dettagli tecnici

- Lo stato della partita vive in una tabella interna per arena, non nei campi dell'arena salvati da `arena_lib`.
- Animali e campana sono entità non persistenti e legate al turno da un token: un clic su un animale di un turno precedente viene ignorato.
- I parametri di gioco (vite, tempi, distanza e larghezza del palco, scala degli animali) sono costanti in cima a `init.lua`.
- Il record per arena è salvato nel mod storage.
- Suoni e particelle usano gli asset di Mineclonia quando sono presenti. Con `mcl_bells` la campana usa il modello 3D di Mineclonia.

## Lingue

Tutti i testi visibili ai giocatori (HUD, chat, nomi degli animali, etichette) seguono la lingua del client Luanti di ciascun giocatore. Traduzioni incluse: italiano, spagnolo, tedesco, polacco e ungherese. Per le altre lingue si usa l'inglese.

Le chiavi sono le stringhe inglesi passate a `S()` in `init.lua`. Le traduzioni si modificano direttamente in `locale/skyss_animalgame.<lingua>.tr`. Per aggiungere una lingua, copia `locale/template.txt` in `skyss_animalgame.<codice>.tr` e compila le righe dopo `=`. Se aggiungi una stringa nel codice, aggiungila anche al template e a ogni file `.tr`.

## Asset

Le texture sono generate da `tools/gen_assets.py` (Python 3 + Pillow):

```bash
python3 tools/gen_assets.py
```

Lo script genera i podi (le fasce colorate sono maschere bianche, colorate dal mod per ogni podio), le particelle (scintille, note musicali, fumo), i cuori dell'HUD, la campana di riserva e l'icona del minigioco.

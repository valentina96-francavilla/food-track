# FoodTrack — prototipo B2B

Demo interattiva di un portale ordini per distribuzione alimentare, con tre viste di ruolo selezionabili: **Admin**, **Fornitore** e **Gastronomo**.

## Funzionalità prototipate
- **Gastronomo:** catalogo assegnato, ricerca per nome/codice, categorie, disponibilità, preferiti, carrello persistente nel browser, selezione data consegna, referente, note, riepilogo e invio ordine simulato, storico e riordino.
- **Fornitore:** gestione del proprio catalogo, attivazione/disattivazione prodotti, formato e quantità minima, etichetta, listini cliente e gestione dello stato degli ordini.
- **Admin:** panoramica, prodotti di tutti i fornitori, listini per gastronomo, gestione fornitori, gastronomi e collegamenti tra clienti e fornitori, ordini.
- **Ordini:** numero univoco demo, data/ora invio, data richiesta, referenza di consegna, formati e confezioni, totale, stato e timestamp della ricezione.
- Layout responsive desktop/mobile.

## Prova la demo
Apri [FoodTrack su GitHub Pages](https://valentina96-francavilla.github.io/food-track/) oppure visita il file [index.html](https://github.com/valentina96-francavilla/food-track/blob/main/index.html).

## Limiti importanti
Questo è un **prototipo frontend**, non un sistema pronto per ordini reali:
- Il selettore dei ruoli simula le schermate, ma non è autenticazione e non applica sicurezza reale.
- I dati sono esempi; le modifiche si salvano nel `localStorage` del browser, non su un database condiviso.
- Non vengono spedite email, inviti o reset password.
- Il caricamento immagini reale, la gestione completa di più formati per prodotto, le notifiche e la sincronizzazione multiutente devono essere completati.
- Il workflow commerciale e le regole di annullamento devono essere validati prima della produzione.

## Prossima fase tecnica
Collegare un backend reale (ad esempio Supabase/PostgreSQL) con autenticazione, autorizzazioni server-side per ruolo e relazione fornitore-cliente, storage immagini, listini cliente/formato, righe d'ordine con snapshot di prezzo, transizioni di stato validate, notifiche email e log delle modifiche. Non usare dati reali o credenziali reali nella demo.

# FoodTrack

Portale B2B per ordini alimentari: catalogo fornitori, listini, gastronomie, ordini e gestione per ruolo.

## Link
- Landing page dimostrativa: https://valentina96-francavilla.github.io/food-track/landing.html
- Portale: https://valentina96-francavilla.github.io/food-track/

## Architettura
- Frontend statico HTML/CSS/JavaScript pubblicato tramite GitHub Pages.
- Autenticazione Supabase Auth collegata al progetto FoodTrack (ID: itzdbziwfwnhqbnhlczy).
- Database PostgreSQL con organizzazioni, membership, relazioni gastronomia-fornitore, prodotti, listini personalizzati per gastronomia, ordini e righe d'ordine.
- RLS attiva sulle tabelle applicative.
- Storage immagini catalogo: bucket foodtrack-product-images. Immagini pubbliche in lettura; upload, modifica ed eliminazione riservati a fornitori autorizzati o amministratore. Il percorso deve iniziare con l'UUID dell'organizzazione fornitrice.
- Checkout tramite funzione PostgreSQL submit_foodtrack_order: valida il ruolo, i collegamenti commerciali, la disponibilità, le quantità minime e i prezzi del listino sul server; salva ordini e righe nel database e crea un ordine separato per ciascun fornitore in un'unica transazione.
- I pagamenti online non sono previsti: si svolgono esternamente tra le aziende.

## Dati dimostrativi inseriti
- 2 fornitori: Fornitore Nord e Fornitore Sud.
- 2 gastronomie: Gastronomia Milano e Gastronomia Bari.
- 12 prodotti in 4 categorie.
- 24 prezzi personalizzati (un prezzo per prodotto per ciascuna gastronomia).
- 4 relazioni gastronomia-fornitore attive.
I dati e i prezzi sono fittizi e servono per testare il flusso. Le organizzazioni demo non hanno account di accesso creati automaticamente.

## Stato e limiti
Il catalogo, i listini e la creazione degli ordini sono collegati al database. È stata verificata la sintassi JavaScript e la presenza dei dati nel database, ma non è ancora stato eseguito un test end-to-end da browser con account distinti. Non usare il portale per ordini commerciali reali finché non sono stati verificati login, checkout, lettura degli ordini da parte del fornitore e isolamento dei dati.

La gestione dei prodotti e dei listini da tutte le schermate amministrative/fornitore deve ancora essere collegata in modo completo alle scritture del database; alcune azioni della UI possono ancora essere locali. Le immagini sono predisposte nello storage, ma l'upload dal modulo prodotto non è ancora collegato.

## Prossime priorità
1. Testare checkout con account admin e account gastronomia reale.
2. Testare che il fornitore veda gli ordini ricevuti e che gli stati siano aggiornati nel database.
3. Collegare modifica/creazione prodotti e listini al database.
4. Collegare upload e visualizzazione immagini reali.
5. Collegare aggiornamenti stato ordine e notifiche.
6. Testare annullamenti, errori, quantità minime e isolamento tra aziende.
7. Valutare hosting adatto a un servizio commerciale prima del lancio nazionale; GitHub Pages è usato qui per la demo frontend.

## Migrazioni
- supabase/migrations/20261022000000_initial_schema.sql
- supabase/migrations/20261023_foodtrack_product_image_storage.sql
- supabase/migrations/20261026_foodtrack_seed_catalog_and_checkout.sql

Le migrazioni documentano il database; non sostituiscono test applicativi e verifiche di sicurezza.

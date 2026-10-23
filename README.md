# FoodTrack

Portale B2B per ordini alimentari: catalogo fornitori, listini, gastronomie, ordini e gestione per ruolo.

## Link
- Landing page dimostrativa: https://valentina96-francavilla.github.io/food-track/landing.html
- Portale: https://valentina96-francavilla.github.io/food-track/

## Architettura attuale
- Frontend statico HTML/CSS/JavaScript pubblicato tramite GitHub Pages.
- Autenticazione Supabase Auth collegata al progetto FoodTrack (ID: itzdbziwfwnhqbnhlczy).
- Database PostgreSQL con organizzazioni, membership, relazioni gastronomia-fornitore, prodotti, prezzi cliente-specifici, ordini e righe d'ordine.
- Row Level Security (RLS) attiva sulle tabelle applicative.
- Storage immagini catalogo: bucket foodtrack-product-images. Immagini pubbliche in lettura; upload, modifica ed eliminazione riservati a fornitori autorizzati o amministratore della piattaforma. Il percorso deve iniziare con l'UUID dell'organizzazione fornitrice, per esempio <supplier-organization-uuid>/filename.webp.

## Decisione sui pagamenti
FoodTrack gestisce la raccolta e lo stato degli ordini. Non gestisce pagamenti online: il pagamento viene concordato e svolto esternamente tra le aziende.

## Stato e limiti
L'autenticazione e il database sono collegati, ma questo non dimostra che tutte le schermate operative usino già dati reali. Catalogo, carrello, prezzi, ordini, preferiti e gestione delle aziende devono essere verificati uno per uno: nel frontend possono ancora esserci dati demo o salvataggi locali. Non usare il portale per ordini commerciali reali finché non è stato completato il test end-to-end con account distinti.

## Prossime priorità
1. Collegare catalogo e immagini reali al database/storage.
2. Implementare creazione ordini e righe d'ordine con validazione server-side di prezzi e totali.
3. Completare la gestione degli stati consentiti e le notifiche email.
4. Verificare permessi RLS con account admin, fornitore e gastronomia separati.
5. Aggiungere ricerca, filtri, gestione disponibilità e UX responsive.
6. Testare errori, duplicati, annullamenti, date di consegna e isolamento tra aziende.
7. Scegliere hosting adatto a un servizio commerciale prima di un lancio nazionale. GitHub Pages è usato qui per la demo frontend, non va considerato automaticamente un hosting SaaS di produzione.

## Migrazioni
- supabase/migrations/20261022000000_initial_schema.sql
- supabase/migrations/20261023_foodtrack_product_image_storage.sql

Le migrazioni descrivono modifiche allo schema; la loro presenza nel repository non sostituisce test di sicurezza e collaudo applicativo.

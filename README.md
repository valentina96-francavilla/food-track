# FoodTrack

Piattaforma B2B per la gestione di cataloghi alimentari, listini per punto vendita, ordini e consegne ricorrenti.

## Accesso
- Portale: https://foodtrack.valeyastudio.it
- Landing page: https://foodtrack.valeyastudio.it/landing.html

## Architettura
- Frontend HTML/CSS/JavaScript pubblicato tramite GitHub Pages.
- Autenticazione tramite Supabase Auth.
- Database PostgreSQL con organizzazioni, membership, relazioni Negozio-Fornitore, prodotti, listini, ordini e ricorrenze.
- Row Level Security sulle tabelle applicative.
- Storage immagini catalogo tramite bucket `foodtrack-product-images`.
- Checkout validato lato database tramite `submit_foodtrack_order`, con verifica di appartenenza, collegamenti commerciali, disponibilità, quantità minime e prezzi.
- Generazione ordini ricorrenti tramite funzione PostgreSQL pianificata con `pg_cron`.
- I pagamenti non vengono elaborati da FoodTrack: restano esterni tra le aziende.

## Stato tecnico e limiti noti
Il portale e il database sono collegati. Il repository contiene il codice applicativo e le migrazioni; il database attivo contiene record inseriti durante la configurazione iniziale. Prima dell'onboarding commerciale occorre verificare e confermare anagrafiche, prodotti, listini e associazioni, senza assumere che ogni record esistente sia già un dato commerciale validato.

Le seguenti attività restano necessarie prima di aprire il servizio a un utilizzo commerciale generalizzato:
1. Il carrello è salvato nel browser e non è ancora sincronizzato tra dispositivi o sessioni.
2. Completare e verificare la persistenza di tutte le modifiche alle anagrafiche e ai collegamenti Negozio-Fornitore.
3. Eseguire test end-to-end con account distinti per Amministratore, Negozio e Fornitore, inclusi test di isolamento tra organizzazioni.
4. Verificare l'intero ciclo degli ordini ricorrenti con account e dati di collaudo dedicati.
5. Verificare upload, modifica e visualizzazione delle immagini nel flusso completo.
6. Configurare e collaudare notifiche operative e gestione degli errori.
7. Completare le impostazioni di sicurezza di Supabase Auth e verificare backup, recupero e monitoraggio.
8. Definire condizioni di servizio, privacy, conservazione dati, assistenza e responsabilità operative prima dell'apertura nazionale.

## Deploy
Il deploy del frontend avviene automaticamente su GitHub Pages a ogni push sul branch `main`. La pipeline esegue un controllo di sintassi JavaScript e controlli minimi sui marcatori applicativi prima della pubblicazione.

## Migrazioni
Le migrazioni SQL sono conservate in `supabase/migrations`. Le modifiche eseguite direttamente sul progetto Supabase devono essere riportate anche in una migrazione versionata, così che il codice e lo schema possano essere ricostruiti in modo coerente.

## Regole di sicurezza
- Non inserire mai chiavi Supabase `service_role` o segreti nel frontend.
- I ruoli sono assegnati tramite membership gestite dall'amministrazione.
- Non consentire agli utenti di autoassegnarsi ruoli privilegiati.
- Le funzioni `SECURITY DEFINER` devono avere privilegi minimi e controlli di autorizzazione espliciti.

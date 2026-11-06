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
Fornitori, negozi, prodotti, listini, associazioni commerciali e ordini presenti nel database sono considerati dati ufficiali da parte della titolare. Non devono essere cancellati, rinominati o sostituiti come se fossero record di prova.

Il carrello è persistito su PostgreSQL tramite `shopping_carts` e `shopping_cart_items`, con RLS per account e organizzazione, validazione server-side di prodotti, collegamenti e prezzi e sincronizzazione Realtime tra sessioni dello stesso account. Le modifiche ai fornitori e ai collegamenti negozio-fornitore vengono salvate su Supabase. L'amministratore può invitare un account a un'organizzazione fornitore già esistente senza creare un duplicato.

Verifiche e attività ancora aperte prima dell'apertura commerciale generalizzata:
1. Completare i test operativi dall'interfaccia browser con account distinti per Amministratore, Negozio e Fornitore. I test SQL transazionali di isolamento e salvataggio carrello sono stati eseguiti e annullati con rollback.
2. Associare le utenze reali a Fiorucci e Venditti tramite inviti ai rispettivi indirizzi email. Le organizzazioni esistenti non sono state modificate; le utenze attuali di altri fornitori non sono state riassegnate.
3. Verificare l'intero ciclo degli ordini ricorrenti con una ricorrenza reale autorizzata; il cron è attivo, ma non ci sono ricorrenze registrate da collaudare.
4. Verificare upload, modifica e visualizzazione delle immagini nel flusso completo.
5. Configurare e collaudare notifiche operative e gestione degli errori. Il server SMTP di Auth è stato configurato dalla titolare, ma la consegna non è stata verificata in questa sessione.
6. Completare le impostazioni di sicurezza di Supabase Auth, verificare backup, recupero e monitoraggio.
7. Definire condizioni di servizio, privacy, conservazione dati, assistenza e responsabilità operative prima dell'apertura nazionale.

## Deploy
Il deploy del frontend avviene automaticamente su GitHub Pages a ogni push sul branch `main`. La pipeline esegue un controllo di sintassi JavaScript e controlli minimi sui marcatori applicativi prima della pubblicazione.

## Migrazioni
Le migrazioni SQL sono conservate in `supabase/migrations`. Le modifiche eseguite direttamente sul progetto Supabase devono essere riportate anche in una migrazione versionata, così che il codice e lo schema possano essere ricostruiti in modo coerente.

## Regole di sicurezza
- Non inserire mai chiavi Supabase `service_role` o segreti nel frontend.
- I ruoli sono assegnati tramite membership gestite dall'amministrazione.
- Non consentire agli utenti di autoassegnarsi ruoli privilegiati.
- Le funzioni `SECURITY DEFINER` devono avere privilegi minimi e controlli di autorizzazione espliciti.

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
- Generazione ordini ricorrenti e promemoria consegne tramite funzioni PostgreSQL pianificate con `pg_cron`.
- Notifiche interne persistenti e in tempo reale: nuovo ordine al fornitore interessato e all'admin, ordine accettato al negozio, promemoria il giorno precedente alla consegna al fornitore e all'admin.
- Stato `organizations.active` applicato a livello RLS: la disattivazione blocca l'accesso ai dati e alle operazioni per tutti gli account associati; la riattivazione ripristina l'accesso.
- I pagamenti non vengono elaborati da FoodTrack: restano esterni tra le aziende.

## Stato tecnico e limiti noti
Fornitori, negozi, prodotti, listini, associazioni commerciali e ordini presenti nel database sono considerati dati ufficiali da parte della titolare. Non devono essere cancellati, rinominati o sostituiti come se fossero record di prova.

Il carrello è persistito su PostgreSQL tramite `shopping_carts` e `shopping_cart_items`, con RLS per account e organizzazione, validazione server-side di prodotti, collegamenti e prezzi e sincronizzazione Realtime tra sessioni dello stesso account. Le modifiche ai fornitori e ai collegamenti negozio-fornitore vengono salvate su Supabase. L'amministratore può invitare un account a un'organizzazione fornitore già esistente senza creare un duplicato.

Verifiche e attività ancora aperte prima dell'apertura commerciale generalizzata:
1. Completare i test operativi dall'interfaccia browser con account distinti per Amministratore, Negozio e Fornitore. I test SQL transazionali di isolamento e salvataggio carrello sono stati eseguiti e annullati con rollback.
2. Associare le utenze reali a Fiorucci e Venditti tramite inviti ai rispettivi indirizzi email. Le organizzazioni esistenti non sono state modificate; le utenze attuali di altri fornitori non sono state riassegnate.
3. Verificare l'intero ciclo degli ordini ricorrenti con una ricorrenza reale autorizzata; il cron è attivo, ma non ci sono ricorrenze registrate da collaudare.
4. Verificare upload, modifica e visualizzazione delle immagini nel flusso completo.
5. Collaudare le notifiche dall'interfaccia con account distinti per Negozio, Fornitore e Admin; le notifiche interne e i trigger sono stati verificati con transazioni di prova annullate. Le email e le notifiche push non fanno parte del sistema attuale.
6. Completare le impostazioni di sicurezza di Supabase Auth, verificare backup, recupero e monitoraggio.
7. Definire condizioni di servizio, privacy, conservazione dati, assistenza e responsabilità operative prima dell'apertura nazionale.

## Deploy
Il deploy del frontend avviene automaticamente su GitHub Pages a ogni push sul branch `main`. La pipeline esegue un controllo di sintassi JavaScript e controlli minimi sui marcatori applicativi prima della pubblicazione.

## Migrazioni
Le migrazioni SQL sono conservate in `supabase/migrations`. Le nuove modifiche sono versionate anche nel progetto Supabase. La cronologia storica remota non è ancora interamente allineata ai file del repository: il dettaglio e i vincoli di ripristino sono documentati in `supabase/MIGRATION_AUDIT.md`. Non eseguire reset o ricostruzioni distruttive sul database attivo.

## Regole di sicurezza
- Non inserire mai chiavi Supabase `service_role` o segreti nel frontend.
- I ruoli sono assegnati tramite membership gestite dall'amministrazione.
- Non consentire agli utenti di autoassegnarsi ruoli privilegiati.
- Le funzioni `SECURITY DEFINER` devono avere privilegi minimi e controlli di autorizzazione espliciti.

# FoodTrack

Portale B2B per ordini alimentari: catalogo fornitori, listini riservati, gastronomi, ordini e gestione per ruolo.

## Stato attuale

**Demo frontend pubblicata:** https://valentina96-francavilla.github.io/food-track/

Il sito attuale è un prototipo HTML/CSS/JavaScript. Le schermate e le interazioni sono demo; il selettore di ruolo non è autenticazione. I dati attuali sono esempi e vengono salvati nel browser con `localStorage`: non sono condivisi tra utenti e non devono essere usati per gestire ordini commerciali reali.

## Obiettivo della prossima versione

- Autenticazione reale e ruoli assegnati lato server.
- Organizzazioni separate per gastronomi e fornitori.
- Catalogo e prezzi cliente-specifici.
- Ordini condivisi, con snapshot di prodotto e prezzo.
- Autorizzazioni a livello database tramite PostgreSQL Row Level Security (RLS).
- Dati reali solo dopo aver collegato un progetto backend dedicato e aver verificato le regole di accesso.

## Backend preparato

La prima bozza dello schema è in `supabase/migrations/20261022000000_initial_schema.sql`. Definisce organizzazioni, membership, collegamenti cliente-fornitore, prodotti, prezzi, ordini, righe d'ordine e preferiti con policy RLS iniziali.

**Questa migrazione non è stata applicata a un database.** Non esiste ancora un progetto Supabase dedicato a FoodTrack collegato al frontend. Il progetto Supabase già presente nell'account si chiama Lookera e non va riutilizzato: separare i dati evita di mescolare due prodotti.

Prima di usare dati reali sono ancora necessari: revisione e test delle policy, flusso sicuro di invito/membership, validazione server-side di prezzi e totali, transizioni di stato consentite, e collegamento del frontend all'API. La bozza SQL è una base di lavoro, non una certificazione di sicurezza.

## Vincolo economico

La demo statica su GitHub Pages non richiede una prova a scadenza. Un backend multiutente gratuito, però, ha quote e possibili pause per inattività: **zero costi non significa servizio garantito senza limiti o sempre attivo**. Non attivare piani a pagamento, fatturazione automatica o upgrade per far funzionare FoodTrack. Prima di creare il backend va verificato che il progetto sia a costo zero; non utilizzare un servizio che richieda carta, prova temporanea o upgrade automatico.

## Pubblicazione

Il workflow `.github/workflows/pages.yml` pubblica il contenuto del repository su GitHub Pages a ogni push su `main`.

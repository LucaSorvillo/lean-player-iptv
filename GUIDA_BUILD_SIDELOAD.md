# Guida: build iOS in cloud + installazione su iPhone (da Windows)

Questa guida serve a **compilare l'app per iOS senza un Mac** (build su GitHub Actions) e a
**installarla sul tuo iPhone** tramite sideload (AltStore/SideStore). Niente costi.

## Prerequisiti
- Un **account GitHub** (gratuito).
- Un **Apple ID** — consigliato uno **secondario/usa-e-getta** (il sideload usa un certificato di sviluppo).
- iPhone + PC Windows sulla stessa rete Wi-Fi.

## Passo 1 — Metti il codice su GitHub
1. Su github.com crea un repository **privato** (es. `scptv_app`), senza inizializzarlo con README.
2. Dal PC, nella cartella del progetto `scptv_app`, collega e pubblica (sostituisci TUO-UTENTE):
   ```
   git remote add origin https://github.com/TUO-UTENTE/scptv_app.git
   git push -u origin main
   ```
   (Per l'autenticazione: usa un **Personal Access Token** GitHub come password, oppure GitHub Desktop.)

## Passo 2 — Compila e scarica l'IPA
1. Su GitHub, scheda **Actions** → il workflow **"iOS build (unsigned IPA)"** parte da solo al push
   (o avvialo a mano con **Run workflow**).
2. Attendi ~10–15 minuti. A build finita, apri il run e scarica l'**Artifact**
   `scptv-ios-unsigned-ipa` (è uno zip che contiene `app-unsigned.ipa`). Estrai l'`.ipa`.

## Passo 3 — Installa sull'iPhone (sideload)
**Opzione A — AltStore (consigliata per iniziare):**
1. Su Windows installa **AltServer** (altstore.io). Installa iTunes + iCloud (versioni Apple, non da Microsoft Store) se richiesto.
2. Collega l'iPhone via USB. Icona AltServer → **Install AltStore** → inserisci l'Apple ID secondario.
3. Sull'iPhone: Impostazioni → Generale → **VPN e gestione dispositivo** → fidati dell'Apple ID.
4. Apri **AltStore** sull'iPhone → tab **My Apps** → **+** → seleziona `app-unsigned.ipa`.

**Opzione B — SideStore:** alternativa che **rinnova l'app da sola** via VPN locale (più comoda a lungo termine).

## Passo 4 — Prova del nove
Apri l'app **SCPTV POC** sull'iPhone: deve partire **Rai 1**.
- ✅ Se il video parte → il de-risking è superato: l'User-Agent `SCPTVPlayer` funziona su iOS e
  possiamo costruire l'app completa.
- ❌ Se non parte → segnalamelo: aggiusto le opzioni del player (es. formato dell'opzione User-Agent).

## Note importanti
- **Apple ID gratuito:** l'app va **riaperta/rinnovata ogni 7 giorni** (AltStore lo fa quando iPhone e PC
  sono sulla stessa rete; SideStore lo automatizza) e si possono avere **max 3 app** sideloadate.
- Ad ogni modifica del codice: nuovo `git push` → nuova build → ri-sideload dell'IPA aggiornato.

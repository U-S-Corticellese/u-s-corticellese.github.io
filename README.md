# Sito della Corticellese

Sito statico con **prossima partita, risultati, calendario e classifica** della Corticellese
(CSI Brescia · Calcio a 7 Open maschile · Serie A · Girone A).

I dati arrivano dal portale ufficiale del CSI Brescia:
https://risultati.csi.brescia.it/albo/risultati-calendario-classifiche-squadre.html

## Come è fatto

| File | A cosa serve |
|---|---|
| `index.html`, `style.css`, `app.js` | Il sito |
| `aggiorna.rb` | Scarica i dati dal CSI e scrive `dati.js` |
| `dati.js` | I dati (generato in automatico, non modificarlo a mano) |
| `.github/workflows/aggiorna.yml` | Su GitHub aggiorna i dati ogni 3 ore e pubblica il sito |

## Vederlo sul computer

Apri `index.html` con un doppio clic.

Per aggiornare i dati a mano, da Terminale nella cartella del sito:

```bash
ruby aggiorna.rb
```

## Pubblicarlo gratis con aggiornamento automatico (GitHub Pages)

1. Crea un account su https://github.com e un nuovo repository (es. `corticellese`).
2. Carica tutti i file di questa cartella, compresa la cartella nascosta `.github`.
3. Nel repository vai su **Settings → Pages** e in **Source** scegli **GitHub Actions**.
4. Vai su **Actions → Aggiorna dati e pubblica sito → Run workflow**.

Dopo un paio di minuti il sito è online su `https://<tuo-utente>.github.io/corticellese/`
e si aggiorna da solo ogni 3 ore.

## A inizio stagione

Se il CSI cambia campionato o girone, modifica il blocco `CONFIG` in cima a
`aggiorna.rb` (`campionato`, `girone`, `descrizione`). I codici si vedono sul
portale CSI selezionando Sport → Società → Campionato.

## Personalizzare

- **Colori:** blu profondo `#001331` e bordeaux `#580003`, presi dalla grafica sociale.
  Sono in cima a `style.css` (`--blu`, `--bordeaux`).
- **Immagini** (tutte nella cartella principale):
  - `stemma.png`: il castello ritagliato dalla grafica blu/bordeaux (testata, piè di pagina, icona)
  - `stemma-storico.jpg`: lo stemma in bianco e nero usato in "Chi siamo"
  - `fulmine.jpg`: la grafica originale, tenuta come riferimento
- **Storia (Chi siamo):** in `index.html` cerca `linea-tempo` e aggiungi altre tappe copiando un `<li>`.
- **Sponsor:** in `index.html` cerca `class="sponsor"`. Per aggiungerne uno copia un `<li>` e metti il logo
  nella cartella principale. Se il logo è bianco, aggiungi `class="scuro"` al `<li>` per avere lo sfondo blu (come Tapporaso).
- **Instagram:** https://www.instagram.com/u.s.corticellese/ (menu, fascia "Seguici" e Chi siamo).
- **Email "Diventa sponsor":** è `piede14@yahoo.it`; per cambiarla cerca `mailto:` in `index.html`.
- **Caratteri:** Oswald, Barlow e Cormorant Garamond da Google Fonts.

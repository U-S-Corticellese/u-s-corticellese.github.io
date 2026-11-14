(function () {
  "use strict";

  var $ = function (id) { return document.getElementById(id); };

  // Anni di storia (dal 1968)
  var anni = $("anni-storia");
  if (anni) anni.textContent = new Date().getFullYear() - 1968;

  // ---------- Foto: album da foto.js, foto a schermo intero ----------
  (function () {
    var album = window.ALBUM || [];
    var sez = $("foto");
    if (!sez) return;
    var voce = document.querySelector(".voce-foto");
    if (!album.length) { if (voce) voce.hidden = true; return; }
    sez.hidden = false;

    var esc = function (s) {
      return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
        return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
      });
    };
    var mini = function (f) { return f.replace(/(\.[a-z]+)$/i, "-mini$1"); };
    var PRIME = 12; // foto mostrate prima di "Mostra tutte"

    $("album").innerHTML = album.map(function (a, ia) {
      return '<article class="album">' +
        '<header class="album-testa"><div><h3>' + esc(a.titolo) + "</h3>" +
        '<p>' + esc([a.data, a.descrizione].filter(Boolean).join(" · ")) + "</p></div>" +
        '<span class="album-conta">' + a.foto.length + " foto</span></header>" +
        '<ul class="griglia-foto">' + a.foto.map(function (f, i) {
          return '<li' + (i >= PRIME ? " hidden" : "") + '><button type="button" data-album="' + ia + '" data-foto="' + i + '" aria-label="Apri foto ' + (i + 1) + '">' +
            '<img src="' + esc(mini(f)) + '" alt="' + esc(a.titolo + ", foto " + (i + 1)) + '" loading="lazy"></button></li>';
        }).join("") + "</ul>" +
        (a.foto.length > PRIME ? '<button type="button" class="bottone mostra-tutte">Mostra tutte le ' + a.foto.length + " foto</button>" : "") +
        "</article>";
    }).join("");
    $("album").addEventListener("click", function (e) {
      var b = e.target.closest(".mostra-tutte");
      if (!b) return;
      b.closest(".album").querySelectorAll(".griglia-foto li[hidden]").forEach(function (li) { li.hidden = false; });
      b.remove();
    });

    var dlg = $("galleria"), img = $("galleria-img"), cap = $("galleria-didascalia");
    var ca = 0, cf = 0;
    function mostra() {
      var a = album[ca];
      img.src = a.foto[cf];
      img.alt = a.titolo + ", foto " + (cf + 1);
      cap.textContent = a.titolo + " · " + (cf + 1) + " di " + a.foto.length;
    }
    function sposta(d) { var n = album[ca].foto.length; cf = (cf + d + n) % n; mostra(); }
    function apri(a, f) {
      ca = a; cf = f; mostra();
      if (dlg.showModal) dlg.showModal(); else dlg.setAttribute("open", "");
    }
    function chiudi() { if (dlg.close) dlg.close(); else dlg.removeAttribute("open"); }

    $("album").addEventListener("click", function (e) {
      var b = e.target.closest("button[data-album]");
      if (b) apri(+b.getAttribute("data-album"), +b.getAttribute("data-foto"));
    });
    dlg.querySelector(".galleria-chiudi").addEventListener("click", chiudi);
    dlg.querySelector(".prec").addEventListener("click", function () { sposta(-1); });
    dlg.querySelector(".succ").addEventListener("click", function () { sposta(1); });
    dlg.addEventListener("click", function (e) { if (e.target === dlg) chiudi(); });
    document.addEventListener("keydown", function (e) {
      if (!dlg.open) return;
      if (e.key === "ArrowLeft") sposta(-1);
      if (e.key === "ArrowRight") sposta(1);
    });
    // scorrimento con il dito sul telefono
    var x0 = null;
    dlg.addEventListener("touchstart", function (e) { x0 = e.touches[0].clientX; }, { passive: true });
    dlg.addEventListener("touchend", function (e) {
      if (x0 === null) return;
      var dx = e.changedTouches[0].clientX - x0;
      if (Math.abs(dx) > 50) sposta(dx < 0 ? 1 : -1);
      x0 = null;
    });
  })();

  // ---------- Menu in alto ----------
  (function () {
    var nav = document.querySelector(".menu-alto");
    var bottone = document.querySelector(".menu-apri");
    if (!nav || !bottone) return;
    function chiudi() { nav.classList.remove("aperto"); bottone.setAttribute("aria-expanded", "false"); }
    bottone.addEventListener("click", function () {
      var aperto = nav.classList.toggle("aperto");
      bottone.setAttribute("aria-expanded", aperto ? "true" : "false");
    });
    nav.querySelectorAll(".menu-voci a").forEach(function (a) { a.addEventListener("click", chiudi); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape") chiudi(); });
    document.addEventListener("click", function (e) { if (!nav.contains(e.target)) chiudi(); });

    // Evidenzia la voce della sezione che si sta guardando
    var voci = {};
    nav.querySelectorAll('.menu-voci a[href^="#"]').forEach(function (a) { voci[a.getAttribute("href").slice(1)] = a; });
    if (!("IntersectionObserver" in window)) return;
    var osserva = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        Object.keys(voci).forEach(function (k) { voci[k].classList.toggle("attiva", k === en.target.id); });
      });
    }, { rootMargin: "-45% 0px -50% 0px" });
    Object.keys(voci).forEach(function (id) { var el = document.getElementById(id); if (el) osserva.observe(el); });
  })();

  var D = window.DATI;
  if (!D) {
    $("prossima-partita").innerHTML = '<div class="corpo"><p class="vuoto">Dati non disponibili.</p></div>';
    return;
  }

  var NOI = D.squadra;

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }

  // "ASD SAN PAOLO" -> "ASD San Paolo" (le sigle restano maiuscole)
  function nome(n) {
    return String(n).toLowerCase().replace(/(^|[\s.'(-])([a-zàèéìòù])/g, function (m, a, b) {
      return a + b.toUpperCase();
    }).replace(/\b(Asd|Us|Sg|Csi|Rgs|Or|Bs)\b/g, function (m) { return m.toUpperCase(); });
  }

  function dataDi(p) {
    var d = (p.data || "").split("/");
    if (d.length !== 3) return null;
    var h = (p.ora || "00:00").split(":");
    return new Date(+d[2], +d[1] - 1, +d[0], +h[0] || 0, +h[1] || 0);
  }

  var fmtGiorno = new Intl.DateTimeFormat("it-IT", { weekday: "short", day: "numeric", month: "short" });
  var fmtLungo = new Intl.DateTimeFormat("it-IT", { weekday: "long", day: "numeric", month: "long" });

  function etichettaGiornata(p) {
    return p.giornata + "ª giornata" + (p.fase ? " di " + p.fase.toLowerCase() : "");
  }
  function giocata(p) { return p.gol_casa != null && p.gol_ospite != null; }
  function nostra(p) { return p.casa === NOI || p.ospite === NOI; }
  function esito(p) {
    if (!giocata(p) || !nostra(p)) return null;
    var noi = p.casa === NOI ? p.gol_casa : p.gol_ospite;
    var loro = p.casa === NOI ? p.gol_ospite : p.gol_casa;
    return noi > loro ? "V" : noi < loro ? "P" : "N";
  }
  var parolaEsito = { V: "Vittoria", N: "Pareggio", P: "Sconfitta" };

  D.partite.forEach(function (p) { p._data = dataDi(p); });
  var mie = D.partite.filter(nostra).sort(function (a, b) { return (a._data || 0) - (b._data || 0); });
  // Una partita senza risultato è "in attesa" se è iniziata da più di 2 ore
  var ORA = Date.now();
  function inAttesa(p) { return !giocata(p) && p._data && p._data.getTime() + 2 * 3600e3 < ORA; }
  var giocate = mie.filter(giocata);
  var passate = mie.filter(function (p) { return giocata(p) || inAttesa(p); });
  var daGiocare = mie.filter(function (p) { return !giocata(p) && !inAttesa(p); });

  $("campionato").textContent = D.campionato;
  if (D.fonte) $("fonte").href = D.fonte;
  $("aggiornato").textContent = "Dati aggiornati al " +
    new Date(D.aggiornato).toLocaleString("it-IT", { dateStyle: "long", timeStyle: "short" }) + ".";

  // ---------- Prossima partita ----------
  (function () {
    var box = $("prossima-partita");
    var p = daGiocare[0];
    if (!p) {
      box.innerHTML = '<div class="testa"><span>Prossima partita</span></div><div class="corpo"><p class="vuoto">Nessuna partita in programma.</p></div>';
      return;
    }
    var inCasa = p.casa === NOI;
    var giorni = p._data ? Math.round((new Date(p._data).setHours(0, 0, 0, 0) - new Date().setHours(0, 0, 0, 0)) / 864e5) : null;
    var conto = giorni === 0 ? "Oggi" : giorni === 1 ? "Domani" : giorni > 1 ? "Tra " + giorni + " giorni" : "";
    var riga = function (n, ruolo) {
      return '<div><span class="' + (n === NOI ? "noi" : "") + '">' + esc(nome(n)) + "</span><small>" + ruolo + "</small></div>";
    };
    box.innerHTML =
      '<div class="testa"><span>Prossima partita</span><span>' + esc(etichettaGiornata(p)) + "</span></div>" +
      '<div class="corpo">' +
        '<p class="quando">' + (p._data ? esc(fmtLungo.format(p._data)) + ' <span class="ora">· ' + esc(p.ora) + "</span>" : "Data da definire") + "</p>" +
        '<div class="sfida">' + riga(p.casa, "CASA") + riga(p.ospite, "OSPITE") + "</div>" +
        '<p class="campo">' + (inCasa ? "<strong>In casa</strong>" : "<strong>In trasferta</strong>") +
          (p.campo ? " · " + esc(nome(p.campo)) : "") +
          (p.spostata ? ' · <span class="etichetta spostata">data variata</span>' : "") + "</p>" +
      "</div>" +
      (conto ? '<span class="conto">' + conto + "</span>" : "");
  })();

  // ---------- Numeri ----------
  (function () {
    var r = null;
    D.classifica.forEach(function (x) { if (x.squadra === NOI) r = x; });
    var celle = [];
    if (r) {
      celle.push('<div><div class="valore">' + r.posizione + '<sup>°</sup></div><div class="didascalia">posto su ' + D.classifica.length + "</div></div>");
      celle.push('<div><div class="valore">' + r.punti + '</div><div class="didascalia">punti</div></div>');
      celle.push('<div><div class="valore">' + r.vinte + "·" + r.pareggiate + "·" + r.perse + '</div><div class="didascalia">vinte · pari · perse</div></div>');
      celle.push('<div><div class="valore">' + r.gol_fatti + ":" + r.gol_subiti + '</div><div class="didascalia">gol fatti : subiti</div></div>');
    }
    var forma = giocate.slice(-5).map(function (p) {
      var e = esito(p);
      return '<span class="esito ' + e + '" title="' + esc(nome(p.casa) + " " + p.gol_casa + "-" + p.gol_ospite + " " + nome(p.ospite)) + '">' + e + "</span>";
    }).join("");
    if (forma) celle.push('<div><div class="didascalia">ultime partite</div><div class="forma">' + forma + "</div></div>");
    $("numeri").innerHTML = celle.join("");
  })();

  // ---------- Riga partita ----------
  function rigaPartita(p, opz) {
    opz = opz || {};
    var g = giocata(p);
    var e = esito(p);
    var extra = [];
    if (!opz.girone) extra.push(esc(etichettaGiornata(p)));
    if (!g && !inAttesa(p) && p.campo && !opz.girone) extra.push(esc(nome(p.campo)));
    var attesa = inAttesa(p);
    if (attesa) extra.push('<span class="etichetta attesa">risultato in attesa</span>');
    if (p.ufficioso) extra.push('<span class="etichetta ufficioso">ufficioso</span>');
    if (p.spostata) extra.push('<span class="etichetta spostata">data variata</span>');
    var sq = function (n, gol) {
      return '<div class="riga-squadra"><span class="nome' + (n === NOI ? " noi" : "") + '">' + esc(nome(n)) +
        '</span><span class="gol">' + (g ? gol : "") + "</span></div>";
    };
    var data = opz.girone ? "" :
      '<div class="data">' + (p._data ? esc(fmtGiorno.format(p._data)) : "—") + "<small>" + esc(p.ora) + "</small></div>";
    var badge = opz.girone ? "" : (e ? '<span class="esito ' + e + '" title="' + parolaEsito[e] + '">' + e + "</span>" : "<span></span>");
    return '<li class="partita' + (g || attesa ? " giocata" : "") + '" data-giocata="' + (g || attesa ? 1 : 0) + '">' + data +
      '<div class="squadre">' + sq(p.casa, p.gol_casa) + sq(p.ospite, p.gol_ospite) + "</div>" + badge +
      (extra.length ? '<div class="extra">' + extra.join("<span>·</span>") + "</div>" : "") + "</li>";
  }

  $("ultimi").innerHTML = passate.length
    ? passate.slice(-5).reverse().map(function (p) { return rigaPartita(p); }).join("")
    : '<li class="vuoto">Ancora nessuna partita giocata.</li>';

  // ---------- Calendario ----------
  $("lista-calendario").innerHTML = mie.map(function (p) { return rigaPartita(p); }).join("");
  document.querySelectorAll(".filtri button").forEach(function (b) {
    b.addEventListener("click", function () {
      document.querySelectorAll(".filtri button").forEach(function (x) { x.classList.toggle("attivo", x === b); });
      var f = b.getAttribute("data-filtro");
      document.querySelectorAll("#lista-calendario .partita").forEach(function (li) {
        var gi = li.getAttribute("data-giocata") === "1";
        li.classList.toggle("nascosta", (f === "giocate" && !gi) || (f === "dagiocare" && gi));
      });
    });
  });

  // ---------- Classifica ----------
  $("righe-classifica").innerHTML = D.classifica.map(function (r) {
    var dr = r.gol_fatti - r.gol_subiti;
    return '<tr class="' + (r.squadra === NOI ? "noi" : "") + '">' +
      '<td class="pos">' + r.posizione + '</td><td class="sx">' + esc(nome(r.squadra)) + "</td>" +
      '<td class="punti">' + r.punti + "</td><td>" + r.giocate + "</td><td>" + r.vinte + "</td><td>" +
      r.pareggiate + "</td><td>" + r.perse + '</td><td class="opz">' + r.gol_fatti + '</td><td class="opz">' +
      r.gol_subiti + "</td><td>" + (dr > 0 ? "+" : "") + dr + "</td></tr>";
  }).join("");
  var pen = D.classifica.filter(function (r) { return r.penalita; });
  $("nota-classifica").textContent =
    (D.classifica.some(function (r) { return r.ufficiosa; }) ? "La classifica comprende risultati ufficiosi. " : "") +
    (pen.length ? "Penalità: " + pen.map(function (r) { return nome(r.squadra) + " " + r.penalita; }).join(", ") + "." : "");

  // ---------- Risultati del girone ----------
  (function () {
    var per = {};
    D.partite.forEach(function (p) { (per[p.turno] = per[p.turno] || []).push(p); });
    var turni = Object.keys(per).map(Number).sort(function (a, b) { return a - b; });
    var ultimo = turni[0];
    turni.forEach(function (n) { if (per[n].some(function (p) { return giocata(p) || inAttesa(p); })) ultimo = n; });
    var sel = $("scegli-giornata");
    sel.innerHTML = turni.map(function (n) {
      return '<option value="' + n + '"' + (n === ultimo ? " selected" : "") + ">" + esc(etichettaGiornata(per[n][0])) + "</option>";
    }).join("");
    function mostra() {
      $("lista-giornata").innerHTML = per[+sel.value].map(function (p) { return rigaPartita(p, { girone: true }); }).join("");
    }
    sel.addEventListener("change", mostra);
    mostra();
  })();
})();

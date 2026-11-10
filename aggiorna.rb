# encoding: utf-8
# Scarica calendario, risultati e classifica della Corticellese dal portale
# ufficiale del CSI Brescia (risultati.csi.brescia.it) e li salva in dati.js.
#
# Uso:  ruby aggiorna.rb
# Richiede solo Ruby (nessuna libreria esterna).

require "net/http"
require "uri"
require "json"
require "time"
require "cgi"

# Orari delle partite: ora italiana (anche quando gira sui server di GitHub)
ENV["TZ"] = "Europe/Rome"

# ---------------------------------------------------------------------------
# Configurazione: da cambiare a inizio stagione se il CSI cambia campionato/girone.
# I codici si trovano su https://risultati.csi.brescia.it/albo/risultati-calendario-classifiche-squadre.html
# ---------------------------------------------------------------------------
CONFIG = {
  squadra:     "CORTICELLESE",          # nome come appare sul portale CSI
  campionato:  "101",                   # Ca7 open maschile - Serie A
  girone:      "A",
  descrizione: "CSI Brescia · Calcio a 7 Open maschile · Serie A · Girone A"
}

BASE = "https://risultati.csi.brescia.it"
ENDPOINT = URI("#{BASE}/public/ajax/filtri.php")
OUTPUT = File.expand_path("dati.js", __dir__)

ENTITA = {
  "&amp;" => "&", "&quot;" => '"', "&#039;" => "'", "&apos;" => "'", "&lt;" => "<", "&gt;" => ">",
  "&agrave;" => "à", "&egrave;" => "è", "&eacute;" => "é", "&igrave;" => "ì", "&ograve;" => "ò",
  "&ugrave;" => "ù", "&Agrave;" => "À", "&Egrave;" => "È", "&Eacute;" => "É", "&nbsp;" => " "
}

def testo(s)
  return nil if s.nil?
  s = s.gsub(/<[^>]+>/, " ").gsub(/&[#a-zA-Z0-9]+;/) { |e| ENTITA[e] || (e =~ /&#(\d+);/ ? [$1.to_i].pack("U") : e) }
  s = s.gsub(/\s+/, " ").strip
  s.empty? ? nil : s
end

def richiesta(parametri)
  tentativi = 0
  begin
    tentativi += 1
    http = Net::HTTP.new(ENDPOINT.host, ENDPOINT.port)
    http.use_ssl = true
    http.open_timeout = 20
    http.read_timeout = 60
    req = Net::HTTP::Post.new(ENDPOINT)
    req["User-Agent"] = "SitoCorticellese/1.0 (aggiornamento risultati)"
    req.set_form_data(parametri)
    res = http.request(req)
    raise "HTTP #{res.code}" unless res.is_a?(Net::HTTPSuccess)
    body = res.body.to_s.force_encoding("UTF-8")
    body = body.encode("UTF-8", "ISO-8859-1") unless body.valid_encoding?
    raise "risposta vuota" if body.strip.empty?
    body
  rescue StandardError => e
    raise "Impossibile scaricare i dati dal CSI (#{e.message})" if tentativi >= 3
    sleep 5
    retry
  end
end

# --- Calendario e risultati -------------------------------------------------
def leggi_partite(html)
  partite = []
  fase = nil
  giornata = nil
  turno = 0 # progressivo su tutta la stagione (nel ritorno le giornate ripartono da 1)
  html.scan(/<caption>([^<]*)|class="giornata">\s*GIORNATA\s*(\d+)|<tr class="([^"]*)">(.*?)<\/tr>/m) do |cap, gio, classe, riga|
    if cap
      fase = testo(cap)
    elsif gio
      giornata = gio.to_i
      turno += 1
    else
      squadre = riga.scan(/class="squadra"><a[^>]*title="([^"]*)"/).flatten.map { |t| testo(t) }
      next unless squadre.size == 2
      punteggio = riga[/<td class="punteggio"[^>]*>(.*?)<\/td>/m, 1].to_s
      gol = punteggio.match(/(\d+)\s*-\s*(\d+)/)
      campo = riga[/ico_campo[^"]*"[^>]*title="([^"]*)"/, 1]
      partite << {
        fase: fase,
        giornata: giornata,
        turno: turno,
        casa: squadre[0],
        ospite: squadre[1],
        data: riga[/class="data">([^<]*)</, 1].to_s.strip,
        ora: riga[/class="ora">([^<]*)</, 1].to_s.strip,
        codice: riga[/class="codice">([^<]*)</, 1].to_s.strip,
        gol_casa: gol ? gol[1].to_i : nil,
        gol_ospite: gol ? gol[2].to_i : nil,
        ufficioso: classe.include?("ufficiosa"),
        spostata: punteggio.include?("ico_spostamenti"),
        campo: testo(campo)
      }
    end
  end
  partite
end

# --- Classifica --------------------------------------------------------------
def leggi_classifica(html)
  tabella = html[/<table class="tbl-standard charts">(.*?)<\/table>/m, 1] || html
  righe = []
  tabella.scan(/<tr class="([^"]*)">(.*?)<\/tr>/m) do |classe, riga|
    nome = testo(riga[/class="squadra"><a[^>]*title="([^"]*)"/, 1])
    next unless nome
    v = {}
    riga.scan(/data-label="([^"]+)">([^<]*)</) { |k, val| v[testo(k).downcase] = val.strip.to_i }
    righe << {
      posizione: righe.size + 1,
      squadra: nome,
      punti: v["punti"], giocate: v["giocate"], vinte: v["vinte"],
      pareggiate: v["pareggiate"], perse: v["perse"], penalita: v["penalità"],
      gol_fatti: v["reti fatte"], gol_subiti: v["reti subite"],
      ufficiosa: classe.include?("ufficiosa")
    }
  end
  righe
end

base = { albo: "ok", campionato: CONFIG[:campionato], squadra: "", girone: CONFIG[:girone] }
partite = leggi_partite(richiesta(base.merge(risultati: "ok")))
classifica = leggi_classifica(richiesta(base.merge(classifiche: "ok")))

raise "Nessuna partita trovata: controlla campionato/girone in CONFIG" if partite.empty?
raise "Classifica vuota: controlla campionato/girone in CONFIG" if classifica.empty?
unless partite.any? { |p| [p[:casa], p[:ospite]].include?(CONFIG[:squadra]) }
  raise "La squadra #{CONFIG[:squadra]} non compare nel girone: controlla CONFIG"
end

dati = {
  squadra: CONFIG[:squadra],
  campionato: CONFIG[:descrizione],
  fonte: "#{BASE}/albo/risultati-calendario-classifiche-squadre.html",
  aggiornato: Time.now.utc.iso8601,
  partite: partite,
  classifica: classifica
}

Dir.mkdir(File.dirname(OUTPUT)) unless Dir.exist?(File.dirname(OUTPUT))
File.write(OUTPUT, "// File generato da aggiorna.rb - non modificare a mano\nwindow.DATI = #{JSON.pretty_generate(dati)};\n")
mie = partite.count { |p| [p[:casa], p[:ospite]].include?(CONFIG[:squadra]) }
puts "OK: #{partite.size} partite (#{mie} della #{CONFIG[:squadra]}), #{classifica.size} squadre in classifica -> #{OUTPUT}"

# ---------------------------------------------------------------------------
# Feed per la newsletter (feed.xml)
# Brevo legge questo feed e manda una mail agli iscritti per ogni novità:
#  - un PROMEMORIA quando mancano meno di PREAVVISO_ORE ore alla partita
#  - il RISULTATO appena il CSI lo pubblica
# ---------------------------------------------------------------------------
FEED = File.expand_path("feed.xml", __dir__)
SITO = "https://u-s-corticellese.github.io/"
PREAVVISO_ORE = 36
GIORNI = %w[domenica lunedì martedì mercoledì giovedì venerdì sabato]
MESI = %w[gennaio febbraio marzo aprile maggio giugno luglio agosto settembre ottobre novembre dicembre]

# Per provare: ORA_TEST="2026-11-11 18:00" ruby aggiorna.rb
adesso = ENV["ORA_TEST"] ? Time.parse(ENV["ORA_TEST"]) : Time.now

def ora_partita(p)
  return nil unless p[:data] =~ %r{(\d+)/(\d+)/(\d{4})}
  g, m, a = $1.to_i, $2.to_i, $3.to_i
  h, mi = p[:ora] =~ /(\d+):(\d+)/ ? [$1.to_i, $2.to_i] : [0, 0]
  Time.local(a, m, g, h, mi)
end

def bel_nome(n)
  n.to_s.downcase.gsub(/(^|[\s.'(-])([[:lower:]])/) { $1 + $2.upcase }
   .gsub(/\b(Asd|Us|Sg|Csi|Rgs|Or|Bs)\b/) { $1.upcase }
end

def quando(t)
  "#{GIORNI[t.wday]} #{t.day} #{MESI[t.month - 1]} alle #{t.strftime('%H:%M')}"
end

def h(s) CGI.escapeHTML(s.to_s) end

# Date di pubblicazione già nel feed: restano uguali, così le mail non partono due volte
gia = {}
if File.exist?(FEED)
  File.read(FEED, encoding: "utf-8").scan(%r{<guid[^>]*>([^<]+)</guid>\s*<pubDate>([^<]+)</pubDate>}) do |g, d|
    gia[g] = (Time.rfc2822(d) rescue nil)
  end
end
primo_giro = !File.exist?(FEED)

noi = CONFIG[:squadra]
riga_noi = classifica.find { |r| r[:squadra] == noi }
nostre = partite.select { |p| [p[:casa], p[:ospite]].include?(noi) }
prossima = nostre.select { |p| p[:gol_casa].nil? && (t = ora_partita(p)) && t > adesso }.min_by { |p| ora_partita(p) }

voci = []
nostre.each do |p|
  t = ora_partita(p)
  sfida = "#{bel_nome(p[:casa])} – #{bel_nome(p[:ospite])}"
  if p[:gol_casa]
    gn, gl = p[:casa] == noi ? [p[:gol_casa], p[:gol_ospite]] : [p[:gol_ospite], p[:gol_casa]]
    esito = gn > gl ? "Vittoria" : gn < gl ? "Sconfitta" : "Pareggio"
    guid = "risultato-#{p[:codice]}"
    # Un risultato è una novità solo se la partita è recente (e non al primo avvio)
    vecchia = t && (primo_giro || adesso - t > 7 * 86400)
    data = gia[guid] || (vecchia ? t + 3 * 3600 : adesso)
    corpo = "<p><strong>#{h(bel_nome(p[:casa]))} #{p[:gol_casa]} – #{p[:gol_ospite]} #{h(bel_nome(p[:ospite]))}</strong></p>" \
            "<p>#{esito} della Corticellese nella #{p[:giornata]}ª giornata di #{h(p[:fase].to_s.downcase)}.</p>"
    corpo += "<p><em>Risultato ufficioso, in attesa di omologazione.</em></p>" if p[:ufficioso]
    corpo += "<p>In classifica: #{riga_noi[:posizione]}° posto con #{riga_noi[:punti]} punti.</p>" if riga_noi
    if prossima
      corpo += "<p>Prossima partita: #{h(bel_nome(prossima[:casa]))} – #{h(bel_nome(prossima[:ospite]))}, " \
               "#{h(quando(ora_partita(prossima)))}.</p>"
    end
    voci << { guid: guid, data: data, titolo: "#{esito}: #{bel_nome(p[:casa])} #{p[:gol_casa]}-#{p[:gol_ospite]} #{bel_nome(p[:ospite])}", corpo: corpo }
  elsif t && t > adesso && t - adesso <= PREAVVISO_ORE * 3600
    guid = "promemoria-#{p[:codice]}-#{t.strftime('%Y%m%d%H%M')}"
    in_casa = p[:casa] == noi
    corpo = "<p><strong>#{h(sfida)}</strong></p>" \
            "<p>#{h(quando(t).capitalize)} · #{in_casa ? 'in casa' : 'in trasferta'} · #{p[:giornata]}ª giornata di #{h(p[:fase].to_s.downcase)}</p>"
    corpo += "<p>Campo: #{h(bel_nome(p[:campo]))}</p>" if p[:campo]
    corpo += "<p><em>Attenzione: la data di questa partita è stata variata.</em></p>" if p[:spostata]
    corpo += "<p>Forza Corticellese! ❤️💙</p>"
    voci << { guid: guid, data: gia[guid] || adesso, titolo: "Promemoria: #{sfida}, #{quando(t)}", corpo: corpo }
  end
end

# Nel feed restano solo le novità delle ultime 3 settimane (al massimo 15)
voci = voci.select { |v| v[:data] > adesso - 21 * 86400 }.sort_by { |v| v[:data] }.reverse.first(15)

xml = +"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
xml << "<rss version=\"2.0\">\n<channel>\n"
xml << "  <title>U.S. Corticellese · Partite e risultati</title>\n"
xml << "  <link>#{SITO}</link>\n"
xml << "  <description>Promemoria delle partite e risultati della U.S. Corticellese (#{h(CONFIG[:descrizione])})</description>\n"
xml << "  <language>it-it</language>\n"
voci.each do |v|
  xml << "  <item>\n"
  xml << "    <title>#{h(v[:titolo])}</title>\n"
  xml << "    <link>#{SITO}#stagione</link>\n"
  xml << "    <guid isPermaLink=\"false\">#{h(v[:guid])}</guid>\n"
  xml << "    <pubDate>#{v[:data].utc.strftime('%a, %d %b %Y %H:%M:%S +0000')}</pubDate>\n"
  xml << "    <description><![CDATA[#{v[:corpo]}]]></description>\n"
  xml << "  </item>\n"
end
xml << "</channel>\n</rss>\n"
File.write(FEED, xml)
puts "Feed newsletter: #{voci.size} voci -> #{FEED}"

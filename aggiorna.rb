# encoding: utf-8
# Scarica calendario, risultati e classifica della Corticellese dal portale
# ufficiale del CSI Brescia (risultati.csi.brescia.it) e li salva in data/dati.js.
#
# Uso:  ruby scripts/aggiorna.rb
# Richiede solo Ruby (nessuna libreria esterna).

require "net/http"
require "uri"
require "json"
require "time"

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
OUTPUT = File.expand_path("../data/dati.js", __dir__)

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
File.write(OUTPUT, "// File generato da scripts/aggiorna.rb - non modificare a mano\nwindow.DATI = #{JSON.pretty_generate(dati)};\n")
mie = partite.count { |p| [p[:casa], p[:ospite]].include?(CONFIG[:squadra]) }
puts "OK: #{partite.size} partite (#{mie} della #{CONFIG[:squadra]}), #{classifica.size} squadre in classifica -> #{OUTPUT}"

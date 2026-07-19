# BITLING OMNI — Legendäre Definition of Done

Eine Funktion ist nicht fertig, weil sie kompiliert oder auf einem Screenshot gut aussieht. Sie ist fertig, wenn Technik, Spielgefühl, Kunst, Audio, Sicherheit, Zugänglichkeit und Betrieb gemeinsam abgenommen wurden.

## 1. Fünf verpflichtende Verbesserungspässe

### Pass 1 — Wahrheit

- Welches konkrete Spielerproblem wird gelöst?
- Welche Zielgruppe profitiert?
- Welche emotionale oder spielerische Wirkung entsteht?
- Welche Risiken werden eingeführt?
- Gibt es eine einfachere, bessere Lösung?

### Pass 2 — System

- Zustände und Zustandsbesitzer sind eindeutig.
- Abhängigkeiten sind dokumentiert.
- Save-, Migrations- und Netzwerkverträge sind definiert.
- Fehler- und Recovery-Pfade sind vorhanden.
- Grenzwerte und Missbrauchsfälle sind bekannt.

### Pass 3 — Erlebnis

- sichtbares Feedback
- Animation und Mimik
- Audio und Haptik
- verständliche Texte
- Überraschung oder Entscheidung
- Lernwirkung, falls relevant
- Alters- und Zugänglichkeitsvarianten

### Pass 4 — Politur

- Timing
- Lesbarkeit
- Mikrointeraktionen
- Übergänge
- Wiederholungsvermeidung
- Performance
- visuelle und akustische Konsistenz

### Pass 5 — Gegnerische Abnahme

- ungültige Eingaben
- Abbruch und Wiederaufnahme
- Offlinebetrieb
- Zeitmanipulation
- schwache Geräte
- große Schrift
- reduzierte Bewegung
- Stummmodus
- Save-Korruption
- Netzwerkverlust
- Datenschutz- und Altersgrenzen

## 2. Definition of Done pro Funktion

Eine Funktion darf erst in `main` integriert werden, wenn alle zutreffenden Punkte erfüllt sind:

### Produkt und Design

- [ ] Spielerwirkung ist in einem Satz beschrieben.
- [ ] Zielgruppe und Altersprofil sind bekannt.
- [ ] Abhängigkeiten sind dokumentiert.
- [ ] Erfolg und Misserfolg sind spielerisch verständlich.
- [ ] Kein bestehendes System wird unnötig dupliziert.
- [ ] Es existiert ein klarer Grund, warum die Funktion BITLING besser macht.

### Code und Daten

- [ ] Zustandsbesitzer ist eindeutig.
- [ ] Datenstruktur ist versioniert.
- [ ] Save- und Migrationspfad sind vorhanden.
- [ ] ungültige Eingaben werden sicher behandelt.
- [ ] Recovery-Pfad existiert.
- [ ] keine unbeschränkten Historien, Queues oder Sammlungen.
- [ ] keine Geheimnisse, Schlüssel oder personenbezogenen Daten im Repository.
- [ ] Parser, Import und Hauptszenen-Boot sind grün.

### Gameplay

- [ ] Funktion erzeugt echte Entscheidung, Geschicklichkeit, Experiment oder Beziehung.
- [ ] Feedback ist innerhalb von 250 ms erkennbar, sofern technisch sinnvoll.
- [ ] Konsequenzen sind sichtbar und nicht nur numerisch.
- [ ] mehrere legitime Spielweisen sind möglich, falls das System Wahlfreiheit verspricht.
- [ ] keine Pay-to-win- oder Angstmechanik.
- [ ] Pausen des Spielers werden respektiert.

### Charakter und Animation

- [ ] Reaktion passt zu Persönlichkeit, Stimmung und Lebensphase.
- [ ] Mimik und Körperhaltung unterstützen die Bedeutung.
- [ ] Übergänge besitzen keine sichtbaren Sprünge.
- [ ] Sekundärbewegung ist vorhanden, falls die Szene sie benötigt.
- [ ] reduzierte Bewegung besitzt eine sichere Alternative.
- [ ] keine finale Kernaktion verwendet nur generischen Bounce als Hauptanimation.

### Audio

- [ ] eindeutiger Aktionssound vorhanden.
- [ ] Lautstärke, Bus und Priorität sind definiert.
- [ ] Sprache oder Voice passt zu Stimmung und Alter.
- [ ] Untertitel oder visuelle Hinweise existieren.
- [ ] Stummmodus verliert keine wichtige Information.
- [ ] Kopfhörer, Lautsprecher und Bluetooth wurden geprüft, falls relevant.

### Text und Erzählung

- [ ] Texte sind kontextuell und charaktertreu.
- [ ] Wiederholungsgrenzen sind definiert.
- [ ] Texte verwenden Lokalisierungsschlüssel.
- [ ] mindestens Deutsch und Englisch sind professionell geprüft, sobald die Funktion 1.0-relevant ist.
- [ ] sensible Themen folgen der Altersrichtlinie.
- [ ] keine unbelegten Aussagen über Bewusstsein, Gesundheit oder Lernleistung.

### UI und Eingabe

- [ ] Smartphone-, Tablet- und Desktoplayout sind geprüft.
- [ ] Touch, Maus und Tastatur funktionieren.
- [ ] Controller ist geprüft, falls die Funktion zur Kernnavigation gehört.
- [ ] Touchziele sind ausreichend groß.
- [ ] Fokuszustände sind sichtbar.
- [ ] Fehler-, Lade- und Leerezustände existieren.
- [ ] große Schrift verursacht keinen kritischen Überlauf.
- [ ] Screenreadertext ist vorhanden, falls die Plattform ihn unterstützt.

### Performance

- [ ] FPS- und Framezeitbudget eingehalten.
- [ ] Speicher- und Draw-Call-Budget eingehalten.
- [ ] keine verwaisten Nodes.
- [ ] keine dauerhaften unnötigen `_process`- oder `_physics_process`-Schleifen.
- [ ] mobile Qualität kann kontrolliert reduziert werden.
- [ ] reale Hardwareprüfung erfolgt bei visuellen oder audiointensiven Funktionen.

### Datenschutz und Sicherheit

- [ ] Datenerhebung ist minimiert und dokumentiert.
- [ ] Einwilligung ist erforderlich, wenn Daten, Kamera, Mikrofon oder soziale Übertragung betroffen sind.
- [ ] Minderjährigenschutz ist berücksichtigt.
- [ ] Blockieren, Melden, Stummschalten und Verlassen sind vorhanden, falls soziale Interaktion betroffen ist.
- [ ] Löschung und Export sind möglich, falls personenbezogene Daten gespeichert werden.
- [ ] Standardzustand ist sicher und privat.

### Tests und Belege

- [ ] automatischer Regressionstest vorhanden.
- [ ] Erfolg, Fehler und Recovery werden getestet.
- [ ] Save-Roundtrip wird getestet.
- [ ] visuelle Referenz ist aktualisiert.
- [ ] reale Geräteprüfung ist dokumentiert.
- [ ] keine offenen P0- oder P1-Mängel.
- [ ] Dokumentation und Roadmapstatus sind aktualisiert.

## 3. Szenenabnahme

Jede finale Hauptszene muss folgende Ebenen besitzen:

### Charakterebene

- erkennbare Silhouette
- glaubwürdiger Bodenkontakt
- Augenfokus
- Mikroexpression
- Sekundärbewegung
- Berührungs- und Zustandsreaktion

### Umweltebene

- Vorder-, Mittel- und Hintergrund
- atmosphärische Tiefe
- bewegte und interaktive Details
- Tageszeitvariation
- eigene akustische Identität
- Umweltgeschichte

### Interfaceebene

- klare Hierarchie
- maximal ein primärer Fokus
- verständliche Navigation
- sichere Lesbarkeit
- keine technische Debug-Anmutung
- elegante Ein- und Ausblendung

### Audioebene

- Musik
- Ambience
- Foley
- Charakter
- UI
- bewusste Stille

## 4. Release-Schweregrade

### P0 — Release blockiert

- Save-Verlust
- Crash oder Startblocker
- Datenschutz- oder Kindersicherheitsverletzung
- Kaufverlust
- unkontrollierte Kamera-/Mikrofonaktivierung
- schwere Moderationslücke

### P1 — Release blockiert

- Kernschleife unverständlich
- massive Performanceprobleme
- zentrale Aktion ohne Feedback
- fehlende finale Assets in einer Hauptszene
- schwerer Accessibility-Blocker
- wiederholbarer Progressionsstillstand

### P2 — vor Release beheben

- auffälliger visueller Fehler
- häufige Dialogwiederholung
- inkonsistente Animation
- unklare Nebenfunktion
- mittlerer Lokalisierungsfehler

### P3 — geplant korrigieren

- kleinere Politur
- seltene kosmetische Abweichung
- optionaler Komfortwunsch

## 5. Meilenstein-Gates

### Vertical Slice

- 20–30 Minuten nahezu finale Qualität
- ein finaler Bitling
- ein finaler Raum
- drei hochwertige Minispiele
- professionelles Audio
- vollständiges Onboarding
- externe Testabnahme

### Alpha

- alle Kernsysteme spielbar
- Hauptpfad vollständig
- keine großen technischen Platzhalter
- Save-Migration und Content-Tools vorhanden

### Beta

- keine neuen Kernsysteme
- vollständige Plattform- und Accessibilitytests
- externe Lernwirkungs- und Sicherheitstests
- Balancing und Performance im Mittelpunkt

### Release Candidate

- Content Lock
- vollständige Lokalisierung
- signierte Builds
- Store- und Datenschutzmaterial
- betriebsfähiger Support und Moderation
- strikter AAA-Release-Gate grün

## 6. Abnahmeformel

Eine Änderung darf nur integriert werden, wenn:

```text
Spielerwirkung
× technische Stabilität
× künstlerische Qualität
× Verständlichkeit
× Sicherheit
× Zugänglichkeit
> bestehender Stand
```

Ein Faktor mit dem Wert null macht die gesamte Änderung nicht releasefähig.

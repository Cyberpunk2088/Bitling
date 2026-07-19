# BITLING OMNI — Partner-World-Entwicklungsbaum

## Zielzustand

Der Spieler lebt nicht neben einem Menü, sondern mit einem einzelnen Bitling in einer wachsenden Welt. Jede kurze Session erzeugt mindestens eine sichtbare Veränderung an Partner, Beziehung, Fähigkeiten oder Umgebung. Jede lange Spielphase eröffnet neue Strategien statt nur größere Zahlen.

## Produktionsgraph

```text
PARTNERKERN
├── Bedürfnisse und Tagesrhythmus
│   ├── lesbare Warnfenster
│   ├── Pflegequalität
│   ├── Belastung ohne Offline-Bestrafung
│   └── aktive Erholungspfade
├── Erziehung
│   ├── Disziplin
│   ├── Routine
│   ├── Selbstkontrolle
│   ├── Unabhängigkeit
│   └── soziale Sicherheit
├── Autonomie
│   ├── Hobby ausüben
│   ├── Selbstpflege
│   ├── Spiel erfinden
│   ├── selbstständig lernen
│   └── andere Bitlings unterrichten
├── Techniklernen
│   ├── Beobachtung
│   ├── individuelle Begabung
│   ├── wiederholte Anwendung
│   ├── Meisterschaft
│   └── Vererbung ausgewählter Techniken
├── Erkundung
│   ├── mehrstufige Entscheidungen
│   ├── Persönlichkeitsfolgen
│   ├── Bewohnerbegegnungen
│   └── seltene Wissens- und Technikereignisse
├── Signalsiedlung
│   ├── Signalposten
│   ├── Zuflucht
│   ├── Gemeinschaft
│   ├── Metropole
│   └── Konstellation
├── Evolution
│   ├── Wachstum
│   ├── Bindung
│   ├── Pflege
│   ├── Gewohnheiten
│   ├── Bonusentdeckungen
│   └── mindestens drei erfüllte Kategorien
└── Vermächtnis
    ├── weise Lebensphase
    ├── freiwillige Erneuerung
    ├── Generationenzähler
    ├── ausgewählte Technikvererbung
    ├── Erinnerungsarchiv
    └── dauerhafte Siedlung
```

## Fünf Implementierungswellen

### Welle A — Systemkern

Status: **implementiert auf Produktionsbranch**

- PartnerWorld-Service
- Pflegequalität und Belastung
- Erholungskette
- vier Lebensphasen
- Technikbeobachtung und Lernen
- autonome Aktivitätsauflösung
- Bewohnerrekrutierung
- fünf Siedlungsränge
- freiwilliger Vermächtnis-Samen
- begrenzte Historien

Abnahme:

- kein Zustand unter 0 oder über seinem Maximum;
- doppelte Entdeckungen erzeugen keine doppelten Bewohner;
- Pflege kann sich nach Fehlern erholen;
- Offline-Zeit altert reduziert und bestraft keine Bedürfnisse;
- Historien bleiben begrenzt.

### Welle B — Evolutionsintelligenz

Status: **implementiert auf Produktionsbranch**

- sechs originale Evolutionsrouten;
- fünf unabhängige Kategorien;
- Mindestlevel als Sicherheitsgrenze;
- gewichtete Fortschrittswerte;
- verständlicher nächster Entwicklungshinweis;
- gespeicherte Entdeckungen;
- Runtime-Adapter für IQ, Attribute, Skills, Erziehung und Weltzustand.

Abnahme:

- mindestens drei Kategorien können eine Route öffnen;
- kein einzelner Wert entscheidet allein;
- zu niedriges Entwicklungslevel verhindert eine verfrühte Form;
- jede Kategorie ist im Forecast prüfbar;
- mehrere Routen müssen gleichzeitig lebensfähig sein können.

### Welle C — Spielbare Darstellung

Status: **nächster sichtbarer Produktionsblock**

- Partner-World-Seite statt Statistikliste;
- Lebensphasen-Timeline;
- Pflegefenster und Erholungsvorschläge;
- Technikbuch mit Beobachtungsfortschritt;
- Evolutionsrad mit Kategorien statt versteckten Tabellen;
- Siedlungskarte mit Bewohnern und Gebäuden;
- Vermächtniszeremonie;
- Audio-, Animations- und Dialogantworten auf jeden Übergang.

Abnahme:

- alle kritischen Zustände sind ohne Debug-Konsole lesbar;
- keine Seite benötigt horizontales Scrollen;
- Smartphone-Hauptaktionen sind mit einer Hand erreichbar;
- Reduced Motion, hoher Kontrast und Screenreader besitzen gleichwertige Information;
- jede Zustandsänderung erzeugt mindestens zwei Feedbackkanäle.

### Welle D — Gameplaytiefe

Status: **geplant nach Welle C**

- trainierbare Befehlssicherheit;
- halbautonome Expeditionen;
- mentorengestütztes Techniklernen;
- interaktive Siedlungsgebäude;
- kooperative Bitling-Begegnungen;
- soziale Lehr- und Debattiersequenzen;
- körperliche Entwicklung und Gewicht als sichtbare, nicht beschämende Körpermerkmale;
- saisonale Weltzustände.

Abnahme:

- mindestens drei erfolgreiche Erziehungsstile;
- kein optimaler Einheitsbuild;
- Techniklernen hat mehr als einen Weg;
- soziale Interaktion ist einwilligungsbasiert;
- Spielpausen vernichten keinen Fortschritt.

### Welle E — Weltmarktbereitschaft

Status: **nicht behauptet, bis externe Daten vorliegen**

Erforderlich:

- professionelle Charaktermodelle, Rigging und Animation;
- komponierte Musik, Ambience, Foley und Voice Direction;
- vollständige Minispiele und Siedlungsinhalte;
- professionelle Lokalisierung und kulturelle Prüfung;
- Eltern-/Kinder- und Seniorentests;
- Datenschutz- und Jugendschutzprüfung;
- mindestens drei kontrollierte externe Playtest-Runden;
- Performanceprofile auf schwachen und starken Geräten;
- Retention-, Abbruch- und Frustrationsanalyse;
- Store-, Marketing- und Community-Produktionsplan.

## Harte Definition of Done

Ein Knoten gilt nur als fertig, wenn:

1. sein Zustand gespeichert, geladen und migriert werden kann;
2. Erfolgs-, Fehler- und Erholungspfad getestet sind;
3. Ursache und Wirkung im Spiel lesbar sind;
4. Smartphone, Tablet und Desktop funktionieren;
5. die Funktion mindestens eine echte Entscheidung erzeugt;
6. keine geschützte Fremdimplementierung benötigt wird;
7. ein Regressionstest einen Rückfall verhindert;
8. ein manueller Gerätecheck definiert ist;
9. die Funktion nach drei Iterationen noch einen messbaren Nutzen besitzt;
10. die Entfernung der Funktion keinen Save beschädigt.

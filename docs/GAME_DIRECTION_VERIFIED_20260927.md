# BITLING: überprüfte Spielrichtung und Weg zur Veröffentlichung

Stand: 27.09.2026. Ziel des Besitzers: das vorhandene GitHub-Spiel zuverlässig, modern, unterhaltsam und pädagogisch sinnvoll bis zur Veröffentlichung entwickeln, geeignete Open-Source-Technik und erfolgreiche Spielprinzipien nutzen. **Gesamtstatus REVIEW: keine Storefreigabe, kein nachgewiesener Markterfolg oder Lernwirksamkeitsnachweis.**

## Visuelle Vorgabe aus den drei Nutzerbildern

Die am 27.09.2026 hochgeladenen LUMO-Konzeptbilder sind als Richtung übernommen: weißblaues weiches Fell, große ausdrucksstarke Augen, warmes Herzlicht, schwebende Naturinseln, kleine gemeinsam bewältigte Aufgaben und klare Touchbedienung. Die eigens generierte Figur mit Moosinsel ist im vorhandenen Lernkatalog und Lernabenteuer integriert; die Karten erhalten wärmere Farben. Auf die folgende ausdrückliche Nutzerforderung nach echter Bewegung wird daraus ein interaktiver 2D-Begleiter mit örtlich getrennten Verformungen und Blinzeln entwickelt. Aufgaben und Eingaben bleiben echte Godot-Controls.

Das ist der erste sichtbare Ausschnitt dieser Richtung, noch kein kompletter Umbau der 3D-Welt oder fertiger Animationssatz. BITLING bleibt vorerst Repository- und technischer Projektname; die Bilder legen den gewünschten LUMO-Auftritt fest. Marketingversprechen in den Bildern sind Ziele und keine Nachweise. Assetherkunft: [Provenienz](../assets/learning/README.md).

## Produktentscheidung

BITLING bleibt ein eigenes Begleitwesen mit veränderbarer Welt. Die Hauptschleife lautet: **beobachten → entscheiden → sichtbare Folge → verstehen → später anwenden → sicher speichern**. Zusätzliche Funktionen müssen diese Schleife stärken. Wiederkehr soll aus Neugier, Gestaltung und Können entstehen. Spielpausen dürfen keine Kauf- oder Rückkehrpflicht erzeugen. Die technische Korrektur eines Quiz ist noch kein fertiges Lernspiel.

Drei verglichene Richtungen:

| Richtung | Stärke | Risiko | Entscheidung |
| --- | --- | --- | --- |
| Haustier plus viele unabhängige Minispiele | Schnell zugängliche Abwechslung | Belohnungen und Lernen bleiben losgelöst von der Welt | Bestehende Spiele erhalten, ihre Qualität und Folgen verbessern |
| Begleiter und gemeinsam veränderte Welt | Bindung, eigene Ziele und sichtbare Konsequenzen | Benötigt konsistente Speicherung und sorgfältig verknüpfte Inhalte | Leitidee für BITLING |
| Größere soziale Onlinewelt mit frei generierter KI | Offene Inhalte und Begegnungen | Laufende Kosten, Moderation, Datenschutz und unkontrollierte Lerninhalte | Für diese Reparatur nicht hinzufügen |

## Vergleich mit geöffneten Originalquellen

| Quelle | Tatsächlich dokumentiert | Für BITLING abgeleitete Entscheidung | Grenze des Belegs |
| --- | --- | --- | --- |
| [Stardew Valley: About](https://www.stardewvalley.net/about/) | Tätigkeiten entwickeln Fähigkeiten; Fortschritt eröffnet Rezepte und Gebiete, die Welt ist gestaltbar | Gelerntes soll neue Handlungen und sichtbare Habitatfolgen ermöglichen | Keine bewiesene Formel für kommerziellen Erfolg |
| [Nintendo: Animal Crossing](https://www.nintendo.com/de-de/Spiele/Nintendo-Switch-Spiele/Animal-Crossing-New-Horizons-1438623.html) | Sammeln, Basteln und persönliche Inselgestaltung | Eigene Entdeckungen und Gestaltung als langfristige Ziele; saisonale Inhalte nachholbar planen | Keine Figuren, Texte oder Assets übernehmen; noch keine neue Funktion in diesem Patch |
| [DragonBox Algebra 5+](https://www.dragonbox.com/products/algebra-5) | Bildkarten werden schrittweise zu Zahlen und Variablen; unmittelbare Rückmeldung | Erst verständlich handeln, dann erklären und übertragen; Feedback darf nicht zu früh verschwinden | Produktbeschreibung ist kein unabhängiger Wirksamkeitsnachweis |
| [Ritchie et al., PLOS ONE, 2013](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0078976) | Abrufübungen verbesserten in zwei Experimenten mit 8–12-Jährigen das spätere Erinnern geografischer Fakten | Spätere neue Transferaufgaben prüfen statt nur wiederholtes Anklicken derselben Position | Kein Nachweis für sämtliche Altersgruppen, allgemeine Intelligenz oder BITLING |
| [Decker-Woodrow et al., 2023](https://files.eric.ed.gov/fulltext/ED627889.pdf) | Randomisierte Untersuchung von Algebra-Lerntechnologien; Vorteile zweier Spiele gegenüber aktiver Kontrolle | Lernspiel als zusammenhängende Handlung entwickeln, Wirkung später direkt messen | Finale Analyse n=1.850, pandemiebedingter Datenausfall; unmittelbares Feedback allein war nach Kovariatenkontrolle nicht signifikant überlegen |
| [UNICEF RITEC Design Toolbox](https://www.unicef.org/childrightsandbusiness/workstreams/responsible-technology/online-gaming/ritec-design-toolbox) | Evidenzinformierte Gestaltungsdimensionen, unter anderem Autonomie, Kompetenz, Beziehungen und Sicherheit; Forschung mit 787 Kindern in 18 Ländern | Freie Lesezeit, hilfreiche Rückmeldung, eigene Entscheidungen und sichere Pausen | Designhilfe, keine Zertifizierung des Spiels; Schwerpunkt 8–12 Jahre |

Die BITLING-Entscheidungen sind aus diesen Quellen abgeleitet. Technische Tests belegen ihre Implementierung, nicht ihren Lern- oder Verkaufserfolg.

## In diesem Schritt umgesetzt

- Die neun bisher vorhersagbaren Lernbereiche erhalten deterministisch gemischte Antworten. Alle gültigen Lösungen bleiben gültig, auch bei mehreren brauchbaren Kreativlösungen.
- Kontext- und Szenariobanken enthalten mindestens drei verschiedene Aufgaben und auf die Aufgabe bezogene Erklärungen. Drei Runden wiederholen nicht dieselbe Aufgabe; auch die Reihenfolge hängt vom Sitzungsseed ab.
- Antwort und Erklärung gehören zur sichtbaren Frage. Erst „WEITER“ beziehungsweise „ERGEBNIS ANSEHEN“ wechselt die Ansicht. Veraltete Eingaben und doppelte Klicks können keine weitere Runde verbrauchen.
- Auswahl, passende Antwort(en), Erklärung und Anwendungstipp bleiben in Ruhe lesbar. Ein falscher Lösungsversuch wird nicht beschämend kommentiert. Die vorherige pauschale Behauptung, Fehler kosteten keinen Fortschritt, wurde entfernt; das bestehende Bewertungssystem ist keine fachlich validierte Kompetenzmessung.
- Profil → Open-Source-Lizenzen zeigt die Lizenz und Drittanbieterhinweise des tatsächlich laufenden Godot-Binaries offline an. Tastatur, Scrollen, Schließen und Fokusrückkehr sind prüfbar.

## Bewegung: überprüfte Vorbilder

[My Talking Tom 2](https://mytalkingtom2.com/gameplay) dokumentiert direkte Manipulation der Figur, Gegenstandsaktionen und unterschiedliche Futterreaktionen. [My Talking Angela 2](https://mytalkingangela2.com/gameplay) verbindet unter anderem Bewegung und Tanz mit Interaktion. [Outfit7s technische Art-Pipeline vom 07.10.2024](https://outfit7.com/blog/tech/outfit7s-art-pipeline) beschreibt Figuren-Rigs, inverse Kinematik, Blendshapes und exportierte Gelenkanimationen. Diese Quellen belegen konkrete Gestaltungsmittel, keine von uns erhobene aktuelle Marktführer-Rangliste.

Für diesen begrenzten BITLING-Schritt werden die Prinzipien mit Godots vorhandener 2D-Technik umgesetzt: Kopf, Ohren, Schweif und Atembewegung verändern die gerenderte Figur relativ zum verankerten Untergrund; Berührung und Lernereignisse steuern verschiedene Reaktionen. Die Augen besitzen einen gesonderten Blinkzustand. Es entsteht kein vollständiges 3D-Rig und noch keine Sammlung fertig animierter Fütter-, Geh- und Bauaktionen. Deren Umsetzung bleibt Bestandteil des anschließenden Welt- und Pflegeausbaus.

Der Nachweis muss wirkliche Rendergeometrie und sichtbare Frames zeigen. Ein wechselnder Zustandsname oder ein insgesamt verschobenes Bild genügt nicht. „Besser“ bleibt ein Ziel für direkte Vergleichs- und Nutzertests. Eigene Figuren und Spielinhalte werden nicht durch kopierte Herstellerassets ersetzt.

## Open Source mit nachvollziehbarer Herkunft

| Baustein | Prüfung | Verwendung |
| --- | --- | --- |
| Godot 4.6.3 | [Offizielle Lizenzanleitung](https://docs.godotengine.org/en/4.6/about/complying_with_licenses.html), MIT für die Engine; Drittkomponenten separat | Bereits eingesetzte Engine. `Engine.get_license_text()`, `get_license_info()` und `get_copyright_info()` liefern die Hinweise versionsgenau in die neue Ansicht |
| Godot-Demos | [Originalrepository](https://github.com/godotengine/godot-demo-projects), MIT | Referenz für passende stabile Versionen; kein neuer Democode in diesem Patch kopiert |
| Kenney UI Pack | [Originalpaket](https://kenney.nl/assets/ui-pack), CC0 | Geeigneter optionaler Assetpool; in diesem Patch nicht importiert, um die vorhandene Bildsprache nicht beliebig zu vermischen |

Keine neue Laufzeitabhängigkeit und kein neuer Dienst wurden hinzugefügt. Die Lizenzansicht deckt Enginekomponenten ab. Sie erteilt keine Rechte an BITLING-Code, Figuren, Musik oder sonstigen Projektassets; diese Rechteprüfung bleibt offen. Neue Assets benötigen vor Import Quelle, konkrete Lizenz, Version und erforderliche Hinweise.

## Übersehene Veröffentlichungshürden

1. **iOS-Buildwerkzeuge:** [Apple verlangt seit 28.04.2026](https://developer.apple.com/news/upcoming-requirements/?id=02032026a) Xcode 26+ und iOS-26-SDK für Uploads. [Xcode 26 benötigt mindestens macOS 15.6](https://developer.apple.com/xcode/system-requirements). Der am 27.09.2026 direkt geprüfte Mac hat macOS 12.7.6 und Xcode 14.2. Er dient weiter dem nativen Desktoptest, erfüllt aber diesen Store-Buildpfad nicht. Keine kostenpflichtige Buildumgebung wurde eingerichtet.
2. **Android-Paket:** [Google verlangt seit 31.08.2026 API 36](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-GB) für neue Smartphone-Apps und Updates. Ein fehlender expliziter Wert im Godot-Preset beweist keine veraltete Zielversion. Maßgeblich bleibt das tatsächlich exportierte signierte AAB samt Manifest und Gerätetest. Ein exportiertes PCK ist kein installierbares App-Paket.
3. **Speichern:** Zentraler Save und konkrete Minispielabschlüsse sind repariert; sämtliche eigenständigen Stores bilden noch keine gemeinsame atomare Transaktion. Lernservice, Reset und Wiederherstellung brauchen gesonderte Fehler- und Neustartnachweise.
4. **Pädagogik:** Drei Aufgaben pro Kontextbereich sind ein Reparaturschritt, keine ausreichend große Langzeitbibliothek. Schwierigkeitsgrade außerhalb numerischer Aufgaben, Bewertung von Denkwegen und echte verzögerte Transferaufgaben bleiben zu entwickeln. Ein gewähltes „ERKLÄREN“ ist kein Beweis, dass der Spieler etwas erklären kann.
5. **Alle Altersgruppen:** Noch fehlen erprobte Vorlese-/Symbolbedienung, altersangemessene Sprache, vollständige Barrierefreiheit sowie Tests mit Kindern, Erwachsenen und älteren Menschen. Die allgemeine Eignung darf nicht behauptet werden.
6. **Rechte und Stores:** Eigene Code-/Assetrechte, öffentliche Datenschutzerklärung, Alters-/Zielgruppenentscheidung, Signierung, Produktionsicon, Storemedien und geprüfte Übersetzungen bleiben Voraussetzungen. Die bestehende [Kinderschutz- und Datenschutzprüfung](PRIVACY_AND_CHILD_SAFETY_RELEASE_GATE.md) bleibt maßgeblich.
7. **Betrieb und Markt:** Offlinefunktion, Akku/Wärme, Ladezeiten, kleine Displays, Audio/Haptik, Unterbrechungen, App-Updates und Migrationen sind auf Geräten zu prüfen. Geschäftsmodell, Preis, Support und Inhaltsproduktion brauchen tragfähige Entscheidungen. Ein Weltmarkt-Erfolg ist weder durch Features noch durch Tests garantiert.

## Roter Faden und Abnahme

| Reihenfolge | Ergebnis, das tatsächlich vorliegen muss | Status nach diesem Schritt |
| --- | --- | --- |
| 1 | Einstieg → Entscheidung → passende Rückmeldung → Fortschritt → Neustart; Fehlerpfade ohne falsche Erfolgsmeldung | Teilweise bestätigt; Lernfeedback verbessert, Gesamtspeicher weiter offen |
| 2 | Inhalte messen Können statt Positionserkennung; Erklärungen fachlich prüfen; neue Anwendung später lösen | Positionsfehler geschlossen; Wirksamkeit und inhaltliche Tiefe offen |
| 3 | Bedienung und Laufzeit auf iPhone 14 Plus und repräsentativen Android-Geräten | Offen; Desktop-Telefonfenster sind kein Ersatz |
| 4 | Originalassets, Rechte, Lokalisierung, Datenschutz, Altersfreigaben, signierte native Pakete | Offen; Enginehinweise jetzt zugänglich |
| 5 | Zielgruppentests, Stabilität, freiwillige Wiederkehr, Supportprozess und Freigabe des konkreten Releasecommits | Offen |

Jede Änderung erhält einen beobachtbaren Zweck, eine Fehlerreproduktion oder ein Abnahmekriterium, ausgeführte Tests und einen klar begrenzten Status. Der [Reparaturbericht](REPAIR_REVIEW_20260927.md) und seine commitbezogenen Nachweise dokumentieren den Arbeitsstand. „Grün“ in Entwicklungstests bedeutet nicht „zur Veröffentlichung freigegeben“.

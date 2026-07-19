extends Node

## Wave 5 authoritative learning runtime. Twelve adventures share one adaptive,
## age-aware and recoverable contract while preserving distinct learning goals,
## mechanics, transfer tasks and permanent consequences in the partner world.

signal catalog_changed(catalog: Array[Dictionary])
signal adventure_started(session: Dictionary)
signal round_created(round_data: Dictionary)
signal round_resolved(result: Dictionary)
signal mastery_changed(adventure_id: String, old_rating: float, new_rating: float)
signal transfer_mastered(adventure_id: String, result: Dictionary)
signal adventure_completed(result: Dictionary)

const SAVE_VERSION := 1
const SAVE_PATH := "user://learning_adventures.json"
const TEMP_PATH := "user://learning_adventures.tmp"
const BACKUP_PATH := "user://learning_adventures.backup.json"
const MAX_HISTORY := 120
const MIN_RATING := 0.0
const MAX_RATING := 100.0

const AGE_PROFILES: Dictionary = {
	"child": {"label": "KLAR", "rounds": 3, "complexity": 0.42, "support": 0.14, "reading": "kurz", "option_count": 3},
	"teen": {"label": "DYNAMISCH", "rounds": 4, "complexity": 0.68, "support": 0.08, "reading": "direkt", "option_count": 3},
	"adult": {"label": "VERTIEFT", "rounds": 4, "complexity": 0.84, "support": 0.04, "reading": "präzise", "option_count": 3},
	"senior": {"label": "ÜBERSICHTLICH", "rounds": 3, "complexity": 0.74, "support": 0.10, "reading": "klar", "option_count": 3}
}

const ADVENTURES: Dictionary = {
	"pattern_relay": {"title": "Musterstaffel", "domain": "logic", "mechanic": "choice", "technique": "pattern_focus", "interaction": "learn_pattern", "accent": "42e8ff", "icon": "◇", "world_hook": "Akademie", "evolution": "radiant_scholar", "description": "Folgen erkennen, Regeln prüfen und Muster auf neue Situationen übertragen.", "learning_goal": "Regelmäßigkeiten beschreiben und auf unbekannte Folgen anwenden.", "transfer_prompt": "Ein Expeditionssignal nutzt dieselbe Regel in anderer Form. Welche Fortsetzung bleibt logisch?", "tags": ["learn", "logic", "pattern"]},
	"signal_language": {"title": "Signalsprachen", "domain": "language", "mechanic": "choice", "technique": "mentor_chorus", "interaction": "teach_language", "accent": "a855f7", "icon": "⌁", "world_hook": "Übersetzungsturm", "evolution": "chorus_mentor", "description": "Bedeutung aus Kontext, Ton und Wortbausteinen erschließen.", "learning_goal": "Kontextsignale nutzen und Bedeutungen begründet übertragen.", "transfer_prompt": "Ein Bewohner verwendet das Wort in einer neuen Situation. Welche Bedeutung passt weiterhin?", "tags": ["learn", "language", "teaching"]},
	"resonance_rhythm": {"title": "Resonanzrhythmus", "domain": "music", "mechanic": "timing", "technique": "signal_dash", "interaction": "learn_music", "accent": "f044d4", "icon": "♪", "world_hook": "Signalplatz", "evolution": "mosaic_trickster", "description": "Takt, Vorhersage und koordinierte Reaktion in bewegten Resonanzfenstern.", "learning_goal": "Regelmäßige Zeitmuster erkennen und Bewegungen vorausschauend abstimmen.", "transfer_prompt": "Der Takt verändert sein Tempo. Triff den Mittelpunkt trotz der neuen Bewegung.", "tags": ["learn", "music", "coordination"]},
	"circuit_garden": {"title": "Schaltkreisgarten", "domain": "logic", "mechanic": "choice", "technique": "echo_shield", "interaction": "learn_circuit", "accent": "64e6a2", "icon": "⚡", "world_hook": "Werkstattdocks", "evolution": "radiant_scholar", "description": "Ursache, Wirkung und logische Verbindungen in lebenden Schaltungen planen.", "learning_goal": "Bedingungen kombinieren und funktionierende Systeme aus Teilregeln bauen.", "transfer_prompt": "Eine Brücke fällt aus. Welche Änderung stellt den Signalfluss mit wenig Aufwand wieder her?", "tags": ["learn", "logic", "technology"]},
	"number_constellation": {"title": "Zahlenkonstellation", "domain": "math", "mechanic": "choice", "technique": "pattern_focus", "interaction": "learn_math", "accent": "ffc85a", "icon": "∑", "world_hook": "Echoarchiv", "evolution": "radiant_scholar", "description": "Mengen, Verhältnisse und Rechenwege als Sternbilder sichtbar machen.", "learning_goal": "Rechenbeziehungen verstehen und den passenden Lösungsweg auswählen.", "transfer_prompt": "Die Expedition braucht dieselbe Rechnung mit anderen Werten. Welcher Rechenweg bleibt gültig?", "tags": ["learn", "math", "pattern"]},
	"evidence_beacon": {"title": "Beweisleuchtfeuer", "domain": "media", "mechanic": "choice", "technique": "echo_shield", "interaction": "debate_evidence", "accent": "6fa8ff", "icon": "◎", "world_hook": "Echoarchiv", "evolution": "elderstar_oracle", "description": "Quellen, Behauptungen und Belege unterscheiden, bevor die Welt darauf reagiert.", "learning_goal": "Glaubwürdigkeit anhand nachvollziehbarer Kriterien einschätzen.", "transfer_prompt": "Eine neue Nachricht klingt überzeugend, ist aber unbekannt. Was ist der stärkste nächste Prüfschritt?", "tags": ["learn", "media", "critical_thinking"]},
	"emotion_mirror": {"title": "Gefühlsspiegel", "domain": "emotion", "mechanic": "choice", "technique": "care_pulse", "interaction": "care_emotion", "accent": "ff8eb6", "icon": "♡", "world_hook": "Regenerationsklinik", "evolution": "heart_bastion", "description": "Gefühle erkennen, Bedürfnisse unterscheiden und Beziehungen reparieren.", "learning_goal": "Emotionale Signale benennen und respektvolle Reaktionen auswählen.", "transfer_prompt": "Die Worte ändern sich, das Bedürfnis bleibt ähnlich. Welche Antwort hilft ohne zu drängen?", "tags": ["learn", "emotion", "care", "social"]},
	"eco_balance": {"title": "Öko-Balance", "domain": "science", "mechanic": "choice", "technique": "care_pulse", "interaction": "learn_science", "accent": "65f0b2", "icon": "✦", "world_hook": "Gartenterrassen", "evolution": "heart_bastion", "description": "Lebende Systeme beobachten und Folgen von Eingriffen abwägen.", "learning_goal": "Wechselwirkungen erkennen und nachhaltige Systementscheidungen treffen.", "transfer_prompt": "Ein anderes Biotop zeigt dasselbe Ungleichgewicht. Welche Maßnahme stabilisiert es langfristig?", "tags": ["learn", "science", "nature", "care"]},
	"story_forge": {"title": "Geschichtenschmiede", "domain": "creativity", "mechanic": "choice", "technique": "comic_trip", "interaction": "learn_story", "accent": "e78cff", "icon": "✎", "world_hook": "Signalplatz", "evolution": "mosaic_trickster", "description": "Figuren, Ursachen und überraschende Wendungen zu verständlichen Geschichten verbinden.", "learning_goal": "Erzählentscheidungen auf Wirkung, Klarheit und Originalität prüfen.", "transfer_prompt": "Eine neue Figur betritt dieselbe Konfliktsituation. Welche Wendung bleibt verständlich und überraschend?", "tags": ["learn", "creativity", "story", "humor"]},
	"debate_bridge": {"title": "Debattenbrücke", "domain": "debate", "mechanic": "choice", "technique": "mentor_chorus", "interaction": "debate_bridge", "accent": "ff9f6f", "icon": "≋", "world_hook": "Begegnungsforum", "evolution": "chorus_mentor", "description": "Behauptung, Beleg und faire Gegenposition zu tragfähigen Brücken verbinden.", "learning_goal": "Argumente prüfen, Gegenpositionen fair darstellen und begründet antworten.", "transfer_prompt": "Das Thema wechselt, aber die Argumentationsstruktur bleibt. Welche Antwort ist am fairsten und stärksten?", "tags": ["learn", "debate", "language", "social"]},
	"navigation_lab": {"title": "Navigationslabor", "domain": "spatial", "mechanic": "choice", "technique": "signal_dash", "interaction": "exploration_navigation", "accent": "42d5ff", "icon": "⌖", "world_hook": "Expeditionstor", "evolution": "signal_wanderer", "description": "Routen, Perspektiven und räumliche Beziehungen unter Unsicherheit planen.", "learning_goal": "Räumliche Hinweise kombinieren und robuste Wege statt bloßer Abkürzungen wählen.", "transfer_prompt": "Die Karte ist gedreht und ein Weg blockiert. Welche Route erfüllt weiterhin alle Hinweise?", "tags": ["learn", "spatial", "exploration"]},
	"mentor_workshop": {"title": "Mentorenwerkstatt", "domain": "teaching", "mechanic": "choice", "technique": "mentor_chorus", "interaction": "teach_peer", "accent": "ffd56f", "icon": "✧", "world_hook": "Musterakademie", "evolution": "chorus_mentor", "description": "Wissen erklären, Verständnis prüfen und hilfreiche Rückmeldungen geben.", "learning_goal": "Eine Idee in eigenen Worten erklären und an unterschiedliche Lernwege anpassen.", "transfer_prompt": "Ein anderer Bitling versteht die erste Erklärung nicht. Welche zweite Erklärung nutzt einen neuen Zugang?", "tags": ["learn", "teaching", "empathy", "language"]}
}

const VARIANTS: Dictionary = {
	"pattern_relay": [
		{"prompt": "2, 4, 6, 8, ?", "options": ["10", "12", "9"], "scores": [1.0, 0.2, 0.0], "hint": "Achte auf den Abstand zwischen zwei Zahlen.", "explanation": "Die Folge wächst immer um zwei."},
		{"prompt": "3, 6, 12, 24, ?", "options": ["48", "30", "36"], "scores": [1.0, 0.1, 0.25], "hint": "Jeder Wert entsteht aus dem vorherigen.", "explanation": "Jede Zahl wird verdoppelt."},
		{"prompt": "◇ △ △ ◇ △ △ ?", "options": ["◇", "△", "○"], "scores": [1.0, 0.0, 0.0], "hint": "Suche einen wiederholten Dreierblock.", "explanation": "Der Block ◇ △ △ wiederholt sich."},
		{"prompt": "1, 4, 9, 16, ?", "options": ["25", "20", "24"], "scores": [1.0, 0.15, 0.35], "hint": "Die Zahlen lassen sich als gleich große Seiten darstellen.", "explanation": "Es sind Quadratzahlen: 1², 2², 3², 4², 5²."},
		{"prompt": "A, C, F, J, ?", "options": ["O", "N", "M"], "scores": [1.0, 0.45, 0.1], "hint": "Die Sprünge werden jeweils um eins größer.", "explanation": "Die Abstände sind +2, +3, +4 und dann +5."}
	],
	"signal_language": [
		{"prompt": "„sela-vim“ wird gesagt, nachdem jemand vorsichtig ein Geheimnis teilt.", "options": ["Ich vertraue dir", "Ich möchte gehen", "Das ist lustig"], "scores": [1.0, 0.0, 0.2], "hint": "Achte auf die verletzliche Situation.", "explanation": "Der Kontext zeigt Vertrauen und Sicherheit."},
		{"prompt": "„noru-kai“ folgt auf einen gemeinsamen Fehlversuch.", "options": ["Wir versuchen es erneut", "Du bist schuld", "Wir schlafen jetzt"], "scores": [1.0, 0.0, 0.1], "hint": "Welche Bedeutung hält die Zusammenarbeit aufrecht?", "explanation": "Die Wortgruppe steht für gemeinsames Wiederholen."},
		{"prompt": "„luma-ren“ begleitet eine plötzlich leuchtende Skizze.", "options": ["Eine neue Idee entsteht", "Der Raum wird kalt", "Das Essen ist fertig"], "scores": [1.0, 0.0, 0.0], "hint": "Bild und Situation geben dieselbe Richtung.", "explanation": "Luma-ren bezeichnet eine aufleuchtende Idee."},
		{"prompt": "„miri-lu“ erklingt, als zwei Bitlings dieselbe unbekannte Spur untersuchen.", "options": ["Gemeinsam neugierig sein", "Etwas verstecken", "Sofort gewinnen"], "scores": [1.0, 0.0, 0.15], "hint": "Wer handelt und mit welcher Haltung?", "explanation": "Miri-lu verbindet Gemeinsamkeit und Neugier."},
		{"prompt": "„plonka“ wird nach einem harmlosen Stolpern lachend gerufen.", "options": ["Ein lustiger Fehler", "Eine Gefahr", "Eine Belohnung"], "scores": [1.0, 0.0, 0.1], "hint": "Tonfall und Folgen sind nicht bedrohlich.", "explanation": "Plonka beschreibt einen komischen, ungefährlichen Fehler."}
	],
	"resonance_rhythm": [
		{"prompt": "Triff den ruhigen Mittelpunkt des pulsierenden Takts.", "target": 0.50, "window": 0.18, "speed": 0.72, "hint": "Beobachte zwei vollständige Bewegungen, bevor du tippst.", "explanation": "Vorausschau ist wichtiger als hektische Reaktion."},
		{"prompt": "Der Takt beschleunigt kurz vor der Mitte.", "target": 0.50, "window": 0.15, "speed": 0.88, "hint": "Tippe einen Augenblick vor dem sichtbaren Zentrum.", "explanation": "Du hast die Beschleunigung antizipiert."},
		{"prompt": "Zwei Resonanzen überlagern sich. Folge der helleren.", "target": 0.62, "window": 0.14, "speed": 0.82, "hint": "Die stärkere Spur ist nicht immer die schnellere.", "explanation": "Aufmerksamkeit trennt relevante von ablenkenden Signalen."},
		{"prompt": "Der Impuls wandert zurück. Triff ihn beim Richtungswechsel.", "target": 0.84, "window": 0.12, "speed": 0.76, "hint": "Der Wendepunkt ist kurz langsamer.", "explanation": "Am Richtungswechsel entsteht ein gut vorhersagbares Fenster."},
		{"prompt": "Halte den Takt trotz eines falschen Nebenimpulses.", "target": 0.44, "window": 0.13, "speed": 0.94, "hint": "Ignoriere den kleinen violetten Blitz.", "explanation": "Du hast den Haupttakt von der Ablenkung getrennt."}
	],
	"circuit_garden": [
		{"prompt": "Eine Lampe leuchtet nur, wenn Wasser UND Energie vorhanden sind. Was fehlt bei Wasser=ja, Energie=nein?", "options": ["Energie zuführen", "Wasser entfernen", "Eine zweite Lampe"], "scores": [1.0, 0.0, 0.2], "hint": "Beide Bedingungen müssen gleichzeitig stimmen.", "explanation": "Die UND-Regel benötigt Wasser und Energie."},
		{"prompt": "Zwei Wege führen zum Kern. Einer reicht aus. Welche Logik passt?", "options": ["ODER", "UND", "NICHT"], "scores": [1.0, 0.0, 0.0], "hint": "Es genügt, wenn mindestens ein Weg aktiv ist.", "explanation": "ODER ist wahr, wenn einer oder beide Wege aktiv sind."},
		{"prompt": "Ein Sensor soll nur bei geschlossener Tür senden.", "options": ["Signal NICHT offen", "Signal UND offen", "Signal ODER offen"], "scores": [1.0, 0.0, 0.1], "hint": "Formuliere die Bedingung über das Gegenteil von offen.", "explanation": "Geschlossen entspricht NICHT offen."},
		{"prompt": "Drei Module sind in Reihe. Das mittlere fällt aus. Welche Reparatur ist am kleinsten?", "options": ["Mittleres Modul überbrücken", "Alle Module ersetzen", "Mehr Energie einspeisen"], "scores": [1.0, 0.35, 0.1], "hint": "Suche die lokale Ursache statt das gesamte System zu tauschen.", "explanation": "Eine gezielte Überbrückung stellt den Pfad wieder her."},
		{"prompt": "Die Pflanze bekommt zu viel Energie und zu wenig Kühlung.", "options": ["Energie senken und Kühlung erhöhen", "Beides erhöhen", "Nur Energie erhöhen"], "scores": [1.0, 0.0, 0.0], "hint": "Korrigiere beide Ursachen in die entgegengesetzte Richtung.", "explanation": "Stabile Systeme brauchen ausgeglichene Zuflüsse und Abfuhr."}
	],
	"number_constellation": [
		{"prompt": "Drei Brücken brauchen je 4 Lichtkerne. Wie viele insgesamt?", "options": ["12", "7", "16"], "scores": [1.0, 0.0, 0.2], "hint": "Addiere drei gleiche Gruppen mit vier Kernen.", "explanation": "3 × 4 ergibt 12."},
		{"prompt": "18 Signale werden gleich auf 3 Teams verteilt.", "options": ["6 pro Team", "9 pro Team", "5 pro Team"], "scores": [1.0, 0.2, 0.0], "hint": "Suche eine Zahl, die dreimal 18 ergibt.", "explanation": "18 ÷ 3 ergibt 6."},
		{"prompt": "Ein Vorrat steigt von 40 auf 50. Um wie viel ist er gestiegen?", "options": ["10", "20", "90"], "scores": [1.0, 0.0, 0.0], "hint": "Vergleiche Endwert und Startwert.", "explanation": "50 − 40 ergibt 10."},
		{"prompt": "Zwei von acht Lichtern sind violett. Welcher Anteil ist das?", "options": ["1/4", "1/2", "2/3"], "scores": [1.0, 0.0, 0.0], "hint": "Kürze 2/8.", "explanation": "2/8 gekürzt ergibt 1/4."},
		{"prompt": "Ein Weg ist 120 Meter lang. 75 Meter sind geschafft.", "options": ["45 Meter fehlen", "55 Meter fehlen", "195 Meter fehlen"], "scores": [1.0, 0.0, 0.0], "hint": "Ziehe den geschafften Teil von der Gesamtstrecke ab.", "explanation": "120 − 75 ergibt 45."}
	],
	"evidence_beacon": [
		{"prompt": "Eine anonyme Nachricht behauptet, morgen falle die Energie aus.", "options": ["Mit offizieller Quelle und zweiter unabhängiger Quelle prüfen", "Sofort weiterleiten", "Nur auf viele Ausrufezeichen achten"], "scores": [1.0, 0.0, 0.0], "hint": "Gute Prüfung sucht Herkunft und Bestätigung.", "explanation": "Mehrere nachvollziehbare Quellen reduzieren Fehlalarme."},
		{"prompt": "Ein Bild wirkt dramatisch, zeigt aber kein Datum und keinen Ort.", "options": ["Kontext und Ursprung suchen", "Das Bild beweist alles", "Nur die Farben bewerten"], "scores": [1.0, 0.0, 0.1], "hint": "Ein Bild ohne Kontext kann echt und trotzdem irreführend sein.", "explanation": "Ort, Datum und Ursprung sind für die Einordnung entscheidend."},
		{"prompt": "Eine Studie wird nur vom Hersteller des Produkts zitiert.", "options": ["Originalstudie und mögliche Interessenkonflikte prüfen", "Automatisch glauben", "Automatisch verwerfen"], "scores": [1.0, 0.0, 0.45], "hint": "Kritisch prüfen bedeutet weder blind glauben noch blind ablehnen.", "explanation": "Methodik und Interessen müssen getrennt bewertet werden."},
		{"prompt": "Zehn Kommentare wiederholen dieselbe Behauptung ohne Beleg.", "options": ["Wiederholung ist kein Beweis", "Mehr Kommentare machen sie wahr", "Der lauteste Kommentar entscheidet"], "scores": [1.0, 0.0, 0.0], "hint": "Zähle Belege, nicht Lautstärke.", "explanation": "Häufigkeit ersetzt keine überprüfbare Evidenz."},
		{"prompt": "Zwei seriöse Quellen widersprechen sich.", "options": ["Methoden, Datenstand und Unsicherheit vergleichen", "Nur die angenehmere wählen", "Beide als Lüge bezeichnen"], "scores": [1.0, 0.0, 0.0], "hint": "Widerspruch kann aus unterschiedlichen Daten oder Methoden entstehen.", "explanation": "Ein Vergleich der Grundlagen zeigt, warum Ergebnisse abweichen."}
	],
	"emotion_mirror": [
		{"prompt": "Ein Bitling sagt: „Lass mich kurz allein“, wirkt aber nicht gefährdet.", "options": ["Raum geben und später ruhig nachfragen", "Sofort weiterreden", "Es ignorieren und nie wieder fragen"], "scores": [1.0, 0.0, 0.35], "hint": "Respektiere die Grenze und halte Verbindung offen.", "explanation": "Raum und ein späteres Angebot verbinden Autonomie mit Fürsorge."},
		{"prompt": "Nach einem Fehler wird ein Bewohner sehr still.", "options": ["Gefühl benennen und Hilfe anbieten", "Den Fehler lächerlich machen", "Schnell das Thema wechseln"], "scores": [1.0, 0.0, 0.25], "hint": "Erst verstehen, dann lösen.", "explanation": "Validierung senkt Druck und öffnet einen Reparaturweg."},
		{"prompt": "Zwei Freunde wollen dasselbe seltene Objekt.", "options": ["Bedürfnisse klären und eine faire Lösung suchen", "Der Lautere gewinnt", "Das Objekt verstecken"], "scores": [1.0, 0.0, 0.0], "hint": "Positionen sind nicht immer dieselben wie Bedürfnisse.", "explanation": "Ein Gespräch über Bedürfnisse ermöglicht mehrere faire Lösungen."},
		{"prompt": "Jemand freut sich über einen Erfolg, du selbst bist enttäuscht.", "options": ["Beides anerkennen: gratulieren und eigene Gefühle später teilen", "Die Freude kleinreden", "So tun, als gäbe es keine Gefühle"], "scores": [1.0, 0.0, 0.1], "hint": "Mehrere Gefühle können gleichzeitig wahr sein.", "explanation": "Emotionale Reife hält eigene und fremde Perspektive nebeneinander."},
		{"prompt": "Ein Bitling entschuldigt sich, aber der Schaden ist noch da.", "options": ["Entschuldigung annehmen und konkrete Reparatur vereinbaren", "Sofort alles vergessen", "Für immer bestrafen"], "scores": [1.0, 0.3, 0.0], "hint": "Eine Entschuldigung beginnt Reparatur, ersetzt sie aber nicht.", "explanation": "Verantwortung verbindet Worte mit einer konkreten Wiedergutmachung."}
	],
	"eco_balance": [
		{"prompt": "Zu viele Leuchtalgen nehmen nachts Sauerstoff aus dem Wasser.", "options": ["Algenmenge schrittweise senken und Sauerstoff messen", "Alle Lebewesen entfernen", "Noch mehr Nährstoffe hinzufügen"], "scores": [1.0, 0.15, 0.0], "hint": "Kleine messbare Eingriffe schützen das restliche System.", "explanation": "Kontrollierte Reduktion behandelt Ursache und begrenzt Nebenwirkungen."},
		{"prompt": "Eine Bestäuberart verschwindet aus dem Garten.", "options": ["Lebensraum und Nahrungsquellen wiederherstellen", "Nur mehr Wasser geben", "Alle Blüten ersetzen"], "scores": [1.0, 0.1, 0.2], "hint": "Frage, was die Art zum Leben und Fortpflanzen braucht.", "explanation": "Lebensraum und Nahrung wirken auf die ganze Population."},
		{"prompt": "Der Boden trocknet trotz häufigem Gießen schnell aus.", "options": ["Boden bedecken und Wasserspeicherung verbessern", "Noch schneller gießen", "Pflanzen nachts beleuchten"], "scores": [1.0, 0.2, 0.0], "hint": "Nicht nur Zufluss, auch Verlust ist wichtig.", "explanation": "Bedeckung reduziert Verdunstung und verbessert Speicherfähigkeit."},
		{"prompt": "Ein neuer Räuber senkt eine Beutepopulation stark.", "options": ["Mehrere Populationen über Zeit beobachten", "Sofort alle Räuber entfernen", "Nur einen Tag messen"], "scores": [1.0, 0.25, 0.0], "hint": "Ökosysteme reagieren verzögert und in mehreren Ebenen.", "explanation": "Zeitreihen zeigen direkte und indirekte Folgen."},
		{"prompt": "Die Gartentemperatur steigt jeden Nachmittag zu stark.", "options": ["Schatten, Luftstrom und Messpunkte kombinieren", "Nur eine Pflanze versetzen", "Die Sensoren abschalten"], "scores": [1.0, 0.2, 0.0], "hint": "Nutze mehrere Ursachen und überprüfbare Maßnahmen.", "explanation": "Schatten und Luftstrom behandeln Energieeintrag und Wärmeabfuhr."}
	],
	"story_forge": [
		{"prompt": "Eine Figur will mutig wirken, hat aber Angst. Welche Szene zeigt beides?", "options": ["Sie hilft trotz zitternder Hände", "Sie sagt nur: Ich bin mutig", "Sie verschwindet ohne Grund"], "scores": [1.0, 0.35, 0.0], "hint": "Zeige Eigenschaften durch Handlung und Widerspruch.", "explanation": "Handeln trotz Angst macht Mut sichtbar."},
		{"prompt": "Ein Geheimnis soll fair vorbereitet werden.", "options": ["Frühe kleine Hinweise setzen", "Die Lösung ohne Hinweis enthüllen", "Alle Hinweise am Ende erklären"], "scores": [1.0, 0.0, 0.25], "hint": "Die Lesenden sollen rückblickend eine Spur erkennen können.", "explanation": "Vorbereitung macht eine Wendung überraschend und nachvollziehbar."},
		{"prompt": "Zwei Szenen wirken unverbunden. Was schafft den stärksten Übergang?", "options": ["Eine Entscheidung aus Szene eins verursacht Szene zwei", "Beide Szenen nur gleich färben", "Eine zufällige Tür öffnen"], "scores": [1.0, 0.15, 0.2], "hint": "Suche Ursache und Folge.", "explanation": "Kausalität verbindet Szenen stärker als bloße Ähnlichkeit."},
		{"prompt": "Eine lustige Szene soll eine Figur nicht erniedrigen.", "options": ["Humor aus Situation und Selbstironie bauen", "Über eine Schwäche spotten", "Die Figur ausschließen"], "scores": [1.0, 0.0, 0.0], "hint": "Lachen kann verbinden statt nach unten zu treten.", "explanation": "Situationskomik erhält Würde und Charakterbindung."},
		{"prompt": "Das Ende soll Entwicklung zeigen.", "options": ["Die Figur entscheidet anders als am Anfang und wir verstehen warum", "Eine Zahl sagt: Entwicklung abgeschlossen", "Alles wird ohne Entscheidung gelöst"], "scores": [1.0, 0.1, 0.0], "hint": "Vergleiche Verhalten am Anfang und am Ende.", "explanation": "Eine veränderte begründete Entscheidung macht Entwicklung sichtbar."}
	],
	"debate_bridge": [
		{"prompt": "Behauptung: Der Garten sollte nachts geschlossen sein. Welcher Beleg ist am stärksten?", "options": ["Messdaten zeigen wiederholte Schäden in der Nacht", "Ich mag geschlossene Türen", "Viele sagen das"], "scores": [1.0, 0.0, 0.15], "hint": "Ein Beleg sollte überprüfbar und zur Behauptung passend sein.", "explanation": "Wiederholte Messdaten stützen die konkrete Ursache."},
		{"prompt": "Wie stellst du eine Gegenposition fair dar?", "options": ["So stark formulieren, dass ihre Vertreter zustimmen würden", "Absichtlich übertreiben", "Nur den schwächsten Satz wählen"], "scores": [1.0, 0.0, 0.0], "hint": "Fairness beginnt vor der Widerlegung.", "explanation": "Ein starkes Gegenargument verhindert einen Strohmann."},
		{"prompt": "Zwei Ziele stehen im Konflikt: Sicherheit und Offenheit.", "options": ["Kriterien und mögliche Kompromisse benennen", "Eines als immer unwichtig erklären", "Das Thema wechseln"], "scores": [1.0, 0.0, 0.0], "hint": "Komplexe Fragen haben oft mehrere legitime Werte.", "explanation": "Kriterien machen den Zielkonflikt verhandelbar."},
		{"prompt": "Ein guter Einwand trifft nur einen Teil deines Arguments.", "options": ["Den gültigen Teil anerkennen und die Aussage präzisieren", "Alles abstreiten", "Die Person angreifen"], "scores": [1.0, 0.0, 0.0], "hint": "Korrektur kann ein Argument stärker machen.", "explanation": "Anerkennung und Präzisierung zeigen intellektuelle Redlichkeit."},
		{"prompt": "Es fehlen Daten für eine sichere Schlussfolgerung.", "options": ["Unsicherheit klar benennen und nächsten Test vorschlagen", "Trotzdem absolute Sicherheit behaupten", "Eine Zahl erfinden"], "scores": [1.0, 0.0, 0.0], "hint": "Nichtwissen ist eine Information, keine Niederlage.", "explanation": "Transparente Unsicherheit führt zu besseren nächsten Schritten."}
	],
	"navigation_lab": [
		{"prompt": "Du gehst nach Norden, dann rechts. In welche Richtung blickst du?", "options": ["Osten", "Westen", "Süden"], "scores": [1.0, 0.0, 0.0], "hint": "Stelle dich gedanklich nach Norden.", "explanation": "Rechts von Norden liegt Osten."},
		{"prompt": "Der direkte Weg ist blockiert. Route A ist kurz, aber unsicher; Route B etwas länger und markiert.", "options": ["Route B wählen", "Ohne Prüfung Route A", "Stehen bleiben"], "scores": [1.0, 0.25, 0.1], "hint": "Robustheit kann wichtiger als minimale Länge sein.", "explanation": "Eine markierte Route reduziert unbekannte Risiken."},
		{"prompt": "Die Karte wird um 180 Grad gedreht. Was passiert mit links und rechts?", "options": ["Sie tauschen aus deiner neuen Blickrichtung", "Sie bleiben absolut gleich", "Oben wird immer Osten"], "scores": [1.0, 0.15, 0.0], "hint": "Unterscheide Kartenrichtung und eigene Perspektive.", "explanation": "Relative Richtungen hängen von der Blickrichtung ab."},
		{"prompt": "Zwei Hinweise: Das Ziel liegt östlich des Turms und nördlich des Gartens.", "options": ["Nordöstlicher Bereich zwischen beiden", "Westlich von beiden", "Südlich des Gartens"], "scores": [1.0, 0.0, 0.0], "hint": "Überlagere beide räumlichen Bedingungen.", "explanation": "Nur der nordöstliche Schnittbereich erfüllt beide Hinweise."},
		{"prompt": "Ein Weg ist schnell, verbraucht aber fast alle Energie.", "options": ["Energiebedarf und Rückweg gemeinsam planen", "Nur die Ankunft betrachten", "Die Anzeige ignorieren"], "scores": [1.0, 0.15, 0.0], "hint": "Eine Route endet nicht zwingend am Ziel.", "explanation": "Gute Navigation berücksichtigt Ressourcen und Rückkehr."}
	],
	"mentor_workshop": [
		{"prompt": "Ein Lernender versteht deine Fachwörter nicht.", "options": ["Mit einem konkreten Beispiel neu erklären", "Die Fachwörter lauter wiederholen", "Das Thema beenden"], "scores": [1.0, 0.0, 0.0], "hint": "Ändere den Zugang, nicht nur die Lautstärke.", "explanation": "Beispiele verbinden neue Begriffe mit bekannten Erfahrungen."},
		{"prompt": "Wie prüfst du echtes Verständnis?", "options": ["Die Idee in eigenen Worten oder neuer Situation anwenden lassen", "Nur fragen: Verstanden?", "Die Lösung vorsagen lassen"], "scores": [1.0, 0.2, 0.1], "hint": "Wiedererkennen ist leichter als selbstständige Anwendung.", "explanation": "Transfer zeigt, ob ein Konzept flexibel verstanden wurde."},
		{"prompt": "Ein Fehler wiederholt sich trotz Erklärung.", "options": ["Den Denkweg gemeinsam untersuchen", "Mehr Druck machen", "Den Lernenden beschämen"], "scores": [1.0, 0.0, 0.0], "hint": "Suche das zugrunde liegende Modell statt nur das Ergebnis.", "explanation": "Der Denkweg zeigt, an welcher Stelle die Vorstellung abweicht."},
		{"prompt": "Zwei Lernende brauchen verschiedene Zugänge.", "options": ["Bild, Sprache oder Handlung passend variieren", "Beiden exakt dieselbe Wiederholung geben", "Nur den schnelleren beachten"], "scores": [1.0, 0.1, 0.0], "hint": "Das Lernziel bleibt, der Weg darf sich ändern.", "explanation": "Variation unterstützt unterschiedliche Stärken ohne das Ziel zu senken."},
		{"prompt": "Welche Rückmeldung hilft nach einem fast richtigen Versuch?", "options": ["Starken Teil benennen und einen konkreten nächsten Schritt geben", "Nur falsch sagen", "Sofort die komplette Lösung übernehmen"], "scores": [1.0, 0.0, 0.25], "hint": "Hilfreiches Feedback ist spezifisch und handlungsfähig.", "explanation": "Anerkennung plus nächster Schritt erhält Orientierung und Eigenständigkeit."}
	]
}

var mastery_profiles: Dictionary = {}
var active_session: Dictionary = {}
var history: Array[Dictionary] = []
var total_completed_sessions: int = 0
var total_transfer_masteries: int = 0

func _ready() -> void:
	if not load_state():
		reset_state(false)
	call_deferred("_connect_game_state")

func get_catalog() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for adventure_id_variant: Variant in ADVENTURES.keys():
		var adventure_id: String = str(adventure_id_variant)
		var definition: Dictionary = (ADVENTURES[adventure_id] as Dictionary).duplicate(true)
		var profile: Dictionary = _ensure_profile(adventure_id)
		definition["id"] = adventure_id
		definition["rating"] = float(profile.get("rating", 20.0))
		definition["mastery_level"] = _mastery_level(float(profile.get("rating", 20.0)))
		definition["sessions"] = int(profile.get("sessions", 0))
		definition["best_score"] = float(profile.get("best_score", 0.0))
		definition["transfer_masteries"] = int(profile.get("transfer_masteries", 0))
		definition["variant_count"] = (VARIANTS.get(adventure_id, []) as Array).size()
		catalog.append(definition)
	catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("title", "")) < str(b.get("title", "")))
	return catalog

func start_adventure(adventure_id: String, seed_value: int = -1) -> Dictionary:
	var normalized: String = adventure_id.strip_edges().to_lower()
	if not ADVENTURES.has(normalized):
		return {"accepted": false, "reason": "unknown_adventure"}
	if not active_session.is_empty():
		return {"accepted": false, "reason": "session_active", "session": active_session.duplicate(true)}
	var definition: Dictionary = ADVENTURES[normalized]
	var profile: Dictionary = _ensure_profile(normalized)
	var age_band: String = _age_band()
	var age_profile: Dictionary = AGE_PROFILES.get(age_band, AGE_PROFILES["adult"]) as Dictionary
	var adaptive_rating: float = _adaptive_rating(str(definition.get("domain", "logic")))
	var local_rating: float = float(profile.get("rating", 20.0))
	var difficulty: int = clampi(int(round((adaptive_rating + local_rating) / 20.0)) + 1, 1, 10)
	var resolved_seed: int = seed_value
	if resolved_seed < 0:
		resolved_seed = int(abs(hash("%s:%d:%d" % [normalized, total_completed_sessions, int(Time.get_unix_time_from_system() / 300.0)])))
	var order: Array[int] = _variant_order(normalized, resolved_seed)
	var core_rounds: int = int(age_profile.get("rounds", 4))
	active_session = {
		"adventure_id": normalized,
		"title": str(definition.get("title", normalized.capitalize())),
		"domain": str(definition.get("domain", "logic")),
		"mechanic": str(definition.get("mechanic", "choice")),
		"age_band": age_band,
		"age_profile": age_profile.duplicate(true),
		"difficulty": difficulty,
		"seed": resolved_seed,
		"variant_order": order,
		"round_index": 0,
		"core_rounds": core_rounds,
		"total_rounds": core_rounds + 1,
		"round_results": [],
		"hints_total": 0,
		"current_hints": 0,
		"started_at": int(Time.get_unix_time_from_system()),
		"started_at_msec": Time.get_ticks_msec()
	}
	active_session["current_round"] = _build_round(active_session)
	save_state()
	var session_snapshot: Dictionary = active_session.duplicate(true)
	adventure_started.emit(session_snapshot)
	round_created.emit((active_session.get("current_round", {}) as Dictionary).duplicate(true))
	return {"accepted": true, "session": session_snapshot, "round": (active_session.get("current_round", {}) as Dictionary).duplicate(true)}

func submit_choice(option_index: int) -> Dictionary:
	if active_session.is_empty():
		return {"accepted": false, "reason": "no_active_session"}
	var round_data: Dictionary = active_session.get("current_round", {}) as Dictionary
	if str(round_data.get("mechanic", "choice")) == "timing":
		return {"accepted": false, "reason": "timing_required"}
	var options: Array = round_data.get("options", []) as Array
	var scores: Array = round_data.get("scores", []) as Array
	if option_index < 0 or option_index >= options.size() or option_index >= scores.size():
		return {"accepted": false, "reason": "invalid_option"}
	var score: float = clampf(float(scores[option_index]), 0.0, 1.0)
	return _resolve_round(score, option_index, str(options[option_index]))

func submit_timing(normalized_value: float) -> Dictionary:
	if active_session.is_empty():
		return {"accepted": false, "reason": "no_active_session"}
	var round_data: Dictionary = active_session.get("current_round", {}) as Dictionary
	if str(round_data.get("mechanic", "")) != "timing":
		return {"accepted": false, "reason": "choice_required"}
	var target: float = float(round_data.get("target", 0.5))
	var window: float = maxf(float(round_data.get("window", 0.15)), 0.04)
	var distance: float = absf(clampf(normalized_value, 0.0, 1.0) - target)
	var score: float = clampf(1.0 - distance / maxf(window * 2.25, 0.08), 0.0, 1.0)
	return _resolve_round(score, -1, "%.2f" % normalized_value)

func request_hint() -> Dictionary:
	if active_session.is_empty():
		return {"accepted": false, "reason": "no_active_session"}
	var round_data: Dictionary = active_session.get("current_round", {}) as Dictionary
	active_session["current_hints"] = int(active_session.get("current_hints", 0)) + 1
	active_session["hints_total"] = int(active_session.get("hints_total", 0)) + 1
	return {"accepted": true, "hint": str(round_data.get("hint", "Betrachte die Aufgabe aus einer anderen Richtung.")), "hints": int(active_session.get("current_hints", 0))}

func abandon_session() -> Dictionary:
	if active_session.is_empty():
		return {"accepted": false, "reason": "no_active_session"}
	var abandoned: Dictionary = active_session.duplicate(true)
	_remember("abandoned", {"adventure_id": str(abandoned.get("adventure_id", "")), "round_index": int(abandoned.get("round_index", 0))})
	active_session.clear()
	save_state()
	return {"accepted": true, "abandoned": abandoned}

func get_active_session() -> Dictionary:
	return active_session.duplicate(true)

func get_mastery_profile(adventure_id: String) -> Dictionary:
	if not ADVENTURES.has(adventure_id):
		return {}
	return _ensure_profile(adventure_id).duplicate(true)

func get_snapshot() -> Dictionary:
	return {
		"catalog": get_catalog(),
		"active_session": active_session.duplicate(true),
		"total_completed_sessions": total_completed_sessions,
		"total_transfer_masteries": total_transfer_masteries,
		"average_rating": get_average_rating(),
		"mastered_adventures": get_mastered_adventure_count(),
		"variant_count": get_total_variant_count()
	}

func get_average_rating() -> float:
	if mastery_profiles.is_empty():
		return 20.0
	var total: float = 0.0
	for profile_variant: Variant in mastery_profiles.values():
		var profile: Dictionary = profile_variant as Dictionary
		total += float(profile.get("rating", 20.0))
	return total / float(maxi(mastery_profiles.size(), 1))

func get_mastered_adventure_count() -> int:
	var count: int = 0
	for profile_variant: Variant in mastery_profiles.values():
		if float((profile_variant as Dictionary).get("rating", 0.0)) >= 70.0:
			count += 1
	return count

func get_total_variant_count() -> int:
	var total: int = 0
	for variants_variant: Variant in VARIANTS.values():
		total += (variants_variant as Array).size()
	return total

func export_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"mastery_profiles": mastery_profiles.duplicate(true),
		"active_session": active_session.duplicate(true),
		"history": history.duplicate(true),
		"total_completed_sessions": total_completed_sessions,
		"total_transfer_masteries": total_transfer_masteries
	}

func import_state(data: Dictionary) -> void:
	mastery_profiles = (data.get("mastery_profiles", {}) as Dictionary).duplicate(true)
	active_session = (data.get("active_session", {}) as Dictionary).duplicate(true)
	history = _dictionary_array(data.get("history", []), MAX_HISTORY)
	total_completed_sessions = maxi(int(data.get("total_completed_sessions", 0)), 0)
	total_transfer_masteries = maxi(int(data.get("total_transfer_masteries", 0)), 0)
	for adventure_id_variant: Variant in ADVENTURES.keys():
		_ensure_profile(str(adventure_id_variant))
	if not active_session.is_empty():
		var current_round: Dictionary = active_session.get("current_round", {}) as Dictionary
		current_round["started_at_msec"] = Time.get_ticks_msec()
		active_session["current_round"] = current_round
	catalog_changed.emit(get_catalog())

func reset_state(remove_files: bool = true) -> void:
	mastery_profiles.clear()
	active_session.clear()
	history.clear()
	total_completed_sessions = 0
	total_transfer_masteries = 0
	for adventure_id_variant: Variant in ADVENTURES.keys():
		_ensure_profile(str(adventure_id_variant))
	if remove_files:
		for path: String in [SAVE_PATH, TEMP_PATH, BACKUP_PATH]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	save_state()
	catalog_changed.emit(get_catalog())

func save_state() -> bool:
	var payload: Dictionary = export_state()
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var temporary: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temporary == null:
		return false
	temporary.store_string(JSON.stringify(payload))
	temporary.close()
	if FileAccess.file_exists(SAVE_PATH) and not _read_payload(SAVE_PATH).is_empty():
		_copy_file(SAVE_PATH, BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		var remove_error: Error = DirAccess.remove_absolute(SAVE_PATH)
		if remove_error != OK:
			return false
	var rename_error: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			_copy_file(BACKUP_PATH, SAVE_PATH)
		return false
	return true

func load_state() -> bool:
	for path: String in [SAVE_PATH, BACKUP_PATH]:
		var payload: Dictionary = _read_payload(path)
		if payload.is_empty():
			continue
		import_state(payload)
		return true
	return false

func _build_round(session: Dictionary) -> Dictionary:
	var adventure_id: String = str(session.get("adventure_id", "pattern_relay"))
	var definition: Dictionary = ADVENTURES[adventure_id]
	var variants: Array = VARIANTS.get(adventure_id, []) as Array
	var order: Array = session.get("variant_order", []) as Array
	var index: int = int(session.get("round_index", 0))
	var core_rounds: int = int(session.get("core_rounds", 3))
	var transfer: bool = index >= core_rounds
	var variant_index: int = int(order[index % maxi(order.size(), 1)]) if not order.is_empty() else index % maxi(variants.size(), 1)
	var variant: Dictionary = (variants[variant_index % maxi(variants.size(), 1)] as Dictionary).duplicate(true)
	var prompt: String = str(variant.get("prompt", "Welche Lösung passt?"))
	if transfer:
		prompt = "%s\n\n%s" % [str(definition.get("transfer_prompt", "Übertrage dein Wissen.")), prompt]
	var difficulty: int = int(session.get("difficulty", 1))
	var age_profile: Dictionary = session.get("age_profile", {}) as Dictionary
	var base_window: float = float(variant.get("window", 0.15))
	variant["id"] = "%s_%d_%d" % [adventure_id, int(session.get("seed", 0)), index]
	variant["adventure_id"] = adventure_id
	variant["title"] = str(definition.get("title", adventure_id.capitalize()))
	variant["domain"] = str(definition.get("domain", "logic"))
	variant["mechanic"] = str(definition.get("mechanic", "choice"))
	variant["prompt"] = prompt
	variant["round_index"] = index
	variant["round_number"] = index + 1
	variant["total_rounds"] = int(session.get("total_rounds", core_rounds + 1))
	variant["difficulty"] = difficulty
	variant["transfer"] = transfer
	variant["age_band"] = str(session.get("age_band", "adult"))
	variant["age_label"] = str(age_profile.get("label", "VERTIEFT"))
	variant["window"] = clampf(base_window + float(age_profile.get("support", 0.0)) - float(difficulty - 1) * 0.005, 0.07, 0.28)
	variant["started_at_msec"] = Time.get_ticks_msec()
	return variant

func _resolve_round(score_value: float, selected_index: int, selected_text: String) -> Dictionary:
	var round_data: Dictionary = active_session.get("current_round", {}) as Dictionary
	var hints: int = int(active_session.get("current_hints", 0))
	var support_penalty: float = minf(float(hints) * 0.04, 0.16)
	var score: float = clampf(score_value - support_penalty, 0.0, 1.0)
	var success: bool = score >= 0.58
	var response_seconds: float = maxf(float(Time.get_ticks_msec() - int(round_data.get("started_at_msec", Time.get_ticks_msec()))) / 1000.0, 0.0)
	var best_index: int = _best_option_index(round_data.get("scores", []) as Array)
	var result: Dictionary = {
		"accepted": true,
		"adventure_id": str(active_session.get("adventure_id", "")),
		"round_index": int(active_session.get("round_index", 0)),
		"round_number": int(round_data.get("round_number", 1)),
		"total_rounds": int(round_data.get("total_rounds", 1)),
		"transfer": bool(round_data.get("transfer", false)),
		"success": success,
		"score": score,
		"raw_score": clampf(score_value, 0.0, 1.0),
		"selected_index": selected_index,
		"selected_text": selected_text,
		"best_index": best_index,
		"best_answer": _option_at(round_data.get("options", []) as Array, best_index),
		"hints_used": hints,
		"response_seconds": response_seconds,
		"explanation": str(round_data.get("explanation", "Jeder Versuch liefert neue Information."))
	}
	var round_results: Array = active_session.get("round_results", []) as Array
	round_results.append(result.duplicate(true))
	active_session["round_results"] = round_results
	round_resolved.emit(result.duplicate(true))
	var next_index: int = int(active_session.get("round_index", 0)) + 1
	if next_index < int(active_session.get("total_rounds", 1)):
		active_session["round_index"] = next_index
		active_session["current_hints"] = 0
		active_session["current_round"] = _build_round(active_session)
		result["session_complete"] = false
		result["next_round"] = (active_session.get("current_round", {}) as Dictionary).duplicate(true)
		save_state()
		round_created.emit((active_session.get("current_round", {}) as Dictionary).duplicate(true))
		return result
	var completion: Dictionary = _complete_session()
	result["session_complete"] = true
	result["completion"] = completion
	return result

func _complete_session() -> Dictionary:
	var session: Dictionary = active_session.duplicate(true)
	var results: Array = session.get("round_results", []) as Array
	var score_total: float = 0.0
	var successes: int = 0
	for result_variant: Variant in results:
		var result: Dictionary = result_variant as Dictionary
		score_total += float(result.get("score", 0.0))
		if bool(result.get("success", false)):
			successes += 1
	var average_score: float = score_total / float(maxi(results.size(), 1))
	var transfer_score: float = float((results.back() as Dictionary).get("score", 0.0)) if not results.is_empty() else 0.0
	var success: bool = average_score >= 0.58 and successes >= int(ceil(float(results.size()) * 0.5))
	var adventure_id: String = str(session.get("adventure_id", ""))
	var profile: Dictionary = _ensure_profile(adventure_id)
	var old_rating: float = float(profile.get("rating", 20.0))
	var difficulty: int = int(session.get("difficulty", 1))
	var target_rating: float = float(difficulty * 10)
	var expected: float = 1.0 / (1.0 + pow(10.0, (target_rating - old_rating) / 40.0))
	var delta: float = 14.0 * (average_score - expected)
	if delta < 0.0:
		delta = maxf(delta, -3.5)
	var new_rating: float = clampf(old_rating + delta, MIN_RATING, MAX_RATING)
	profile["rating"] = new_rating
	profile["sessions"] = int(profile.get("sessions", 0)) + 1
	profile["successful_sessions"] = int(profile.get("successful_sessions", 0)) + (1 if success else 0)
	profile["total_rounds"] = int(profile.get("total_rounds", 0)) + results.size()
	profile["best_score"] = maxf(float(profile.get("best_score", 0.0)), average_score)
	profile["last_score"] = average_score
	profile["last_difficulty"] = difficulty
	profile["last_played_at"] = int(Time.get_unix_time_from_system())
	profile["current_streak"] = int(profile.get("current_streak", 0)) + 1 if success else 0
	profile["best_streak"] = maxi(int(profile.get("best_streak", 0)), int(profile.get("current_streak", 0)))
	var transfer_mastered_now: bool = transfer_score >= 0.72
	if transfer_mastered_now:
		profile["transfer_masteries"] = int(profile.get("transfer_masteries", 0)) + 1
		total_transfer_masteries += 1
	var seen: Dictionary = profile.get("variants_seen", {}) as Dictionary
	for result_variant: Variant in results:
		var result: Dictionary = result_variant as Dictionary
		seen[str(result.get("round_index", 0))] = true
	profile["variants_seen"] = seen
	mastery_profiles[adventure_id] = profile
	total_completed_sessions += 1
	var xp_reward: int = int(round(18.0 + average_score * 30.0 + float(difficulty) * 3.0 + (12.0 if transfer_mastered_now else 0.0)))
	var impact: Dictionary = _apply_world_impact(adventure_id, success, average_score, transfer_score, xp_reward)
	var completion: Dictionary = {
		"accepted": true,
		"adventure_id": adventure_id,
		"title": str((ADVENTURES.get(adventure_id, {}) as Dictionary).get("title", adventure_id.capitalize())),
		"success": success,
		"score": average_score,
		"transfer_score": transfer_score,
		"transfer_mastered": transfer_mastered_now,
		"successes": successes,
		"rounds": results.size(),
		"difficulty": difficulty,
		"old_rating": old_rating,
		"rating": new_rating,
		"mastery_level": _mastery_level(new_rating),
		"xp_reward": xp_reward,
		"impact": impact,
		"age_band": str(session.get("age_band", "adult"))
	}
	_remember("completed", completion)
	active_session.clear()
	save_state()
	if not is_equal_approx(old_rating, new_rating):
		mastery_changed.emit(adventure_id, old_rating, new_rating)
	if transfer_mastered_now:
		transfer_mastered.emit(adventure_id, completion.duplicate(true))
	adventure_completed.emit(completion.duplicate(true))
	catalog_changed.emit(get_catalog())
	return completion

func _apply_world_impact(adventure_id: String, success: bool, score: float, transfer_score: float, xp_reward: int) -> Dictionary:
	var definition: Dictionary = ADVENTURES.get(adventure_id, {}) as Dictionary
	var quality: float = clampf(0.45 + score * 1.35, 0.45, 1.80)
	var impact: Dictionary = {"xp": xp_reward, "quality": quality}
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and state.has_method("apply_learning_result"):
		state.call("apply_learning_result", {"accepted": true, "success": success, "score": score, "xp_reward": xp_reward, "adventure_id": adventure_id})
		if transfer_score >= 0.72 and state.has_method("add_memory"):
			state.call("add_memory", "learning_transfer", "%s wurde in einer neuen Situation angewendet." % str(definition.get("title", adventure_id)))
	var development: Node = get_node_or_null("/root/DevelopmentProfile")
	if development != null and development.has_method("record_interaction"):
		var tags: Array[String] = _string_array(definition.get("tags", []))
		development.call("record_interaction", str(definition.get("interaction", "learn")), tags, quality)
		impact["development"] = str(definition.get("interaction", "learn"))
	var partner: Node = get_node_or_null("/root/PartnerWorld")
	if partner != null:
		if partner.has_method("observe_technique"):
			impact["technique"] = partner.call("observe_technique", str(definition.get("technique", "pattern_focus")), quality)
		if partner.has_method("add_settlement_xp"):
			var settlement_xp: int = int(round(6.0 + score * 14.0 + transfer_score * 8.0))
			partner.call("add_settlement_xp", settlement_xp)
			impact["settlement_xp"] = settlement_xp
		if transfer_score >= 0.82 and partner.has_method("award_legacy_points"):
			partner.call("award_legacy_points", 2.0 + transfer_score * 2.0, "learning_transfer")
			impact["legacy_points"] = 2.0 + transfer_score * 2.0
	var adaptive: Node = get_node_or_null("/root/AdaptiveLearning")
	if adaptive != null and adaptive.has_method("record_result"):
		impact["adaptive_profile"] = adaptive.call("record_result", str(definition.get("domain", "logic")), int(active_session.get("difficulty", 1)), success, _session_response_seconds(), int(active_session.get("hints_total", 0)))
	var evolution: Node = get_node_or_null("/root/EvolutionMatrix")
	if evolution != null and evolution.has_method("evaluate_runtime"):
		var forecast: Array = evolution.call("evaluate_runtime") as Array
		impact["evolution_best"] = (forecast[0] as Dictionary).get("id", "") if not forecast.is_empty() else ""
	var dialogue: Node = get_node_or_null("/root/DialogueDirector")
	if dialogue != null and dialogue.has_method("emit_line"):
		impact["dialogue"] = dialogue.call("emit_line", "learn", {"learning_domain": str(definition.get("domain", "logic")), "learning_score": score, "transfer": transfer_score >= 0.72})
	var performance: Node = get_node_or_null("/root/CharacterPerformance")
	if performance != null and performance.has_method("request_action"):
		performance.call("request_action", "learn", clampf(score, 0.35, 1.0))
	var audio: Node = get_node_or_null("/root/OmniAudio")
	if audio != null and audio.has_method("play_learning_cue"):
		audio.call("play_learning_cue", "transfer" if transfer_score >= 0.72 else "complete" if success else "retry", score)
	var quest: Node = get_node_or_null("/root/QuestService")
	if quest != null and quest.has_method("record_event"):
		quest.call("record_event", "learning_adventure_completed")
	if state != null and state.has_method("save_game_state"):
		state.call("save_game_state")
	return impact

func _ensure_profile(adventure_id: String) -> Dictionary:
	if not mastery_profiles.has(adventure_id):
		mastery_profiles[adventure_id] = {
			"rating": 20.0,
			"sessions": 0,
			"successful_sessions": 0,
			"total_rounds": 0,
			"best_score": 0.0,
			"last_score": 0.0,
			"last_difficulty": 1,
			"current_streak": 0,
			"best_streak": 0,
			"transfer_masteries": 0,
			"variants_seen": {},
			"last_played_at": 0
		}
	return mastery_profiles[adventure_id] as Dictionary

func _mastery_level(rating: float) -> int:
	return clampi(1 + int(floor(clampf(rating, 0.0, 100.0) / 20.0)), 1, 6)

func _adaptive_rating(domain: String) -> float:
	var adaptive: Node = get_node_or_null("/root/AdaptiveLearning")
	if adaptive != null and adaptive.has_method("get_skill_profile"):
		return float((adaptive.call("get_skill_profile", domain) as Dictionary).get("rating", 20.0))
	return 20.0

func _age_band() -> String:
	var development: Node = get_node_or_null("/root/DevelopmentProfile")
	if development != null and development.has_method("get_display_snapshot"):
		var snapshot: Dictionary = development.call("get_display_snapshot") as Dictionary
		var band: String = str(snapshot.get("player_age_band", "adult"))
		if AGE_PROFILES.has(band):
			return band
	return "adult"

func _variant_order(adventure_id: String, seed_value: int) -> Array[int]:
	var variants: Array = VARIANTS.get(adventure_id, []) as Array
	var order: Array[int] = []
	for index: int in range(variants.size()):
		order.append(index)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: int = order[index]
		order[index] = order[swap_index]
		order[swap_index] = temporary
	return order

func _best_option_index(scores: Array) -> int:
	var best_index: int = -1
	var best_score: float = -1.0
	for index: int in range(scores.size()):
		var score: float = float(scores[index])
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _option_at(options: Array, index: int) -> String:
	return str(options[index]) if index >= 0 and index < options.size() else ""

func _session_response_seconds() -> float:
	if active_session.is_empty():
		return 0.0
	return maxf(float(Time.get_ticks_msec() - int(active_session.get("started_at_msec", Time.get_ticks_msec()))) / 1000.0, 0.0)

func _connect_game_state() -> void:
	var state: Node = get_node_or_null("/root/GameState")
	if state != null and state.has_signal("state_changed"):
		var callback: Callable = Callable(self, "_on_game_state_changed")
		if not state.is_connected("state_changed", callback):
			state.connect("state_changed", callback)

func _on_game_state_changed(key: String, _value: Variant) -> void:
	if key == "new_game":
		reset_state()

func _remember(event_type: String, data: Dictionary) -> void:
	history.append({"type": event_type, "data": data.duplicate(true), "at": int(Time.get_unix_time_from_system())})
	while history.size() > MAX_HISTORY:
		history.pop_front()

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var payload: Dictionary = parsed as Dictionary
	return payload if int(payload.get("version", 0)) > 0 else {}

func _copy_file(source: String, target: String) -> bool:
	var source_file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	var bytes: PackedByteArray = source_file.get_buffer(source_file.get_length())
	source_file.close()
	var target_file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	if target_file == null:
		return false
	target_file.store_buffer(bytes)
	target_file.close()
	return true

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			result.append(str(entry))
	return result

func _dictionary_array(value: Variant, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate(true))
	while result.size() > limit:
		result.pop_front()
	return result

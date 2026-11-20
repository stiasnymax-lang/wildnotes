# WildNotes (Flutter)

Flutter-Portierung der Android-App aus `../alt_application`: Protokollierung von
Tieren in ihren Gehegen mit Login (Firebase Auth), Firestore-Datenbank und
interaktiver Zookarte.

## Struktur

| Alt (Java/Activity)                      | Neu (Dart/Screen)                              |
| ---------------------------------------- | ---------------------------------------------- |
| `MainActivity`                           | `lib/auth/welcome_screen.dart`                 |
| `auth/LoginActivity`, `RegisterActivity` | `lib/auth/login_screen.dart`, `register_screen.dart` |
| Bottom Navigation in jeder Activity      | `lib/core/main_shell.dart`                     |
| `core/HomeActivity`                      | `lib/core/home_screen.dart`                    |
| `core/MapActivity`                       | `lib/core/map_screen.dart` + `map_hotspots.dart` |
| `core/EnclosureActivity`                 | `lib/core/enclosure_screen.dart`               |
| `core/LibraryActivity`                   | `lib/core/library_screen.dart`                 |
| `core/SettingsActivity`                  | `lib/core/settings_screen.dart`                |
| `feature_animals/*`                      | `lib/feature_animals/*`                        |
| `feature_events/*`                       | `lib/feature_events/*`                         |

Neu dazu: `lib/org/` (Organisationen, Rollen, Einladungen) und
`lib/feature_appointments/` (Terminkalender, Gehege-Ampel auf der Karte).

## Firestore-Struktur

```
users/{uid}                         activeOrgId, email
users/{uid}/memberships/{orgId}     orgName
organizations/{orgId}               name, ownerId, roles{id: {name, permissions[]}}
  members/{uid}                     email, role
  invitations/{email}               email, orgId, orgName, role, invitedByEmail
  animals/{id}                      name, info, enclosureNr
    events/{id}                     name, info, date
  enclosures/{id}                   enclosureNr, name
  appointments/{id}                 subject, description, start, end,
                                    animalIds[], animalNames{}, participantIds[],
                                    participantEmails{}, done, doneByEmail
```

Die alten Top-Level-Collections `animals` und `enclosures` bleiben erhalten,
sind laut `firestore.rules` aber nur noch für das Konto des Projektinhabers
zugänglich (alte Android-App und Übernahme in eine Organisation). Nur dieses
Konto sieht in der App die Option „Bisherige Tiere & Gehege übernehmen“.
Weitere Konten freischalten: UID in `isLegacyOwner()` ergänzen und die Regeln
neu veröffentlichen.

Sicherheitsregeln und Index: `firestore.rules`, `firestore.indexes.json`.
Veröffentlichen mit `firebase deploy --only firestore`.

## Voraussetzungen

- **Windows-Entwicklermodus** aktivieren (Flutter braucht Symlinks für Plugins):
  `start ms-settings:developers`
- **Android SDK Command-line Tools** installieren (Android Studio → SDK Manager →
  SDK Tools → „Android SDK Command-line Tools“), danach `flutter doctor --android-licenses`.

## Starten

```powershell
flutter pub get
flutter run
```

### Firebase-Konfiguration (nicht im Repository)

`lib/firebase_options.dart` und `android/app/google-services.json` enthalten die
API-Keys und sind deshalb in `.gitignore` eingetragen. Nach dem Klonen einmal
erzeugen (Projekt `wildnotes-b8a05`):

```powershell
flutterfire configure --project=wildnotes-b8a05 --platforms=android,ios,web --android-package-name=hsa.de --ios-bundle-id=hsa.flutterApplicationTiergarto
```

Für den automatischen Web-Build auf GitHub liegt der Inhalt von
`lib/firebase_options.dart` im Repository-Secret **`FIREBASE_OPTIONS_DART`**
(Settings → Secrets and variables → Actions). Nach einem erneuten
`flutterfire configure` das Secret aktualisieren.

Hinweis: Bei einer Web-App ist der Firebase-API-Key im ausgelieferten
JavaScript immer sichtbar – das ist bei Firebase so vorgesehen. Geschützt wird
über die Firestore-Sicherheitsregeln und über Einschränkungen des Keys in der
Google Cloud Console (erlaubte Websites/Android-App).

Android nutzt weiterhin die Application ID `hsa.de` der alten App.
Zum Testen ohne Android-Gerät: `flutter run -d chrome`.

## Web-App & Hosting (GitHub Pages)

Die App läuft auch im Browser und lässt sich dort als App installieren
(„Zum Startbildschirm hinzufügen“). Das Layout passt sich dem Gerät an:

- **Handy:** Navigation unten
- **Tablet (ab 840 px):** Navigationsleiste links, Kalender zweispaltig
- **Desktop (ab 1200 px):** Navigationsleiste mit Beschriftung,
  Inhalte zentriert mit begrenzter Breite
- Helles/dunkles Design folgt automatisch der Systemeinstellung.

Veröffentlicht wird automatisch über GitHub Actions
(`.github/workflows/deploy-web.yml`) bei jedem Push auf `main`:

1. Repository auf GitHub anlegen (öffentlich – GitHub Pages ist für private
   Repositories nur mit kostenpflichtigem Plan verfügbar) und pushen.
2. Auf GitHub: **Settings → Pages → Build and deployment → Source:
   „GitHub Actions“** auswählen.
3. Nach dem nächsten Push (oder „Actions → Web-App veröffentlichen → Run
   workflow“) ist die App unter `https://<benutzer>.github.io/<repository>/`
   erreichbar.

Lokal testen: `flutter run -d chrome`

## Tests

```powershell
flutter test
```

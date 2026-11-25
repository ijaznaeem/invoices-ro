# Firebase setup and SQLite migration

The app uses Firebase Authentication and Cloud Firestore in project **`invoices-ro`** (project number `442149700791`). Android and iOS Firebase app configurations are checked in. Google login reuses the existing `roinvoices` OAuth identity. Its Web client ID is configured in the app and has been added to Firebase's external-client safelist. Google sign-in and migration were verified on the connected Samsung phone. Google sign-in is enabled, the default Firestore database exists in `nam5`, and owner-only security rules are deployed.

## Run the configured app

```powershell
flutter pub get
flutter run
```

The configured Web OAuth client is `788321164761-tidq3hc8ofa8j5occckd39ok2f9psq8e.apps.googleusercontent.com` from `roinvoices`. Normal builds need no extra flags. `--dart-define=FIREBASE_WEB_CLIENT_ID=...` remains an optional override for another verified Web client in that project.

Android package: `com.octavions.invoices_ro`. iOS bundle ID: `com.octavions.invoicesRo`. The local Android debug certificate's SHA-1 and SHA-256 are registered. If you use a different release key or Google Play App Signing, register those certificates too.

To regenerate Firebase options later:

```powershell
flutterfire configure --project=invoices-ro --platforms=android,ios
firebase deploy --only firestore:rules --project=invoices-ro
```

After regeneration, retain the original `roinvoices` Google sign-in IDs in `lib/firebase_server_client.dart` and the matching `GIDClientID`/reversed URL scheme in `ios/Runner/Info.plist`. The generated `firebase_options.dart` continues to identify the separate `invoices-ro` Firebase project. These are public client identifiers; no OAuth client secret belongs in the application.

The optional Drive backup feature retains the original `roinvoices` OAuth identity to preserve access to its private Drive app-data folder. Firebase data lives in `invoices-ro`; safelisting the original Google clients allows the same Google identity to authenticate to that project. Local ZIP backups remain compatible.

### Existing Google Drive OAuth client

The prior Google Drive project is `roinvoices` (`788321164761`). If Google rejects a new Android OAuth client because the package/SHA-1 pair is already in use, inspect that project's existing client before making further changes. The existing Drive client should be retained.

Firebase supports using an external project's Google OAuth client: open **Authentication > Sign-in method > Google > Safelist client IDs from external projects** in `invoices-ro` and add the verified existing client IDs. The app's Google sign-in configuration must use the corresponding original project IDs as well. See [Firebase's cross-project OAuth instructions](https://support.google.com/firebase/answer/6401008?hl=en).

## Android build compatibility

Some dependencies still apply the Kotlin Gradle Plugin. Keep `android.builtInKotlin=false`, `android.newDsl=false`, and the explicit `org.jetbrains.kotlin.android` plugin in the app module until all dependencies support built-in Kotlin. This also avoids the Kotlin plugin's cross-drive diagnostic crash when the Pub cache is on `C:` and this workspace is on `G:`.

Official references: [Flutter setup](https://firebase.google.com/docs/flutter/setup), [Google sign-in](https://firebase.google.com/docs/auth/flutter/federated-auth), [transactions](https://firebase.google.com/docs/firestore/manage-data/transactions), [offline persistence](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

## What migration does

- The first successful sign-in imports this installation's existing `ledger.db`. It upgrades a working copy (`ledger.db.firestore-import`), preserving the original SQLite file and WAL.
- All twelve collections are imported: clients, templates, invoices, payments, taxes, expense heads, expenses, cash receipts, ledger entries, payment options, business settings, and notifications.
- A frozen import plan is saved before uploading. Imports use small transactions and a completion marker, so an interrupted import can resume. Conflicting existing documents are never silently overwritten.
- Empty cloud ledgers retain SQLite IDs. When merging into an existing ledger, deterministic IDs remap foreign keys and journal references. Conflicting invoice numbers receive a migration suffix; the original number remains in `legacy_invoice_number`. Existing cloud business settings take precedence.
- This installation's local ledger binds to the first Firebase UID receiving its import. Switching accounts does not automatically copy the original SQLite data into another account.
- Logos are stored with the business settings and materialized locally for PDF generation. Logos larger than 650 KB must be resized before import.

The ledger stays closed until authentication and migration succeed. There is no fallback that continues writing financial records to SQLite. Keep an exported backup before deploying the migration to existing users. An upgrade must retain the app's package ID and signing identity; uninstalling first would remove its private SQLite data.

## Storage and accounting

Normal collections live at `users/{uid}/{collection}/{integerId}`. Financial operations use Firestore transactions: invoice and journal creation, payments and receipts, and recurring invoice generation commit together. Invoice numbers are allocated with a transactional counter. Other-device changes update the UI through snapshot listeners.

Firestore persistence supports cached reads after the account has been opened. Financial transactions require an internet connection. No assumption is made that a local cache is a complete ledger on a newly installed device.

## Backups and restore

New ZIP backups contain `ledger.json` (schema 7), `manifest.json` (format 2), and an optional logo. Existing format-1 SQLite backups can still be restored.

Restore validates records, uploads them into `users/{uid}/datasets/{generation}/...`, then atomically changes `users/{uid}/metadata/storage.activeDataset`. Other devices follow this pointer. Upload failures leave the old ledger active. Previous generations remain stored for recovery; removing them is a separate administrative task.

Restore replaces the **account's ledger on all devices**. Close the app on other devices while restoring. Transactions verify the active generation so stale devices cannot commit financial changes into a different generation. New edits made in the old generation during staging are not included in the restored backup.

## Verification

```powershell
flutter test
flutter analyze --no-fatal-infos
```

Unit tests use `fake_cloud_firestore`, including owner access checks against the checked-in rules. They do not substitute for testing native Google sign-in, real Firestore transaction retries, deployed rules, and migration from a device with production data. Once Firebase is configured, verify those flows on a test Firebase project and two devices before release.

## Verified phone migration — 2026-11-25

The Samsung phone's installed app used a different signing certificate. With explicit user approval, the old app was replaced after verifying a fresh format-1 backup. All 36 original database records and the business logo were restored before first launch, then verified against Cloud Firestore after Google sign-in. Additional payments and their accounting entries were also present in Firestore.

Original backup, original APK, and verification receipts are retained in `migration_backups/phone-2026-11-25/`, which is excluded from Git and survives `flutter clean`. Local backup preferences reset during reinstall; configure the desired schedule and optional Drive upload again in Backup & Restore.

The debug APK builds successfully; all 22 tests pass. Offline UI fonts are bundled. The Windows Subsystem for Android emulator lacks working Google Play services, so Google sign-in validation used the Samsung phone.

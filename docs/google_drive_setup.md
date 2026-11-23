# Google Drive backups (Android and iOS)

The app uses `google_sign_in` 6.2.2 and Drive API v3. Backups contain the
SQLite database and business logo. They live in Google's private `appDataFolder`,
so they do not appear in My Drive. Use Backup & Restore in the app to list and
restore them. Use the same Google account and Cloud project after reinstalling.

## 1. Configure Google Cloud

1. Open [Google Cloud Console](https://console.cloud.google.com/) and create or
   select the project that will own this app's OAuth credentials.
2. Under APIs & Services → Library, enable **Google Drive API**.
3. Configure Google Auth Platform (OAuth consent screen): fill in the app name,
   support email, developer contact, and audience. For a personal Gmail account,
   choose External. While the app is in Testing, add your Google account as a
   test user.
4. Under Data Access, add this scope:
   `https://www.googleapis.com/auth/drive.appdata`.
5. Under Clients (or APIs & Services → Credentials), create an **Android** OAuth
   client with:

   - Package: `com.octavions.invoices_ro`
   - SHA-1 for the APK's signing certificate.

On this development machine, the current debug certificate SHA-1 is:

```text
AA:9C:B9:78:B1:D8:B9:14:87:5A:6A:0F:C3:35:F7:51:A7:B9:DF:2F
```

Confirm it yourself in PowerShell:

```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

For all build variants, run from the project:

```powershell
Set-Location android
.\gradlew.bat signingReport
```

Currently, `android/app/build.gradle.kts` also signs release builds with the debug
key. When setting up production signing, register that release certificate's
SHA-1 too. For Play Store builds, use the **app signing** certificate SHA-1 from
Play Console. A separate Android OAuth client can be registered for each
certificate in the same Cloud project.

For this Android integration and the pinned plugin version, no Firebase project,
`google-services.json`, client secret, or pasted client ID is required. The
Android OAuth client identifies the application using package and signing SHA-1.
Do not embed a client secret in the app.

6. In the same Cloud project, create an **iOS** OAuth client with bundle ID
   `com.octavions.invoicesRo`. Copy `CLIENT_ID` into `GIDClientID` and
   `REVERSED_CLIENT_ID` into `CFBundleURLTypes` in `ios/Runner/Info.plist`.
   Do not add `GoogleService-Info.plist` to the Flutter project.

## 2. Build and test on Android

```powershell
flutter pub get
flutter run -d <android_device_id>
```

1. Open **Backup & Restore** and enable **Upload after each backup**.
2. Choose your configured test account and grant the requested permission.
3. Tap **Back up now**. A local backup is retained even if Drive upload fails.
4. Tap **Refresh Drive backups** and verify the new archive is listed.
5. To retry an upload, use a local backup's menu → **Upload to Google Drive**.
6. To restore, tap a Drive backup's restore button and confirm. The app downloads
   the archive and makes a local safety backup before replacing your data.

Test restore with disposable data first: create a backup, change a record, then
restore and confirm that the original record and logo return.

The schedule is checked when the app opens/resumes; it is not an Android
background job and will not run while the app is closed. Retention applies to
local app backups and Drive archives; separate exported/Documents copies are
not pruned by this setting. Disconnecting revokes the app's access; it does not
delete your existing Drive archives.

## Troubleshooting

- **Android error 10 / DEVELOPER_ERROR:** the installed app's package and signing
  SHA-1 must exactly match an Android OAuth client in the correct Cloud project.
- **403 / accessNotConfigured:** enable Google Drive API in that project.
- **Access denied in Testing:** add the selected Google account as a test user.
- **Reconnect requested:** use **Reconnect Google Drive** and authorize again.
- **No archives after reinstall:** check the Google account, package and Cloud
  project. Archives are private to that application, not ordinary My Drive files.
- **Windows or web:** Drive backup is configured for Android and iOS only.

## References

- [Pinned Flutter Google Sign-In integration documentation](https://pub.dev/packages/google_sign_in/versions/6.2.2)
- [Google Drive application data folder](https://developers.google.com/workspace/drive/api/guides/appdata)
- [Drive files.list and pagination](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/list)

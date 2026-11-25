/// Existing roinvoices Google OAuth identity, shared by Drive and Firebase.
/// The Web client must be safelisted in the invoices-ro Firebase project.
/// A build can override it with --dart-define=FIREBASE_WEB_CLIENT_ID=... .
const String firebaseAndroidServerClientId = String.fromEnvironment(
  'FIREBASE_WEB_CLIENT_ID',
  defaultValue:
      '788321164761-tidq3hc8ofa8j5occckd39ok2f9psq8e.apps.googleusercontent.com',
);

const String googleIosClientId =
    '788321164761-h6e8rp04jli0414uhtuvoqbcoi550lqp.apps.googleusercontent.com';

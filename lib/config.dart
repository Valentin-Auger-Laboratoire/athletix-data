/// URL de base de l'API PHP (dossier `backend/`). C'est la seule constante à modifier.
///
/// Elle peut aussi être fixée à la compilation, sans toucher au code :
/// `flutter run -d chrome --dart-define=API_BASE_URL=https://mon-serveur.exemple/backend`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost/athletix-data/backend',
);

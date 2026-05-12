import 'firebase_options/prod.dart' deferred as prod;
import 'main.dart' deferred as source;

Future<void> main() async {
  await prod.loadLibrary();
  await source.loadLibrary();

  return source.main(
    firebaseOptions: prod.DefaultFirebaseOptions.currentPlatform,
  );
}

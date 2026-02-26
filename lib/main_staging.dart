import 'firebase_options/staging.dart' deferred as staging;
import 'main.dart' deferred as source;

Future<void> main() async {
  await staging.loadLibrary();
  await source.loadLibrary();

  return source.main(firebaseOptions: staging.DefaultFirebaseOptions.currentPlatform);
}

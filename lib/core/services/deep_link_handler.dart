// import 'dart:async';
// import 'package:flutter/services.dart';
// import 'package:flutter/widgets.dart';
// import 'package:uni_links/uni_links.dart';

// class DeepLinkHandler {
//   static bool _initialUriIsHandled = false;

//   /// Handle initial deep link if the app was launched from a link
//   static Future<void> handleInitialDeepLink(void Function(Uri) onLink) async {
//     if (!_initialUriIsHandled) {
//       _initialUriIsHandled = true;
//       try {
//         final uri = await getInitialUri();
//         if (uri != null) {
//           onLink(uri);
//         }
//       } on PlatformException {
//         debugPrint('Failed to get initial uri.');
//       }
//     }
//   }

//   /// Listen for deep links while the app is running
//   static StreamSubscription? listenToDeepLinks(void Function(Uri) onLink) {
//     return uriLinkStream.listen((Uri? uri) {
//       if (uri != null) {
//         onLink(uri);
//       }
//     }, onError: (err) {
//       debugPrint('Deep link error: $err');
//     });
//   }

//   /// Parse the deep link and handle navigation
//   static void handleDeepLink(Uri uri, BuildContext context) {
//     // Example: handling different paths
//     switch (uri.path) {
//       case '/note':
//         final noteId = uri.queryParameters['id'];
//         if (noteId != null) {
//           // Navigate to specific note
//           // Navigator.pushNamed(context, '/note/$noteId');
//         }
//         break;
//       case '/tag':
//         final tagName = uri.queryParameters['name'];
//         if (tagName != null) {
//           // Navigate to tag view
//           // Navigator.pushNamed(context, '/tag/$tagName');
//         }
//         break;
//       // Add more cases as needed
//     }
//   }
// }

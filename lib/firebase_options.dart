import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError('This app only supports Android and web platforms.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCzapltT_RItwO0lCP-S3qPkXlkIIqfKqc',
    appId: '1:717667508105:android:d9ccc389bc899998000b58',
    messagingSenderId: '717667508105',
    projectId: 'prostock-a913b',
    storageBucket: 'prostock-a913b.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCzapltT_RItwO0lCP-S3qPkXlkIIqfKqc',
    appId: '1:717667508105:android:d9ccc389bc899998000b58',
    messagingSenderId: '717667508105',
    projectId: 'prostock-a913b',
    storageBucket: 'prostock-a913b.firebasestorage.app',
  );
}

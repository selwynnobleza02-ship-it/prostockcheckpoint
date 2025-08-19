import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart'; // New

// A mock implementation of [FirebaseAppPlatform].
class MockFirebaseApp extends Mock
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {
  MockFirebaseApp({required String name, required FirebaseOptions options});

  @override
  Future<void> delete() {
    return Future.value();
  }
}

/// A mock implementation of [FirebasePlatform].
class MockFirebasePlatform extends Mock
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  MockFirebasePlatform() : super();

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp(name: name!, options: options!);
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp(
      name: name,
      options: const FirebaseOptions(
        apiKey: 'testApiKey',
        appId: 'testAppId',
        messagingSenderId: 'testSenderId',
        projectId: 'testProjectId',
      ),
    );
  }
}

/// Sets up the mock Firebase environment for tests.
void setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = MockFirebasePlatform();
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) {
      debugPrint(
        '[Auth] Firebase initialized: project=${app.options.projectId}, '
        'appId=${app.options.appId}',
      );
    }
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('[Auth] Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    rethrow;
  }

  runApp(const GrihSetuApp(enableAuthentication: true));
}

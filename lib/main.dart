import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'services/errors/firebase_error_mapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global uncaught error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final failure = FirebaseErrorMapper.map(details.exception, details.stack);
    debugPrint('[GlobalError] FlutterError: $failure');
    // TODO: Crashlytics - FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    final failure = FirebaseErrorMapper.map(error, stack);
    debugPrint('[GlobalError] PlatformError: $failure');
    // TODO: Crashlytics - FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Something went wrong. Please restart the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      );
    };
  }

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

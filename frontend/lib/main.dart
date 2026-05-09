import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: TrashBountyApp()));
}

class TrashBountyApp extends StatelessWidget {
  const TrashBountyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TrashBounty Lumi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: routerProvider,
    );
  }
}


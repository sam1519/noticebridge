import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..boot()),
        ChangeNotifierProvider(create: (_) => ThemeController()..load()),
      ],
      child: const NoticeBridgeApp(),
    ),
  );
}

class NoticeBridgeApp extends StatelessWidget {
  const NoticeBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'NoticeBridge',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(theme.palette),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (!auth.ready) {
            return Scaffold(
              body: AuroraBackground(
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: const [
                    BridgeLogo(size: 120),
                    SizedBox(height: 24),
                    SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ]),
                ),
              ),
            );
          }
          return auth.loggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}

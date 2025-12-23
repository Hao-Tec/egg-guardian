import 'package:flutter/material.dart';
import 'package:egg_guardian/screens/login_screen.dart';
import 'package:egg_guardian/screens/device_list_screen.dart';
import 'package:egg_guardian/screens/device_detail_screen.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/session_service.dart';
import 'package:egg_guardian/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  runApp(const EggGuardianApp());
}

class EggGuardianApp extends StatefulWidget {
  const EggGuardianApp({super.key});

  // Global key for navigation from anywhere
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<EggGuardianApp> createState() => _EggGuardianAppState();
}

class _EggGuardianAppState extends State<EggGuardianApp> {
  @override
  void initState() {
    super.initState();

    // Initialize session service with logout callback
    SessionService().init(onSessionExpired: _handleSessionExpired);
  }

  void _handleSessionExpired() async {
    await ApiService().logout();

    // Navigate to login and show message
    EggGuardianApp.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
      arguments: 'Session expired. Please login again.',
    );
  }

  @override
  void dispose() {
    SessionService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ActivityDetector(
      child: MaterialApp(
        navigatorKey: EggGuardianApp.navigatorKey,
        title: 'Egg Guardian',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        initialRoute: '/login',
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/login':
              final message = settings.arguments as String?;
              return MaterialPageRoute(
                builder: (_) => LoginScreen(sessionExpiredMessage: message),
              );
            case '/devices':
              return MaterialPageRoute(
                builder: (_) => const DeviceListScreen(),
              );
            case '/device':
              final device = settings.arguments as Device;
              return MaterialPageRoute(
                builder: (_) => DeviceDetailScreen(device: device),
              );
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}

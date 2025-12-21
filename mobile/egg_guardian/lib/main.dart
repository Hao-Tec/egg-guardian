import 'package:flutter/material.dart';
import 'package:egg_guardian/screens/login_screen.dart';
import 'package:egg_guardian/screens/device_list_screen.dart';
import 'package:egg_guardian/screens/device_detail_screen.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  runApp(const EggGuardianApp());
}

class EggGuardianApp extends StatelessWidget {
  const EggGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case '/devices':
            return MaterialPageRoute(builder: (_) => const DeviceListScreen());
          case '/device':
            final device = settings.arguments as Device;
            return MaterialPageRoute(
              builder: (_) => DeviceDetailScreen(device: device),
            );
          default:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
        }
      },
    );
  }
}

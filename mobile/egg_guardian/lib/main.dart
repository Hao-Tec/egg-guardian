import 'dart:async';
import 'package:flutter/material.dart';
import 'package:egg_guardian/screens/login_screen.dart';
import 'package:egg_guardian/screens/device_list_screen.dart';
import 'package:egg_guardian/screens/device_detail_screen.dart';
import 'package:egg_guardian/screens/admin_screen.dart';
import 'package:egg_guardian/services/api_service.dart';
import 'package:egg_guardian/services/session_service.dart';
import 'package:egg_guardian/services/websocket_service.dart';
import 'package:egg_guardian/models.dart';
import 'package:egg_guardian/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Request permission for notifications (Android 13+ and iOS)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  
  // Print FCM token for debugging/backend integration
  FirebaseMessaging.instance.getToken().then((token) {
    debugPrint('FCM Token: $token');
  }).catchError((e) {
    debugPrint('Failed to get FCM Token (Firebase not fully configured): $e');
  });

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
  final GlobalKey<_AlertBannerState> _alertKey = GlobalKey<_AlertBannerState>();
  StreamSubscription? _alertSub;

  @override
  void initState() {
    super.initState();

    // Initialize session service with logout callback
    SessionService().init(onSessionExpired: _handleSessionExpired);
    
    // Start session if already logged in (auto-login)
    if (ApiService().isLoggedIn) {
      SessionService().startSession();
    }
    
    // Global alert listener
    _setupGlobalAlerts();
  }

  void _setupGlobalAlerts() {
    final ws = WebSocketService();
    // Listen to the broadcast stream for global alerts
    _alertSub = ws.messageStream.listen((msg) {
      if (msg.type == 'alert') {
        _alertKey.currentState?.showAlert(msg.message ?? 'Critical temperature alert!');
      }
    });

    // Listen to Firebase foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _alertKey.currentState?.showAlert(message.notification!.body ?? 'Critical temperature alert via FCM!');
      }
    });
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
    _alertSub?.cancel();
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
        theme: EgTheme.themeData(),
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              AlertBanner(key: _alertKey),
            ],
          );
        },
        initialRoute: ApiService().isLoggedIn 
            ? (ApiService().isAdmin ? '/admin' : '/devices') 
            : '/login',
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
            case '/admin':
              return MaterialPageRoute(
                builder: (_) => const AdminScreen(),
              );
            default:
              return MaterialPageRoute(builder: (_) => const LoginScreen());
          }
        },
      ),
    );
  }
}

class AlertBanner extends StatefulWidget {
  const AlertBanner({super.key});

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> with SingleTickerProviderStateMixin {
  String? _message;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -4.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
  }

  void showAlert(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    _controller.forward();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CRITICAL ALERT',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        _message ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  onPressed: () => _controller.reverse(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

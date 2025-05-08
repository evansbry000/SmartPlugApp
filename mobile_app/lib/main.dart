import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/smart_plug_service.dart';
import 'services/notification_service.dart';
import 'services/data_mirroring_service.dart';
import 'firebase_config.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: firebaseOptions,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
        Provider<DataMirroringService>(
          create: (_) {
            final service = DataMirroringService();
            service.initialize(); // Initialize the service on creation
            return service;
          },
          dispose: (_, service) => service.dispose(),
        ),
        ProxyProvider<AuthService, SmartPlugService>(
          update: (_, authService, __) => SmartPlugService(authService: authService),
        ),
        Provider<NotificationService>(
          create: (_) => NotificationService(),
          lazy: false,
        ),
      ],
      child: MaterialApp(
        title: 'Smart Plug App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return StreamBuilder(
      stream: authService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        }
        
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
} 
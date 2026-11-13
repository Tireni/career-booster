import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'data/repositories/remote_analysis_repository.dart';
import 'data/services/analysis_api_service.dart';
import 'models/analysis_repository.dart';
import 'presentation/view_models/booster_view_model.dart';
import 'presentation/view_models/auth_view_model.dart';
import 'presentation/views/auth_view.dart';
import 'presentation/views/booster_view.dart';

void main() {
  const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  const appKey = String.fromEnvironment('APP_API_KEY');
  runApp(
    MultiProvider(
      providers: [
        Provider<Dio>(
          create: (_) => Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 90),
              headers: {
                'ngrok-skip-browser-warning': 'true',
                if (appKey.isNotEmpty) 'X-App-Key': appKey,
              },
            ),
          ),
        ),
        Provider<AnalysisApiService>(
          create: (context) => AnalysisApiService(context.read<Dio>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              AuthViewModel(context.read<Dio>(), const FlutterSecureStorage())
                ..initialize(),
        ),
        Provider<AnalysisRepository>(
          create: (context) =>
              RemoteAnalysisRepository(context.read<AnalysisApiService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              BoosterViewModel(context.read<AnalysisRepository>()),
        ),
      ],
      child: const CareerBoosterApp(),
    ),
  );
}

class CareerBoosterApp extends StatelessWidget {
  const CareerBoosterApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Career Booster',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3659A3)),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    home: const _AuthGate(),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.signedIn ? const BoosterView() : const AuthView();
  }
}

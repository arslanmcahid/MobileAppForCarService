import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/app_config.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'config/supabase_config.dart';
import 'services/supabase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🚀 App starting...');
    
    // 1. Önce Supabase'i başlat
    print('🔧 Initializing Supabase...');
    await SupabaseConfig.initialize();
    print('✅ Supabase initialized');
    
    // 2. Sonra Auth Service'i başlat  
    print('🔐 Initializing Auth Service...');
    await SupabaseAuthService.instance.initialize();
    print('✅ Auth Service initialized');
    
    // 3. App Config'i başlat
    print('⚙️ Initializing App Config...');
    await AppConfig.initialize();
    print('✅ App Config initialized');
    
    print('🎉 All services initialized successfully!');
  } catch (e) {
    print('❌ Initialization error: $e');
  }
  
  runApp(
    const ProviderScope(
      child: CarMaintenanceApp(),
    ),
  );
}

class CarMaintenanceApp extends ConsumerWidget {
  const CarMaintenanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Araba Bakım Takibi',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
} 
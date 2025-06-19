import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../presentation/screens/auth/splash_screen.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/auth/register_screen.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/cars/cars_screen.dart';
import '../presentation/screens/cars/car_detail_screen.dart';
import '../presentation/screens/maintenance/add_maintenance_screen.dart';
import '../presentation/screens/maintenance/maintenance_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final String location = state.uri.toString();
      
      // Splash screen her zaman açılabilir
      if (location == '/splash') {
        return null;
      }
      
      // Kullanıcı giriş yapmamışsa login'e yönlendir
      if (!isAuthenticated) {
        if (location != '/login' && location != '/register') {
          return '/login';
        }
        return null;
      }
      
      // Kullanıcı giriş yapmışsa auth sayfalarından ana sayfaya yönlendir
      if (location == '/login' || 
          location == '/register' || 
          location == '/splash') {
        return '/';
      }
      
      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Main app routes
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // Cars routes
      GoRoute(
        path: '/cars',
        builder: (context, state) => const CarsScreen(),
      ),
      GoRoute(
        path: '/cars/detail/:carId',
        builder: (context, state) {
          final carId = state.pathParameters['carId']!;
          return CarDetailScreen(carId: carId);
        },
      ),
      
      // Maintenance routes
      GoRoute(
        path: '/maintenance',
        builder: (context, state) => const MaintenanceScreen(),
      ),
      GoRoute(
        path: '/maintenance/add',
        builder: (context, state) {
          final carId = state.uri.queryParameters['carId'];
          return AddMaintenanceScreen(carId: carId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Sayfa bulunamadı',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'İstediğiniz sayfa mevcut değil',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      ),
    ),
  );
}); 
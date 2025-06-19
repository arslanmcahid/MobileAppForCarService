import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class SupabaseConfig {
  // Supabase credentials
  static const String supabaseUrl = 'https://tifggkjrgjglqufhadmc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRpZmdna2pyZ2pnbHF1ZmhhZG1jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk1NzkwNzgsImV4cCI6MjA2NTE1NTA3OH0.a_Bl9NAiKgycnjV0YPx8Y3i2Khhb8FFkOCIgL-9OWyY';

  static Future<void> initialize() async {
    try {
      if (kDebugMode) {
        print('🔧 Initializing Supabase with:');
        print('📍 URL: $supabaseUrl');
        print('🔑 Key: ${supabaseAnonKey.substring(0, 20)}...');
      }

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        debug: kDebugMode,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );

      if (kDebugMode) {
        print('✅ Supabase initialized successfully');
        print('🌐 Client ready');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Supabase initialization error: $e');
      }
      rethrow;
    }
  }
}

// Global Supabase client
SupabaseClient get supabase => Supabase.instance.client; 
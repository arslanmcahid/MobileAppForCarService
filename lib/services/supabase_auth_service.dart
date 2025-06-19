import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase_flutter;
import '../data/models/user.dart';
import '../config/supabase_config.dart';

class SupabaseAuthService {
  static SupabaseAuthService? _instance;
  static SupabaseAuthService get instance {
    _instance ??= SupabaseAuthService._internal();
    return _instance!;
  }
  SupabaseAuthService._internal();

  // Supabase client getter - her zaman güncel instance'ı alır
  supabase_flutter.SupabaseClient get _client => supabase_flutter.Supabase.instance.client;

  // Stream controller for user changes
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userController.stream;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Initialize service and listen to auth changes
  Future<void> initialize() async {
    try {
      if (kDebugMode) print('🔧 SupabaseAuthService initializing...');
      
      // Listen to auth state changes
      _client.auth.onAuthStateChange.listen((data) {
        final supabase_flutter.AuthChangeEvent event = data.event;
        final supabase_flutter.Session? session = data.session;
        
        if (kDebugMode) print('🔐 Auth event: $event');
        
        if (event == supabase_flutter.AuthChangeEvent.signedIn && session?.user != null) {
          _handleSignedIn(session!.user);
        } else if (event == supabase_flutter.AuthChangeEvent.signedOut) {
          _handleSignedOut();
        }
      });

      // Check current session
      final session = _client.auth.currentSession;
      if (session?.user != null) {
        await _handleSignedIn(session!.user);
      }
      
      if (kDebugMode) print('✅ SupabaseAuthService initialized successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Auth initialize error: $e');
    }
  }

  /// Handle user signed in
  Future<void> _handleSignedIn(supabase_flutter.User supabaseUser) async {
    try {
      if (kDebugMode) print('👤 Handling user sign in: ${supabaseUser.email}');
      
      // Get user profile from database
      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (response != null) {
        _currentUser = User.fromMap(response);
        if (kDebugMode) print('📋 User profile loaded from database');
      } else {
        // Create user profile if doesn't exist
        _currentUser = User(
          id: supabaseUser.id,
          email: supabaseUser.email ?? '',
          name: supabaseUser.userMetadata?['name'],
          phoneNumber: supabaseUser.phone,
          createdAt: DateTime.parse(supabaseUser.createdAt),
          updatedAt: DateTime.now(),
          isEmailVerified: supabaseUser.emailConfirmedAt != null,
        );
        if (kDebugMode) print('🆕 New user profile created');
      }

      _userController.add(_currentUser);
      if (kDebugMode) print('✅ User signed in successfully: ${_currentUser!.email}');
    } catch (e) {
      if (kDebugMode) print('❌ Handle signed in error: $e');
    }
  }

  /// Handle user signed out
  void _handleSignedOut() {
    _currentUser = null;
    _userController.add(null);
    if (kDebugMode) print('👋 User signed out');
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      if (kDebugMode) print('🔐 Attempting sign in for: $email');
      
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        if (kDebugMode) print('✅ Sign in successful');
        return AuthResult.success(_currentUser);
      } else {
        if (kDebugMode) print('❌ Sign in failed - no user returned');
        return AuthResult.error('Giriş yapılamadı');
      }
    } on supabase_flutter.AuthException catch (e) {
      if (kDebugMode) print('❌ Auth exception: ${e.message}');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      if (kDebugMode) print('❌ Sign in error: $e');
      return AuthResult.error('Giriş yapılırken hata oluştu: $e');
    }
  }

  /// Create user with email and password
  Future<AuthResult> createUserWithEmailAndPassword(
    String email, 
    String password,
    String? name,
  ) async {
    try {
      if (kDebugMode) print('📝 Attempting sign up for: $email');
      
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: name != null ? {'name': name} : null,
      );

      if (response.user != null) {
        if (kDebugMode) print('✅ Sign up successful');
        return AuthResult.success(_currentUser, 
          message: 'Hesap oluşturuldu! E-posta adresinizi doğrulayın.');
      } else {
        if (kDebugMode) print('❌ Sign up failed - no user returned');
        return AuthResult.error('Hesap oluşturulamadı');
      }
    } on supabase_flutter.AuthException catch (e) {
      if (kDebugMode) print('❌ Auth exception: ${e.message}');
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      if (kDebugMode) print('❌ Sign up error: $e');
      return AuthResult.error('Hesap oluşturulurken hata oluştu: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (kDebugMode) print('👋 Signing out...');
      await _client.auth.signOut();
    } catch (e) {
      if (kDebugMode) print('❌ Sign out error: $e');
    }
  }

  /// Update user profile
  Future<AuthResult> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.error('Kullanıcı girişi yapılmamış');
      }

      // Update user metadata
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;

      if (updates.isNotEmpty) {
        await _client.auth.updateUser(
          supabase_flutter.UserAttributes(data: updates)
        );
      }

      // Update user profile in database
      await _client
          .from('user_profiles')
          .update({
            'name': name,
            'phone_number': phoneNumber,
            'profile_image_url': profileImageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentUser!.id);

      // Update local user
      _currentUser = _currentUser!.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      _userController.add(_currentUser);
      return AuthResult.success(_currentUser);
      
    } catch (e) {
      if (kDebugMode) print('Update profile error: $e');
      return AuthResult.error('Profil güncellenirken hata oluştu: $e');
    }
  }

  /// Reset password
  Future<AuthResult> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult.success(null, 
        message: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi');
    } on supabase_flutter.AuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Şifre sıfırlama isteği gönderilirken hata oluştu: $e');
    }
  }

  /// Get user-friendly error message
  String _getErrorMessage(supabase_flutter.AuthException e) {
    switch (e.message.toLowerCase()) {
      case 'invalid login credentials':
        return 'E-posta veya şifre hatalı';
      case 'user not found':
        return 'Bu e-posta adresi kayıtlı değil';
      case 'email not confirmed':
        return 'E-posta adresinizi doğrulamanız gerekiyor';
      case 'weak password':
        return 'Şifre çok zayıf, daha güçlü bir şifre seçin';
      case 'email already registered':
        return 'Bu e-posta adresi zaten kullanılıyor';
      default:
        return e.message;
    }
  }

  /// Dispose
  void dispose() {
    _userController.close();
  }
}

/// Authentication result class
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? error;
  final String? message;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.error,
    this.message,
  });

  factory AuthResult.success(User? user, {String? message}) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
    );
  }

  factory AuthResult.error(String error) {
    return AuthResult._(
      isSuccess: false,
      error: error,
    );
  }
} 
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../data/models/user.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }
  AuthService._internal();

  // Current user stream
  final StreamController<User?> _userController = StreamController<User?>.broadcast();
  Stream<User?> get userStream => _userController.stream;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Mock kullanıcı veritabanı (gerçekte Firebase/Backend olacak)
  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'test@example.com': {
      'id': '1',
      'email': 'test@example.com',
      'password': '123456', // Gerçekte hash'lenmiş olacak
      'name': 'Test Kullanıcı',
      'phone_number': null,
      'profile_image_url': null,
      'created_at': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_email_verified': true,
    },
    'demo@demo.com': {
      'id': '2',
      'email': 'demo@demo.com',
      'password': 'demo123',
      'name': 'Demo Kullanıcı',
      'phone_number': '+90 555 123 45 67',
      'profile_image_url': null,
      'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'is_email_verified': true,
    },
  };

  /// Uygulama başlatıldığında çağrılır
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      
      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromMap(userMap);
        _userController.add(_currentUser);
        if (kDebugMode) print('User loaded from storage: ${_currentUser!.email}');
      }
    } catch (e) {
      if (kDebugMode) print('Error loading user: $e');
    }
  }

  /// E-posta ve şifre ile giriş
  Future<AuthResult> signInWithEmailAndPassword(String email, String password) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Network simulation
      
      final userData = _mockUsers[email.toLowerCase()];
      if (userData == null) {
        return AuthResult.error('Bu e-posta adresi kayıtlı değil');
      }
      
      if (userData['password'] != password) {
        return AuthResult.error('Şifre hatalı');
      }

      // Kullanıcı bilgilerini oluştur (şifre hariç)
      final userMap = Map<String, dynamic>.from(userData);
      userMap.remove('password');
      
      _currentUser = User.fromMap(userMap);
      
      // Local storage'a kaydet
      await _saveUserToStorage(_currentUser!);
      
      // Stream'e bildir
      _userController.add(_currentUser);
      
      if (kDebugMode) print('User signed in: ${_currentUser!.email}');
      return AuthResult.success(_currentUser!);
      
    } catch (e) {
      if (kDebugMode) print('Sign in error: $e');
      return AuthResult.error('Giriş yapılırken hata oluştu: $e');
    }
  }

  /// Yeni hesap oluştur
  Future<AuthResult> createUserWithEmailAndPassword(
    String email, 
    String password,
    String? name,
  ) async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Network simulation
      
      if (_mockUsers.containsKey(email.toLowerCase())) {
        return AuthResult.error('Bu e-posta adresi zaten kullanılıyor');
      }

      if (password.length < 6) {
        return AuthResult.error('Şifre en az 6 karakter olmalıdır');
      }

      // Yeni kullanıcı oluştur
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();
      
      final newUserData = {
        'id': userId,
        'email': email.toLowerCase(),
        'password': password, // Gerçekte hash'lenmiş olacak
        'name': name,
        'phone_number': null,
        'profile_image_url': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'is_email_verified': false,
      };

      // Mock veritabanına ekle
      _mockUsers[email.toLowerCase()] = newUserData;
      
      // Kullanıcı bilgilerini oluştur (şifre hariç)
      final userMap = Map<String, dynamic>.from(newUserData);
      userMap.remove('password');
      
      _currentUser = User.fromMap(userMap);
      
      // Local storage'a kaydet
      await _saveUserToStorage(_currentUser!);
      
      // Stream'e bildir
      _userController.add(_currentUser);
      
      if (kDebugMode) print('User created: ${_currentUser!.email}');
      return AuthResult.success(_currentUser!);
      
    } catch (e) {
      if (kDebugMode) print('Create user error: $e');
      return AuthResult.error('Hesap oluşturulurken hata oluştu: $e');
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    try {
      _currentUser = null;
      
      // Local storage'dan sil
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      
      // Stream'e bildir
      _userController.add(null);
      
      if (kDebugMode) print('User signed out');
    } catch (e) {
      if (kDebugMode) print('Sign out error: $e');
    }
  }

  /// Kullanıcı bilgilerini güncelle
  Future<AuthResult> updateUserProfile({
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    try {
      if (_currentUser == null) {
        return AuthResult.error('Kullanıcı girişi yapılmamış');
      }

      // Güncellenmiş kullanıcı oluştur
      final updatedUser = _currentUser!.copyWith(
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
        updatedAt: DateTime.now(),
      );

      // Mock veritabanını güncelle
      if (_mockUsers.containsKey(_currentUser!.email)) {
        _mockUsers[_currentUser!.email]!.addAll({
          'name': name,
          'phone_number': phoneNumber,
          'profile_image_url': profileImageUrl,
          'updated_at': updatedUser.updatedAt.toIso8601String(),
        });
      }

      _currentUser = updatedUser;
      
      // Local storage'a kaydet
      await _saveUserToStorage(_currentUser!);
      
      // Stream'e bildir
      _userController.add(_currentUser);
      
      return AuthResult.success(_currentUser!);
      
    } catch (e) {
      if (kDebugMode) print('Update profile error: $e');
      return AuthResult.error('Profil güncellenirken hata oluştu: $e');
    }
  }

  /// Şifre sıfırlama (mock)
  Future<AuthResult> resetPassword(String email) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      
      if (!_mockUsers.containsKey(email.toLowerCase())) {
        return AuthResult.error('Bu e-posta adresi kayıtlı değil');
      }
      
      // Gerçekte e-posta gönderimi yapılacak
      if (kDebugMode) print('Password reset email sent to: $email');
      return AuthResult.success(null, message: 'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi');
      
    } catch (e) {
      return AuthResult.error('Şifre sıfırlama isteği gönderilirken hata oluştu: $e');
    }
  }

  /// Kullanıcıyı local storage'a kaydet
  Future<void> _saveUserToStorage(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(user.toMap());
      await prefs.setString('current_user', userJson);
    } catch (e) {
      if (kDebugMode) print('Error saving user to storage: $e');
    }
  }

  /// Mock kullanıcıları al (geliştirme amaçlı)
  List<String> getMockUserEmails() {
    return _mockUsers.keys.toList();
  }

  /// Stream'i temizle
  void dispose() {
    _userController.close();
  }
}

/// Authentication sonuç sınıfı
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
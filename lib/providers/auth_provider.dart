import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user.dart';
import '../services/supabase_auth_service.dart';

/// Auth state class
class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
}

/// Auth provider
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseAuthService _authService;

  AuthNotifier(this._authService) : super(const AuthState()) {
    _init();
  }

  void _init() {
    // Listen to auth service user stream
    _authService.userStream.listen((user) {
      state = state.copyWith(user: user, isLoading: false, error: null);
    });

    // Set initial user if logged in
    if (_authService.currentUser != null) {
      state = state.copyWith(user: _authService.currentUser);
    }
  }

  /// Sign in with email and password
  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.signInWithEmailAndPassword(email, password);
      
      if (!result.isSuccess) {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create account
  Future<void> createAccount(String email, String password, String? name) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.createUserWithEmailAndPassword(
        email, 
        password, 
        name,
      );
      
      if (!result.isSuccess) {
        state = state.copyWith(isLoading: false, error: result.error);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.signOut();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? name,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.updateUserProfile(
        name: name,
        phoneNumber: phoneNumber,
        profileImageUrl: profileImageUrl,
      );

      if (result.isSuccess) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _authService.resetPassword(email);
      
      if (result.isSuccess) {
        state = state.copyWith(isLoading: false);
        return true;
      } else {
        state = state.copyWith(isLoading: false, error: result.error);
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Auth provider instance
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(SupabaseAuthService.instance);
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// Is authenticated provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
}); 
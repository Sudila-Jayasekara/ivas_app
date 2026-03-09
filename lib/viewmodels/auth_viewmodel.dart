import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class AuthViewModel extends ChangeNotifier {
  static const String _tag = '[AuthVM]';
  final ApiService _api;

  AuthViewModel(this._api) {
    debugPrint('$_tag Initialized');
  }

  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  UserRole get userRole => _user?.role ?? UserRole.student;
  String get userId => _user?.id ?? ApiService.hardcodedStudentId;

  /// Legacy getter for backward-compat in home/viva screens
  Student? get student => _user != null
      ? Student(id: _user!.id, name: _user!.name, courseId: '')
      : null;
  String get studentId => userId;

  Future<bool> login(String email, String password) async {
    debugPrint('$_tag login() called with email=$email');
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final appUser = _api.validateCredentials(email, password);
    if (appUser == null) {
      debugPrint('$_tag ✗ Invalid credentials');
      _error = 'Invalid email or password';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _user = appUser;
    _isLoggedIn = true;
    _isLoading = false;
    debugPrint(
        '$_tag ✓ Login success — ${appUser.role.name}: ${appUser.name} (${appUser.id})');
    notifyListeners();
    return true;
  }

  void logout() {
    debugPrint('$_tag logout() called');
    _user = null;
    _isLoggedIn = false;
    _error = null;
    notifyListeners();
    debugPrint('$_tag ✓ Logged out');
  }
}

import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class AuthViewModel extends ChangeNotifier {
  static const String _tag = '[AuthVM]';
  final ApiService _api;

  AuthViewModel(this._api) {
    debugPrint('$_tag Initialized');
  }

  Student? _student;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  Student? get student => _student;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  String get studentId => _student?.id ?? ApiService.hardcodedStudentId;

  Future<bool> login(String email, String password) async {
    debugPrint('$_tag login() called with email=$email');
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Small delay for UX polish
    await Future.delayed(const Duration(milliseconds: 800));

    if (!_api.validateCredentials(email, password)) {
      debugPrint('$_tag ✗ Invalid credentials');
      _error = 'Invalid email or password';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    debugPrint('$_tag ✓ Credentials valid, fetching student profile...');
    try {
      _student = await _api.getStudent(ApiService.hardcodedStudentId);
      _isLoggedIn = true;
      _isLoading = false;
      debugPrint(
          '$_tag ✓ Login success — student: ${_student!.name} (${_student!.id})');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('$_tag ⚠ API unreachable ($e), using fallback student');
      // If mock API is not running, create a fallback student
      _student = Student(
        id: ApiService.hardcodedStudentId,
        name: 'Alice Johnson',
        courseId: 'course-001',
        email: ApiService.hardcodedEmail,
      );
      _isLoggedIn = true;
      _isLoading = false;
      debugPrint(
          '$_tag ✓ Login success (fallback) — student: ${_student!.name}');
      notifyListeners();
      return true;
    }
  }

  void logout() {
    debugPrint('$_tag logout() called');
    _student = null;
    _isLoggedIn = false;
    _error = null;
    notifyListeners();
    debugPrint('$_tag ✓ Logged out');
  }
}

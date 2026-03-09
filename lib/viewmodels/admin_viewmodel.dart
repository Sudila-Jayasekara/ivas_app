import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminViewModel extends ChangeNotifier {
  static const String _tag = '[AdminVM]';
  final ApiService _api;

  AdminViewModel(this._api) {
    debugPrint('$_tag Initialized');
  }

  // ── State ─────────────────────────────────────────────────────────
  Map<String, dynamic>? _health;
  Map<String, dynamic>? _ready;
  Map<String, dynamic>? _llmProvider;
  Map<String, dynamic>? _llmHealth;
  bool _isLoading = false;
  String? _error;
  String? _successMessage;
  Timer? _autoRefresh;

  // ── Getters ───────────────────────────────────────────────────────
  Map<String, dynamic>? get health => _health;
  Map<String, dynamic>? get ready => _ready;
  Map<String, dynamic>? get llmProvider => _llmProvider;
  Map<String, dynamic>? get llmHealth => _llmHealth;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;

  bool get isHealthy =>
      _health?['status'] == 'healthy' || _health?['status'] == 'ok';
  bool get isReady => _ready?['status'] == 'ready' || _ready?['ready'] == true;
  String get currentProvider =>
      _llmProvider?['provider'] as String? ??
      _llmProvider?['current_provider'] as String? ??
      'Unknown';

  // ── Load all system info ──────────────────────────────────────────
  Future<void> loadSystemInfo() async {
    debugPrint('$_tag loadSystemInfo()');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getHealth(),
        _api.getReady(),
        _api.getLLMProvider(),
        _api.getLLMHealth(),
      ]);
      _health = results[0];
      _ready = results[1];
      _llmProvider = results[2];
      _llmHealth = results[3];
      debugPrint('$_tag ✓ System info loaded');
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to load system info. Is the server running?';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshHealth() async {
    try {
      _health = await _api.getHealth();
      _ready = await _api.getReady();
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag ✗ refreshHealth: $e');
    }
  }

  Future<void> refreshLLM() async {
    try {
      final results = await Future.wait([
        _api.getLLMProvider(),
        _api.getLLMHealth(),
      ]);
      _llmProvider = results[0];
      _llmHealth = results[1];
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag ✗ refreshLLM: $e');
    }
  }

  // ── Switch LLM provider ──────────────────────────────────────────
  Future<bool> switchProvider(String provider) async {
    debugPrint('$_tag switchProvider($provider)');
    _isLoading = true;
    _error = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _api.switchLLMProvider(provider);
      _successMessage = 'Switched to $provider successfully.';
      await refreshLLM();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to switch provider.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshHealth();
    });
  }

  void stopAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = null;
  }

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }
}

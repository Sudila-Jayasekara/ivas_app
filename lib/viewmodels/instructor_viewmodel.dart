import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/grading_criteria.dart';
import '../models/question.dart';
import '../services/api_service.dart';

class InstructorViewModel extends ChangeNotifier {
  static const String _tag = '[InstructorVM]';
  final ApiService _api;

  InstructorViewModel(this._api) {
    debugPrint('$_tag Initialized');
  }

  // ── State ─────────────────────────────────────────────────────────
  List<Assignment> _assignments = [];
  List<Map<String, dynamic>> _assessments = [];
  List<GradingCriteria> _criteria = [];
  List<QuestionOut> _questions = [];
  Map<String, dynamic>? _transcript;
  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;
  String? _selectedAssignmentId;
  String? _statusFilter;

  // ── Getters ───────────────────────────────────────────────────────
  List<Assignment> get assignments => _assignments;
  List<Map<String, dynamic>> get assessments => _assessments;
  List<GradingCriteria> get criteria => _criteria;
  List<QuestionOut> get questions => _questions;
  Map<String, dynamic>? get transcript => _transcript;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  String? get selectedAssignmentId => _selectedAssignmentId;
  String? get statusFilter => _statusFilter;

  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  // ── Load dashboard data ───────────────────────────────────────────
  Future<void> loadDashboard(String instructorId) async {
    debugPrint('$_tag loadDashboard($instructorId)');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getAssignments(),
        _api.getInstructorAssessments(instructorId, status: _statusFilter),
      ]);
      _assignments = results[0] as List<Assignment>;
      _assessments = results[1] as List<Map<String, dynamic>>;
      debugPrint(
          '$_tag ✓ ${_assignments.length} assignments, ${_assessments.length} assessments');
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to load dashboard data.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshAssessments(String instructorId) async {
    try {
      _assessments = await _api.getInstructorAssessments(
        instructorId,
        status: _statusFilter,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('$_tag ✗ refreshAssessments: $e');
    }
  }

  // ── Assignment detail ─────────────────────────────────────────────
  Future<void> loadAssignmentDetail(String assignmentId) async {
    debugPrint('$_tag loadAssignmentDetail($assignmentId)');
    _selectedAssignmentId = assignmentId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.getGradingCriteria(assignmentId),
        _api.getQuestions(assignmentId),
      ]);
      _criteria = results[0] as List<GradingCriteria>;
      _questions = results[1] as List<QuestionOut>;
      debugPrint(
          '$_tag ✓ ${_criteria.length} criteria, ${_questions.length} questions');
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to load assignment details.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Generate grading criteria ─────────────────────────────────────
  Future<GenerateResult?> generateCriteria(String assignmentId) async {
    debugPrint('$_tag generateCriteria($assignmentId)');
    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.generateGradingCriteria(assignmentId);
      debugPrint('$_tag ✓ Generated ${result.totalGenerated} criteria');
      // Refresh criteria list
      _criteria = await _api.getGradingCriteria(assignmentId);
      _isGenerating = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to generate grading criteria.';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  // ── Generate questions ────────────────────────────────────────────
  Future<GenerateResult?> generateQuestions(
    String assignmentId, {
    int count = 5,
  }) async {
    debugPrint('$_tag generateQuestions($assignmentId, count=$count)');
    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.generateQuestions(assignmentId, count: count);
      debugPrint('$_tag ✓ Generated ${result.totalGenerated} questions');
      // Refresh questions list
      _questions = await _api.getQuestions(assignmentId);
      _isGenerating = false;
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to generate questions.';
      _isGenerating = false;
      notifyListeners();
      return null;
    }
  }

  // ── Transcript ────────────────────────────────────────────────────
  Future<void> loadTranscript(String sessionId) async {
    debugPrint('$_tag loadTranscript($sessionId)');
    _isLoading = true;
    _error = null;
    _transcript = null;
    notifyListeners();

    try {
      _transcript = await _api.getSessionTranscript(sessionId);
      debugPrint('$_tag ✓ Transcript loaded');
    } catch (e) {
      debugPrint('$_tag ✗ $e');
      _error = 'Failed to load transcript.';
    }

    _isLoading = false;
    notifyListeners();
  }

  String getAssignmentTitle(String assignmentId) {
    final a = _assignments.cast<Assignment?>().firstWhere(
          (a) => a?.assignmentId == assignmentId,
          orElse: () => null,
        );
    return a?.title ?? assignmentId;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

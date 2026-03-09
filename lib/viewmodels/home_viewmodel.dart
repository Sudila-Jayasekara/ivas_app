import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../models/session.dart';
import '../services/api_service.dart';

class HomeViewModel extends ChangeNotifier {
  static const String _tag = '[HomeVM]';
  final ApiService _api;

  HomeViewModel(this._api) {
    debugPrint('$_tag Initialized');
  }

  List<Assignment> _assignments = [];
  List<StudentSession> _sessions = [];
  bool _isLoading = false;
  String? _error;

  List<Assignment> get assignments => _assignments;
  List<StudentSession> get sessions => _sessions;
  List<StudentSession> get completedSessions =>
      _sessions.where((s) => s.status == 'completed').toList();
  List<StudentSession> get activeSessions => _sessions
      .where((s) => s.status == 'in_progress' || s.status == 'paused')
      .toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadData(String studentId) async {
    debugPrint('$_tag loadData(studentId=$studentId) called');
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('$_tag   Fetching assignments and sessions in parallel...');
      final results = await Future.wait([
        _api.getAssignments(),
        _api.getStudentSessions(studentId),
      ]);
      _assignments = results[0] as List<Assignment>;
      _sessions = results[1] as List<StudentSession>;
      debugPrint(
          '$_tag ✓ Loaded ${_assignments.length} assignments, ${_sessions.length} sessions');
      for (final a in _assignments) {
        debugPrint('$_tag   Assignment: ${a.title} (${a.assignmentId})');
      }
      for (final s in _sessions) {
        debugPrint('$_tag   Session: ${s.sessionId} status=${s.status}');
      }
    } catch (e) {
      debugPrint('$_tag ⚠ API error ($e), using fallback mock data');
      // Fallback mock data if API isn't running
      _assignments = [
        Assignment(
          assignmentId: 'assign-001',
          instructorId: 'inst-001',
          courseId: 'course-001',
          title: 'Introduction to Loops',
          competencies: ['loops', 'iteration', 'control-flow'],
          learningObjectives: ['Understand for loops', 'Apply while loops'],
          difficultyMin: 1,
          difficultyMax: 3,
        ),
        Assignment(
          assignmentId: 'assign-002',
          instructorId: 'inst-002',
          courseId: 'course-002',
          title: 'Data Structures: Arrays & Lists',
          competencies: ['arrays', 'lists', 'indexing'],
          learningObjectives: [
            'Master array operations',
            'Understand linked lists'
          ],
          difficultyMin: 2,
          difficultyMax: 4,
        ),
      ];
      _sessions = [];
      _error = null; // Don't show error for fallback
      debugPrint('$_tag ✓ Using ${_assignments.length} fallback assignments');
    }

    _isLoading = false;
    notifyListeners();
    debugPrint('$_tag loadData() complete');
  }

  String getAssignmentTitle(String assignmentId) {
    final assignment = _assignments.cast<Assignment?>().firstWhere(
          (a) => a?.assignmentId == assignmentId,
          orElse: () => null,
        );
    return assignment?.title ?? assignmentId;
  }
}

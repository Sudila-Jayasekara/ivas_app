import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/student.dart';
import '../models/assignment.dart';
import '../models/session.dart';

class ApiService {
  static const String _tag = '[ApiService]';
  static const String _defaultBaseUrl = 'http://localhost:9999';
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = http.Client() {
    debugPrint('$_tag Initialized with baseUrl: ${baseUrl ?? _defaultBaseUrl}');
  }

  // ── Auth (hardcoded) ──────────────────────────────────────────────
  static const String hardcodedEmail = 'student.test@gradeloop.com';
  static const String hardcodedPassword = 'Test@12345!';
  static const String hardcodedStudentId = 'stud-001';

  bool validateCredentials(String email, String password) {
    final valid = email == hardcodedEmail && password == hardcodedPassword;
    debugPrint('$_tag validateCredentials(email=$email) => $valid');
    return valid;
  }

  // ── Helper for logging HTTP responses ──────────────────────────────
  void _logRequest(String method, String url) {
    debugPrint('$_tag ➜ $method $url');
  }

  void _logResponse(String method, String url, int statusCode, String body) {
    debugPrint('$_tag ✓ $method $url => $statusCode');
    debugPrint(
        '$_tag   Response body (truncated): ${body.length > 300 ? '${body.substring(0, 300)}...' : body}');
  }

  void _logError(String method, String url, Object error) {
    debugPrint('$_tag ✗ $method $url FAILED: $error');
  }

  // ── Mock endpoints ────────────────────────────────────────────────
  Future<Student> getStudent(String studentId) async {
    final url = '$baseUrl/mock/students/$studentId';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final student = Student.fromJson(json);
        debugPrint('$_tag   Parsed student: ${student.name} (${student.id})');
        return student;
      }
      throw ApiException('Failed to fetch student: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<List<Student>> getStudents() async {
    final url = '$baseUrl/mock/students';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final students =
            (json['data'] as List).map((e) => Student.fromJson(e)).toList();
        debugPrint('$_tag   Parsed ${students.length} students');
        return students;
      }
      throw ApiException('Failed to fetch students: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<List<Assignment>> getAssignments() async {
    final url = '$baseUrl/mock/assignments';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final assignments =
            (json['data'] as List).map((e) => Assignment.fromJson(e)).toList();
        debugPrint('$_tag   Parsed ${assignments.length} assignments');
        return assignments;
      }
      throw ApiException('Failed to fetch assignments: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<Assignment> getAssignment(String assignmentId) async {
    final url = '$baseUrl/mock/assignments/$assignmentId';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        return Assignment.fromJson(jsonDecode(res.body));
      }
      throw ApiException('Failed to fetch assignment: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  // ── Student Sessions ─────────────────────────────────────────────
  Future<List<StudentSession>> getStudentSessions(String studentId,
      {String? status}) async {
    var uri = Uri.parse('$baseUrl/api/v1/students/$studentId/sessions');
    if (status != null) {
      uri = uri.replace(queryParameters: {'status': status});
    }
    _logRequest('GET', uri.toString());
    try {
      final res = await _client.get(uri);
      _logResponse('GET', uri.toString(), res.statusCode, res.body);
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final sessions = (json['data'] as List)
            .map((e) => StudentSession.fromJson(e))
            .toList();
        debugPrint('$_tag   Parsed ${sessions.length} sessions');
        return sessions;
      }
      throw ApiException('Failed to fetch sessions: ${res.statusCode}');
    } catch (e) {
      _logError('GET', uri.toString(), e);
      rethrow;
    }
  }

  // ── Assessments ───────────────────────────────────────────────────
  Future<AssessmentSession> triggerAssessment({
    required String studentId,
    required String assignmentId,
    String codeContext = '',
  }) async {
    final url = '$baseUrl/api/v1/assessments/trigger';
    final payload = {
      'student_id': studentId,
      'assignment_id': assignmentId,
      'code_context': codeContext,
    };
    debugPrint('$_tag ➜ POST $url');
    debugPrint('$_tag   Payload: $payload');
    try {
      final res = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      _logResponse('POST', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final session = AssessmentSession.fromTriggerJson(jsonDecode(res.body));
        debugPrint(
            '$_tag   Session created: ${session.sessionId}, totalQ=${session.totalQuestions}');
        return session;
      }
      throw ApiException(
          'Failed to trigger assessment: ${res.statusCode} ${res.body}');
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  Future<ResponseResult> submitResponse({
    required String sessionId,
    required String questionInstanceId,
    required String responseText,
    String responseType = 'text',
  }) async {
    final url = '$baseUrl/api/v1/assessments/sessions/$sessionId/respond';
    final payload = {
      'question_instance_id': questionInstanceId,
      'response_text': responseText,
      'response_type': responseType,
    };
    debugPrint('$_tag ➜ POST $url');
    debugPrint('$_tag   Payload: $payload');
    try {
      final res = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      _logResponse('POST', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final result = ResponseResult.fromJson(jsonDecode(res.body));
        debugPrint(
            '$_tag   Response result: score=${result.evaluationScore}, isComplete=${result.isComplete}');
        return result;
      }
      throw ApiException(
          'Failed to submit response: ${res.statusCode} ${res.body}');
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSessionTranscript(String sessionId) async {
    final url = '$baseUrl/api/v1/assessments/sessions/$sessionId/transcript';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw ApiException('Failed to fetch transcript: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestHint({
    required String sessionId,
    required String questionInstanceId,
  }) async {
    final url = '$baseUrl/api/v1/assessments/sessions/$sessionId/hint';
    final payload = {
      'session_id': sessionId,
      'question_instance_id': questionInstanceId,
    };
    debugPrint('$_tag ➜ POST $url');
    debugPrint('$_tag   Payload: $payload');
    try {
      final res = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      _logResponse('POST', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw ApiException('Failed to get hint: ${res.statusCode}');
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  Future<void> abandonSession(String sessionId) async {
    final url = '$baseUrl/api/v1/assessments/sessions/$sessionId/abandon';
    _logRequest('PUT', url);
    try {
      final res = await _client.put(Uri.parse(url));
      _logResponse('PUT', url, res.statusCode, res.body);
      if (res.statusCode != 200) {
        throw ApiException('Failed to abandon session: ${res.statusCode}');
      }
      debugPrint('$_tag   Session $sessionId abandoned');
    } catch (e) {
      _logError('PUT', url, e);
      rethrow;
    }
  }

  // ── Voice Biometrics ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getEnrollmentStatus(String studentId) async {
    final url = '$baseUrl/api/v1/voice-biometrics/enrollment-status/$studentId';
    _logRequest('GET', url);
    try {
      final res = await _client.get(Uri.parse(url));
      _logResponse('GET', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        final result = jsonDecode(res.body) as Map<String, dynamic>;
        debugPrint(
            '$_tag   Enrollment: enrolled=${result['is_enrolled']}, samples=${result['sample_count']}');
        return result;
      }
      throw ApiException('Failed to check enrollment: ${res.statusCode}');
    } catch (e) {
      _logError('GET', url, e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> enrollVoiceSample({
    required String studentId,
    required String audioBase64,
  }) async {
    final url = '$baseUrl/api/v1/voice-biometrics/enroll/sample';
    debugPrint('$_tag ➜ POST $url');
    debugPrint(
        '$_tag   studentId=$studentId, audioLength=${audioBase64.length} chars');
    try {
      final res = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'audio_sample': audioBase64,
        }),
      );
      _logResponse('POST', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw ApiException('Failed to enroll sample: ${res.statusCode}');
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyVoice({
    required String studentId,
    required String sessionId,
    required String audioBase64,
  }) async {
    final url = '$baseUrl/api/v1/voice-biometrics/verify';
    debugPrint('$_tag ➜ POST $url');
    debugPrint(
        '$_tag   studentId=$studentId, sessionId=$sessionId, audioLength=${audioBase64.length}');
    try {
      final res = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'student_id': studentId,
          'session_id': sessionId,
          'audio_data': audioBase64,
        }),
      );
      _logResponse('POST', url, res.statusCode, res.body);
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      throw ApiException('Failed to verify voice: ${res.statusCode}');
    } catch (e) {
      _logError('POST', url, e);
      rethrow;
    }
  }

  void dispose() {
    debugPrint('$_tag dispose() called');
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}

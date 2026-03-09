import 'question.dart';

class AssessmentSession {
  final String sessionId;
  final String? studentId;
  final String? assignmentId;
  final String status;
  final QuestionWithContext? firstQuestion;
  final int totalQuestions;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final double? finalScore;
  final double? maxScore;
  final List<CompetencySummary>? competencySummary;

  AssessmentSession({
    required this.sessionId,
    this.studentId,
    this.assignmentId,
    required this.status,
    this.firstQuestion,
    this.totalQuestions = 0,
    this.startedAt,
    this.completedAt,
    this.finalScore,
    this.maxScore,
    this.competencySummary,
  });

  factory AssessmentSession.fromTriggerJson(Map<String, dynamic> json) {
    return AssessmentSession(
      sessionId: json['session_id'] as String,
      status: json['status'] as String? ?? 'in_progress',
      firstQuestion: json['first_question'] != null
          ? QuestionWithContext.fromJson(json['first_question'])
          : null,
      totalQuestions: json['total_questions'] as int? ?? 0,
    );
  }

  factory AssessmentSession.fromSessionJson(Map<String, dynamic> json) {
    final session = json['session'] as Map<String, dynamic>? ?? json;
    return AssessmentSession(
      sessionId:
          session['id'] as String? ?? session['session_id'] as String? ?? '',
      studentId: session['student_id'] as String?,
      assignmentId: session['assignment_id'] as String?,
      status: session['status'] as String? ?? '',
      totalQuestions: json['total_questions'] as int? ?? 0,
      startedAt: session['started_at'] != null
          ? DateTime.tryParse(session['started_at'])
          : null,
      completedAt: session['completed_at'] != null
          ? DateTime.tryParse(session['completed_at'])
          : null,
      finalScore: (session['final_score'] as num?)?.toDouble(),
      maxScore: (session['max_score'] as num?)?.toDouble(),
    );
  }
}

class StudentSession {
  final String sessionId;
  final String assignmentId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int questionsAsked;
  final int responsesGiven;

  StudentSession({
    required this.sessionId,
    required this.assignmentId,
    required this.status,
    this.startedAt,
    this.completedAt,
    required this.questionsAsked,
    required this.responsesGiven,
  });

  factory StudentSession.fromJson(Map<String, dynamic> json) {
    return StudentSession(
      sessionId: json['session_id'] as String,
      assignmentId: json['assignment_id'] as String,
      status: json['status'] as String,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
      questionsAsked: json['questions_asked'] as int? ?? 0,
      responsesGiven: json['responses_given'] as int? ?? 0,
    );
  }
}

class CompetencySummary {
  final String competency;
  final double score;
  final double max;

  CompetencySummary({
    required this.competency,
    required this.score,
    required this.max,
  });

  factory CompetencySummary.fromJson(Map<String, dynamic> json) {
    return CompetencySummary(
      competency: json['competency'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      max: (json['max'] as num?)?.toDouble() ?? 10,
    );
  }
}

class ResponseResult {
  final String responseId;
  final QuestionWithContext? nextQuestion;
  final bool isComplete;
  final String message;
  final double? evaluationScore;
  final String? feedbackText;
  final List<String>? detectedMisconceptions;
  final double? finalScore;
  final double? maxScore;
  final List<CompetencySummary>? competencySummary;

  ResponseResult({
    required this.responseId,
    this.nextQuestion,
    required this.isComplete,
    this.message = '',
    this.evaluationScore,
    this.feedbackText,
    this.detectedMisconceptions,
    this.finalScore,
    this.maxScore,
    this.competencySummary,
  });

  factory ResponseResult.fromJson(Map<String, dynamic> json) {
    return ResponseResult(
      responseId: json['response_id'] as String? ?? '',
      nextQuestion: json['next_question'] != null
          ? QuestionWithContext.fromJson(json['next_question'])
          : null,
      isComplete: json['is_complete'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      evaluationScore: (json['evaluation_score'] as num?)?.toDouble(),
      feedbackText: json['feedback_text'] as String?,
      detectedMisconceptions: json['detected_misconceptions'] != null
          ? List<String>.from(json['detected_misconceptions'])
          : null,
      finalScore: (json['final_score'] as num?)?.toDouble(),
      maxScore: (json['max_score'] as num?)?.toDouble(),
      competencySummary: json['competency_summary'] != null
          ? (json['competency_summary'] as List)
              .map((e) => CompetencySummary.fromJson(e))
              .toList()
          : null,
    );
  }
}

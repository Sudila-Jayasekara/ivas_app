class QuestionWithContext {
  final String questionId;
  final String questionInstanceId;
  final String questionText;
  final String competency;
  final int difficulty;
  final String codeContext;
  final String hint;
  final bool isFollowUp;
  final String questionType;

  QuestionWithContext({
    required this.questionId,
    required this.questionInstanceId,
    required this.questionText,
    required this.competency,
    required this.difficulty,
    this.codeContext = '',
    this.hint = '',
    this.isFollowUp = false,
    this.questionType = 'new',
  });

  factory QuestionWithContext.fromJson(Map<String, dynamic> json) {
    return QuestionWithContext(
      questionId: json['question_id'] as String? ?? '',
      questionInstanceId: json['question_instance_id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      competency: json['competency'] as String? ?? '',
      difficulty: json['difficulty'] as int? ?? 1,
      codeContext: json['code_context'] as String? ?? '',
      hint: json['hint'] as String? ?? '',
      isFollowUp: json['is_follow_up'] as bool? ?? false,
      questionType: json['question_type'] as String? ?? 'new',
    );
  }
}

/// A saved question from the question bank (GET /assignments/{id}/questions)
class QuestionOut {
  final String id;
  final String assignmentId;
  final String? gradingCriteriaId;
  final String questionText;
  final String competency;
  final int difficulty;
  final String expectedAnswer;
  final int maxPoints;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuestionOut({
    required this.id,
    required this.assignmentId,
    this.gradingCriteriaId,
    required this.questionText,
    required this.competency,
    required this.difficulty,
    required this.expectedAnswer,
    required this.maxPoints,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuestionOut.fromJson(Map<String, dynamic> json) {
    return QuestionOut(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      gradingCriteriaId: json['grading_criteria_id'] as String?,
      questionText: json['question_text'] as String,
      competency: json['competency'] as String,
      difficulty: json['difficulty'] as int,
      expectedAnswer: json['expected_answer'] as String? ?? '',
      maxPoints: json['max_points'] as int? ?? 10,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

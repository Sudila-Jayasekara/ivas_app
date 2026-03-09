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

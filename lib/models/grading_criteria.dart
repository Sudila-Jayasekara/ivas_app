class GradingCriteria {
  final String id;
  final String assignmentId;
  final String competency;
  final int difficultyLevel;
  final String levelLabel;
  final String levelDescription;
  final String markingCriteria;
  final String programmingLanguage;
  final List<String> learningObjectives;
  final DateTime createdAt;
  final DateTime updatedAt;

  GradingCriteria({
    required this.id,
    required this.assignmentId,
    required this.competency,
    required this.difficultyLevel,
    required this.levelLabel,
    required this.levelDescription,
    required this.markingCriteria,
    required this.programmingLanguage,
    required this.learningObjectives,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GradingCriteria.fromJson(Map<String, dynamic> json) {
    return GradingCriteria(
      id: json['id'] as String,
      assignmentId: json['assignment_id'] as String,
      competency: json['competency'] as String,
      difficultyLevel: json['difficulty_level'] as int,
      levelLabel: json['level_label'] as String,
      levelDescription: json['level_description'] as String,
      markingCriteria: json['marking_criteria'] as String,
      programmingLanguage: json['programming_language'] as String? ?? '',
      learningObjectives: List<String>.from(json['learning_objectives'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class GenerateResult {
  final String assignmentId;
  final List<String> ids;
  final int totalGenerated;

  GenerateResult({
    required this.assignmentId,
    required this.ids,
    required this.totalGenerated,
  });

  factory GenerateResult.fromJson(Map<String, dynamic> json) {
    return GenerateResult(
      assignmentId: json['assignment_id'] as String,
      ids:
          List<String>.from(json['criteria_ids'] ?? json['question_ids'] ?? []),
      totalGenerated: json['total_generated'] as int,
    );
  }
}

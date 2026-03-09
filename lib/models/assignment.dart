class Assignment {
  final String assignmentId;
  final String instructorId;
  final String courseId;
  final String title;
  final List<String> competencies;
  final List<String> learningObjectives;
  final int difficultyMin;
  final int difficultyMax;

  Assignment({
    required this.assignmentId,
    required this.instructorId,
    required this.courseId,
    required this.title,
    required this.competencies,
    required this.learningObjectives,
    required this.difficultyMin,
    required this.difficultyMax,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    final diffRange = json['difficulty_range'] as Map<String, dynamic>? ?? {};
    return Assignment(
      assignmentId: json['assignment_id'] as String,
      instructorId: json['instructor_id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      competencies: List<String>.from(json['competencies'] ?? []),
      learningObjectives: List<String>.from(json['learning_objectives'] ?? []),
      difficultyMin: diffRange['min'] as int? ?? 1,
      difficultyMax: diffRange['max'] as int? ?? 5,
    );
  }
}

class Student {
  final String id;
  final String name;
  final String courseId;
  final String? email;

  Student({
    required this.id,
    required this.name,
    required this.courseId,
    this.email,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      courseId: json['course_id'] as String,
      email: json['email'] as String?,
    );
  }
}

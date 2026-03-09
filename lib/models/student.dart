enum UserRole { student, instructor, admin }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? courseId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.courseId,
  });
}

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

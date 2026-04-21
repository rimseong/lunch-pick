class AppUser {
  final int id;
  final String name;
  final String employeeNo;

  AppUser({required this.id, required this.name, required this.employeeNo});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      employeeNo: json['employee_no'] as String,
    );
  }
}

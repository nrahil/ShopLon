class UserModel {
  final String name;
  final String email;
  final String avatarUrl;

  UserModel({
    required this.name,
    required this.email,
    this.avatarUrl = 'https://i.imgur.com/IXnO207.png', // Demo Avatar
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatarUrl'] ?? 'https://i.imgur.com/IXnO207.png',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
    };
  }
}

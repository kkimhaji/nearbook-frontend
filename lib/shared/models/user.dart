class UserModel {
  final String id;
  final String username;
  final String nickname;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.username,
    required this.nickname,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}

import 'user.dart';

class FriendModel {
  final int friendshipId;
  final UserModel user;
  final DateTime since;

  const FriendModel({
    required this.friendshipId,
    required this.user,
    required this.since,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      friendshipId: json['friendshipId'] as int,
      user: UserModel.fromJson(json['friend'] as Map<String, dynamic>),
      since: DateTime.parse(json['since'] as String),
    );
  }
}

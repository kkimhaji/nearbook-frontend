import 'package:nearbook_frontend/shared/models/user.dart';

class GuestbookEntry {
  final int id;
  final String content;
  final DateTime createdAt;
  final UserModel writer;

  const GuestbookEntry({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.writer,
  });

  factory GuestbookEntry.fromJson(Map<String, dynamic> json) {
    return GuestbookEntry(
      id: json['id'] as int,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      writer: UserModel.fromJson(json['writer'] as Map<String, dynamic>),
    );
  }
}

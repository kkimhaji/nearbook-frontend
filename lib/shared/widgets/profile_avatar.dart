import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String nickname;
  final double radius;

  const ProfileAvatar({
    super.key,
    required this.nickname,
    this.imageUrl,
    this.radius = 16,
  });

  String _buildImageUrl(String path) {
    final host = ApiConstants.baseUrl.replaceFirst('/api', '');
    return '$host$path';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (imageUrl != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: CachedNetworkImageProvider(
          _buildImageUrl(imageUrl!),
        ),
        backgroundColor: colorScheme.primaryContainer,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      child: Text(
        nickname.isNotEmpty ? nickname[0] : '?',
        style: TextStyle(
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

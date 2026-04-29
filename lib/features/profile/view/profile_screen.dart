import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../provider/profile_provider.dart';
import '../../auth/provider/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/api_constants.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).fetchProfile());
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  Future<void> _showNicknameDialog(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '새 닉네임'),
          autofocus: true,
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final success = await ref
        .read(profileProvider.notifier)
        .updateNickname(controller.text.trim());
    _showMessage(
      success
          ? '닉네임이 변경되었습니다.'
          : ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
      isError: !success,
    );
  }

  Future<void> _showPasswordDialog() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('비밀번호 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '현재 비밀번호'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 (8자 이상)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('새 비밀번호가 일치하지 않습니다.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final success = await ref.read(profileProvider.notifier).changePassword(
          currentPassword: currentController.text,
          newPassword: newController.text,
        );
    _showMessage(
      success
          ? '비밀번호가 변경되었습니다.'
          : ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
      isError: !success,
    );
  }

  Future<void> _showBleVisibilityDialog(String current) async {
    final options = {
      'public': '전체 공개',
      'friends_only': '친구에게만',
      'hidden': '숨김',
    };

    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('BLE 공개 설정'),
        children: options.entries.map((e) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, e.key),
            child: Row(
              children: [
                if (current == e.key)
                  const Icon(Icons.check, size: 18)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(e.value),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected == null || selected == current) return;
    final success =
        await ref.read(profileProvider.notifier).updateBleVisibility(selected);
    _showMessage(
      success
          ? 'BLE 공개 설정이 변경되었습니다.'
          : ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
      isError: !success,
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('계정 탈퇴'),
        content: const Text('정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final success = await ref.read(profileProvider.notifier).deleteAccount();
    if (success && mounted) {
      await ref.read(authProvider.notifier).logout();
      context.go('/login');
    } else if (!success && mounted) {
      _showMessage(
        ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
        isError: true,
      );
    }
  }

  String _bleVisibilityLabel(String? value) {
    switch (value) {
      case 'public':
        return '전체 공개';
      case 'friends_only':
        return '친구에게만';
      case 'hidden':
        return '숨김';
      default:
        return '-';
    }
  }

  String _buildImageUrl(String? path) {
    if (path == null) return '';
    final host = ApiConstants.baseUrl.replaceFirst('/api', '');
    return '$host$path';
  }

  Future<void> _pickAndUploadImage() async {
    final profile = ref.read(profileProvider).profile;

    // 선택 방법 선택 (갤러리 / 카메라)
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (profile?['profileImageUrl'] != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('사진 삭제', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, null),
              ),
          ],
        ),
      ),
    );

    // null 반환 = 삭제 선택
    if (!mounted) return;
    if (source == null && profile?['profileImageUrl'] != null) {
      await _deleteProfileImage();
      return;
    }
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    final success = await ref
        .read(profileProvider.notifier)
        .uploadProfileImage(picked.path);
    _showMessage(
      success
          ? '프로필 사진이 변경되었습니다.'
          : ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
      isError: !success,
    );
  }

  Future<void> _deleteProfileImage() async {
    final success =
        await ref.read(profileProvider.notifier).deleteProfileImage();
    _showMessage(
      success
          ? '프로필 사진이 삭제되었습니다.'
          : ref.read(profileProvider).errorMessage ?? '오류가 발생했습니다.',
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final profile = state.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: state.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 프로필 헤더
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: profile?['profileImageUrl'] !=
                                      null
                                  ? CachedNetworkImageProvider(
                                      _buildImageUrl(
                                        profile!['profileImageUrl'] as String,
                                      ),
                                    )
                                  : null,
                              child: profile?['profileImageUrl'] == null
                                  ? Text(
                                      (profile?['nickname'] as String? ??
                                          '?')[0],
                                      style: const TextStyle(fontSize: 28),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile?['nickname'] as String? ?? '-',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${profile?['username'] as String? ?? '-'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        profile?['email'] as String? ?? '-',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 계정 설정
                _SectionHeader(title: '계정'),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('닉네임 변경'),
                  subtitle: Text(profile?['nickname'] as String? ?? '-'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: profile == null
                      ? null
                      : () => _showNicknameDialog(
                            profile['nickname'] as String,
                          ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('비밀번호 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showPasswordDialog,
                ),

                const SizedBox(height: 8),

                // 개인정보 설정
                _SectionHeader(title: '개인정보'),
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('BLE 공개 설정'),
                  subtitle: Text(
                    _bleVisibilityLabel(profile?['bleVisibility'] as String?),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: profile == null
                      ? null
                      : () => _showBleVisibilityDialog(
                            profile['bleVisibility'] as String,
                          ),
                ),

                const SizedBox(height: 8),

                // 기타
                _SectionHeader(title: '기타'),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('로그아웃'),
                  onTap: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (!mounted) return;
                    context.go('/login');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    '계정 탈퇴',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

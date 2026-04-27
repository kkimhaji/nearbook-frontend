import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_repository.dart';
import '../../../core/network/dio_exception_handler.dart';

class ProfileState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  ProfileState copyWith({
    Map<String, dynamic>? profile,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final UserRepository _repository;

  ProfileNotifier(this._repository) : super(const ProfileState());

  Future<void> fetchProfile() async {
    state = state.copyWith(isLoading: true);
    try {
      final profile = await _repository.getMyProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: DioExceptionHandler.getMessage(e),
      );
    }
  }

  Future<bool> updateNickname(String nickname) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateNickname(nickname);
      final updated = Map<String, dynamic>.from(state.profile ?? {});
      updated['nickname'] = nickname;
      state = state.copyWith(
        profile: updated,
        isLoading: false,
        successMessage: '닉네임이 변경되었습니다.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: DioExceptionHandler.getMessage(e),
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: '비밀번호가 변경되었습니다.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: DioExceptionHandler.getMessage(e),
      );
      return false;
    }
  }

  Future<bool> updateBleVisibility(String visibility) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateBleVisibility(visibility);
      final updated = Map<String, dynamic>.from(state.profile ?? {});
      updated['bleVisibility'] = visibility;
      state = state.copyWith(
        profile: updated,
        isLoading: false,
        successMessage: 'BLE 공개 설정이 변경되었습니다.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: DioExceptionHandler.getMessage(e),
      );
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.deleteAccount();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: DioExceptionHandler.getMessage(e),
      );
      return false;
    }
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository());

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref.watch(userRepositoryProvider)),
);

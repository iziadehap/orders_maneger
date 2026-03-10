import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moamen_project/core/error/failure.dart';
import 'package:moamen_project/core/services/supabase_service.dart';
import 'package:moamen_project/core/utils/supabase_text.dart';
import 'package:moamen_project/core/utils/images.dart';
import 'package:moamen_project/features/auth/presentation/controller/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'setting_state.dart';

class SettingNotifier extends Notifier<SettingState> {
  late SupabaseClient _supabase;

  @override
  SettingState build() {
    _supabase = ref.read(supabaseClientProvider);
    return const SettingState();
  }

  Future<void> updateProfile({
    String? name,
    File? imageFile,
    required bool isImageChanged,
  }) async {
    state = state.copyWith(
      isLoading: true,
      failureInEditScreen: null,
      isSuccess: false,
    );
    print('name $name');

    try {
      final user = ref.read(authProvider).user;
      // check if user is null
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          failureInEditScreen: Failure(
            // arabic message
            message: 'يوجد مشكلة',
            // type with arabic 'try to logout and login again '
            description:
                'الرجاء تسجيل الخروج ثم تسجيل الدخول لكي تتمكن من تحديث الملف الشخصي',
          ),
        );
        print('user is null');
        return;
      }
      // check if image file is null
      if (isImageChanged && imageFile == null) {
        state = state.copyWith(
          isLoading: false,
          failureInEditScreen: Failure(
            // arabic message
            message: 'يوجد مشكلة',
            // type with arabic 'try to logout and login again '
            description:
                'الرجاء المحاولة مرة أخرى لكي تتمكن من تحديث الملف الشخصي',
          ),
        );
        print('image file is null');
        return;
      }
      // cehck if any think changed
      // if (name != user.name || isImageChanged) {
      //   state = state.copyWith(isLoading: false, isUpdateBottonEnabled: true);
      //   print('any think changed');
      //   return;
      // }

      String? imageUrl = user.imageUrl;

      // 1. Compress and Upload image if provided
      if (imageFile != null) {
        final compressedFile = await ImageUtils.compressImage(imageFile);
        imageUrl = await ImageUtils.uploadPhoto(
          supabase: _supabase,
          file: compressedFile,
          bucket: SupabaseTables.PhotosBucket,
        );

        if (imageUrl == null) {
          state = state.copyWith(
            isLoading: false,
            failureInEditScreen: Failure(
              // arabic message 'there is problem win uploading image'
              message: 'يوجد مشكلة في رفع الصورة',
              // type with arabic 'try another time '
              description:
                  'الرجاء المحاولة مرة أخرى لكي تتمكن من تحديث الملف الشخصي',
            ),
          );
        }
      }

      // 2. Update profile in database
      final updates = {
        if (name != null) SupabaseProfileCulomns.name: name,
        SupabaseProfileCulomns.imageUrl: imageUrl,
        // SupabaseProfileCulomns.updatedAt: DateTime.now().toIso8601String(),
      };

      await _supabase
          .from(SupabaseTables.profiles)
          .update(updates)
          .eq(SupabaseProfileCulomns.id, user.id);

      // 3. Update local auth state
      final updatedUser = user.copyWith(
        name: name ?? user.name,
        imageUrl: imageUrl,
      );
      ref.read(authProvider.notifier).setUser(updatedUser);

      print('updated user $updatedUser');

      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      print('error while updating profile $e');
      // arabic message 'there is problem win updating profile'
      state = state.copyWith(
        isLoading: false,
        failureInEditScreen: Failure(
          message: 'يوجد مشكلة في تحديث الملف الشخصي',
          description:
              'الرجاء المحاولة مرة أخرى لكي تتمكن من تحديث الملف الشخصي',
        ),
      );
    }
  }

  void reset() {
    state = const SettingState();
  }
}

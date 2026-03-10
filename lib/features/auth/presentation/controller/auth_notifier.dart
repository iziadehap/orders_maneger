import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:moamen_project/core/utils/fake_email.dart';
import 'package:moamen_project/core/utils/normiliz_eg_phone.dart';
import 'package:moamen_project/core/utils/supabase_text.dart';
import 'package:moamen_project/features/auth/presentation/controller/auth_provider.dart';
import 'package:moamen_project/features/dashboard/presentation/controller/nav_notifier.dart';
import 'package:moamen_project/features/map/presentation/controller/map_provider.dart';
import 'package:moamen_project/features/orders/presentation/controller/order_provider.dart';
import 'package:moamen_project/features/pricelist/presentation/controller/priceList_provider.dart';
import 'package:moamen_project/features/settings/presentation/riverpod/setting_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/models/user_model.dart';
import 'auth_state.dart';

class AuthNotifier extends Notifier<AppAuthState> {
  late final SupabaseClient _supabase;

  @override
  AppAuthState build() {
    _supabase = ref.read(supabaseClientProvider);
    return const AppAuthState();
  }

  Future<void> login(
    String phone,
    String password, {
    bool isFromCash = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Normalize phone number
      String normalizedPhone;
      try {
        normalizedPhone = normalizeEgyptianPhone(phone);
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: 'رقم الهاتف غير صحيح، يرجى إدخال رقم مصري صالح',
        );
        return;
      }

      final phoneEmail = PhoneToEmailConverter.generateFakeEmail(
        normalizedPhone,
      );

      final response = await _supabase.auth.signInWithPassword(
        email: phoneEmail,
        password: password,
      );

      if (response.user == null) {
        state = state.copyWith(error: 'رقم الهاتف غير موجود');
        return;
      }

      // Get user profile from profiles table
      final profileResponse = await _supabase
          .from(SupabaseTables.profiles)
          .select()
          .eq(SupabaseProfileCulomns.id, response.user!.id)
          .maybeSingle();

      if (profileResponse == null) {
        state = state.copyWith(error: 'حدث خطأ في تحميل البيانات');
        return;
      }

      // Create user model
      final user = UserModel.fromMap(profileResponse);
      state = state.copyWith(user: user, error: null);
    } on AuthException catch (error) {
      print('❌ Auth error: ${error.message} (code: ${error.statusCode})');

      if (error.message.contains('Invalid login credentials') ||
          error.message.contains('invalid_credentials')) {
        state = state.copyWith(error: 'رقم الهاتف أو كلمة المرور غير صحيحة');
      } else if (error.message.contains('User not found') ||
          error.message.contains('user_not_found')) {
        state = state.copyWith(error: 'رقم الهاتف غير مسجل');
      } else {
        state = state.copyWith(error: 'فشل تسجيل الدخول: ${error.message}');
      }
    } on PostgrestException catch (error) {
      print('❌ Postgrest error: ${error.message} (code: ${error.code})');
      state = state.copyWith(error: 'حدث خطأ في تحميل البيانات');
    } catch (e) {
      print('❌ Unexpected error: $e');
      state = state.copyWith(error: 'حدث خطأ: ${e.toString()}');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Future<void> login(
  //   String phone,
  //   String password, {
  //   bool isFromCash = false,
  // }) async {
  //   state = state.copyWith(isLoading: true, error: null);
  //
  //   try {
  //     phone = normalizeEgyptianPhone(phone);
  //     // Query user by phone
  //     final response = await _supabase
  //         .from(SupabaseTables.accounts)
  //         .select()
  //         .eq(SupabaseAccountsCulomns.phone, phone)
  //         .maybeSingle();
  //
  //     if (response == null) {
  //       state = AppAuthState(error: 'رقم الهاتف غير موجود');
  //       return;
  //     }
  //
  //     // Verify password
  //     final passwordHash = response[SupabaseAccountsCulomns.password] as String;
  //     // if isFromCash is true then compare the password with the passwordHash
  //     final isValid = isFromCash
  //         ? passwordHash == password
  //         : BCrypt.checkpw(password, passwordHash);
  //
  //     if (!isValid) {
  //       state = AppAuthState(error: 'كلمة المرور غير صحيحة');
  //       return;
  //     }
  //
  //     // save user in cash
  //     if (!isFromCash) {
  //       await PrivcyCash.saveCredentials(phone: phone, password: passwordHash);
  //     }
  //
  //     // Create user model
  //     final user = UserModel.fromMap(response);
  //     state = AppAuthState(user: user);
  //   } catch (e) {
  //     state = AppAuthState(error: 'حدث خطأ: ${e.toString()}');
  //   }
  // }

  Future<void> register(
    String phone,
    String password,
    String name,
    String name2,
  ) async {
    phone = normalizeEgyptianPhone(phone);
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Hash password
      // final passwordHash = await PrivcyCash.hashPassword(password);

      final fullName = name + ' ' + name2;
      final phoneEmail = PhoneToEmailConverter.generateFakeEmail(phone);

      final response = await _supabase.auth.signUp(
        email: phoneEmail,
        password: password,
      );

      // Insert + return the new row (now safe because of the SELECT policy above)
      final inserted = await _supabase
          .from(SupabaseTables.profiles)
          .insert({
            SupabaseProfileCulomns.id: response.user!.id,
            SupabaseProfileCulomns.phone: phoneEmail,
            SupabaseProfileCulomns.role: 'user',
            SupabaseProfileCulomns.name: fullName,
            SupabaseProfileCulomns.isActive: false,
            SupabaseProfileCulomns.maxOrders: 0,
            // SupabaseAccountsCulomns.password: password,
            // SupabaseAccountsCulomns.role: 'user',
            // SupabaseAccountsCulomns.isActive: false,
          })
          .select()
          .single();

      print('✅ Account created: $inserted');

      // Create user model
      final user = UserModel.fromMap(inserted);
      print('✅ User created: $user');
      print('user id = ${user.id}');
      print('user name = ${user.name}');
      print('user phone = ${user.phone}');
      print('user role = ${user.role}');
      print('user is active = ${user.isActive}');

      // save user in cash
      // await PrivcyCash.saveCredentials(phone: phone, password: passwordHash);

      // Success → put the user in state
      state = state.copyWith(user: user, error: null);
    } on PostgrestException catch (error) {
      print('❌ Postgrest error: ${error.message} (code: ${error.code})');

      if (error.code == '23505') {
        state = state.copyWith(error: 'رقم الهاتف مسجل بالفعل');
      } else if (error.code == '42501') {
        state = state.copyWith(error: 'خطأ في الصلاحيات، حاول مرة أخرى');
      } else {
        state = state.copyWith(error: 'فشل إنشاء الحساب: ${error.message}');
      }
    } on AuthException catch (error) {
      print('❌ Auth error: ${error.message} (code: ${error.statusCode})');

      if (error.message.contains('already registered') ||
          error.message.contains('user_already_exists')) {
        state = state.copyWith(
          error: 'رقم الهاتف مسجل بالفعل، يرجى تسجيل الدخول',
        );
      } else {
        state = state.copyWith(error: 'فشل إنشاء الحساب: ${error.message}');
      }
    } catch (e) {
      print('Unexpected error: $e');
      print('errorcode = ${e}');

      state = state.copyWith(error: 'فشل إنشاء الحساب: ${e.toString()}');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
  // Future<void> register(
  //   String phone,
  //   String password,
  //   String name,
  //   String name2,
  // ) async {
  //   phone = normalizeEgyptianPhone(phone);
  //   state = state.copyWith(isLoading: true, error: null);
  //
  //   try {
  //     // Hash password
  //     final passwordHash = await PrivcyCash.hashPassword(password);
  //
  //     final fullName = name + ' ' + name2;
  //
  //     // Insert + return the new row (now safe because of the SELECT policy above)
  //     final inserted = await _supabase
  //         .from(SupabaseTables.accounts)
  //         .insert({
  //           SupabaseAccountsCulomns.phone: phone,
  //           SupabaseAccountsCulomns.password: passwordHash,
  //           SupabaseAccountsCulomns.name: fullName,
  //           SupabaseAccountsCulomns.role: 'user',
  //           SupabaseAccountsCulomns.isActive: false,
  //         })
  //         .select()
  //         .single();
  //
  //     print('✅ Account created: $inserted');
  //
  //     // Create user model
  //     final user = UserModel.fromMap(inserted);
  //     print('✅ User created: $user');
  //     print('user id = ${user.id}');
  //     print('user name = ${user.name}');
  //     print('user phone = ${user.phone}');
  //     print('user role = ${user.role}');
  //     print('user is active = ${user.isActive}');
  //
  //     // save user in cash
  //     await PrivcyCash.saveCredentials(phone: phone, password: passwordHash);
  //
  //     // Success → put the user in state
  //     state = state.copyWith(user: user, error: null);
  //   } on PostgrestException catch (error) {
  //     print('❌ Postgrest error: ${error.message} (code: ${error.code})');
  //
  //     if (error.code == '23505') {
  //       state = state.copyWith(error: 'رقم الهاتف مسجل بالفعل');
  //     } else if (error.code == '42501') {
  //       state = state.copyWith(error: 'خطأ في الصلاحيات، حاول مرة أخرى');
  //     } else {
  //       state = state.copyWith(error: 'فشل إنشاء الحساب: ${error.message}');
  //     }
  //   } catch (e) {
  //     print('Unexpected error: $e');
  //     state = state.copyWith(error: 'فشل إنشاء الحساب: ${e.toString()}');
  //   } finally {
  //     state = state.copyWith(isLoading: false);
  //   }
  // }

  void setUser(UserModel user) {
    state = state.copyWith(user: user, error: null);
  }

  void logout() {
    _supabase.auth.signOut();
   
  ref.invalidate(authProvider);
  ref.invalidate(orderProvider);
  ref.invalidate(mapProvider);
  ref.invalidate(priceProvider);
  ref.invalidate(navIndexProvider);
  ref.invalidate(settingProvider);
  
  // auth غالبًا هتعمله set null أو invalidate حسب تصميمك

    state = state.clearUser();
  }

  void clearError() {
    state = state.clearError();
  }
}

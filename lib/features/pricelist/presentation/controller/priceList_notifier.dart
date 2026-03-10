import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moamen_project/core/utils/images.dart';
import 'package:moamen_project/core/utils/supabase_text.dart';
import 'package:moamen_project/features/pricelist/data/priceList_model.dart';
import 'package:moamen_project/features/pricelist/presentation/controller/priceList_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PricelistNotifier extends Notifier<PricelistState> {
  late SupabaseClient _supabase;

  @override
  PricelistState build() {
    _supabase = Supabase.instance.client;
    return PricelistState(pricelist: [], isLoading: false, error: null);
  }

  Future<void> getPricelist() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _supabase
          .from(SupabaseTables.pricelist)
          .select()
          .order(SupabasePricelistCulomns.createdAt, ascending: false);

      final pricelist = List<PriceListModel>.from(
        data.map((e) => PriceListModel.fromJson(e)),
      );

      state = state.copyWith(pricelist: pricelist, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> pickLocalPhoto() async {
    final picker = ImagePicker();
    final List<XFile> pickedXFiles = await picker.pickMultiImage();
    if (pickedXFiles.isEmpty) return;

    final List<File> pickedFiles = pickedXFiles
        .map((x) => File(x.path))
        .toList();
    state = state.copyWith(localPhotos: [...state.localPhotos, ...pickedFiles]);
  }

  void removeLocalPhoto(int index) {
    final newLocalPhotos = List<File>.from(state.localPhotos);
    newLocalPhotos.removeAt(index);
    state = state.copyWith(localPhotos: newLocalPhotos);
  }

  Future<List<String>> uploadAllPhotos() async {
    if (state.localPhotos.isEmpty) return [];

    state = state.copyWith(isLoading: true, error: null);
    final List<String> uploadedUrls = [];

    try {
      for (var file in state.localPhotos) {
        final compressedFile = await ImageUtils.compressImage(file);
        final url = await ImageUtils.uploadPhoto(
          supabase: _supabase,
          file: compressedFile,
          bucket: SupabaseTables.PhotosBucket,
        );
        if (url != null) {
          uploadedUrls.add(url);
        }
      }
      state = state.copyWith(isLoading: false);
      return uploadedUrls;
    } catch (e) {
      print('Error uploading photos: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return [];
    }
  }

  void setPhotoUrls(List<String> urls) {
    state = state.copyWith(photoUrls: urls);
  }

  void removePhoto(int index) {
    final newUrls = List<String>.from(state.photoUrls);
    newUrls.removeAt(index);
    state = state.copyWith(photoUrls: newUrls);
  }

  // Administrative Operations (Add, Update, Delete)

  Future<void> addPriceItem({
    required String title,
    required double price,
    String? description,
    List<String>? photoUrls,
    bool isActive = true,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final res = await _supabase
          .from(SupabaseTables.pricelist)
          .insert({
            SupabasePricelistCulomns.title: title,
            SupabasePricelistCulomns.price: price,
            SupabasePricelistCulomns.description: description,
            SupabasePricelistCulomns.photoUrls: photoUrls ?? [],
            SupabasePricelistCulomns.isActive: isActive,
          })
          .select()
          .single();

      if (res.isNotEmpty) {
        state = state.copyWith(isLoading: false, isSuccess: true);
        await getPricelist();
      } else {
        throw 'فشل في إضافة الخدمة: لم يتم إرجاع بيانات';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updatePriceItem({
    required String priceId,
    String? title,
    double? price,
    String? description,
    List<String>? photoUrls,
    bool? isActive,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);

    try {
      final updates = {
        if (title != null) SupabasePricelistCulomns.title: title,
        if (price != null) SupabasePricelistCulomns.price: price,
        if (description != null)
          SupabasePricelistCulomns.description: description,
        if (photoUrls != null) SupabasePricelistCulomns.photoUrls: photoUrls,
        if (isActive != null) SupabasePricelistCulomns.isActive: isActive,
      };

      final res = await _supabase
          .from(SupabaseTables.pricelist)
          .update(updates)
          .eq(SupabasePricelistCulomns.id, priceId)
          .select();

      if (res.isEmpty) {
        throw 'فشل التعديل: لا توجد صلاحيات أو الخدمة غير موجودة';
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
      await getPricelist();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> deletePriceItem({required String priceId}) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final res = await _supabase
          .from(SupabaseTables.pricelist)
          .delete()
          .eq(SupabasePricelistCulomns.id, priceId)
          .select();

      if (res.isEmpty) {
        throw 'فشل الحذف: لا توجد صلاحيات أو الخدمة غير موجودة';
      }

      state = state.copyWith(isLoading: false, isSuccess: true);
      await getPricelist();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void resetActionState() {
    state = state.resetAction();
  }
}

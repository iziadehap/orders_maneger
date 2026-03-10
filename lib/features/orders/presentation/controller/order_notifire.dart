import 'dart:io';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moamen_project/core/error/failure.dart';
import 'package:moamen_project/core/utils/app_config_data.dart';
import 'package:moamen_project/core/utils/supabase_text.dart';
import 'package:moamen_project/core/utils/images.dart';
import 'package:moamen_project/features/orders/data/models/order_model.dart';
import 'package:moamen_project/features/orders/presentation/controller/order_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderNotifier extends Notifier<OrderState> {
  @override
  OrderState build() {
    return OrderState();
  }

  final _supabase = Supabase.instance.client;

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true, isError: false);

    try {
      final response = await _supabase
          .from(SupabaseTables.ordersWithWorker)
          .select()
          .order(SupabaseOrdersCulomns.createdAt, ascending: false);

      // print('response $response');

      final List<Order> orders = (response as List<dynamic>)
          .map((order) => Order.fromJson(order as Map<String, dynamic>))
          .toList();

      // change priority
      var ordersWithPriority = await updatePriority(orders);

      state = state.copyWith(
        orders: ordersWithPriority,
        isLoading: false,
        hasFetched: true,
      );
    } catch (e) {
      print(e);
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
        hasFetched: true,
      );
    }
  }

  Future<List<Order>> updatePriority(List<Order> orders) async {
    print('DEBUG: updatePriority started with ${orders.length} orders');
    try {
      final appConfig = await AppConfigData().getAppConfig();

      final interval = appConfig.fold(
        (failure) {
          state = state.copyWith(
            hintError: HintError(
              message: 'خطأ في تحديث الأولوية',
              description: 'حدث خطأ أثناء تحديث الأولوية',
            ),
          );
          return 0;
        },
        (configModel) {
          return configModel.priorityChange;
        },
      );

      // print('DEBUG: priorityChange interval from config: $interval');

      if (interval <= 0) {
        // print('DEBUG: interval is <= 0, skipping priority update');
        return orders;
      }

      final now = DateTime.now();

      final updatedOrders = orders.map((order) {
        if (order.createdAt == null) return order;

        final hoursElapsed = now.difference(order.createdAt!).inHours;
        final bumps = hoursElapsed ~/ interval;

        if (bumps <= 0) return order;

        int currentIdx = order.priority.index;
        int newIdx = currentIdx + bumps;

        if (newIdx > OrderPriority.urgent.index) {
          newIdx = OrderPriority.urgent.index;
        }

        if (newIdx == currentIdx) return order;

        // print(
        //   'DEBUG: Upgrading Order "${order.title}" from ${order.priority.name} to ${OrderPriority.values[newIdx].name} (Age: ${hoursElapsed}h, Bumps: $bumps)',
        // );
        return order.copyWith(priority: OrderPriority.values[newIdx]);
      }).toList();

      print('DEBUG: updatePriority completed successfully');
      return updatedOrders;
    } catch (e, stack) {
      print('DEBUG: Error in updatePriority: $e');
      print('DEBUG: StackTrace: $stack');
      return orders;
    }
  }

  Future<dartz.Either<Failure, bool>> acceptOrder(String orderId) async {
    final userId = _supabase.auth.currentUser!.id;
    state = state.copyWith(isLoading: true, isError: false);

    try {
      await _supabase.rpc(
        SupabaseFunctions.acceptOrder,
        params: {'p_user_id': userId, 'p_order_id': orderId},
      );

      // عدّل الطلب محليًا بدل fetchOrders()
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          print('order accepted');

          return order.copyWith(
            status: OrderStatus.accepted,
            workerId: userId,
            acceptedAt: DateTime.now(), // تقريبًا، لأن DB هي اللي بتحددها
          );
        }
        return order;
      }).toList();

      state = state.copyWith(isLoading: false, orders: updatedOrders);

      return dartz.Right(true);
    } on PostgrestException catch (e) {
      // print('error in accept order with PostgrestException $e');
      // print('error in accept order with PostgrestException ${e.message}');
      if (e.message == 'User Max_order is 0') {
        state = state.copyWith(isLoading: false);
        return dartz.Left(
          Failure(
            message: 'الحد الاقصى للطلبات',
            description:
                'لا يمكن قبول المزيد من الطلبات تواصل مع مسؤول النظام لاضافه أردرات ',
          ),
        );
      }
      state = state.copyWith(isLoading: false);
      return dartz.Left(
        Failure(message: 'خطأ في قبول الطلب', description: e.toString()),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      print('error in accept order with catch $e');
      return dartz.Left(
        Failure(message: 'خطأ في قبول الطلب', description: e.toString()),
      );
    }
  }

  Future<void> completeOrder(String orderId) async {
    state = state.copyWith(isLoading: true, isError: false);

    try {
      await _supabase
          .from(SupabaseTables.orders)
          .update({
            SupabaseOrdersCulomns.status: OrderStatus.completed.name,
            SupabaseOrdersCulomns.updatedAt: DateTime.now().toIso8601String(),
          })
          .eq(SupabaseOrdersCulomns.id, orderId);

      // عدّل الطلب محليًا بدل fetchOrders()
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          print('order completed');

          return order.copyWith(
            status: OrderStatus.completed,
            updatedAt: DateTime.now(),
          );
        }
        return order;
      }).toList();

      state = state.copyWith(isLoading: false, orders: updatedOrders);
    } catch (e) {
      print('error in complete order $e');
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String?> createOrderByAdmin({
    required String adminId,
    required Order orderData,
  }) async {
    state = state.copyWith(isLoading: true, isError: false);

    try {
      print('DEBUG: createOrderByAdmin starting');

      final jsonPayload = orderData.toJson();
      print('DEBUG: Insert Payload: $jsonPayload');

      final response = await _supabase
          .from(SupabaseTables.orders) // تأكد هنا جدول orders الأصلي
          .insert(jsonPayload)
          .select(); // ترجع الصف الجديد

      print('DEBUG: admin_create_order success, response: $response');

      state = state.copyWith(isLoading: false);

      if (response.isNotEmpty) {
        final serverOrder = Order.fromJson(response[0]);
        // add server-side order to list (it has createdAt)
        state = state.copyWith(orders: [serverOrder, ...state.orders]);
        return serverOrder.id;
      }

      return null;
    } catch (e) {
      print('DEBUG: createOrderByAdmin ERROR: $e');
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<bool> updateOrder({
    required String orderId,
    required Order orderData,
  }) async {
    state = state.copyWith(isLoading: true, isError: false);

    try {
      print('DEBUG: updateOrder starting for $orderId');
      final response = await _supabase
          .from(SupabaseTables.orders)
          .update(orderData.toJson())
          .eq('id', orderId);

      print('DEBUG: updateOrder success');

      state = state.copyWith(isLoading: false);
      // update order in list
      final updatedOrders = state.orders.map((order) {
        if (order.id == orderId) {
          return orderData;
        }
        return order;
      }).toList();
      state = state.copyWith(orders: updatedOrders);
      // fetchOrders(); // Refresh the list
      return true;
    } catch (e) {
      print('DEBUG: updateOrder ERROR: $e');
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
      );
      return false;
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

    state = state.copyWith(isLoading: true, isError: false);
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
      state = state.copyWith(isLoading: false, isError: true);
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

  void resetPhotos() {
    state = state.copyWith(photoUrls: [], localPhotos: []);
  }

  // Future<bool> deleteOrder({
  //   required String orderId,
  //   required String userId,
  //   required Order order,
  // }) async {
  //   state = state.copyWith(isLoading: true, isError: false);

  //   try {
  //     final List<String> filePaths = order.photoUrls.map((url) {
  //       final uri = Uri.parse(url);
  //       // uri.path = "/storage/v1/object/public/orders-photos/1771459910224_48_compressed.webp"
  //       final parts = uri.path.split('/public/');
  //       if (parts.length < 2) {
  //         throw Exception('Invalid photo URL: $url');
  //       }
  //       final bucketAndPath =
  //           parts[1]; // "orders-photos/1771459910224_48_compressed.webp"
  //       final pathParts = bucketAndPath.split(
  //         '/',
  //       ); // [ "orders-photos", "1771459910224_48_compressed.webp" ]
  //       if (pathParts.length < 2) {
  //         throw Exception('Invalid path format: $url');
  //       }
  //       return pathParts[1]; // => "1771459910224_48_compressed.webp" فقط
  //     }).toList();

  //     if (filePaths.isNotEmpty) {
  //       try {
  //         await _supabase.storage
  //             .from(SupabaseTables.PhotosBucket)
  //             .remove(filePaths);
  //       } catch (e) {
  //         print('Storage cleanup error (proceeding): $e');
  //       }
  //     }

  //     // 3. Delete the record from the database
  //     // Use select() to confirm deletion
  //     final dbResponse = await _supabase
  //         .from(SupabaseTables.orders)
  //         .delete()
  //         .eq(SupabaseOrdersCulomns.id, orderId)
  //         .select();

  //     print('DB Delete Response: $dbResponse');

  //     if ((dbResponse as List).isEmpty) {
  //       print(
  //         'Error: Order NOT deleted from database. Check RLS policies for table "orders".',
  //       );
  //       state = state.copyWith(
  //         isLoading: false,
  //         isError: true,
  //         errorMessage: 'فشل حذف الاوردر.',
  //       );
  //       return false;
  //     }

  //     state = state.copyWith(isLoading: false);
  //     // remove order from list
  //     final updatedOrders = state.orders
  //         .where((order) => order.id != orderId)
  //         .toList();
  //     state = state.copyWith(orders: updatedOrders);
  //     // fetchOrders();
  //     return true;
  //   } catch (e) {
  //     print('Delete error: $e');
  //     state = state.copyWith(
  //       isLoading: false,
  //       isError: true,
  //       errorMessage: e.toString(),
  //     );
  //     return false;
  //   }
  // }

  // Future<bool> cancelOrder({
  //   required String orderId,
  //   required String userId,
  // }) async {
  //   state = state.copyWith(isLoading: true, isError: false);

  //   try {
  //     final response = await _supabase
  //         .from(SupabaseTables.orders)
  //         .update({SupabaseOrdersCulomns.status: OrderStatus.cancelled.name})
  //         .eq(SupabaseOrdersCulomns.id, orderId);

  //     print(response); // "تم حذف الاوردر بنجاح" أو "غير مصرح لك بحذف "

  //     state = state.copyWith(isLoading: false);

  //     // change order status to cancelled in list
  //     final updatedOrders = state.orders.map((order) {
  //       if (order.id == orderId) {
  //         return order.copyWith(status: OrderStatus.cancelled);
  //       }
  //       return order;
  //     }).toList();
  //     state = state.copyWith(orders: updatedOrders);
  //     // fetchOrders(); // Refresh the list
  //     return true;
  //   } catch (e) {
  //     print(e);
  //     state = state.copyWith(
  //       isLoading: false,
  //       isError: true,
  //       errorMessage: e.toString(),
  //     );
  //     return false;
  //   }
  // }

  void clearHintError() {
    print('DEBUG: clearHintError');
    print('DEBUG: state: ${state.hintError}');
    state = state.copyWith(clearHintError: true);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:moamen_project/features/map/data/map_model.dart';
import 'package:moamen_project/features/map/presentation/controller/map_state.dart';
import 'package:moamen_project/features/orders/data/models/order_model.dart';
import 'package:moamen_project/features/orders/presentation/controller/order_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mbtiles/mbtiles.dart';

class MapNotifier extends Notifier<MapState> {
  StreamSubscription<Position>? _locationSubscription;

  static const String _osrmBase = 'https://router.project-osrm.org';

  @override
  MapState build() {
    ref.onDispose(() {
      _locationSubscription?.cancel();
    });

    // ✅ Listen to order changes and re-process map data automatically
    ref.listen(orderProvider, (previous, next) {
      if (!next.isLoading && next.orders.isNotEmpty) {
        _processOrders(next.orders);
      }
    });

    return MapState(
      isLoding: false,
      mapModel: MapModel(userPoints: [], publicPoints: []),
      errorMassage: "",
      hintMassage: "",
      userLocation: const LatLng(30.0444, 31.2357), // Default Cairo
      showPublicCircles: true,
      routePoints: const [],
    );
  }

  // ✅ Cache keys
  static const String _cacheRoutePoints = 'map_cache_route_points';
  static const String _cacheLastLocLat = 'map_cache_last_loc_lat';
  static const String _cacheLastLocLon = 'map_cache_last_loc_lon';
  static const String _cacheOrderIds = 'map_cache_order_ids';
  // ─── MBTiles ───────────────────────────────────

  Future<void> initLocationService() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      state = state.copyWith(
        userLocation: LatLng(position.latitude, position.longitude),
      );

      // Trigger re-sort/routing if orders are already loaded but were routed with default location
      if (state.mapModel.userPoints.isNotEmpty) {
        sortOrdersByRoad(state.userLocation!, state.mapModel);
      }

      _locationSubscription?.cancel();
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (Position position) {
              // تحديث الموقع فقط.. من غير routing عشان ما نضربش OSRM كتير
              state = state.copyWith(
                userLocation: LatLng(position.latitude, position.longitude),
              );
            },
            onError: (e) {
              print("Location stream error: $e");
            },
          );
    } catch (e) {
      print("Error in initLocationService: $e");
    }
  }

  void togglePublicCircles() {
    state = state.copyWith(showPublicCircles: !state.showPublicCircles);
  }

  Future<void> getOrders() async {
    state = state.copyWith(isLoding: true, errorMassage: "", hintMassage: "");
    try {
      await ref.read(orderProvider.notifier).fetchOrders();
      // Logic removed from here, handled by the listener in build()
    } catch (e) {
      print('Error triggering getOrders: $e');
      state = state.copyWith(isLoding: false, errorMassage: e.toString());
    }
  }

  Future<void> _processOrders(List<Order> orders) async {
    state = state.copyWith(isLoding: true, errorMassage: "", hintMassage: "");
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      final MapModel mapModel = MapModel(userPoints: [], publicPoints: []);
      final List<CircleOrder> circles = [];

      for (final order in orders) {
        if (order.latitude == null || order.longitude == null) continue;

        if (order.workerId == currentUserId &&
            (order.status == OrderStatus.accepted)) {
          mapModel.userPoints.add(order);
          continue;
        }

        if (order.status != OrderStatus.pending) continue;

        bool addedToCircle = false;
        for (final circle in circles) {
          if (circle.orders.isNotEmpty) {
            final center = circle.orders.first;
            final distance = Geolocator.distanceBetween(
              order.latitude!,
              order.longitude!,
              center.latitude!,
              center.longitude!,
            );
            if (distance <= 1000) {
              circle.orders.add(order);
              addedToCircle = true;
              break;
            }
          }
        }
        if (!addedToCircle) {
          circles.add(
            CircleOrder(
              points: LatLng(order.latitude!, order.longitude!),
              orders: [order],
            ),
          );
        }
      }

      mapModel.publicPoints = circles;

      final loc = state.userLocation;
      if (loc != null && mapModel.userPoints.isNotEmpty) {
        await sortOrdersByRoad(loc, mapModel);
      } else {
        state = state.copyWith(
          isLoding: false,
          mapModel: mapModel,
          routePoints: const [],
        );
      }
    } catch (e) {
      print('Error in _processOrders map screen: $e');
      state = state.copyWith(isLoding: false, errorMassage: e.toString());
    }
  }

  // =========================
  // ✅ OSRM helpers
  // =========================
  String _coord(LatLng p) => '${p.longitude},${p.latitude}'; // lon,lat

  Future _sortOrdersByDistance(List<Order> orders, LatLng location) async {
    orders.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        a.latitude!,
        a.longitude!,
      );
      final distB = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        b.latitude!,
        b.longitude!,
      );
      return distA.compareTo(distB);
    });
  }

  Future<List<LatLng>> _osrmRouteGeoJson(List<LatLng> orderedPoints) async {
    final coords = orderedPoints.map(_coord).join(';');
    final url = Uri.parse(
      '$_osrmBase/route/v1/driving/$coords?overview=full&geometries=geojson',
    );

    int retries = 2;
    while (retries >= 0) {
      try {
        final res = await http
            .get(url, headers: {'User-Agent': 'moamen-project/1.0'})
            .timeout(const Duration(seconds: 20));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final routes = json['routes'] as List<dynamic>;
          if (routes.isEmpty) return [];

          final firstRoute = routes.first as Map<String, dynamic>;
          final geometry = firstRoute['geometry'] as Map<String, dynamic>;
          final coordsList = geometry['coordinates'] as List<dynamic>;

          return coordsList.map((c) {
            final pair = c as List<dynamic>;
            final lon = (pair[0] as num).toDouble();
            final lat = (pair[1] as num).toDouble();
            return LatLng(lat, lon);
          }).toList();
        } else {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          if (res.statusCode == 400 && json['code'] == 'NoRoute') {
            print(
              '⚠️ OSRM: Impossible route between points. Skipping retries.',
            );
            return [];
          }
          throw Exception('OSRM route failed: ${res.statusCode} ${res.body}');
        }
      } catch (e) {
        if (retries == 0) rethrow;
        print('Retrying OSRM route due to: $e');
        retries--;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    return [];
  }

  // =========================
  // ✅ Main sorting by road
  // =========================
  Future<void> sortOrdersByRoad(LatLng location, MapModel mapModel) async {
    try {
      final orders = mapModel.userPoints
          .where((o) => o.latitude != null && o.longitude != null)
          .toList();

      if (orders.isEmpty) {
        state = state.copyWith(
          isLoding: false,
          mapModel: mapModel,
          routePoints: const [],
        );
        return;
      }

      // 1) Sort by distance from current location
      await _sortOrdersByDistance(orders, location);

      final limited = orders.take(10).toList();
      final points = <LatLng>[
        location,
        ...limited.map((o) => LatLng(o.latitude!, o.longitude!)),
      ];

      final remaining = orders.skip(10).toList();
      final sortedAll = <Order>[...limited, ...remaining];

      final sortedMapModel = MapModel(
        userPoints: sortedAll,
        publicPoints: mapModel.publicPoints,
      );

      // --- ✅ Caching Logic Start ---
      final prefs = await SharedPreferences.getInstance();
      final currentOrderIds = limited.map((o) => o.id).join(',');

      final cachedOrderIds = prefs.getString(_cacheOrderIds);
      final cachedLat = prefs.getDouble(_cacheLastLocLat);
      final cachedLon = prefs.getDouble(_cacheLastLocLon);
      final cachedRouteStr = prefs.getString(_cacheRoutePoints);

      bool isCacheValid = false;
      List<LatLng> routePoints = [];

      if (cachedOrderIds == currentOrderIds &&
          cachedLat != null &&
          cachedLon != null &&
          cachedRouteStr != null) {
        final distToCache = Geolocator.distanceBetween(
          location.latitude,
          location.longitude,
          cachedLat,
          cachedLon,
        );

        // threshold 2km
        if (distToCache < 2000) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedRouteStr);
            routePoints = decoded.map((e) => LatLng(e[0], e[1])).toList();
            isCacheValid = true;
            print('✅ Map cache hit (Dist: ${distToCache.toInt()}m)');
          } catch (e) {
            print('❌ Cached route decode failed: $e');
          }
        }
      }

      if (!isCacheValid) {
        print('🔄 Map cache miss, fetching from OSRM...');
        try {
          routePoints = await _osrmRouteGeoJson(points);
          if (routePoints.isNotEmpty) {
            // Save to cache
            await prefs.setString(_cacheOrderIds, currentOrderIds);
            await prefs.setDouble(_cacheLastLocLat, location.latitude);
            await prefs.setDouble(_cacheLastLocLon, location.longitude);
            final encoded = routePoints
                .map((p) => [p.latitude, p.longitude])
                .toList();
            await prefs.setString(_cacheRoutePoints, jsonEncode(encoded));
          }
        } catch (e) {
          print('Route calculation failed: $e');
          routePoints = points; // Fallback to straight lines
        }
      }
      // --- ✅ Caching Logic End ---

      state = state.copyWith(
        isLoding: false,
        mapModel: sortedMapModel,
        routePoints: routePoints.isNotEmpty ? routePoints : points,
        errorMassage: "",
        hintMassage: routePoints.isEmpty ? "الطريق غير متاح حاليا" : "",
      );
    } catch (e) {
      print('Major error in sortOrdersByRoad: $e');

      // Global fallback: simple distance sort without road routing
      final orders = mapModel.userPoints
          .where((o) => o.latitude != null && o.longitude != null)
          .toList();

      await _sortOrdersByDistance(orders, location);

      state = state.copyWith(
        isLoding: false,
        mapModel: MapModel(
          userPoints: orders,
          publicPoints: mapModel.publicPoints,
        ),
        routePoints: [
          location,
          ...orders.map((o) => LatLng(o.latitude!, o.longitude!)),
        ],
        hintMassage: "حدث خطأ في عرض المسار",
      );
    }
  }
}

// import 'package:mbtiles/mbtiles.dart';

// Future<void> debugMbtiles(String path) async {
//   final mb = MbTiles(mbtilesPath: path);
//   // await mb.open();
//   final meta = mb.getMetadata();
//   // meta keys usually include: format, bounds, center, minzoom, maxzoom, scheme...
//   // print them:
//   // ignore: avoid_print
//   print('MBTiles metadata: $meta');
//   // await mb.close();
// }

// Future<String> prepareMbtiles(
//   String mbtilesAssetPath,
//   int mbtilesVersion,
// ) async {
//   final dir = await getApplicationDocumentsDirectory();

//   // Versioned filename prevents rewriting every launch + supports upgrades.
//   final fileName = 'alexandria.mbtiles';
//   final file = File('${dir.path}/$fileName');

//   // ✅ If already exists, DO NOTHING.
//   print('✅ Checking for existing mbtiles file: ${file.path}');
//   if (await file.exists()) {
//     // debugMbtiles(file.path);
//     print('✅ MBTiles file already exists: ${file.path}');
//     return file.path;
//   }

//   // // Optional cleanup: delete older versions so you don't waste storage.
//   // try {
//   //   await deleteOldMbtilesVersions(dir.path, mbtilesVersion);
//   // } catch (e) {
//   //   print('Failed to delete old mbtiles versions: $e');
//   // }

//   // ✅ First run (or new version): copy from assets once.
//   print('✅ Copying mbtiles file from assets: $mbtilesAssetPath');
//   try {
//     final bytes = await rootBundle.load(mbtilesAssetPath);
//     await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
//   } catch (e) {
//     print('Failed to copy mbtiles file: $e');
//     throw e;
//   }

//   return file.path;
// }

// Future<void> deleteOldMbtilesVersions(
//   String dirPath,
//   int mbtilesVersion,
// ) async {
//   final dir = Directory(dirPath);
//   if (!await dir.exists()) return;

//   final files = dir.listSync().whereType<File>();
//   for (final f in files) {
//     final name = f.path.split(Platform.pathSeparator).last;
//     // delete any old alexandria_v*.mbtiles except the current version
//     if (name.startsWith('alexandria_v') &&
//         name.endsWith('.mbtiles') &&
//         !name.contains('_v$mbtilesVersion')) {
//       try {
//         await f.delete();
//       } catch (_) {
//         // ignore
//       }
//     }
//   }
// }

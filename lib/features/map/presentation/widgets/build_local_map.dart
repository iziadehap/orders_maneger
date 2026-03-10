// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:moamen_project/core/theme/app_colors.dart';
// import 'package:moamen_project/core/theme/app_theme.dart';
// import 'package:moamen_project/features/map/presentation/controller/map_state.dart';
// import 'package:path_provider/path_provider.dart';
//
// // Copy MBTiles from assets to a readable file path (required for MBTiles plugins).
// Future<String> _ensureMbtilesOnDisk({
//   required String assetPath,
//   required String fileName,
// }) async {
//   final dir = await getApplicationDocumentsDirectory();
//   final file = File('${dir.path}/$fileName');
//
//   if (await file.exists()) return file.path;
//
//   final bytes = await rootBundle.load(assetPath);
//   await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
//   return file.path;
// }
//
// class _LocalMapWrapper extends StatelessWidget {
//   const _LocalMapWrapper({
//     required this.mapController,
//     required this.center,
//     required this.mapState,
//     required this.showPublicCircles,
//     required this.customTheme,
//   });
//
//   final MapController mapController;
//   final LatLng center;
//   final MapState mapState;
//   final bool showPublicCircles;
//   final CustomThemeExtension customTheme;
//
//   @override
//   Widget build(BuildContext context) {
//     // NOTE: You can change this to your exact asset path/name.
//     const mbtilesAssetPath = 'assets/maps/alexandria.mbtiles';
//     const mbtilesFileName = 'alexandria.mbtiles';
//
//     return FutureBuilder<String>(
//       future: _ensureMbtilesOnDisk(
//         assetPath: mbtilesAssetPath,
//         fileName: mbtilesFileName,
//       ),
//       builder: (context, snap) {
//         if (!snap.hasData) {
//           return const Center(child: CircularProgressIndicator());
//         }
//
//         final mbtilesPath = snap.data!;
//
//         return FlutterMap(
//           mapController: mapController,
//           options: MapOptions(
//             initialCenter: center,
//             initialZoom: 13.0,
//             interactionOptions: const InteractionOptions(
//               flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
//             ),
//             onMapEvent: (event) {
//               // Rebuild to update edge indicator position
//               // (If this widget isn't State, remove this logic or lift it up)
//             },
//           ),
//           children: [
//             // ✅ OFFLINE TILE LAYER (MBTiles)
//             TileLayer(
//               // If your MBTiles is raster tiles (PNG/JPG/WebP), this works.
//               tileProvider: MbTilesTileProvider.fromPath(path: mbtilesPath),
//               // Optional: clamp zoom range to what's inside your MBTiles
//               // minZoom: 0,
//               // maxZoom: 18,
//               // retinaMode is irrelevant offline unless your tiles support @2x.
//             ),
//
//             if (mapState.routePoints.isNotEmpty)
//               PolylineLayer(
//                 polylines: [
//                   Polyline(
//                     points: mapState.routePoints,
//                     strokeWidth: 5,
//                     color: AppColors.primaryBlue.withOpacity(0.8),
//                     borderStrokeWidth: 2,
//                     borderColor: AppColors.primaryBlue.withOpacity(0.3),
//                   ),
//                 ],
//               ),
//
//             if (showPublicCircles)
//               CircleLayer(
//                 circles: mapState.mapModel.publicPoints.map((circleOrder) {
//                   return CircleMarker(
//                     point: circleOrder.points,
//                     color: AppColors.primaryPurple.withOpacity(0.1),
//                     borderColor: AppColors.primaryPurple.withOpacity(0.4),
//                     borderStrokeWidth: 1.5,
//                     useRadiusInMeter: true,
//                     radius: 1000,
//                   );
//                 }).toList(),
//               ),
//
//             MarkerLayer(
//               markers: [
//                 if (mapState.userLocation != null)
//                   Marker(
//                     point: mapState.userLocation!,
//                     width: 60,
//                     height: 60,
//                     child: _UserLocationMarker(),
//                   ),
//
//                 if (showPublicCircles)
//                   ...mapState.mapModel.publicPoints.map((circleOrder) {
//                     return Marker(
//                       point: circleOrder.points,
//                       width: 64,
//                       height: 64,
//                       child: GestureDetector(
//                         onTap: () => _showPublicOrdersSheet(circleOrder),
//                         child: _PublicClusterMarker(
//                           count: circleOrder.orders.length,
//                         ),
//                       ),
//                     );
//                   }),
//
//                 ...mapState.mapModel.userPoints.asMap().entries.map((entry) {
//                   final index = entry.key;
//                   final order = entry.value;
//
//                   if (order.latitude == null || order.longitude == null) {
//                     return const Marker(
//                       point: LatLng(0, 0),
//                       child: SizedBox.shrink(),
//                     );
//                   }
//
//                   return Marker(
//                     point: LatLng(order.latitude!, order.longitude!),
//                     width: 60,
//                     height: 60,
//                     child: GestureDetector(
//                       onTap: () => _showOrderDetailsSheet(order),
//                       child: _UserOrderMarker(
//                         index: index,
//                         priority: order.priority,
//                       ),
//                     ),
//                   );
//                 }),
//               ],
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
//
// // ─── Map Builder ─────────────────────────────
// Widget _buildLocalMap(
//   MapState mapState,
//   bool isDarkMode, // no longer used for tiles offline
//   CustomThemeExtension customTheme,
// ) {
//   final mapModel = mapState.mapModel;
//   final userLocation = mapState.userLocation;
//   final showPublicCircles = mapState.showPublicCircles;
//
//   LatLng center = const LatLng(30.0444, 31.2357);
//
//   if (userLocation != null) {
//     center = userLocation;
//   } else if (mapModel.userPoints.isNotEmpty &&
//       mapModel.userPoints.first.latitude != null) {
//     center = LatLng(
//       mapModel.userPoints.first.latitude!,
//       mapModel.userPoints.first.longitude!,
//     );
//   } else if (mapModel.publicPoints.isNotEmpty) {
//     center = mapModel.publicPoints.first.points;
//   }
//
//   return _LocalMapWrapper(
//     mapController: _mapController,
//     center: center,
//     mapState: mapState,
//     showPublicCircles: showPublicCircles,
//     customTheme: customTheme,
//   );
// }

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:moamen_project/core/theme/app_colors.dart';
import 'package:moamen_project/core/theme/app_theme.dart';
import 'package:moamen_project/core/widgets/animation_widget.dart';
import 'package:moamen_project/features/map/data/map_model.dart';
import 'package:moamen_project/features/map/presentation/controller/map_state.dart';
import 'package:moamen_project/features/map/presentation/controller/map_provider.dart';
import 'package:moamen_project/features/orders/data/models/order_model.dart';
import 'package:moamen_project/features/map/presentation/widgets/map_bottom_sheet.dart';
import 'package:moamen_project/features/map/presentation/widgets/order_details_card.dart';
import 'package:moamen_project/features/orders/presentation/orders_screen.dart';

// import 'package:moamen_project/features/map/presentation/controller/map_notifier.dart';
// import 'package:vector_map_tiles/vector_map_tiles.dart';
// import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
// import 'package:mbtiles/mbtiles.dart';
// import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

// ─────────────────────────────────────────────
//  Design Tokens
// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
//  Map Screen
// ─────────────────────────────────────────────
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  late final AnimationController _fadeController;
  late final AnimationController _slideController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // late final Future<String> _mbtilesPathFuture;

  // final mbtilesAssetPath = 'assets/map/alexandria.mbtiles';
  // final mbtilesVersion = 1;

  // MbTiles? _mbtilesDb;
  // MbTilesMetadata? _mbtilesMeta;

  @override
  void initState() {
    super.initState();
    // debugMbtiles(mbtilesAssetPath);

    // _mbtilesPathFuture = prepareMbtiles(mbtilesAssetPath, mbtilesVersion);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    Future.microtask(() async {
      _fadeController.forward();
      _slideController.forward();

      // Ensure we have location before fetching/routing orders
      await ref.read(mapProvider.notifier).initLocationService();
      ref.read(mapProvider.notifier).getOrders();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ─── Build ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mapState = ref.watch(mapProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // ① Map layer
            FadeTransition(
              opacity: _fadeAnim,
              child: _buildApiMap(mapState, isDarkMode, customTheme),
              // child: _buildLocalMap(mapState, isDarkMode, customTheme),
            ),

            // ② Vignette overlay
            _buildVignette(isDarkMode, customTheme),

            // ③ Header
            // const MapHeader(),

            // ④ Top Toasts
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (mapState.errorMassage.isNotEmpty) ...[
                        _buildErrorToast(mapState.errorMassage),
                        const SizedBox(height: 10),
                      ],
                      if (mapState.hintMassage.isNotEmpty) ...[
                        _buildHintToast(mapState.hintMassage),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ⑤ Bottom controls
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildFloatingControls(
                            mapState,
                            isDarkMode,
                            customTheme,
                          ),
                          const SizedBox(height: 14),
                          _buildOrdersPanel(mapState, isDarkMode, customTheme),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ⑤ Edge Indicators (NEW: Multiple & Numbered)
            ..._buildEdgeIndicators(mapState),

            // ⑤ Loading overlay
            if (mapState.isLoding) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  // ─── Vignette ────────────────────────────────
  Widget _buildVignette(bool isDarkMode, CustomThemeExtension customTheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.4,
              colors: [
                Colors.transparent,
                isDarkMode
                    ? AppColors.midnightNavy.withOpacity(0.4)
                    : Colors.white.withOpacity(0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Floating Controls Row ───────────────────
  Widget _buildFloatingControls(
    dynamic mapState,
    bool isDarkMode,
    CustomThemeExtension customTheme,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _MapActionButton(
          icon: HeroIcons.map_pin,
          color: AppColors.primaryBlue,
          tooltip: 'موقعي',
          onTap: () => _goToUserLocation(mapState.userLocation),
        ),
        const SizedBox(width: 10),
        _MapActionButton(
          icon: mapState.showPublicCircles
              ? HeroIcons.eye_slash
              : HeroIcons.eye,
          color: AppColors.primaryPurple,
          tooltip: mapState.showPublicCircles
              ? 'إخفاء الدوائر'
              : 'إظهار الدوائر',
          onTap: () => ref.read(mapProvider.notifier).togglePublicCircles(),
        ),
      ],
    );
  }

  // ─── Orders Panel ────────────────────────────
  Widget _buildOrdersPanel(
    dynamic mapState,
    bool isDarkMode,
    CustomThemeExtension customTheme,
  ) {
    return _MapCard(
      child: InkWell(
        onTap: _navigateToOrdersScreen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  HeroIcons.truck,
                  color: isDarkMode ? Colors.white : AppColors.textWhite,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أوردراتك',
                      style: GoogleFonts.cairo(
                        color: customTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${mapState.mapModel.userPoints.length} طلب نشط',
                      style: GoogleFonts.cairo(
                        color: customTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (mapState.mapModel.userPoints.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${mapState.mapModel.userPoints.length}',
                    style: GoogleFonts.cairo(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              const Icon(
                HeroIcons.chevron_left,
                color: Colors.white24,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Loading Overlay ─────────────────────────
  Widget _buildLoadingOverlay() {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Container(
      color: Colors.black45,
      child: Center(
        child: _MapCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AnimationWidget.loadingAnimation(24),
                ),
                const SizedBox(height: 16),
                Text(
                  'جاري التحميل...',
                  style: GoogleFonts.cairo(
                    color: customTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Error Toast ─────────────────────────────
  Widget _buildErrorToast(String message) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: customTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            HeroIcons.exclamation_circle,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hint Toast ──────────────────────────────
  Widget _buildHintToast(String message) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: customTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            HeroIcons.information_circle,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Map Builder ─────────────────────────────
  Widget _buildApiMap(
    MapState mapState,
    bool isDarkMode,
    CustomThemeExtension customTheme,
  ) {
    final mapModel = mapState.mapModel;
    final userLocation = mapState.userLocation;
    final showPublicCircles = mapState.showPublicCircles;

    LatLng center = const LatLng(30.0444, 31.2357);

    if (userLocation != null) {
      center = userLocation;
    } else if (mapModel.userPoints.isNotEmpty &&
        mapModel.userPoints.first.latitude != null) {
      center = LatLng(
        mapModel.userPoints.first.latitude!,
        mapModel.userPoints.first.longitude!,
      );
    } else if (mapModel.publicPoints.isNotEmpty) {
      center = mapModel.publicPoints.first.points;
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapEvent: (event) {
          // Rebuild to update edge indicator position
          if (mounted) setState(() {});
        },
      ),
      children: [
        TileLayer(
          urlTemplate: isDarkMode
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.moamen.project',
          retinaMode: RetinaMode.isHighDensity(context),
        ),
        if (mapState.routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: mapState.routePoints,
                strokeWidth: 5,
                color: AppColors.primaryBlue.withOpacity(0.8),
                borderStrokeWidth: 2,
                borderColor: AppColors.primaryBlue.withOpacity(0.3),
              ),
            ],
          ),
        if (showPublicCircles)
          CircleLayer(
            circles: mapModel.publicPoints.map((circleOrder) {
              return CircleMarker(
                point: circleOrder.points,
                color: AppColors.primaryPurple.withOpacity(0.1),
                borderColor: AppColors.primaryPurple.withOpacity(0.4),
                borderStrokeWidth: 1.5,
                useRadiusInMeter: true,
                radius: 1000,
              );
            }).toList(),
          ),
        MarkerLayer(
          markers: [
            if (userLocation != null)
              Marker(
                point: userLocation,
                width: 60,
                height: 60,
                child: _UserLocationMarker(),
              ),
            if (showPublicCircles)
              ...mapModel.publicPoints.map((circleOrder) {
                return Marker(
                  point: circleOrder.points,
                  width: 64,
                  height: 64,
                  child: GestureDetector(
                    onTap: () => _showPublicOrdersSheet(circleOrder),
                    child: _PublicClusterMarker(
                      count: circleOrder.orders.length,
                    ),
                  ),
                );
              }),
            ...mapModel.userPoints.asMap().entries.map((entry) {
              final index = entry.key;
              final order = entry.value;
              if (order.latitude == null || order.longitude == null) {
                return const Marker(
                  point: LatLng(0, 0),
                  child: SizedBox.shrink(),
                );
              }
              return Marker(
                point: LatLng(order.latitude!, order.longitude!),
                width: 60,
                height: 60,
                child: GestureDetector(
                  onTap: () => _showOrderDetailsSheet(order),
                  child: _UserOrderMarker(
                    index: index,
                    priority: order.priority,
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // Widget _buildLocalMap(
  //   MapState mapState,
  //   bool isDarkMode,
  //   CustomThemeExtension customTheme,
  // ) {
  //   final mapModel = mapState.mapModel;
  //   final userLocation = mapState.userLocation;
  //   final showPublicCircles = mapState.showPublicCircles;

  //   // Use Alexandria by default (your mbtiles bounds are Alexandria only)
  //   LatLng center = const LatLng(31.228, 29.992);

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

  //   return FutureBuilder<String>(
  //     future: _mbtilesPathFuture,
  //     builder: (context, snap) {
  //       if (!snap.hasData) {
  //         return Center(
  //           child: AnimationWidget.loadingAnimation(
  //             25,
  //             color: AppColors.primaryBlue,
  //           ),
  //         );
  //       }

  //       final mbtilesPath = snap.data!;

  //       // ✅ Open DB ONCE (don’t reopen every rebuild)
  //       _mbtilesDb ??= MbTiles(gzip: false, mbtilesPath: mbtilesPath);
  //       _mbtilesMeta ??= _mbtilesDb!.getMetadata();

  //       final vtr.Theme theme = vtr.ProvidedThemes.lightTheme(
  //         logger: const vtr.Logger.console(),
  //       );

  //       return FlutterMap(
  //         mapController: _mapController,
  //         options: MapOptions(
  //           // Better: center on the MBTiles default center if available
  //           initialCenter: _mbtilesMeta!.defaultCenter ?? center,
  //           initialZoom: _mbtilesMeta!.defaultZoom ?? 13.0,
  //           interactionOptions: const InteractionOptions(
  //             flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
  //           ),
  //           onMapEvent: (event) {
  //             if (mounted) setState(() {});
  //           },
  //         ),
  //         children: [
  //           /// ✅ OFFLINE VECTOR TILE LAYER (PBF)
  //           /// This is the correct layer/provider for pbf MBTiles. :contentReference[oaicite:4]{index=4}
  //           VectorTileLayer(
  //             theme: theme,
  //             tileProviders: TileProviders({
  //               'openmaptiles': MbTilesVectorTileProvider(
  //                 mbtiles: _mbtilesDb!,
  //                 silenceTileNotFound:
  //                     true, // stops spam logs when outside bounds
  //               ),
  //             }),
  //             // Don't set this to metadata.maxZoom or you prevent over-zooming
  //             // Package docs explicitly warn about that. :contentReference[oaicite:5]{index=5}
  //             maximumZoom: 18,
  //             tileOffset: TileOffset.mapbox,
  //           ),

  //           if (mapState.routePoints.isNotEmpty)
  //             PolylineLayer(
  //               polylines: [
  //                 Polyline(
  //                   points: mapState.routePoints,
  //                   strokeWidth: 5,
  //                   color: AppColors.primaryBlue.withOpacity(0.8),
  //                   borderStrokeWidth: 2,
  //                   borderColor: AppColors.primaryBlue.withOpacity(0.3),
  //                 ),
  //               ],
  //             ),

  //           if (showPublicCircles)
  //             CircleLayer(
  //               circles: mapModel.publicPoints.map((circleOrder) {
  //                 return CircleMarker(
  //                   point: circleOrder.points,
  //                   color: AppColors.primaryPurple.withOpacity(0.1),
  //                   borderColor: AppColors.primaryPurple.withOpacity(0.4),
  //                   borderStrokeWidth: 1.5,
  //                   useRadiusInMeter: true,
  //                   radius: 1000,
  //                 );
  //               }).toList(),
  //             ),

  //           MarkerLayer(
  //             markers: [
  //               if (userLocation != null)
  //                 Marker(
  //                   point: userLocation,
  //                   width: 60,
  //                   height: 60,
  //                   child: _UserLocationMarker(),
  //                 ),

  //               if (showPublicCircles)
  //                 ...mapModel.publicPoints.map((circleOrder) {
  //                   return Marker(
  //                     point: circleOrder.points,
  //                     width: 64,
  //                     height: 64,
  //                     child: GestureDetector(
  //                       onTap: () => _showPublicOrdersSheet(circleOrder),
  //                       child: _PublicClusterMarker(
  //                         count: circleOrder.orders.length,
  //                       ),
  //                     ),
  //                   );
  //                 }),

  //               ...mapModel.userPoints.asMap().entries.map((entry) {
  //                 final index = entry.key;
  //                 final order = entry.value;

  //                 if (order.latitude == null || order.longitude == null) {
  //                   return const Marker(
  //                     point: LatLng(0, 0),
  //                     child: SizedBox.shrink(),
  //                   );
  //                 }

  //                 return Marker(
  //                   point: LatLng(order.latitude!, order.longitude!),
  //                   width: 60,
  //                   height: 60,
  //                   child: GestureDetector(
  //                     onTap: () => _showOrderDetailsSheet(order),
  //                     child: _UserOrderMarker(
  //                       index: index,
  //                       priority: order.priority,
  //                     ),
  //                   ),
  //                 );
  //               }),
  //             ],
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // ─── Edge Indicators ─────────────────────────
  List<Widget> _buildEdgeIndicators(MapState mapState) {
    if (mapState.mapModel.userPoints.isEmpty) return [];

    final List<Widget> indicators = [];
    final List<ui.Offset> placedPositions = [];

    // MapController might not be ready on first build
    try {
      final camera = _mapController.camera;
      final bounds = camera.visibleBounds;
      final size = MediaQuery.of(context).size;

      final cx = size.width / 2;
      final cy = size.height / 2;

      // Effective bounds (clamped area)
      const horizontalPadding = 35.0;
      const topPadding = 110.0;
      const bottomPadding = 190.0;

      final left = horizontalPadding;
      final top = topPadding;
      final right = size.width - horizontalPadding;
      final bottom = size.height - bottomPadding;

      for (int i = 0; i < mapState.mapModel.userPoints.length; i++) {
        final order = mapState.mapModel.userPoints[i];
        if (order.latitude == null || order.longitude == null) continue;

        final target = LatLng(order.latitude!, order.longitude!);

        // If target is visible, skip
        if (bounds.contains(target)) continue;

        // Project target to viewport pixels
        final point = camera.getOffsetFromOrigin(target);
        double vx = point.dx - cx;
        double vy = point.dy - cy;

        // Find intersection with the screen edge
        double scaleX = double.infinity;
        double scaleY = double.infinity;

        if (vx < 0) scaleX = (left - cx) / vx;
        if (vx > 0) scaleX = (right - cx) / vx;
        if (vy < 0) scaleY = (top - cy) / vy;
        if (vy > 0) scaleY = (bottom - cy) / vy;

        final scale = scaleX < scaleY ? scaleX : scaleY;

        double indicatorX = cx + vx * scale;
        double indicatorY = cy + vy * scale;

        // --- Basic Anti-Overlap Logic ---
        // If this position is too close to a previous one, shift it along the edge
        bool overlapped = true;
        int shiftCount = 0;
        const buttonSize = 52.0;

        while (overlapped && shiftCount < 10) {
          overlapped = false;
          for (final pos in placedPositions) {
            final dist = (ui.Offset(indicatorX, indicatorY) - pos).distance;
            if (dist < buttonSize) {
              overlapped = true;
              // Shift along the edge depending on which side it's on
              if (indicatorX <= left || indicatorX >= right) {
                indicatorY += (indicatorY > cy ? buttonSize : -buttonSize);
              } else {
                indicatorX += (indicatorX > cx ? buttonSize : -buttonSize);
              }
              // Clamp again after shift
              indicatorX = indicatorX.clamp(left, right);
              indicatorY = indicatorY.clamp(top, bottom);
              break;
            }
          }
          shiftCount++;
        }
        placedPositions.add(ui.Offset(indicatorX, indicatorY));

        // Calculate arrow rotation relative to vector from center
        final angle = ui.Offset(vx, vy).direction;

        indicators.add(
          Positioned(
            left: indicatorX - 26,
            top: indicatorY - 26,
            child: GestureDetector(
              onTap: () => _animateMapMove(target, 16.0),
              child: _EdgeIndicatorButton(index: i + 1, angle: angle),
            ),
          ),
        );
      }
    } catch (_) {
      return [];
    }

    return indicators;
  }

  void _goToUserLocation(LatLng? userLocation) {
    if (userLocation == null) return;
    _animateMapMove(userLocation, _mapController.camera.zoom);
  }

  void _animateMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _showOrderDetailsSheet(Order order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MapBottomSheet(
        title: 'تفاصيل الأوردر',
        content: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(children: [OrderDetailsCard(order: order)]),
          ),
        ),
      ),
    );
  }

  void _showPublicOrdersSheet(CircleOrder circleOrder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MapBottomSheet(
        title: 'الأوردرات المتاحة (${circleOrder.orders.length})',
        content: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              children: circleOrder.orders
                  .map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: OrderDetailsCard(order: order, isPublicOnly: true),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToOrdersScreen() async {
    final selectedOrder = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrdersScreen(isSelectionMode: true),
      ),
    );

    if (selectedOrder is Order &&
        selectedOrder.latitude != null &&
        selectedOrder.longitude != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      try {
        _mapController.move(
          LatLng(selectedOrder.latitude!, selectedOrder.longitude!),
          16.0,
        );
        _showOrderDetailsSheet(selectedOrder);
      } catch (e) {
        debugPrint('Navigation map move error: $e');
      }
    }
  }
}

// ─────────────────────────────────────────────
//  Reusable Widgets
// ─────────────────────────────────────────────

/// Custom card container without blur
class _MapCard extends StatelessWidget {
  final Widget child;

  const _MapCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Container(
      decoration: BoxDecoration(
        color: customTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: customTheme.textPrimary.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Custom action button without blur
class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _MapActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: customTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

/// Animated pulsing user location marker
class _UserLocationMarker extends StatefulWidget {
  @override
  State<_UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<_UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withOpacity(0.15 * _pulseAnim.value),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.4 * _pulseAnim.value),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                HeroIcons.cursor_arrow_rays,
                color: Colors.white,
                size: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Public cluster marker
class _PublicClusterMarker extends StatelessWidget {
  final int count;
  const _PublicClusterMarker({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$count',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

/// User order "pin" marker
class _UserOrderMarker extends StatelessWidget {
  final int index;
  final OrderPriority priority;

  const _UserOrderMarker({required this.index, required this.priority});

  Color _getPriorityColor() {
    switch (priority) {
      case OrderPriority.low:
        return AppColors.primaryBlue;
      case OrderPriority.medium:
        return Colors.greenAccent;
      case OrderPriority.high:
        return Colors.orangeAccent;
      case OrderPriority.urgent:
        return Colors.redAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getPriorityColor();

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          bottom: 0,
          child: Container(
            width: 20,
            height: 6,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(0, 0, 0, 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(12, 7),
              painter: _PinTailPainter(color),
            ),
          ],
        ),
      ],
    );
  }
}

/// Paints the triangle pin tail.
/// Explicitly uses [ui.Path] to avoid conflict with flutter_map's Path<LatLng>.
class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    // ui.Path is dart:ui's Path — avoids the flutter_map Path<LatLng> conflict
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Edge Indicator Button UI ───────────────────
class _EdgeIndicatorButton extends StatelessWidget {
  final int index;
  final double angle;

  const _EdgeIndicatorButton({required this.index, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.45),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Number in center
          Text(
            '$index',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          // Directional arrow at circumference
          Positioned.fill(
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(1),
                    child: const Icon(
                      HeroIcons.chevron_right,
                      color: AppColors.primaryBlue,
                      size: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

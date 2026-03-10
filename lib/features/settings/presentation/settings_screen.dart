// import 'package:flutter/material.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:moamen_project/core/theme/app_theme.dart';

// // ─────────────────────────────────────────────
// //  Settings Screen
// // ─────────────────────────────────────────────
// class SettingsScreen extends StatefulWidget {
//   const SettingsScreen({super.key});

//   @override
//   State<SettingsScreen> createState() => _SettingsScreenState();
// }

// class _SettingsScreenState extends State<SettingsScreen>
//     with SingleTickerProviderStateMixin {
//   // ── State ──────────────────────────────────
//   ThemeMode _themeMode = ThemeMode.system; // light | dark | system
//   String _mapType = 'local'; // 'local' | 'api'
//   String _apiMapTheme = 'app'; // 'dark' | 'light' | 'app'
//   DateTime? _lastUpdated;
//   bool _isUpdating = false;

//   late AnimationController _animController;
//   late Animation<double> _fadeAnim;

//   @override
//   void initState() {
//     super.initState();
//     _animController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _fadeAnim = CurvedAnimation(
//       parent: _animController,
//       curve: Curves.easeOut,
//     );
//     _animController.forward();
//   }

//   @override
//   void dispose() {
//     _animController.dispose();
//     super.dispose();
//   }

//   // ── Helpers ────────────────────────────────
//   Future<void> _triggerUpdate() async {
//     setState(() => _isUpdating = true);
//     await Future.delayed(const Duration(seconds: 2));
//     setState(() {
//       _isUpdating = false;
//       _lastUpdated = DateTime.now();
//     });
//   }

//   String _formatLastUpdated() {
//     if (_lastUpdated == null) return 'Never updated';
//     final diff = DateTime.now().difference(_lastUpdated!);
//     if (diff.inSeconds < 60) return 'Just now';
//     if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
//     if (diff.inHours < 24) return '${diff.inHours}h ago';
//     return '${diff.inDays}d ago';
//   }

//   // ── Build ──────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
//     final colorScheme = Theme.of(context).colorScheme;
//     final isDark = Theme.of(context).brightness == Brightness.dark;

//     return SafeArea(
//       child: Scaffold(
//         backgroundColor: Colors.transparent,
//         body: Container(
//           decoration: BoxDecoration(gradient: customTheme.accentGradient),
//           child: FadeTransition(
//             opacity: _fadeAnim,
//             child: CustomScrollView(
//               physics: const BouncingScrollPhysics(),
//               slivers: [
//                 // ── App Bar ──────────────────
//                 SliverToBoxAdapter(
//                   child: _buildHeader(context, isDark),
//                 ),

//                 // ── Sections ─────────────────
//                 SliverPadding(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 20, vertical: 8),
//                   sliver: SliverList(
//                     delegate: SliverChildListDelegate([
//                       _SectionLabel(label: 'Appearance'),
//                       const SizedBox(height: 10),
//                       _buildThemeCard(context, isDark),

//                       const SizedBox(height: 24),
//                       _SectionLabel(label: 'Map'),
//                       const SizedBox(height: 10),
//                       _buildMapTypeCard(context, isDark),

//                       // API Map theme — only visible when api is chosen
//                       AnimatedSize(
//                         duration: const Duration(milliseconds: 350),
//                         curve: Curves.easeInOut,
//                         child: _mapType == 'api'
//                             ? Padding(
//                                 padding: const EdgeInsets.only(top: 12),
//                                 child:
//                                     _buildApiMapThemeCard(context, isDark),
//                               )
//                             : const SizedBox.shrink(),
//                       ),

//                       const SizedBox(height: 24),
//                       _SectionLabel(label: 'Data'),
//                       const SizedBox(height: 10),
//                       _buildUpdatePlacesCard(context, isDark),

//                       const SizedBox(height: 40),
//                     ]),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Header ─────────────────────────────────
//   Widget _buildHeader(BuildContext context, bool isDark) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
//       child: Row(
//         children: [
//           _GlassIconButton(
//             icon: CupertinoIcons.chevron_left,
//             isDark: isDark,
//             onTap: () => Navigator.maybePop(context),
//           ),
//           const SizedBox(width: 16),
//           Text(
//             'Settings',
//             style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                   fontWeight: FontWeight.w700,
//                   letterSpacing: -0.5,
//                 ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Theme Card ─────────────────────────────
//   Widget _buildThemeCard(BuildContext context, bool isDark) {
//     return _SettingsCard(
//       isDark: isDark,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardTitle(
//             icon: CupertinoIcons.moon_stars_fill,
//             label: 'App Theme',
//             isDark: isDark,
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               _ThemeChip(
//                 label: 'Light',
//                 icon: CupertinoIcons.sun_max_fill,
//                 selected: _themeMode == ThemeMode.light,
//                 isDark: isDark,
//                 onTap: () => setState(() => _themeMode = ThemeMode.light),
//               ),
//               const SizedBox(width: 10),
//               _ThemeChip(
//                 label: 'Dark',
//                 icon: CupertinoIcons.moon_fill,
//                 selected: _themeMode == ThemeMode.dark,
//                 isDark: isDark,
//                 onTap: () => setState(() => _themeMode = ThemeMode.dark),
//               ),
//               const SizedBox(width: 10),
//               _ThemeChip(
//                 label: 'System',
//                 icon: CupertinoIcons.device_phone_portrait,
//                 selected: _themeMode == ThemeMode.system,
//                 isDark: isDark,
//                 onTap: () =>
//                     setState(() => _themeMode = ThemeMode.system),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Map Type Card ──────────────────────────
//   Widget _buildMapTypeCard(BuildContext context, bool isDark) {
//     return _SettingsCard(
//       isDark: isDark,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardTitle(
//             icon: CupertinoIcons.map_fill,
//             label: 'Map Source',
//             isDark: isDark,
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               Expanded(
//                 child: _MapSourceButton(
//                   label: 'Local Map',
//                   icon: CupertinoIcons.folder_fill,
//                   selected: _mapType == 'local',
//                   isDark: isDark,
//                   onTap: () => setState(() => _mapType = 'local'),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: _MapSourceButton(
//                   label: 'API Map',
//                   icon: CupertinoIcons.cloud_fill,
//                   selected: _mapType == 'api',
//                   isDark: isDark,
//                   onTap: () => setState(() => _mapType = 'api'),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── API Map Theme Card ─────────────────────
//   Widget _buildApiMapThemeCard(BuildContext context, bool isDark) {
//     return _SettingsCard(
//       isDark: isDark,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardTitle(
//             icon: CupertinoIcons.paintbrush_fill,
//             label: 'Map Style',
//             isDark: isDark,
//           ),
//           const SizedBox(height: 16),
//           Row(
//             children: [
//               _MapThemeChip(
//                 label: 'Dark',
//                 icon: CupertinoIcons.moon_fill,
//                 selected: _apiMapTheme == 'dark',
//                 isDark: isDark,
//                 onTap: () => setState(() => _apiMapTheme = 'dark'),
//               ),
//               const SizedBox(width: 8),
//               _MapThemeChip(
//                 label: 'Light',
//                 icon: CupertinoIcons.sun_max_fill,
//                 selected: _apiMapTheme == 'light',
//                 isDark: isDark,
//                 onTap: () => setState(() => _apiMapTheme = 'light'),
//               ),
//               const SizedBox(width: 8),
//               _MapThemeChip(
//                 label: 'App Theme',
//                 icon: CupertinoIcons.wand_stars,
//                 selected: _apiMapTheme == 'app',
//                 isDark: isDark,
//                 onTap: () => setState(() => _apiMapTheme = 'app'),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Update Places Card ─────────────────────
//   Widget _buildUpdatePlacesCard(BuildContext context, bool isDark) {
//     final accent = Theme.of(context).colorScheme.primary;

//     return _SettingsCard(
//       isDark: isDark,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           _CardTitle(
//             icon: CupertinoIcons.location_fill,
//             label: 'Places Data',
//             isDark: isDark,
//           ),
//           const SizedBox(height: 6),
//           Row(
//             children: [
//               Icon(
//                 CupertinoIcons.clock,
//                 size: 13,
//                 color: isDark
//                     ? Colors.white38
//                     : Colors.black38,
//               ),
//               const SizedBox(width: 5),
//               Text(
//                 'Last update: ${_formatLastUpdated()}',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: isDark
//                       ? Colors.white38
//                       : Colors.black38,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           SizedBox(
//             width: double.infinity,
//             child: AnimatedContainer(
//               duration: const Duration(milliseconds: 300),
//               child: ElevatedButton.icon(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: accent,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                   elevation: 0,
//                 ),
//                 onPressed: _isUpdating ? null : _triggerUpdate,
//                 icon: _isUpdating
//                     ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(
//                           color: Colors.white,
//                           strokeWidth: 2,
//                         ),
//                       )
//                     : const Icon(CupertinoIcons.arrow_clockwise, size: 18),
//                 label: Text(
//                   _isUpdating ? 'Updating...' : 'Update Places',
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 15,
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// //  Reusable sub-widgets
// // ─────────────────────────────────────────────

// class _SectionLabel extends StatelessWidget {
//   final String label;
//   const _SectionLabel({required this.label});

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       label.toUpperCase(),
//       style: TextStyle(
//         fontSize: 11,
//         fontWeight: FontWeight.w700,
//         letterSpacing: 1.4,
//         color: Theme.of(context).colorScheme.primary,
//       ),
//     );
//   }
// }

// class _SettingsCard extends StatelessWidget {
//   final Widget child;
//   final bool isDark;

//   const _SettingsCard({required this.child, required this.isDark});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: isDark
//             ? Colors.white.withOpacity(0.07)
//             : Colors.white.withOpacity(0.75),
//         borderRadius: BorderRadius.circular(20),
//         border: Border.all(
//           color: isDark
//               ? Colors.white.withOpacity(0.08)
//               : Colors.black.withOpacity(0.06),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
//             blurRadius: 20,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: child,
//     );
//   }
// }

// class _CardTitle extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final bool isDark;

//   const _CardTitle({
//     required this.icon,
//     required this.label,
//     required this.isDark,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(7),
//           decoration: BoxDecoration(
//             color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Icon(
//             icon,
//             size: 16,
//             color: Theme.of(context).colorScheme.primary,
//           ),
//         ),
//         const SizedBox(width: 10),
//         Text(
//           label,
//           style: TextStyle(
//             fontWeight: FontWeight.w700,
//             fontSize: 16,
//             color: isDark ? Colors.white : Colors.black87,
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Theme Chips ────────────────────────────────
// class _ThemeChip extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final bool selected;
//   final bool isDark;
//   final VoidCallback onTap;

//   const _ThemeChip({
//     required this.label,
//     required this.icon,
//     required this.selected,
//     required this.isDark,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final accent = Theme.of(context).colorScheme.primary;

//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//           padding: const EdgeInsets.symmetric(vertical: 11),
//           decoration: BoxDecoration(
//             color: selected
//                 ? accent
//                 : (isDark
//                     ? Colors.white.withOpacity(0.08)
//                     : Colors.black.withOpacity(0.05)),
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(
//               color: selected
//                   ? accent
//                   : Colors.transparent,
//               width: 1.5,
//             ),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 icon,
//                 size: 20,
//                 color: selected
//                     ? Colors.white
//                     : (isDark ? Colors.white60 : Colors.black45),
//               ),
//               const SizedBox(height: 5),
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                   color: selected
//                       ? Colors.white
//                       : (isDark ? Colors.white60 : Colors.black45),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Map Source Button ──────────────────────────
// class _MapSourceButton extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final bool selected;
//   final bool isDark;
//   final VoidCallback onTap;

//   const _MapSourceButton({
//     required this.label,
//     required this.icon,
//     required this.selected,
//     required this.isDark,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final accent = Theme.of(context).colorScheme.primary;

//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         curve: Curves.easeOut,
//         padding: const EdgeInsets.symmetric(vertical: 14),
//         decoration: BoxDecoration(
//           color: selected
//               ? accent.withOpacity(0.15)
//               : (isDark
//                   ? Colors.white.withOpacity(0.06)
//                   : Colors.black.withOpacity(0.04)),
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(
//             color: selected ? accent : Colors.transparent,
//             width: 1.5,
//           ),
//         ),
//         child: Column(
//           children: [
//             Icon(
//               icon,
//               size: 22,
//               color: selected
//                   ? accent
//                   : (isDark ? Colors.white54 : Colors.black38),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               label,
//               style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 fontSize: 13,
//                 color: selected
//                     ? accent
//                     : (isDark ? Colors.white54 : Colors.black38),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ── API Map Theme Chip ─────────────────────────
// class _MapThemeChip extends StatelessWidget {
//   final String label;
//   final IconData icon;
//   final bool selected;
//   final bool isDark;
//   final VoidCallback onTap;

//   const _MapThemeChip({
//     required this.label,
//     required this.icon,
//     required this.selected,
//     required this.isDark,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final accent = Theme.of(context).colorScheme.primary;

//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//           padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
//           decoration: BoxDecoration(
//             color: selected
//                 ? accent.withOpacity(0.15)
//                 : (isDark
//                     ? Colors.white.withOpacity(0.06)
//                     : Colors.black.withOpacity(0.04)),
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(
//               color: selected ? accent : Colors.transparent,
//               width: 1.5,
//             ),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(
//                 icon,
//                 size: 18,
//                 color: selected
//                     ? accent
//                     : (isDark ? Colors.white54 : Colors.black38),
//               ),
//               const SizedBox(height: 5),
//               Text(
//                 label,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: 11,
//                   fontWeight: FontWeight.w600,
//                   color: selected
//                       ? accent
//                       : (isDark ? Colors.white54 : Colors.black38),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ── Glass Icon Button ──────────────────────────
// class _GlassIconButton extends StatelessWidget {
//   final IconData icon;
//   final bool isDark;
//   final VoidCallback onTap;

//   const _GlassIconButton({
//     required this.icon,
//     required this.isDark,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color: isDark
//               ? Colors.white.withOpacity(0.1)
//               : Colors.black.withOpacity(0.06),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isDark
//                 ? Colors.white.withOpacity(0.1)
//                 : Colors.black.withOpacity(0.06),
//           ),
//         ),
//         child: Icon(
//           icon,
//           size: 18,
//           color: isDark ? Colors.white : Colors.black87,
//         ),
//       ),
//     );
//   }
// }
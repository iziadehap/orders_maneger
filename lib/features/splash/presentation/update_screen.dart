import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moamen_project/core/services/update/update_app.dart';
import 'package:moamen_project/core/widgets/custom_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  UpdateDecision? decision;
  bool loading = true;
  String? err;
  bool installing = false;
  double downloadProgress = 0.0; // التقدم من 0.0 لـ 1.0

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      loading = true;
      err = null;
    });

    try {
      print('checking for update');
      final supabase = Supabase.instance.client;
      final d = await AppUpdateService(supabase).checkForUpdate();
      setState(() {
        decision = d;
        loading = false;
      });
    } catch (e) {
      print('error in update $e');
      setState(() {
        err = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _install() async {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>();

    if (installing) return;
    setState(() {
      installing = true;
      downloadProgress = 0.0;
    });

    try {
      final updater = GithubReleaseUpdater();
      await updater.installApkFromUrl(
        latestVersion: decision!.latestVersion,
        onProgress: (p) {
          if (mounted) setState(() => downloadProgress = p);
        },
      );
    } catch (e) {
      if (mounted) {
        print('error in update $e');
        showCustomSnackBar(
          context,
          customTheme: customTheme!,
          message: 'فشل التحديث: $e',
          icon: Icons.error,
          isError: true,
          color: customTheme.errorColor,
        );
      }
    } finally {
      if (mounted) setState(() => installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || err != null || decision == null) return widget.child;

    final d = decision!;
    if (d.type == UpdateDecisionType.none) return widget.child;

    final customTheme = Theme.of(context).extension<CustomThemeExtension>();
    if (customTheme == null) return widget.child;

    if (d.type == UpdateDecisionType.forced) {
      return AnimatedForcedUpdateScreen(
        decision: d,
        customTheme: customTheme,
        installing: installing,
        downloadProgress: downloadProgress,
        onInstall: _install,
      );
    }

    // optional: Banner above the app
    return Stack(
      children: [
        widget.child,
        AnimatedUpdateBanner(
          decision: d,
          installing: installing,
          downloadProgress: downloadProgress,
          onInstall: _install,
          onDismiss: () => setState(() => decision = null),
          customTheme: customTheme,
        ),
      ],
    );
  }
}

class AnimatedUpdateBanner extends StatefulWidget {
  final UpdateDecision decision;
  final CustomThemeExtension customTheme;
  final bool installing;
  final double downloadProgress;
  final VoidCallback onInstall;
  final VoidCallback onDismiss;

  const AnimatedUpdateBanner({
    super.key,
    required this.decision,
    required this.customTheme,
    required this.installing,
    required this.downloadProgress,
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  State<AnimatedUpdateBanner> createState() => _AnimatedUpdateBannerState();
}

class _AnimatedUpdateBannerState extends State<AnimatedUpdateBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _particleController;

  late final Animation<double> _slideIn;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _pulse;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _slideIn = Tween<double>(begin: -80, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );
    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _scaleIn = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    // Pulse glow on the icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Shimmer sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Particle float
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entranceController,
            _pulseController,
            _shimmerController,
            _particleController,
          ]),
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _slideIn.value),
              child: Opacity(
                opacity: _fadeIn.value,
                child: Transform.scale(
                  scale: _scaleIn.value,
                  child: _buildCard(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard() {
    final customTheme = widget.customTheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          // Layered glassmorphism background
          color: customTheme.cardBackground.withOpacity(0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryBlue.withOpacity(0.25),
            width: 1.2,
          ),
          boxShadow: [
            // Ambient
            BoxShadow(
              color: Colors.black.withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
            // Blue glow
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.18 * _pulse.value),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── Animated progress fill ──
            if (widget.installing)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.downloadProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue.withOpacity(0.18),
                            AppColors.primaryBlue.withOpacity(0.32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Shimmer sweep ──
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Transform.translate(
                  offset: Offset(
                    _shimmer.value * MediaQuery.of(context).size.width,
                    0,
                  ),
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.06),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Floating particles ──
            ..._buildParticles(),

            // ── Main content ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildIconWithPulse(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextColumn()),
                  if (!widget.installing) _buildDismissButton(customTheme),
                  const SizedBox(width: 8),
                  _buildActionButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pulsing glowing icon
  Widget _buildIconWithPulse() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue.withOpacity(0.12 * _pulse.value),
          ),
        ),
        // Inner ring
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryBlue.withOpacity(0.2 * _pulse.value),
          ),
        ),
        // Icon button
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryBlue.withBlue(255),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.5 * _pulse.value),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, v, child) =>
                Transform.rotate(angle: (1 - v) * math.pi, child: child),
            child: const Icon(Icons.update, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildTextColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title with character-by-character fade (simple stagger via index)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Text(
            'تحديث جديد متاح',
            style: GoogleFonts.cairo(
              color: widget.customTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 2),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v * 0.85, child: child),
          child: Text(
            widget.installing
                ? 'جاري التحميل... ${(widget.downloadProgress * 100).toInt()}%'
                : 'الإصدار ${widget.decision.latestVersion} متوفر الآن',
            style: GoogleFonts.cairo(
              color: widget.customTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        // Progress bar shown when installing
        if (widget.installing) ...[
          const SizedBox(height: 6),
          _buildProgressBar(),
        ],
      ],
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        children: [
          Container(height: 3, color: AppColors.primaryBlue.withOpacity(0.15)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: 3,
            width: double.infinity,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widget.downloadProgress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withOpacity(0.7),
                      AppColors.primaryBlue,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton(CustomThemeExtension customTheme) {
    return TextButton(
      onPressed: widget.onDismiss,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        'لاحقاً',
        style: GoogleFonts.cairo(color: customTheme.textSecondary),
      ),
    );
  }

  Widget _buildActionButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton(
        onPressed: widget.installing ? null : widget.onInstall,
        style:
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith(
                (states) => Colors.white.withOpacity(0.15),
              ),
            ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            widget.installing
                ? '${(widget.downloadProgress * 100).toInt()}%'
                : 'تحديث',
            key: ValueKey(widget.installing),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Floating subtle particles for depth
  List<Widget> _buildParticles() {
    final rng = math.Random(42);
    return List.generate(5, (i) {
      final xStart = rng.nextDouble();
      final delay = rng.nextDouble();
      final size = 2.0 + rng.nextDouble() * 2;
      final t = (_particleController.value + delay) % 1.0;
      final opacity = math.sin(t * math.pi) * 0.25;
      final yOffset = -20.0 * t;

      return Positioned(
        left: xStart * 300 + 20,
        bottom: 8 + yOffset,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    });
  }
}

class AnimatedForcedUpdateScreen extends StatefulWidget {
  final UpdateDecision decision;
  final CustomThemeExtension customTheme;
  final bool installing;
  final double downloadProgress;
  final VoidCallback onInstall;

  const AnimatedForcedUpdateScreen({
    super.key,
    required this.decision,
    required this.customTheme,
    required this.installing,
    required this.downloadProgress,
    required this.onInstall,
  });

  @override
  State<AnimatedForcedUpdateScreen> createState() =>
      _AnimatedForcedUpdateScreenState();
}

class _AnimatedForcedUpdateScreenState extends State<AnimatedForcedUpdateScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleIn = Tween<double>(begin: 0.9, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = widget.customTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: customTheme.scaffoldGradient),
        child: Stack(
          children: [
            // Floating Particles
            ..._buildParticles(),

            Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _entranceController,
                  _pulseController,
                ]),
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeIn.value,
                    child: Transform.scale(
                      scale: _scaleIn.value,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildIconSection(customTheme),
                            const SizedBox(height: 48),
                            _buildTextSection(customTheme),
                            const SizedBox(height: 64),
                            _buildProgressButton(customTheme),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconSection(CustomThemeExtension customTheme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow rings
        ...List.generate(3, (i) {
          final size = 120.0 + (i * 40);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryBlue.withOpacity(
                0.05 * (3 - i) / 3 * _pulse.value,
              ),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryBlue, Color(0xFF6366F1)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.4 * _pulse.value),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.system_update_rounded,
            size: 64,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextSection(CustomThemeExtension customTheme) {
    return Column(
      children: [
        Text(
          'تحديث إجباري مطلوب',
          style: GoogleFonts.cairo(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: customTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'نسختك الحالية (${widget.decision.currentVersion}) لم تعد مدعومة. يرجى التحديث إلى الإصدار (${widget.decision.latestVersion}) للمتابعة.',
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(
            fontSize: 16,
            color: customTheme.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressButton(CustomThemeExtension customTheme) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: GestureDetector(
        onTap: widget.installing ? null : widget.onInstall,
        child: Container(
          decoration: BoxDecoration(
            color: customTheme.cardBackground.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
            boxShadow: [
              if (widget.installing)
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Progress Fill
              if (widget.installing)
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerRight,
                      widthFactor: widget.downloadProgress,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF6366F1), AppColors.primaryBlue],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Text Content
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: widget.installing
                      ? Text(
                          '${(widget.downloadProgress * 100).toInt()}%',
                          key: const ValueKey('progress'),
                          style: GoogleFonts.cairo(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: customTheme.textPrimary,
                          ),
                        )
                      : Text(
                          'تحديث الآن',
                          key: const ValueKey('label'),
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: customTheme.textPrimary,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildParticles() {
    final rng = math.Random(123);
    return List.generate(15, (i) {
      final xStart = rng.nextDouble();
      final yStart = rng.nextDouble();
      final delay = rng.nextDouble();
      final size = 2.0 + rng.nextDouble() * 4;

      return AnimatedBuilder(
        animation: _particleController,
        builder: (context, child) {
          final t = (_particleController.value + delay) % 1.0;
          final opacity = math.sin(t * math.pi) * 0.15;
          final yOffset = -50.0 * t;

          return Positioned(
            left: xStart * MediaQuery.of(context).size.width,
            top: yStart * MediaQuery.of(context).size.height + yOffset,
            child: Opacity(
              opacity: opacity,
              child: Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

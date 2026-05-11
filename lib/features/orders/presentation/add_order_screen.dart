import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:moamen_project/core/theme/app_theme.dart';
import 'package:moamen_project/core/utils/normiliz_eg_phone.dart';
import 'package:moamen_project/core/widgets/animation_widget.dart';
import 'package:moamen_project/core/widgets/custom_snackbar.dart';
import 'package:moamen_project/features/orders/presentation/controller/order_provider.dart';
import 'package:moamen_project/features/orders/data/models/order_model.dart';
import 'package:moamen_project/features/auth/presentation/controller/auth_provider.dart';
import 'package:moamen_project/features/orders/presentation/location_picker_screen.dart';
import 'package:moamen_project/features/orders/presentation/widgets/add_order_widgets.dart';
import 'package:moamen_project/core/utils/alx_places.dart';
import 'package:moamen_project/core/utils/availability_utils.dart';
import 'package:moamen_project/features/orders/presentation/availability_settings_screen.dart';

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────

class AddOrderScreen extends ConsumerStatefulWidget {
  final Order? order;
  const AddOrderScreen({super.key, this.order});

  @override
  ConsumerState<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends ConsumerState<AddOrderScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  bool _isDeleting = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  // ── State ─────────────────────────────────
  OrderPriority _priority = OrderPriority.medium;
  OrderStatus _status = OrderStatus.pending;
  String? _workerId;
  bool _isAllWeek = true;
  bool _isManualArea = false;
  AlexPlace? _selectedPlace;
  bool _hasChanges = false;
  Map<String, dynamic> _originalSnapshot = {};

  AvailabilityConfig _availabilityConfig = const AvailabilityConfig(
    weeklyRules: [],
    overrides: [],
  );
  TimeOfDay _allWeekFromTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _allWeekToTime = const TimeOfDay(hour: 23, minute: 59);

  final Map<WeekDay, (TimeOfDay, TimeOfDay)> _dailyTimes = {
    for (final day in WeekDay.values)
      day: (
        const TimeOfDay(hour: 0, minute: 0),
        const TimeOfDay(hour: 23, minute: 59),
      ),
  };

  // ── Animation ─────────────────────────────
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ─────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    if (widget.order != null) _initFields(widget.order!);

    _setupChangeListeners();

    // snapshot after first frame so controllers are populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _originalSnapshot = _buildSnapshot();
    });

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    for (final ctrl in _textControllers) {
      ctrl.removeListener(_onFieldChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _textControllers => [
    _titleController,
    _descriptionController,
    _areaController,
    _fullAddressController,
    _latController,
    _lngController,
    _contactNameController,
    _contactPhoneController,
  ];

  void _setupChangeListeners() {
    for (final ctrl in _textControllers) {
      ctrl.addListener(_onFieldChanged);
    }
  }

  // ─────────────────────────────────────────
  // Change Detection
  // ─────────────────────────────────────────

  Map<String, dynamic> _buildSnapshot() => {
    'title': _titleController.text,
    'description': _descriptionController.text,
    'area': _areaController.text,
    'fullAddress': _fullAddressController.text,
    'contact': _contactNameController.text,
    'phone': _contactPhoneController.text,
    'lat': _latController.text,
    'lng': _lngController.text,
    'priority': _priority,
    'status': _status,
    'workerId': _workerId,
    'isAllWeek': _isAllWeek,
    'allWeekFrom': '${_allWeekFromTime.hour}:${_allWeekFromTime.minute}',
    'allWeekTo': '${_allWeekToTime.hour}:${_allWeekToTime.minute}',
    'dailyTimes': _dailyTimes.map(
      (k, v) => MapEntry(
        k.name,
        '${v.$1.hour}:${v.$1.minute}-${v.$2.hour}:${v.$2.minute}',
      ),
    ),
  };

  void _onFieldChanged() {
    final changed = _buildSnapshot().toString() != _originalSnapshot.toString();
    if (changed != _hasChanges) setState(() => _hasChanges = changed);
  }

  void _markChanged() {
    _onFieldChanged();
  }

  // ─────────────────────────────────────────
  // Init Helpers
  // ─────────────────────────────────────────

  void _initFields(Order order) {
    _titleController.text = order.title;
    _descriptionController.text = order.description;
    _areaController.text = order.publicArea;
    _fullAddressController.text = order.fullAddress ?? '';
    _latController.text = order.latitude?.toString() ?? '';
    _lngController.text = order.longitude?.toString() ?? '';
    _contactNameController.text = order.contactName ?? '';
    _contactPhoneController.text = order.contactPhone ?? '';
    _priority = order.priority;
    _status = order.status;
    _workerId = order.workerId;

    final matchingPlace = alexPlaces
        .where((p) => p.name == order.publicArea)
        .firstOrNull;
    if (matchingPlace != null) {
      _selectedPlace = matchingPlace;
      _isManualArea = false;
    } else {
      _isManualArea = true;
    }

    if (order.availability.isNotEmpty) {
      _initAvailability(order.availability);
      _availabilityConfig = AvailabilityConfig.fromModelAvailability(
        order.availability,
      );
    }

    if (order.photoUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ref.read(orderProvider.notifier).setPhotoUrls(order.photoUrls);
      });
    }
  }

  void _initAvailability(List<Map<String, dynamic>> availability) {
    if (availability.isEmpty) return;

    final firstRange = availability.first['timeRange'] as Map<String, dynamic>?;
    if (firstRange == null) return;

    final allSame =
        availability.length == 7 &&
        availability.every((avail) {
          final range = avail['timeRange'] as Map<String, dynamic>?;
          return range != null &&
              range['fromHour'] == firstRange['fromHour'] &&
              range['fromMinute'] == firstRange['fromMinute'] &&
              range['toHour'] == firstRange['toHour'] &&
              range['toMinute'] == firstRange['toMinute'];
        });

    if (allSame) {
      _isAllWeek = true;
      _allWeekFromTime = TimeOfDay(
        hour: firstRange['fromHour'] ?? 0,
        minute: firstRange['fromMinute'] ?? 0,
      );
      _allWeekToTime = TimeOfDay(
        hour: firstRange['toHour'] ?? 23,
        minute: firstRange['toMinute'] ?? 59,
      );
    } else {
      _isAllWeek = false;
      for (final avail in availability) {
        final dayName = avail['day'] as String?;
        if (dayName == null) continue;
        final day = WeekDay.values.firstWhere(
          (d) => d.name == dayName,
          orElse: () => WeekDay.monday,
        );
        final range = avail['timeRange'] as Map<String, dynamic>?;
        if (range != null) {
          _dailyTimes[day] = (
            TimeOfDay(
              hour: range['fromHour'] ?? 0,
              minute: range['fromMinute'] ?? 0,
            ),
            TimeOfDay(
              hour: range['toHour'] ?? 23,
              minute: range['toMinute'] ?? 59,
            ),
          );
        }
      }
    }
  }

  // ─────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────

  Future<void> _onBackPressed() async {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (_) => _UnsavedChangesDialog(
        customTheme: Theme.of(context).extension<CustomThemeExtension>()!,
      ),
    );

    if (shouldLeave == true && mounted) Navigator.pop(context);
  }

  Future<void> _pickLocation() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);

    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: (lat != null && lng != null)
              ? LatLng(lat, lng)
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.location.latitude.toString();
        _lngController.text = result.location.longitude.toString();
      });
      _markChanged();
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;

    if (_latController.text.isEmpty || _lngController.text.isEmpty) {
      _showSnackbar(
        customTheme,
        message: 'يرجى تحديد الموقع على الخريطة أولاً',
        icon: Icons.error,
        isError: true,
      );
      return;
    }

    final notifier = ref.read(orderProvider.notifier);
    final newUrls = await notifier.uploadAllPhotos();

    if (ref.read(orderProvider).isError) {
      _showSnackbar(
        customTheme,
        message: 'حدث خطأ أثناء رفع الصور، يرجى المحاولة مرة أخرى',
        icon: Icons.error,
        isError: true,
      );
      return;
    }

    final totalPhotoUrls = [...ref.read(orderProvider).photoUrls, ...newUrls];
    final orderData = _buildOrderData(totalPhotoUrls);

    final success = widget.order != null
        ? await notifier.updateOrder(
            orderId: widget.order!.id,
            orderData: orderData,
          )
        : await notifier.createOrderByAdmin(
            adminId: ref.read(authProvider).user?.id ?? '',
            orderData: orderData,
          );

    if (success != null && success != false && mounted) {
      ref.read(orderProvider.notifier).resetPhotos();

      // reset change tracking
      setState(() {
        _hasChanges = false;
        _originalSnapshot = _buildSnapshot();
      });

      _showSnackbar(
        customTheme,
        message: widget.order != null
            ? 'تم تحديث الاوردر بنجاح'
            : 'تم إضافة الاوردر بنجاح',
        icon: Icons.check,
        color: customTheme.statusGreen,
      );
      Navigator.pop(context);
    }
  }

  void _showSnackbar(
    CustomThemeExtension customTheme, {
    required String message,
    required IconData icon,
    bool isError = false,
    Color? color,
  }) {
    showCustomSnackBar(
      context,
      customTheme: customTheme,
      message: message,
      icon: icon,
      isError: isError,
      color: color ?? customTheme.errorColor,
    );
  }

  Order _buildOrderData(List<String> photoUrls) {
    return Order(
      title: _titleController.text,
      description: _descriptionController.text,
      priority: _priority,
      publicArea: _areaController.text,
      availability: _buildAvailabilityJson(),
      fullAddress: _fullAddressController.text.isNotEmpty
          ? _fullAddressController.text
          : null,
      latitude: double.tryParse(_latController.text),
      longitude: double.tryParse(_lngController.text),
      contactName: _contactNameController.text.isNotEmpty
          ? _contactNameController.text
          : null,
      contactPhone: _contactPhoneController.text.isNotEmpty
          ? _contactPhoneController.text
          : null,
      photoUrls: photoUrls,
      id: widget.order?.id ?? '',
      status: widget.order != null ? _status : OrderStatus.pending,
      workerId: _workerId,
      createdAt: widget.order?.createdAt,
      updatedAt: widget.order?.updatedAt,
    );
  }

  List<Map<String, dynamic>> _buildAvailabilityJson() {
    if (_availabilityConfig.weeklyRules.isNotEmpty ||
        _availabilityConfig.overrides.isNotEmpty) {
      final list = <Map<String, dynamic>>[];
      for (final rule in _availabilityConfig.weeklyRules) {
        for (final day in rule.days) {
          for (final range in rule.ranges) {
            list.add({
              'day': day.name,
              'timeRange': {
                'fromHour': range.startMin ~/ 60,
                'fromMinute': range.startMin % 60,
                'toHour': range.endMin ~/ 60,
                'toMinute': range.endMin % 60,
              },
            });
          }
        }
      }
      if (list.isNotEmpty) return list;
    }

    TimeOfDay Function(WeekDay) fromTime;
    TimeOfDay Function(WeekDay) toTime;

    if (_isAllWeek) {
      fromTime = (_) => _allWeekFromTime;
      toTime = (_) => _allWeekToTime;
    } else {
      fromTime = (day) => _dailyTimes[day]!.$1;
      toTime = (day) => _dailyTimes[day]!.$2;
    }

    return WeekDay.values
        .map(
          (day) => {
            'day': day.name,
            'timeRange': {
              'fromHour': fromTime(day).hour,
              'fromMinute': fromTime(day).minute,
              'toHour': toTime(day).hour,
              'toMinute': toTime(day).minute,
            },
          },
        )
        .toList();
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    final isLoading = ref.watch(orderProvider).isLoading;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (!didPop) await _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: customTheme.background,
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(gradient: customTheme.scaffoldGradient),
          child: SafeArea(
            child: Column(
              children: [
                _OrderHeader(
                  isEditing: widget.order != null,
                  isLoading: isLoading,
                  hasChanges: _hasChanges,
                  onBack: _onBackPressed,
                  onSubmit: (isLoading || !_hasChanges) ? null : _submit,
                  customTheme: customTheme,
                ),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const BouncingScrollPhysics(),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildGeneralSection(customTheme),
                                const SizedBox(height: 32),
                                _buildAvailabilitySection(customTheme),
                                const SizedBox(height: 32),
                                _buildLocationSection(customTheme),
                                const SizedBox(height: 32),
                                _buildContactSection(),
                                const SizedBox(height: 40),
                                if (widget.order != null) ...[
                                  _buildDeleteButton(),
                                  const SizedBox(height: 40),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Sections
  // ─────────────────────────────────────────

  Widget _buildDeleteButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(
              context,
            ).extension<CustomThemeExtension>()!.errorColor.withOpacity(0.1),
            Theme.of(
              context,
            ).extension<CustomThemeExtension>()!.errorColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).extension<CustomThemeExtension>()!.errorColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _confirmDelete(),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(
                    context,
                  ).extension<CustomThemeExtension>()!.errorColor,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'حذف الاوردر',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).extension<CustomThemeExtension>()!.errorColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: customTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: customTheme.errorColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'تأكيد الحذف',
              style: GoogleFonts.cairo(
                color: customTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف هذا الاوردر؟\nهذا الإجراء لا يمكن التراجع عنه.',
          style: GoogleFonts.cairo(
            color: customTheme.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: GoogleFonts.cairo(
                color: customTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: customTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'حذف',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await _performDelete();
    }
  }

  Future<void> _performDelete() async {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    final notifier = ref.read(orderProvider.notifier);

    // Show loading overlay or disable button
    setState(() {
      _isDeleting = true;
    });

    final success = await notifier.deleteOrder(
      orderId: widget.order!.id,
      userId: ref.read(authProvider).user?.id ?? '',
      order: widget.order!,
    );

    setState(() {
      _isDeleting = false;
    });

    if (success && mounted) {
      _showSnackbar(
        customTheme,
        message: 'تم حذف الاوردر بنجاح',
        icon: Icons.check,
        color: customTheme.statusGreen,
      );
      Navigator.pop(context, true); // Return true to indicate deletion
    } else if (mounted) {
      _showSnackbar(
        customTheme,
        message: 'حدث خطأ أثناء حذف الاوردر',
        icon: Icons.error,
        isError: true,
      );
    }
  }

  Widget _buildGeneralSection(CustomThemeExtension customTheme) {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'المعلومات العامة (عام للجميع)'),
          const SizedBox(height: 16),
          FormTextField(
            controller: _titleController,
            label: 'عنوان الاوردر (مثلاً: نقل حديد)',
            icon: Icons.title_rounded,
            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _descriptionController,
            label: 'وصف تفصيلي للخدمة',
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _PriorityDropdown(
            value: _priority,
            customTheme: customTheme,
            onChanged: (v) => setState(() {
              _priority = v;
              _markChanged();
            }),
          ),
          if (widget.order != null) ...[
            const SizedBox(height: 16),
            _StatusDropdown(
              value: _status,
              customTheme: customTheme,
              onChanged: (v) => setState(() {
                _status = v;
                if (_status == OrderStatus.pending) _workerId = null;
                _markChanged();
              }),
            ),
          ],
          if (_workerId != null && _workerId!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _WorkerCard(
              workerId: _workerId!,
              customTheme: customTheme,
              onRemove: () => setState(() {
                _workerId = null;
                _status = OrderStatus.pending;
                _markChanged();
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection(CustomThemeExtension customTheme) {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'التوافر والوقت'),
          const SizedBox(height: 16),
          AvailabilityToggle(
            isAllWeek: _isAllWeek,
            onChanged: (v) => setState(() {
              _isAllWeek = v;
              _markChanged();
            }),
            fromTime: _allWeekFromTime,
            toTime: _allWeekToTime,
            onFromChanged: (t) => setState(() {
              _allWeekFromTime = t;
              _markChanged();
            }),
            onToChanged: (t) => setState(() {
              _allWeekToTime = t;
              _markChanged();
            }),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            child: !_isAllWeek
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      ...WeekDay.values.map(
                        (day) => DailyScheduleItem(
                          day: day,
                          fromTime: _dailyTimes[day]!.$1,
                          toTime: _dailyTimes[day]!.$2,
                          onFromChanged: (t) => setState(() {
                            _dailyTimes[day] = (t, _dailyTimes[day]!.$2);
                            _markChanged();
                          }),
                          onToChanged: (t) => setState(() {
                            _dailyTimes[day] = (_dailyTimes[day]!.$1, t);
                            _markChanged();
                          }),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          _AdvancedAvailabilityButton(
            customTheme: customTheme,
            config: _availabilityConfig,
            onResult: (result) => setState(() {
              _availabilityConfig = result;
              _markChanged();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(CustomThemeExtension customTheme) {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'الموقع العام (يظهر للجميع)'),
          const SizedBox(height: 16),
          _PlacesDropdownButton(
            customTheme: customTheme,
            isManualArea: _isManualArea,
            selectedPlace: _selectedPlace,
            onTap: () => _showPlacesPicker(customTheme),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            child: _isManualArea
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FormTextField(
                      controller: _areaController,
                      label: 'المنطقة أو الحي (يدوياً)',
                      icon: Icons.location_city_rounded,
                      validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
            child: (_isManualArea || _selectedPlace != null)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      const SectionHeader(title: 'الموقع التفصيلي (خاص)'),
                      const SizedBox(height: 16),
                      FormTextField(
                        controller: _fullAddressController,
                        label: 'العنوان الكامل',
                        icon: Icons.map_rounded,
                      ),
                      const SizedBox(height: 16),
                      _MapPickerButton(
                        customTheme: customTheme,
                        onTap: _pickLocation,
                      ),
                      if (_latController.text.isNotEmpty)
                        _LocationStatusText(
                          lat: _latController.text,
                          lng: _lngController.text,
                          customTheme: customTheme,
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return _AnimatedSection(
      delay: const Duration(milliseconds: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'بيانات التواصل (خاص)'),
          const SizedBox(height: 16),
          FormTextField(
            controller: _contactNameController,
            label: 'اسم جهة الاتصال',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 16),
          FormTextField(
            controller: _contactPhoneController,
            label: 'رقم التواصل',
            icon: Icons.phone_android_rounded,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v!.isEmpty) return 'مطلوب';
              try {
                normalizeEgyptianPhone(v);
              } catch (_) {
                return 'رقم الهاتف غير صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          uplodePhotoWidget(),
        ],
      ),
    );
  }

  void _showPlacesPicker(CustomThemeExtension customTheme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlacesPickerSheet(
        customTheme: customTheme,
        onPlaceSelected: (place) => setState(() {
          _isManualArea = false;
          _selectedPlace = place;
          _areaController.text = place.name;
          _latController.text = place.lat.toString();
          _lngController.text = place.lng.toString();
          _markChanged();
        }),
        onManualSelected: () => setState(() {
          _isManualArea = true;
          _selectedPlace = null;
          _areaController.clear();
          _latController.clear();
          _lngController.clear();
          _markChanged();
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _AnimatedSection
// ─────────────────────────────────────────────

class _AnimatedSection extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _AnimatedSection({required this.child, required this.delay});

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ─────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────

class _OrderHeader extends StatelessWidget {
  final bool isEditing;
  final bool isLoading;
  final bool hasChanges;
  final VoidCallback onBack;
  final VoidCallback? onSubmit;
  final CustomThemeExtension customTheme;

  const _OrderHeader({
    required this.isEditing,
    required this.isLoading,
    required this.hasChanges,
    required this.onBack,
    required this.onSubmit,
    required this.customTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // back button — shows warning dot when has changes
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: customTheme.textPrimary,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: customTheme.textPrimary.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (hasChanges)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: customTheme.errorColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: customTheme.background,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'تعديل الاوردر' : 'إضافة اوردر جديد',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: customTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: hasChanges
                      ? Text(
                          'يوجد تعديلات غير محفوظة',
                          key: const ValueKey('unsaved'),
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: customTheme.errorColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('saved')),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HeaderActionButton(
            isLoading: isLoading,
            hasChanges: hasChanges,
            label: isEditing ? 'تحديث' : 'إنشاء',
            onTap: onSubmit,
            customTheme: customTheme,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Unsaved Changes Dialog
// ─────────────────────────────────────────────

class _UnsavedChangesDialog extends StatelessWidget {
  final CustomThemeExtension customTheme;
  const _UnsavedChangesDialog({required this.customTheme});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: customTheme.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: customTheme.errorColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'تعديلات غير محفوظة',
            style: GoogleFonts.cairo(
              color: customTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: Text(
        'عندك تعديلات لسه ما اتحفظتش،\nلو خرجت دلوقتي هتتفقد!',
        style: GoogleFonts.cairo(
          color: customTheme.textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'ارجع للتعديل',
            style: GoogleFonts.cairo(
              color: customTheme.primaryBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: customTheme.errorColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            'اخرج بدون حفظ',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Dropdowns
// ─────────────────────────────────────────────

class _DropdownContainer extends StatelessWidget {
  final CustomThemeExtension customTheme;
  final Widget child;
  const _DropdownContainer({required this.customTheme, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: customTheme.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: customTheme.textPrimary.withOpacity(0.1)),
    ),
    child: child,
  );
}

class _PriorityDropdown extends StatelessWidget {
  final OrderPriority value;
  final CustomThemeExtension customTheme;
  final ValueChanged<OrderPriority> onChanged;

  const _PriorityDropdown({
    required this.value,
    required this.customTheme,
    required this.onChanged,
  });

  static String _label(OrderPriority p) => switch (p) {
    OrderPriority.low => 'منخفضة',
    OrderPriority.medium => 'متوسطة',
    OrderPriority.high => 'عالية',
    OrderPriority.urgent => 'عاجل جداً',
    _ => '',
  };

  @override
  Widget build(BuildContext context) => _DropdownContainer(
    customTheme: customTheme,
    child: DropdownButton<OrderPriority>(
      value: value,
      dropdownColor: customTheme.cardBackground,
      isExpanded: true,
      underline: const SizedBox(),
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: customTheme.textSecondary,
      ),
      style: GoogleFonts.cairo(color: customTheme.textPrimary),
      items: OrderPriority.values
          .map((p) => DropdownMenuItem(value: p, child: Text(_label(p))))
          .toList(),
      onChanged: (v) => onChanged(v!),
    ),
  );
}

class _StatusDropdown extends StatelessWidget {
  final OrderStatus value;
  final CustomThemeExtension customTheme;
  final ValueChanged<OrderStatus> onChanged;

  const _StatusDropdown({
    required this.value,
    required this.customTheme,
    required this.onChanged,
  });

  static String _label(OrderStatus s) => switch (s) {
    OrderStatus.pending => 'قيد الانتظار',
    OrderStatus.accepted => 'تم القبول',
    OrderStatus.completed => 'مكتمل',
    OrderStatus.cancelled => 'ملغي',
    _ => '',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LabelText(text: 'حالة الاوردر', customTheme: customTheme),
      const SizedBox(height: 8),
      _DropdownContainer(
        customTheme: customTheme,
        child: DropdownButton<OrderStatus>(
          value: value,
          dropdownColor: customTheme.cardBackground,
          isExpanded: true,
          underline: const SizedBox(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: customTheme.textSecondary,
          ),
          style: GoogleFonts.cairo(color: customTheme.textPrimary),
          items: OrderStatus.values
              .map((s) => DropdownMenuItem(value: s, child: Text(_label(s))))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// Worker Card
// ─────────────────────────────────────────────

class _WorkerCard extends StatelessWidget {
  final String workerId;
  final CustomThemeExtension customTheme;
  final VoidCallback onRemove;

  const _WorkerCard({
    required this.workerId,
    required this.customTheme,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: customTheme.cardBackground,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: customTheme.primaryBlue.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.engineering_rounded, color: customTheme.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LabelText(text: 'العامل المعين', customTheme: customTheme),
              Text(
                workerId,
                style: GoogleFonts.cairo(
                  color: customTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onRemove,
          icon: Icon(
            Icons.person_remove_rounded,
            color: customTheme.errorColor,
            size: 18,
          ),
          label: Text(
            'حذف',
            style: GoogleFonts.cairo(
              color: customTheme.errorColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// Location Widgets
// ─────────────────────────────────────────────

class _PlacesDropdownButton extends StatelessWidget {
  final CustomThemeExtension customTheme;
  final bool isManualArea;
  final AlexPlace? selectedPlace;
  final VoidCallback onTap;

  const _PlacesDropdownButton({
    required this.customTheme,
    required this.isManualArea,
    required this.selectedPlace,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _LabelText(text: 'المنطقة أو الحي', customTheme: customTheme),
      const SizedBox(height: 8),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: customTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: customTheme.textPrimary.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(
                isManualArea
                    ? Icons.edit_location_alt_rounded
                    : Icons.location_on_rounded,
                color: customTheme.primaryBlue.withOpacity(0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isManualArea
                      ? 'أخرى (إدخال يدوي)'
                      : (selectedPlace?.name ?? 'اختر منطقة من القائمة'),
                  style: GoogleFonts.cairo(
                    color: (isManualArea || selectedPlace != null)
                        ? customTheme.textPrimary
                        : customTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: customTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _MapPickerButton extends StatelessWidget {
  final CustomThemeExtension customTheme;
  final VoidCallback onTap;

  const _MapPickerButton({required this.customTheme, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: customTheme.primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: customTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_rounded, color: customTheme.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Text(
            'تحديد الموقع من الخريطة *',
            style: GoogleFonts.cairo(
              color: customTheme.primaryBlue,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

class _LocationStatusText extends StatelessWidget {
  final String lat;
  final String lng;
  final CustomThemeExtension customTheme;

  const _LocationStatusText({
    required this.lat,
    required this.lng,
    required this.customTheme,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, right: 12),
    child: Text(
      'تم تحديد الموقع: $lat, $lng',
      style: GoogleFonts.cairo(
        color: customTheme.statusGreen,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Advanced Availability Button
// ─────────────────────────────────────────────

class _AdvancedAvailabilityButton extends StatelessWidget {
  final CustomThemeExtension customTheme;
  final AvailabilityConfig config;
  final ValueChanged<AvailabilityConfig> onResult;

  const _AdvancedAvailabilityButton({
    required this.customTheme,
    required this.config,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: customTheme.primaryBlue.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: customTheme.primaryBlue.withOpacity(0.2)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push<AvailabilityConfig>(
            context,
            MaterialPageRoute(
              builder: (_) => AvailabilitySettingsScreen(initialConfig: config),
            ),
          );
          if (result != null) onResult(result);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                Icons.settings_suggest_rounded,
                color: customTheme.primaryBlue,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدارة التوافر المتقدمة',
                      style: GoogleFonts.cairo(
                        color: customTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'فترات متعددة، استثناءات تواريخ معينة',
                      style: GoogleFonts.cairo(
                        color: customTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: customTheme.textSecondary,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// Header Action Button
// ─────────────────────────────────────────────

class _HeaderActionButton extends StatelessWidget {
  final bool isLoading;
  final bool hasChanges;
  final String label;
  final VoidCallback? onTap;
  final CustomThemeExtension customTheme;

  const _HeaderActionButton({
    required this.isLoading,
    required this.hasChanges,
    required this.label,
    required this.onTap,
    required this.customTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !hasChanges || isLoading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: isDisabled ? 0.4 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: isDisabled ? null : customTheme.primaryGradient,
          color: isDisabled ? customTheme.textSecondary.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: customTheme.primaryBlue.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: AnimationWidget.loadingAnimation(18),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasChanges
                            ? Icons.check_rounded
                            : Icons.check_circle_outline_rounded,
                        color: isDisabled
                            ? customTheme.textSecondary
                            : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDisabled
                              ? customTheme.textSecondary
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Places Picker Sheet
// ─────────────────────────────────────────────

class _PlacesPickerSheet extends StatefulWidget {
  final CustomThemeExtension customTheme;
  final ValueChanged<AlexPlace> onPlaceSelected;
  final VoidCallback onManualSelected;

  const _PlacesPickerSheet({
    required this.customTheme,
    required this.onPlaceSelected,
    required this.onManualSelected,
  });

  @override
  State<_PlacesPickerSheet> createState() => _PlacesPickerSheetState();
}

class _PlacesPickerSheetState extends State<_PlacesPickerSheet> {
  final _searchController = TextEditingController();
  List<AlexPlace> _filtered = alexPlaces;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? alexPlaces
          : alexPlaces
                .where(
                  (p) =>
                      p.name.contains(query) ||
                      p.zone.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
    });
  }

  static String _zoneArabic(String zone) => switch (zone.toLowerCase()) {
    'west' => 'غرب الإسكندرية',
    'center' => 'وسط الإسكندرية',
    'east' => 'شرق الإسكندرية',
    'montaza' => 'حي المنتزة',
    _ => zone,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: widget.customTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        gradient: widget.customTheme.scaffoldGradient,
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.customTheme.textPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'اختر المنطقة',
                  style: GoogleFonts.cairo(
                    color: widget.customTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: widget.customTheme.textPrimary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: GoogleFonts.cairo(color: widget.customTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'ابحث عن منطقة...',
                hintStyle: GoogleFonts.cairo(
                  color: widget.customTheme.textSecondary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: widget.customTheme.primaryBlue,
                ),
                filled: true,
                fillColor: widget.customTheme.textPrimary.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: widget.customTheme.textPrimary.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _PlaceItem(
                    icon: Icons.edit_location_alt_rounded,
                    title: 'أخرى (إدخال يدوي)',
                    subtitle: 'اختر هذا للمناطق غير الموجودة بالقائمة',
                    isManual: true,
                    customTheme: widget.customTheme,
                    onTap: () {
                      widget.onManualSelected();
                      Navigator.pop(context);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: widget.customTheme.textPrimary.withOpacity(0.1),
                    ),
                  ),
                  ..._filtered.map(
                    (place) => _PlaceItem(
                      icon: Icons.location_on_rounded,
                      title: place.name,
                      subtitle: _zoneArabic(place.zone),
                      customTheme: widget.customTheme,
                      onTap: () {
                        widget.onPlaceSelected(place);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isManual;
  final CustomThemeExtension customTheme;
  final VoidCallback onTap;

  const _PlaceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.customTheme,
    required this.onTap,
    this.isManual = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isManual
        ? customTheme.primaryBlue
        : customTheme.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isManual
            ? customTheme.primaryBlue.withOpacity(0.1)
            : customTheme.textPrimary.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isManual
              ? customTheme.primaryBlue.withOpacity(0.3)
              : customTheme.textPrimary.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            color: isManual ? customTheme.primaryBlue : customTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.cairo(
            color: customTheme.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          color: accent.withOpacity(0.5),
          size: 14,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Utility
// ─────────────────────────────────────────────

class _LabelText extends StatelessWidget {
  final String text;
  final CustomThemeExtension customTheme;
  const _LabelText({required this.text, required this.customTheme});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.cairo(
      color: customTheme.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    ),
  );
}

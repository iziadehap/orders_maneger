import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moamen_project/core/theme/app_theme.dart';
import 'package:moamen_project/features/pricelist/data/priceList_model.dart';
import 'package:moamen_project/features/pricelist/presentation/controller/priceList_provider.dart';

Widget uplodePhotoWidget() {
  return Consumer(
    builder: (context, ref, child) {
      final state = ref.watch(priceProvider);
      final controller = ref.read(priceProvider.notifier);
      final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'الصور المرفقة', customTheme: customTheme),
          const SizedBox(height: 16),
          if (state.photoUrls.isNotEmpty || state.localPhotos.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Remote Photos
                  ...state.photoUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return _PhotoItem(
                      image: NetworkImage(url),
                      onRemove: () => controller.removePhoto(index),
                    );
                  }),
                  // Local Photos
                  ...state.localPhotos.asMap().entries.map((entry) {
                    final index = entry.key;
                    final file = entry.value;
                    return _PhotoItem(
                      image: FileImage(file),
                      onRemove: () => controller.removeLocalPhoto(index),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 12),
          InkWell(
            onTap: state.isLoading ? null : () => controller.pickLocalPhoto(),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: customTheme.primaryBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: customTheme.primaryBlue.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_rounded,
                      color: customTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'إضافة صور',
                      style: GoogleFonts.cairo(
                        color: customTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PhotoItem extends StatelessWidget {
  final ImageProvider image;
  final VoidCallback onRemove;

  const _PhotoItem({required this.image, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: image, fit: BoxFit.cover),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final CustomThemeExtension customTheme;
  final String title;
  const SectionHeader({
    super.key,
    required this.title,
    required this.customTheme,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = Theme.of(context).extension<CustomThemeExtension>()!;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: customTheme.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Theme.of(
              context,
            ).extension<CustomThemeExtension>()!.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

Widget price_list_item_widget(
  BuildContext context,
  PriceListModel priceItem,
  bool isAdmin,
  CustomThemeExtension customTheme,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              priceItem.title,
              style: GoogleFonts.cairo(
                color: customTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            _ActiveBadge(
              isActive: priceItem.isActive,
              customTheme: customTheme,
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Text(
        priceItem.description,
        style: GoogleFonts.cairo(
          color: customTheme.textPrimary.withOpacity(0.8),
          fontSize: 13,
          height: 1.4,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      const SizedBox(height: 16),
      _buildPriceBadge(priceItem, customTheme),
    ],
  );
}

Widget _buildPriceBadge(
  PriceListModel priceItem,
  CustomThemeExtension customTheme,
) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          customTheme.primaryBlue.withOpacity(0.15),
          customTheme.primaryBlue.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: customTheme.primaryBlue.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          priceItem.price.toString(),
          style: GoogleFonts.cairo(
            color: customTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'ج.م',
          style: GoogleFonts.cairo(
            color: customTheme.primaryBlue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _ActiveBadge extends StatelessWidget {
  final bool isActive;
  final CustomThemeExtension customTheme;

  const _ActiveBadge({required this.isActive, required this.customTheme});

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? customTheme.statusGreen
        : customTheme.textSecondary;
    final text = isActive ? 'نشط' : 'معطل';
    final icon = isActive ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

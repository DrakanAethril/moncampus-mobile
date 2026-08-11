import 'package:flutter/material.dart';

import '../models/quiz.dart';
import '../theme/app_theme.dart';

/// How one zone should be painted - the passation drives [selected]/[dimmed], the correction
/// drives [good]/[bad]. Mirrors the web's cm-zone modifier classes.
enum ZoneVisualState { none, selected, dimmed, good, bad }

/// The support of a Zone/Légende question - the phone counterpart of the web's
/// templates/quiz/_zone_support.html.twig, shared by the passation and the correction so the two
/// can never disagree on what a zone looks like.
///
/// Three kinds: prose ('texte'), numbered monospace lines ('code'), and an image with drawn
/// rectangle overlays ('image', coordinates normalized 0..1 of the rendered picture). Zones are
/// tappable when [onZoneTap] is given, inert otherwise (correction).
class QuizZoneSupport extends StatelessWidget {
  const QuizZoneSupport({
    super.key,
    required this.kind,
    required this.lines,
    required this.imageZones,
    required this.imageUrl,
    required this.stateOf,
    this.placedTextOf,
    this.onZoneTap,
  });

  final String kind;
  final List<List<QuizZoneSegment>> lines;
  final List<QuizImageZone> imageZones;
  final String? imageUrl;
  final ZoneVisualState Function(String id) stateOf;

  /// The label currently sitting on a zone (légende), null when the zone is empty.
  final String? Function(String id)? placedTextOf;
  final void Function(String id)? onZoneTap;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      'image' => _buildImage(),
      'code' => _buildCode(),
      _ => _buildText(),
    };
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map((line) => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 6,
                children: line.map((segment) => _buildSegment(segment, monospace: false)).toList(),
              ))
          .toList(),
    );
  }

  Widget _buildCode() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.asMap().entries.map((entry) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  child: Text('${entry.key + 1}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, color: AppColors.faint, height: 2.1)),
                ),
                const SizedBox(width: 10),
                ...entry.value.map((segment) => _buildSegment(segment, monospace: true)),
                // An empty line still needs height, or the numbering visually skips it.
                if (entry.value.isEmpty) const Text(' ', style: TextStyle(fontFamily: 'monospace', height: 2.1)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSegment(QuizZoneSegment segment, {required bool monospace}) {
    final baseStyle = TextStyle(
      fontSize: monospace ? 13 : 16,
      height: monospace ? 2.1 : 1.9,
      color: AppColors.ink,
      fontFamily: monospace ? 'monospace' : null,
    );

    if (!segment.isZone) {
      return Text(segment.text, style: baseStyle);
    }

    final state = stateOf(segment.id);
    final placed = placedTextOf?.call(segment.id);
    final colors = _colorsFor(state);

    final zone = GestureDetector(
      onTap: onZoneTap == null ? null : () => onZoneTap!(segment.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: colors.background,
          border: Border.all(color: colors.border, width: colors.border == Colors.transparent ? 0 : 1.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              segment.text,
              style: baseStyle.copyWith(
                color: colors.foreground,
                fontWeight: state == ZoneVisualState.none ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            if (placed != null) ...[
              const SizedBox(width: 5),
              _PlacedChip(text: placed, state: state),
            ],
          ],
        ),
      ),
    );

    return state == ZoneVisualState.dimmed ? Opacity(opacity: .25, child: zone) : zone;
  }

  Widget _buildImage() {
    if (imageUrl == null) {
      return const Text('Image indisponible', style: TextStyle(fontSize: 12.5, color: AppColors.faint));
    }

    // The Stack shrink-wraps the loaded image; the overlay then positions each rectangle as a
    // fraction of that rendered size, so any screen width works.
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Image.network(imageUrl!),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: imageZones.map((zone) {
                  final state = stateOf(zone.id);
                  final placed = placedTextOf?.call(zone.id);
                  final colors = _colorsFor(state);
                  final area = GestureDetector(
                    onTap: onZoneTap == null ? null : () => onZoneTap!(zone.id),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // ignore: deprecated_member_use
                        color: colors.background.withOpacity(state == ZoneVisualState.none ? .08 : .30),
                        border: Border.all(
                          color: colors.border == Colors.transparent ? AppColors.brand : colors.border,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: placed != null ? _PlacedChip(text: placed, state: state) : null,
                    ),
                  );

                  return Positioned(
                    left: zone.x * constraints.maxWidth,
                    top: zone.y * constraints.maxHeight,
                    width: zone.w * constraints.maxWidth,
                    height: zone.h * constraints.maxHeight,
                    child: state == ZoneVisualState.dimmed ? Opacity(opacity: .25, child: area) : area,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ({Color background, Color border, Color foreground}) _colorsFor(ZoneVisualState state) {
    return switch (state) {
      ZoneVisualState.selected => (background: AppColors.blueBg, border: AppColors.brand, foreground: AppColors.blueTx),
      ZoneVisualState.good => (background: AppColors.greenBg, border: AppColors.greenTx, foreground: AppColors.greenTx),
      ZoneVisualState.bad => (background: AppColors.redBg, border: AppColors.redTx, foreground: AppColors.redTx),
      _ => (background: Colors.transparent, border: Colors.transparent, foreground: AppColors.blueTx),
    };
  }
}

class _PlacedChip extends StatelessWidget {
  const _PlacedChip({required this.text, required this.state});

  final String text;
  final ZoneVisualState state;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      ZoneVisualState.good => AppColors.greenTx,
      ZoneVisualState.bad => AppColors.redTx,
      _ => AppColors.brand,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), maxLines: 1),
    );
  }
}

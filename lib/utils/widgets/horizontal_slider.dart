import 'package:flutter/material.dart';
import 'package:parla/services/color.dart';

typedef OnSelectCallback =
    void Function(int index, HorizontalSelectionItem item);

class HorizontalSelectionItem {
  final IconData? icon;
  final String? title;

  const HorizontalSelectionItem({this.icon, this.title});
}

class CoolHorizontalSliderSelector extends StatefulWidget {
  final List<HorizontalSelectionItem> items;
  final int visibleItemCount;
  final int initialIndex;
  final OnSelectCallback? onSelect;
  final Duration animationDuration;
  final Curve opacityFalloffCurve;
  final double? itemSpacing;
  final double? itemWidth;
  final bool emphasizeSelected;

  const CoolHorizontalSliderSelector({
    super.key,
    required this.items,
    this.visibleItemCount = 3,
    this.initialIndex = 0,
    this.onSelect,
    this.animationDuration = const Duration(milliseconds: 350),
    this.opacityFalloffCurve = Curves.easeOut,
    this.itemSpacing,
    this.itemWidth,
    this.emphasizeSelected = true,
  });

  @override
  State<CoolHorizontalSliderSelector> createState() =>
      _CoolHorizontalSliderSelectorState();
}

class _CoolHorizontalSliderSelectorState
    extends State<CoolHorizontalSliderSelector> {
  late PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(
      viewportFraction: 1 / widget.visibleItemCount,
      initialPage: _currentPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateTo(int index) {
    _pageController.animateToPage(
      index,
      duration: widget.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  double _lookupOpacity(double dist) {
    const lookup = [1.0, 0.7, 0.5, 0.3, 0.0];
    if (dist <= 0) return 1.0;
    if (dist >= lookup.length - 1) return lookup.last;
    final low = dist.floor();
    final high = low + 1;
    final frac = dist - low;
    return lookup[low] + (lookup[high] - lookup[low]) * frac;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewportFraction = widget.itemWidth != null
            ? widget.itemWidth!.clamp(10, width) / width
            : 1 / widget.visibleItemCount;

        if ((_pageController.viewportFraction - viewportFraction).abs() >
            0.001) {
          final page = _pageController.hasClients
              ? (_pageController.page ?? _currentPage.toDouble())
              : _currentPage.toDouble();
          _pageController.dispose();
          _pageController = PageController(
            viewportFraction: viewportFraction,
            initialPage: page.round(),
          );
        }

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.12, 0.88, 1.0],
            ).createShader(rect);
          },
          child: SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                _currentPage = index;
                widget.onSelect?.call(index, widget.items[index]);
              },
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, _) {
                    final page = _pageController.hasClients
                        ? (_pageController.page ?? _currentPage.toDouble())
                        : _currentPage.toDouble();

                    final dist = (index - page).abs();
                    final t = widget.opacityFalloffCurve.transform(
                      dist.clamp(0.0, 4.0) / 4.0,
                    );

                    final rawOpacity = _lookupOpacity(t * 4);

                    final scale = widget.emphasizeSelected
                        ? 1.0 + ((1.0 - dist.clamp(0.0, 1.0)) * 0.06)
                        : 1.0;

                    final isSelected = dist < 0.01;

                    final fgColor = colorScheme.onSurface.opacityAlpha(
                      rawOpacity.clamp(0.0, 1.0),
                    );

                    final item = widget.items[index];

                    return Center(
                      child: Transform.scale(
                        scale: scale,
                        child: GestureDetector(
                          onTap: () => _animateTo(index),
                          child: AnimatedContainer(
                            duration: widget.animationDuration,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.opacityAlpha(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SizedBox(
                              width:
                                  widget.itemWidth ?? width * viewportFraction,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (item.icon != null)
                                    Icon(item.icon, color: fgColor),
                                  if (item.icon != null && item.title != null)
                                    const SizedBox(width: 8),
                                  if (item.title != null)
                                    Text(
                                      item.title!,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: fgColor,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

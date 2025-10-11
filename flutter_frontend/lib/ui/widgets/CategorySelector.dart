import 'package:flutter/material.dart';

class CategorySelector extends StatefulWidget {
  const CategorySelector({
    super.key,
    this.categories = const ['Messages', 'Online', 'Groups', 'Requests'],
    this.initialIndex,
    this.onCategorySelected,
    this.backgroundColor,
    this.scrollDirection = Axis.horizontal,
    this.padding = const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
  });

  final List<String> categories;
  final int? initialIndex;
  final ValueChanged<int>? onCategorySelected;
  final Color? backgroundColor;
  final Axis scrollDirection;
  final EdgeInsets padding;

  @override
  State<CategorySelector> createState() => _CategorySelectorState();
}

class _CategorySelectorState extends State<CategorySelector> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  @override
  void didUpdateWidget(covariant CategorySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != null &&
        widget.initialIndex != oldWidget.initialIndex &&
        widget.initialIndex != _selectedIndex) {
      _selectedIndex = widget.initialIndex!;
    }
  }

  void _handleTap(int index) {
    if (widget.initialIndex == null) {
      setState(() {
        _selectedIndex = index;
      });
    }
    widget.onCategorySelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIndex = widget.initialIndex ?? _selectedIndex;
    final backgroundColor =
        widget.backgroundColor ?? Theme.of(context).primaryColor;

    return Container(
      height: widget.scrollDirection == Axis.horizontal ? 90.0 : null,
      width: widget.scrollDirection == Axis.vertical ? double.infinity : null,
      color: backgroundColor,
      child: ListView.builder(
        shrinkWrap: widget.scrollDirection == Axis.vertical,
        physics: widget.scrollDirection == Axis.vertical
            ? const NeverScrollableScrollPhysics()
            : null,
        scrollDirection: widget.scrollDirection,
        itemCount: widget.categories.length,
        itemBuilder: (BuildContext context, int index) {
          final isSelected = index == effectiveIndex;
          final text = widget.categories[index];

          return GestureDetector(
            onTap: () => _handleTap(index),
            child: Padding(
              padding: widget.scrollDirection == Axis.horizontal
                  ? widget.padding
                  : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: widget.scrollDirection == Axis.horizontal
                  ? Text(
                      text,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    )
                  : AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            text,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.7),
                              fontSize: 16.0,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'recipe.dart';

class IngredientPrepChecklistWidget extends StatefulWidget {
  final List<IngredientItem> ingredients;
  final String? title;
  final ValueChanged<List<IngredientItem>>? onIngredientsChanged;

  const IngredientPrepChecklistWidget({
    super.key,
    required this.ingredients,
    this.title,
    this.onIngredientsChanged,
  });

  @override
  State<IngredientPrepChecklistWidget> createState() =>
      _IngredientPrepChecklistWidgetState();
}

class _IngredientPrepChecklistWidgetState
    extends State<IngredientPrepChecklistWidget> {
  late List<IngredientItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.ingredients);
  }

  @override
  void didUpdateWidget(covariant IngredientPrepChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ingredients != widget.ingredients) {
      _items = List.of(widget.ingredients);
    }
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index] = _items[index].copyWith(
        isPrepped: !_items[index].isPrepped,
      );
    });
    widget.onIngredientsChanged?.call(_items);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preppedCount = _items.where((i) => i.isPrepped).length;
    final totalCount = _items.length;
    final progress = totalCount > 0 ? preppedCount / totalCount : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title ?? 'Prep Checklist',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: progress == 1.0
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$preppedCount / $totalCount prepped',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: progress == 1.0
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < _items.length; i++) ...[
            _buildChecklistItem(theme, _items[i], i),
            if (i < _items.length - 1) const Divider(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistItem(ThemeData theme, IngredientItem item, int index) {
    final isChecked = item.isPrepped;

    final quantityUnit = [item.quantity, item.unit]
        .where((s) => s.trim().isNotEmpty)
        .join(' ');

    return Semantics(
      label:
          'Ingredient: ${item.displayText}. ${isChecked ? 'Prepped' : 'Not prepped'}. Tap to toggle.',
      checked: isChecked,
      button: true,
      child: InkWell(
        onTap: () => _toggleItem(index),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isChecked,
                activeColor: theme.colorScheme.primary,
                onChanged: (_) => _toggleItem(index),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (quantityUnit.isNotEmpty)
                      Text(
                        quantityUnit,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isChecked
                              ? theme.colorScheme.onSurfaceVariant
                                  .withAlpha(120)
                              : theme.colorScheme.onSurface,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isChecked
                            ? theme.colorScheme.onSurfaceVariant.withAlpha(120)
                            : theme.colorScheme.onSurface,
                        decoration:
                            isChecked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.prepAction.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? theme.colorScheme.surfaceContainerHighest
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.prepAction,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isChecked
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onPrimaryContainer,
                            decoration:
                                isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recipe.dart';
import 'recipe_import.dart';

class ImportRecipeDialog extends StatefulWidget {
  final RecipeImporter importer;
  final Future<Recipe> Function(Recipe) onSave;
  const ImportRecipeDialog({
    super.key,
    required this.importer,
    required this.onSave,
  });
  @override
  State<ImportRecipeDialog> createState() => _ImportRecipeDialogState();
}

class _ImportRecipeDialogState extends State<ImportRecipeDialog> {
  final controller = TextEditingController();
  Recipe? preview;
  String? error;
  bool busy = false;
  Future<void> pasteLink() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted || busy || preview != null) return;
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        setState(
          () => error =
              'Clipboard is empty. Copy the recipe link on this device first.',
        );
        return;
      }
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      setState(() => error = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not access the clipboard. Long-press the link field and choose Paste.',
        );
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (preview == null) {
        final recipe = await widget.importer.importUrl(controller.text);
        if (mounted) {
          setState(() => preview = recipe);
        }
      } else {
        final saved = await widget.onSave(preview!);
        if (mounted) {
          Navigator.of(context).pop(saved);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is RecipeImportException
              ? e.message
              : 'Could not ${preview == null ? 'import' : 'save'} this recipe. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: Text(preview == null ? 'Import a cooking link' : 'Review recipe'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (preview == null) ...[
                const Text(
                  'Paste a recipe page link to bring its ingredients and cooking steps into your collection.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('import-url'),
                  controller: controller,
                  enabled: !busy,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  onSubmitted: (_) {
                    if (!busy) {
                      submit();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Recipe link',
                    hintText: 'https://example.com/recipe',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : pasteLink,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Paste link'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Works with recipe websites that share structured recipe data. Video-only links are not supported.',
                ),
              ] else ...[
                Text(
                  preview!.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: Color(0xFF887E8D)),
                    const SizedBox(width: 4),
                    Text(
                      preview!.timeLabel,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF887E8D)),
                    ),
                  ],
                ),
                for (final notice in preview!.notices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Notice: $notice',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SelectableText(
                  preview!.sourceUrl!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF887E8D)),
                ),
                if (preview!.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    preview!.description,
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Ingredients',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF43333E),
                  ),
                ),
                const SizedBox(height: 8),
                for (final ingredient in preview!.ingredients)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(
                            color: Color(0xFFEC4E6E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ingredient[1],
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Cooking Steps',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF43333E),
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < preview!.steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(right: 10, top: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEC4E6E),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            preview!.steps[i],
                            style: const TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (preview != null)
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    preview = null;
                    error = null;
                  }),
            child: const Text('Change link'),
          ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(preview == null ? 'Import recipe' : 'Save recipe'),
        ),
      ],
    ),
  );
}

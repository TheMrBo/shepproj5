import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'recipe.dart';

/// ---------------------------------------------------------------------------
/// 1. SUBMISSION LEGAL FOOTER WIDGET (`RecipePublishLegalWidget`)
/// ---------------------------------------------------------------------------
class RecipePublishLegalWidget extends StatefulWidget {
  final bool isCertified;
  final ValueChanged<bool> onCertifiedChanged;

  const RecipePublishLegalWidget({
    super.key,
    required this.isCertified,
    required this.onCertifiedChanged,
  });

  @override
  State<RecipePublishLegalWidget> createState() =>
      _RecipePublishLegalWidgetState();
}

class _RecipePublishLegalWidgetState extends State<RecipePublishLegalWidget> {
  void _showLegalModal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.gavel_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Community Guidelines & DMCA Policy',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildLegalSection(
                          theme,
                          title: 'Community Guidelines',
                          icon: Icons.groups_outlined,
                          body: '• Original Work & Attribution: Only share recipes and photos that you own or have permission to post. Use the "Adapted from" option for inspired recipes.\n\n'
                              '• Quality & Authenticity: Ensure instructions are accurate, clear, and safe for home cooks.\n\n'
                              '• Respect & Moderation: Spam, offensive language, or duplicate submissions will be removed by moderation.',
                        ),
                        const SizedBox(height: 16),
                        _buildLegalSection(
                          theme,
                          title: 'DMCA Copyright Policy',
                          icon: Icons.copyright_outlined,
                          body: 'We adhere to the Digital Millennium Copyright Act (DMCA):\n\n'
                              '1. Copyright Protection: We respect intellectual property rights. Infringing content will be removed.\n\n'
                              '2. Reporting Infringements: Rightsholders can file a DMCA violation notice via the recipe popup menu.\n\n'
                              '3. Notice & Takedown: Verified notices result in prompt content removal and notification to the uploader.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegalSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(128),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: 'Recipe publishing copyright certification and policies',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isCertified
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label:
                  'Certification checkbox: I certify that this recipe and its accompanying photo are my own work or that I have proper rights and attribution to share them.',
              checked: widget.isCertified,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: theme.colorScheme.primary,
                value: widget.isCertified,
                onChanged: (val) => widget.onCertifiedChanged(val ?? false),
                title: Text(
                  'I certify that this recipe and its accompanying photo are my own work or that I have proper rights and attribution to share them.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              hint: 'Opens Community Guidelines and DMCA Copyright Policy modal',
              child: InkWell(
                onTap: () => _showLegalModal(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Read Community Guidelines & DMCA Copyright Policy',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2. PUBLIC-FACING RECIPE DISPLAY CARD HEADER (`RecipeAttributionHeader`)
/// ---------------------------------------------------------------------------
class RecipeAttributionHeader extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  const RecipeAttributionHeader({
    super.key,
    required this.recipe,
    this.onSave,
    this.onShare,
  });

  Future<void> _launchSourceUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open source URL: $url')),
        );
      }
    }
  }

  void _showReportDMCADialog(BuildContext context) {
    final theme = Theme.of(context);
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.report_problem_outlined, color: Colors.orange),
            SizedBox(width: 8),
            Text('Report DMCA Violation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report "${recipe.name}" for copyright infringement or violation of community standards.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details / Original Creator Link',
                hintText: 'Explain why this content violates copyright...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'DMCA report submitted. Our team will review this notice.',
                  ),
                ),
              );
            },
            child: const Text('Submit Report'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label:
          'Recipe header by ${recipe.authorName}, posted ${recipe.postedDate}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(100),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AUTHOR PROFILE & OPTIONS ROW
            Row(
              children: [
                Semantics(
                  label: "Author profile avatar",
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      recipe.authorName.isNotEmpty
                          ? recipe.authorName[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Posted ${recipe.postedDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                Semantics(
                  button: true,
                  label: "Recipe options menu",
                  child: PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'share':
                          onShare?.call();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sharing "${recipe.name}"...'),
                            ),
                          );
                          break;
                        case 'save':
                          onSave?.call();
                          break;
                        case 'dmca':
                          _showReportDMCADialog(context);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Share'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'save',
                        child: Row(
                          children: [
                            Icon(Icons.bookmark_border, size: 18),
                            SizedBox(width: 8),
                            Text('Save'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'dmca',
                        child: Row(
                          children: [
                            Icon(
                              Icons.report_outlined,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Report Copyright / DMCA Violation',
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ADAPTED BADGE WITH URL LAUNCHER
            if (recipe.isAdapted ||
                (recipe.sourceName != null && recipe.sourceName!.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Semantics(
                button: recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty,
                label:
                    'Adapted from ${recipe.sourceName ?? "Original Author"}. Tap to open source link.',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: recipe.sourceUrl != null &&
                            recipe.sourceUrl!.trim().isNotEmpty
                        ? () => _launchSourceUrl(context, recipe.sourceUrl!)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withAlpha(150),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.secondary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Adapted from ${recipe.sourceName ?? "Original Source"}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (recipe.sourceUrl != null &&
                              recipe.sourceUrl!.trim().isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new,
                              size: 13,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

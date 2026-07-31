import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../services/tool_usage_service.dart';
import '../theme/appearance_settings.dart';
import '../widgets/prismatic_surface.dart';
import '../widgets/tool_visual.dart';
import 'home_screen.dart';
import 'price_check_screen.dart';
import 'tos_screen.dart';
import 'watchlist_screen.dart';

class ToolsScreen extends StatefulWidget {
  final LibraryService libraryService;
  final TextAiService textAiService;
  final bool usesRealAi;
  final VoidCallback onConfigureAi;
  final ToolUsageService usageService;

  const ToolsScreen({
    super.key,
    required this.libraryService,
    required this.textAiService,
    required this.usesRealAi,
    required this.onConfigureAi,
    this.usageService = const ToolUsageService(),
  });

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  late final List<_ToolDefinition> _tools;
  Map<String, int> _usageCounts = const {};

  @override
  void initState() {
    super.initState();
    _tools = [
      _ToolDefinition(
        id: 'text_analysis',
        title: 'Text Analysis',
        description: 'Summarize or simplify dense text.',
        visual: ToolVisualKind.textAnalysis,
        colors: const [Color(0xff3949ab), Color(0xff1a237e)],
        screenBuilder: () => HomeScreen(
          libraryService: widget.libraryService,
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
          onConfigureAi: widget.onConfigureAi,
          title: 'Text Analysis',
          initialPreset: TextAiTaskType.summary,
          allowCustomInstructions: false,
        ),
      ),
      _ToolDefinition(
        id: 'tos_analysis',
        title: 'ToS Analysis',
        description: 'Find important terms, risks, and obligations.',
        visual: ToolVisualKind.termsAnalysis,
        colors: const [Color(0xff6a1b9a), Color(0xff311b92)],
        screenBuilder: () => TosScreen(
          libraryService: widget.libraryService,
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
          onConfigureAi: widget.onConfigureAi,
        ),
      ),
      _ToolDefinition(
        id: 'allergy_watchlist',
        title: 'Allergy Watchlist',
        description: 'Check labels against ingredients you avoid.',
        visual: ToolVisualKind.allergyWatchlist,
        colors: const [Color(0xff00897b), Color(0xff004d40)],
        screenBuilder: () => WatchlistScreen(
          libraryService: widget.libraryService,
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
        ),
      ),
      _ToolDefinition(
        id: 'price_check',
        title: 'Price Check',
        description: 'Estimate an item’s market range for buying or selling.',
        visual: ToolVisualKind.priceCheck,
        colors: const [Color(0xff0277bd), Color(0xff00695c)],
        screenBuilder: () => const PriceCheckScreen(),
      ),
      _ToolDefinition(
        id: 'custom_instructions',
        title: 'Custom Instructions',
        description: 'Tell the AI exactly how to help with your text.',
        visual: ToolVisualKind.customInstructions,
        colors: const [Color(0xffef6c00), Color(0xffbf360c)],
        screenBuilder: () => HomeScreen(
          libraryService: widget.libraryService,
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
          onConfigureAi: widget.onConfigureAi,
          title: 'Custom Instructions',
          showPresets: false,
        ),
      ),
    ];
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final counts = await widget.usageService.load(_tools.map((tool) => tool.id));
    if (mounted) setState(() => _usageCounts = counts);
  }

  _ToolDefinition get _featuredTool {
    var featured = _tools.first;
    for (final tool in _tools.skip(1)) {
      if ((_usageCounts[tool.id] ?? 0) >
          (_usageCounts[featured.id] ?? 0)) {
        featured = tool;
      }
    }
    return featured;
  }

  Future<void> _openTool(_ToolDefinition tool) async {
    final count = await widget.usageService.increment(tool.id);
    if (!mounted) return;
    setState(() => _usageCounts = {..._usageCounts, tool.id: count});
    await Navigator.push<void>(
      context,
      prismaticPageRoute(
        context: context,
        builder: (_) => tool.screenBuilder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = _featuredTool;
    final remaining = _tools.where((tool) => tool.id != featured.id).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What would you like to do?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a tool, then scan, photograph, import, or paste.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                _ToolCard(
                  tool: featured,
                  featured: true,
                  onTap: () => _openTool(featured),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: remaining.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth < 360 ? 1 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: constraints.maxWidth < 360 ? 2.1 : 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final tool = remaining[index];
                    return _ToolCard(
                      tool: tool,
                      onTap: () => _openTool(tool),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolDefinition {
  final String id;
  final String title;
  final String description;
  final ToolVisualKind visual;
  final List<Color> colors;
  final Widget Function() screenBuilder;

  const _ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.visual,
    required this.colors,
    required this.screenBuilder,
  });
}

class _ToolCard extends StatelessWidget {
  final _ToolDefinition tool;
  final bool featured;
  final VoidCallback onTap;

  const _ToolCard({
    required this.tool,
    required this.onTap,
    this.featured = false,
  });

  @override
  Widget build(BuildContext context) {
    final glass = Theme.of(context).extension<GlassStyle>() ??
        GlassStyle.fromLevel(GlassLevel.none);

    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        tint: tool.colors.first,
        child: SizedBox(
          height: featured ? 184 : null,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tool.colors.first.withValues(
                            alpha: 0.14 + (0.06 * glass.intensity),
                          ),
                          Colors.transparent,
                          tool.colors.last.withValues(
                            alpha: 0.1 + (0.05 * glass.intensity),
                          ),
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
              ),
              if (featured)
                Positioned.fill(
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      Expanded(child: _ToolCardCopy(tool: tool)),
                      const SizedBox(width: 12),
                      SizedBox(
                        key: const ValueKey('featured-tool-visual-region'),
                        width: 120,
                        child: Center(
                          child: ToolVisual(
                            kind: tool.visual,
                            colors: tool.colors,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Positioned(
                  right: 4,
                  top: 10,
                  child: ToolVisual(
                    kind: tool.visual,
                    colors: tool.colors,
                    compact: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ToolCardCopy(tool: tool, compact: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolCardCopy extends StatelessWidget {
  const _ToolCardCopy({required this.tool, this.compact = false});

  final _ToolDefinition tool;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (!compact) ...[
          Icon(Icons.auto_awesome, color: colors.primary),
          const Spacer(),
        ] else
          const Spacer(),
        Text(
          tool.title,
          style: (compact
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.titleLarge)
              ?.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tool.description,
          maxLines: compact ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

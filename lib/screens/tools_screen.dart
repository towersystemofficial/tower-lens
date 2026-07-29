import 'package:flutter/material.dart';

import '../services/library_service.dart';
import '../services/text_ai_service.dart';
import '../services/tool_usage_service.dart';
import 'home_screen.dart';
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
        icon: Icons.auto_awesome_outlined,
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
        icon: Icons.policy_outlined,
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
        icon: Icons.health_and_safety_outlined,
        colors: const [Color(0xff00897b), Color(0xff004d40)],
        screenBuilder: () => WatchlistScreen(
          libraryService: widget.libraryService,
          textAiService: widget.textAiService,
          usesRealAi: widget.usesRealAi,
        ),
      ),
      _ToolDefinition(
        id: 'custom_instructions',
        title: 'Custom Instructions',
        description: 'Tell the AI exactly how to help with your text.',
        icon: Icons.tune_outlined,
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
      MaterialPageRoute(builder: (_) => tool.screenBuilder()),
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
                  'Choose a tool, then scan, import, or paste your text.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
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
  final IconData icon;
  final List<Color> colors;
  final Widget Function() screenBuilder;

  const _ToolDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
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
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          height: featured ? 148 : null,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tool.colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: featured ? 20 : -6,
                top: featured ? 16 : 8,
                child: Icon(
                  tool.icon,
                  size: featured ? 88 : 64,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(tool.icon, color: Colors.white),
                    const Spacer(),
                    Text(
                      tool.title,
                      style: (featured
                              ? Theme.of(context).textTheme.titleLarge
                              : Theme.of(context).textTheme.titleMedium)
                          ?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tool.description,
                      maxLines: featured ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
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

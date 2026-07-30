import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/appearance_settings.dart';

Route<T> prismaticPageRoute<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final motion =
      Theme.of(context).extension<MotionStyle>()?.intensity ?? 0;
  final duration = Duration(milliseconds: (280 * motion).round());

  if (motion == 0) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: eased,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.035 * motion, 0.025 * motion),
            end: Offset.zero,
          ).animate(eased),
          child: child,
        ),
      );
    },
  );
}

class PrismaticBackground extends StatefulWidget {
  const PrismaticBackground({super.key, required this.child});

  final Widget child;

  @override
  State<PrismaticBackground> createState() => _PrismaticBackgroundState();
}

class _PrismaticBackgroundState extends State<PrismaticBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final motion = theme.extension<MotionStyle>()?.intensity ?? 0;
    final glass = theme.extension<GlassStyle>()?.intensity ?? 0;

    return ColoredBox(
      color: theme.canvasColor,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final phase = motion == 0 ? 0.0 : _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(
                  -0.8 + (0.32 * phase * motion),
                  -0.95 + (0.22 * phase * motion),
                ),
                radius: 1.45,
                colors: [
                  colors.primary.withValues(alpha: 0.18 * glass),
                  colors.secondary.withValues(alpha: 0.08 * glass),
                  Colors.transparent,
                ],
                stops: const [0, 0.43, 1],
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final glass =
        Theme.of(context).extension<GlassStyle>() ??
        GlassStyle.fromLevel(GlassLevel.none);
    final radius = BorderRadius.circular(borderRadius);
    final surface = Color.alphaBlend(
      (tint ?? colors.primary).withValues(alpha: 0.09 * glass.intensity),
      colors.surfaceContainerHighest.withValues(alpha: glass.surfaceOpacity),
    );

    Widget result = Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: radius,
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.58 + (0.2 * glass.intensity),
          ),
        ),
        boxShadow: glass.glowOpacity == 0
            ? null
            : [
                BoxShadow(
                  color: (tint ?? colors.primary).withValues(
                    alpha: glass.glowOpacity * 0.45,
                  ),
                  blurRadius: 22 * glass.intensity,
                  spreadRadius: -7,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (glass.blurSigma > 0) {
      result = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glass.blurSigma,
            sigmaY: glass.blurSigma,
          ),
          child: result,
        ),
      );
    }
    return result;
  }
}

class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final glass =
        Theme.of(context).extension<GlassStyle>() ??
        GlassStyle.fromLevel(GlassLevel.none);
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(24);
    Widget bar = Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: glass.surfaceOpacity),
        borderRadius: radius,
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.58 + (0.2 * glass.intensity),
          ),
        ),
        boxShadow: glass.glowOpacity == 0
            ? null
            : [
                BoxShadow(
                  color: colors.primary.withValues(
                    alpha: glass.glowOpacity * 0.38,
                  ),
                  blurRadius: 26 * glass.intensity,
                  spreadRadius: -8,
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: NavigationBar(
          height: 68,
          backgroundColor: Colors.transparent,
          indicatorColor: colors.primaryContainer.withValues(
            alpha: 0.72 + (0.18 * glass.intensity),
          ),
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      ),
    );
    if (glass.blurSigma > 0) {
      bar = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: glass.blurSigma,
            sigmaY: glass.blurSigma,
          ),
          child: bar,
        ),
      );
    }
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: bar,
    );
  }
}

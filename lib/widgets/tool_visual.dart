import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/appearance_settings.dart';

enum ToolVisualKind {
  textAnalysis,
  termsAnalysis,
  allergyWatchlist,
  priceCheck,
  customInstructions,
}

class ToolVisual extends StatefulWidget {
  const ToolVisual({
    super.key,
    required this.kind,
    required this.colors,
    this.compact = false,
  });

  final ToolVisualKind kind;
  final List<Color> colors;
  final bool compact;

  @override
  State<ToolVisual> createState() => _ToolVisualState();
}

class _ToolVisualState extends State<ToolVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = Theme.of(context).extension<MotionStyle>()?.intensity ?? 0;
    if (motion == 0) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = Theme.of(context).extension<MotionStyle>()?.intensity ?? 0;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          key: ValueKey('tool-visual-${widget.kind.name}'),
          painter: _ToolVisualPainter(
            kind: widget.kind,
            colors: widget.colors,
            phase: motion == 0 ? 0 : _controller.value,
            motion: motion,
          ),
          size: Size.square(widget.compact ? 58 : 112),
        ),
      ),
    );
  }
}

class _ToolVisualPainter extends CustomPainter {
  const _ToolVisualPainter({
    required this.kind,
    required this.colors,
    required this.phase,
    required this.motion,
  });

  final ToolVisualKind kind;
  final List<Color> colors;
  final double phase;
  final double motion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final pulse = math.sin(phase * math.pi * 2) * motion;
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.first.withValues(alpha: 0.34),
          colors.last.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * .52));
    canvas.drawCircle(center, size.width * (.48 + pulse * .025), glow);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pulse * .035);
    canvas.translate(-center.dx, -center.dy);

    final prism = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: .92),
          colors.first.withValues(alpha: .86),
          colors.last.withValues(alpha: .72),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.8, size.width * .026)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final faint = Paint()
      ..color = Colors.white.withValues(alpha: .28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * .014)
      ..strokeCap = StrokeCap.round;

    switch (kind) {
      case ToolVisualKind.textAnalysis:
        _paintText(canvas, size, prism, faint, pulse);
      case ToolVisualKind.termsAnalysis:
        _paintTerms(canvas, size, prism, faint, pulse);
      case ToolVisualKind.allergyWatchlist:
        _paintWatchlist(canvas, size, prism, faint, pulse);
      case ToolVisualKind.priceCheck:
        _paintPriceCheck(canvas, size, prism, faint, pulse);
      case ToolVisualKind.customInstructions:
        _paintInstructions(canvas, size, prism, faint, pulse);
    }
    canvas.restore();
  }

  void _paintText(
    Canvas canvas,
    Size size,
    Paint prism,
    Paint faint,
    double pulse,
  ) {
    final page = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .29, size.height * .18, size.width * .48,
          size.height * .64),
      Radius.circular(size.width * .07),
    );
    canvas.drawRRect(page, prism);
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.34 + i * .105);
      canvas.drawLine(
        Offset(size.width * (i < 2 ? .18 : .25), y),
        Offset(size.width * ((i < 2 ? .55 : .48) + pulse * .018), y),
        faint,
      );
    }
    final crystal = Path()
      ..moveTo(size.width * .58, size.height * .36)
      ..lineTo(size.width * .85, size.height * .5)
      ..lineTo(size.width * .58, size.height * .64)
      ..lineTo(size.width * .48, size.height * .5)
      ..close();
    canvas.drawPath(crystal, prism);
  }

  void _paintTerms(
    Canvas canvas,
    Size size,
    Paint prism,
    Paint faint,
    double pulse,
  ) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * .18, size.height * .16, size.width * .5,
            size.height * .67),
        Radius.circular(size.width * .05),
      ),
      prism,
    );
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.31 + i * .13);
      canvas.drawLine(
        Offset(size.width * .28, y),
        Offset(size.width * (.57 + pulse * .012), y),
        faint,
      );
    }
    canvas.drawCircle(
      Offset(size.width * .67, size.height * .6),
      size.width * .18,
      prism,
    );
    canvas.drawLine(
      Offset(size.width * .79, size.height * .73),
      Offset(size.width * .9, size.height * .86),
      prism,
    );
  }

  void _paintWatchlist(
    Canvas canvas,
    Size size,
    Paint prism,
    Paint faint,
    double pulse,
  ) {
    final shield = Path()
      ..moveTo(size.width * .5, size.height * .12)
      ..quadraticBezierTo(size.width * .7, size.height * .23,
          size.width * .82, size.height * .24)
      ..lineTo(size.width * .77, size.height * .58)
      ..quadraticBezierTo(
          size.width * .72, size.height * .79, size.width * .5, size.height * .9)
      ..quadraticBezierTo(size.width * .28, size.height * .79,
          size.width * .23, size.height * .58)
      ..lineTo(size.width * .18, size.height * .24)
      ..quadraticBezierTo(
          size.width * .3, size.height * .23, size.width * .5, size.height * .12)
      ..close();
    canvas.drawPath(shield, prism);
    const particles = [
      Offset(.39, .45),
      Offset(.58, .38),
      Offset(.62, .59),
      Offset(.42, .65),
    ];
    for (var i = 0; i < particles.length; i++) {
      final point = particles[i];
      canvas.drawCircle(
        Offset(
          size.width * point.dx,
          size.height * (point.dy + pulse * .008 * (i.isEven ? 1 : -1)),
        ),
        size.width * (i.isEven ? .035 : .025),
        faint,
      );
    }
  }

  void _paintInstructions(
    Canvas canvas,
    Size size,
    Paint prism,
    Paint faint,
    double pulse,
  ) {
    final page = Path()
      ..moveTo(size.width * .25, size.height * .17)
      ..lineTo(size.width * .68, size.height * .17)
      ..lineTo(size.width * .78, size.height * .28)
      ..lineTo(size.width * .78, size.height * .82)
      ..lineTo(size.width * .25, size.height * .82)
      ..close();
    canvas.drawPath(page, prism);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.37 + i * .13);
      canvas.drawLine(
        Offset(size.width * .36, y),
        Offset(size.width * (.67 + pulse * .012), y),
        faint,
      );
    }
    final cursorX = size.width * (.48 + pulse * .025);
    canvas.drawLine(
      Offset(cursorX, size.height * .68),
      Offset(cursorX, size.height * .76),
      prism,
    );
  }

  void _paintPriceCheck(
    Canvas canvas,
    Size size,
    Paint prism,
    Paint faint,
    double pulse,
  ) {
    final tag = Path()
      ..moveTo(size.width * .18, size.height * .27)
      ..lineTo(size.width * .55, size.height * .14)
      ..lineTo(size.width * .84, size.height * .43)
      ..lineTo(size.width * .55, size.height * .78)
      ..lineTo(size.width * .2, size.height * .62)
      ..close();
    canvas.drawPath(tag, prism);
    canvas.drawCircle(
      Offset(size.width * .33, size.height * .38),
      size.width * .055,
      faint,
    );
    canvas.drawLine(
      Offset(size.width * .46, size.height * (.48 + pulse * .01)),
      Offset(size.width * .68, size.height * (.48 + pulse * .01)),
      prism,
    );
    canvas.drawLine(
      Offset(size.width * .57, size.height * .37),
      Offset(size.width * .57, size.height * .59),
      prism,
    );
  }

  @override
  bool shouldRepaint(covariant _ToolVisualPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.colors != colors ||
      oldDelegate.phase != phase ||
      oldDelegate.motion != motion;
}

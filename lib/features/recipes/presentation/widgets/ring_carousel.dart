import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/recipe.dart';

class RingCarousel extends StatefulWidget {
  final List<ImageProvider> images;
  final List<Recipe>? recipes;
  final ValueChanged<Recipe>? onTapRecipe;
  final Widget? bottomChild;
  final ValueChanged<double>? onProgressChanged;
  final Color borderColor;
  final double initialProgress;

  const RingCarousel({
    super.key,
    required this.images,
    this.recipes,
    this.onTapRecipe,
    this.bottomChild,
    this.onProgressChanged,
    this.borderColor = Colors.greenAccent,
    this.initialProgress = 0.0,
  });

  @override
  State<RingCarousel> createState() => RingCarouselState();
}

class RingCarouselState extends State<RingCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: widget.initialProgress,
  );
  final PageController _pc = PageController();

  double get progress => _t.value;

  void toggleRing() {
    final open = _t.value < 0.5;
    _t.animateTo(open ? 1.0 : 0.0, curve: Curves.easeOutCubic);
  }

  void openRing() {
    _t.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void closeRing() {
    _t.animateTo(0.0, curve: Curves.easeOutCubic);
  }

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      widget.onProgressChanged?.call(_t.value);
    });
  }

  @override
  void dispose() {
    _t.dispose();
    _pc.dispose();
    super.dispose();
  }

  void _onDrag(DragUpdateDetails d, double h) {
    _t.value = (_t.value + d.delta.dy / (h * 0.5)).clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final open = v > 300 || (v.abs() <= 300 && _t.value > 0.5);
    _t.animateTo(open ? 1.0 : 0.0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final W = constraints.maxWidth;
        final H = constraints.maxHeight;
        final n = widget.images.length;
        if (n == 0) return const SizedBox.shrink();
        final sheetH = H * 0.54;
        final R = math.min(W, H) * 0.28; // ring radius
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (d) => _onDrag(d, H),
          onVerticalDragEnd: _onDragEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: Listenable.merge([_t, _pc]),
                builder: (_, __) {
                  final t = Curves.easeInOut.transform(_t.value);
                  final page = _pc.hasClients && _pc.position.haveDimensions
                      ? (_pc.page ?? 0.0)
                      : 0.0;

                  // draw far cards first so near ones overlap correctly
                  final order = List.generate(n, (i) => i)
                    ..sort((a, b) => _depth(b, page, n).compareTo(_depth(a, page, n)));

                  return Stack(
                    children: [
                      for (final i in order)
                        _card(i, page, t, W, H, R, n),
                    ],
                  );
                },
              ),
              // invisible PageView: handles horizontal swipes while flat,
              // and rotates the ring when it's formed
              Positioned.fill(
                child: PageView(
                  controller: _pc,
                  children: List.generate(
                    n,
                    (i) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (widget.onTapRecipe != null &&
                            widget.recipes != null &&
                            i < widget.recipes!.length) {
                          widget.onTapRecipe!(widget.recipes![i]);
                        }
                      },
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              if (widget.bottomChild != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: sheetH,
                  child: AnimatedBuilder(
                    animation: _t,
                    builder: (context, _) {
                      final t = Curves.easeInOut.transform(_t.value);
                      if (t <= 0.01) return const SizedBox.shrink();
                      return Transform.translate(
                        offset: Offset(0, (1.0 - t) * sheetH),
                        child: Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: widget.bottomChild!,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  double _depth(int i, double page, int n) {
    final th = 2 * math.pi * (i - page) / n;
    return -math.cos(th); // top of ring (front) = smaller
  }

  Widget _card(int i, double page, double t, double W, double H, double R, int n) {
    final theta = 2 * math.pi * (i - page) / n;

    // size: full screen -> thin arc segment
    final segW = 2 * math.pi * R / n * 0.92;
    final w = lerpD(W, segW, t);
    final h = lerpD(H, R * 0.55, t);

    final dx = (i - page) * W * (1 - t); // flat carousel offset

    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // perspective
      ..translate(W / 2, lerpD(H / 2, H * 0.45, t))
      ..rotateX(1.0 * t) // whole ring tilts forward
      ..translate(dx, 0.0)
      ..rotateZ(theta * t) // place around the circle
      ..translate(0.0, -R * t) // push out to the radius
      ..rotateX(0.00 * t) // each block leans so tops meet
      ..translate(-w / 2, -h / 2);

    final recipe = (widget.recipes != null && i < widget.recipes!.length)
        ? widget.recipes![i]
        : null;

    return Transform(
      transform: m,
      child: SizedBox(
        width: w,
        height: h,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(lerpD(0, 14, t)),
            border: Border.all(
              color: widget.borderColor.withOpacity(t),
              width: 3 * t,
            ),
            image: DecorationImage(
              image: widget.images[i],
              fit: BoxFit.cover,
              onError: (_, __) {},
            ),
          ),
          child: (recipe != null && t < 0.35)
              ? Opacity(
                  opacity: (1.0 - t * 2.8).clamp(0.0, 1.0),
                  child: _buildFlatCardContent(recipe),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFlatCardContent(Recipe recipe) {
    final badge = recipe.primaryBadge ??
        (recipe.nutrition.proteinGrams != null && recipe.nutrition.proteinGrams! >= 25
            ? '💪 ${recipe.nutrition.proteinGrams!.toInt()}g Protein'
            : 'Chef Special');
    final calories = recipe.nutrition.calories?.toInt() ?? 0;
    final protein = recipe.nutrition.proteinGrams?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.25),
            Colors.transparent,
            const Color(0xFF0C0A09).withOpacity(0.95),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Bottom dish details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (calories > 0)
                    _macroPill('🔥 $calories kcal', const Color(0xFFFF6E2E)),
                  if (protein > 0)
                    _macroPill('💪 ${protein}g Protein', const Color(0xFF10B981)),
                  _macroPill('⏱ ${recipe.formattedTime}', const Color(0xFFFBBF24)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: Color(0xFFA8A29E), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap for recipe  •  Drag down for 3D Ring',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroPill(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1C19).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  double lerpD(double a, double b, double t) => a + (b - a) * t;
}

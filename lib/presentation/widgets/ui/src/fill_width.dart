import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Stretches its child to the full available width when [fill] is true and
/// the width is bounded; otherwise keeps the child's natural width.
///
/// Unlike `SizedBox(width: double.infinity)` it never throws in unbounded
/// contexts (a `Row` without `Expanded`), and unlike `LayoutBuilder` it
/// works inside intrinsic-size parents such as `AlertDialog`.
class FillWidthIfBounded extends SingleChildRenderObjectWidget {
  const FillWidthIfBounded({super.key, required this.fill, super.child});

  final bool fill;

  @override
  RenderFillWidthIfBounded createRenderObject(BuildContext context) =>
      RenderFillWidthIfBounded(fill: fill);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFillWidthIfBounded renderObject,
  ) {
    renderObject.fill = fill;
  }
}

class RenderFillWidthIfBounded extends RenderProxyBox {
  RenderFillWidthIfBounded({required bool fill}) : _fill = fill;

  bool _fill;
  bool get fill => _fill;
  set fill(bool value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsLayout();
  }

  BoxConstraints _childConstraints(BoxConstraints constraints, RenderBox child) {
    if (constraints.hasBoundedWidth) {
      return _fill ? constraints.tighten(width: constraints.maxWidth) : constraints;
    }
    // Unbounded: give the child exactly its natural width, so flexible
    // children (e.g. a label in a Row) still get a finite width.
    final natural = child.getMaxIntrinsicWidth(constraints.maxHeight);
    return BoxConstraints(
      minWidth: constraints.minWidth,
      maxWidth: math.max(natural, constraints.minWidth),
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints, child), parentUsesSize: true);
    size = constraints.constrain(child.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(_childConstraints(constraints, child)),
    );
  }
}

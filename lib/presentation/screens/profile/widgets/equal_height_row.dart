import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays [children] out side by side in equal-width slots and stretches each
/// one to the height of the tallest, so a row of tiles always lines up.
///
/// Unlike `IntrinsicHeight` + `Row`, this never asks children for intrinsic
/// sizes, so it works with any child (including ones built on
/// `LayoutBuilder`). Children are laid out once at their natural height,
/// then again with that row height as their minimum height; a child whose
/// content later grows re-triggers the measurement.
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({
    super.key,
    required super.children,
    this.spacing = 12,
  });

  /// Horizontal gap between slots.
  final double spacing;

  @override
  RenderEqualHeightRow createRenderObject(BuildContext context) {
    return RenderEqualHeightRow(
      spacing: spacing,
      textDirection: Directionality.of(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..textDirection = Directionality.of(context);
  }
}

/// Parent data for [RenderEqualHeightRow] children.
class EqualHeightRowParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object behind [EqualHeightRow].
class RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, EqualHeightRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, EqualHeightRowParentData> {
  RenderEqualHeightRow({
    required double spacing,
    required TextDirection textDirection,
  })  : _spacing = spacing,
        _textDirection = textDirection;

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! EqualHeightRowParentData) {
      child.parentData = EqualHeightRowParentData();
    }
  }

  double _slotWidth(double maxWidth) {
    if (childCount == 0) return 0;
    final available = maxWidth - spacing * (childCount - 1);
    return math.max(0.0, available / childCount);
  }

  @override
  void performLayout() {
    final constraints = this.constraints;
    assert(
      constraints.hasBoundedWidth,
      'EqualHeightRow needs a bounded width.',
    );
    final width = constraints.maxWidth;
    final slot = _slotWidth(width);

    // Pass 1: natural heights at the slot width.
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints.tightFor(width: slot), parentUsesSize: true);
      tallest = math.max(tallest, child.size.height);
      child = childAfter(child);
    }
    final height = constraints.constrainHeight(tallest);

    // Pass 2: every child at least as tall as the tallest one. The max
    // height stays open so a child is never a relayout boundary here and a
    // change in its content re-measures the whole row.
    final stretched = BoxConstraints(
      minWidth: slot,
      maxWidth: slot,
      minHeight: height,
    );
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      child.layout(stretched, parentUsesSize: true);
      final data = child.parentData! as EqualHeightRowParentData;
      final dx = textDirection == TextDirection.rtl ? width - x - slot : x;
      data.offset = Offset(dx, 0);
      x += slot + spacing;
      child = childAfter(child);
    }

    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth) return constraints.smallest;
    final slot = _slotWidth(constraints.maxWidth);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      final childSize =
          child.getDryLayout(BoxConstraints.tightFor(width: slot));
      tallest = math.max(tallest, childSize.height);
      child = childAfter(child);
    }
    return constraints.constrain(Size(constraints.maxWidth, tallest));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    final slot = _slotWidth(width);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      tallest = math.max(tallest, child.getMinIntrinsicHeight(slot));
      child = childAfter(child);
    }
    return tallest;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    final slot = _slotWidth(width);
    var tallest = 0.0;
    var child = firstChild;
    while (child != null) {
      tallest = math.max(tallest, child.getMaxIntrinsicHeight(slot));
      child = childAfter(child);
    }
    return tallest;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var widest = 0.0;
    var child = firstChild;
    while (child != null) {
      widest = math.max(widest, child.getMinIntrinsicWidth(height));
      child = childAfter(child);
    }
    return widest * childCount + spacing * math.max(0, childCount - 1);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var widest = 0.0;
    var child = firstChild;
    while (child != null) {
      widest = math.max(widest, child.getMaxIntrinsicWidth(height));
      child = childAfter(child);
    }
    return widest * childCount + spacing * math.max(0, childCount - 1);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToFirstActualBaseline(baseline);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

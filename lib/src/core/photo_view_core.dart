import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;
import 'package:photo_view/photo_view.dart'
    show
        PhotoViewScaleState,
        PhotoViewHeroAttributes,
        PhotoViewImageTapDownCallback,
        PhotoViewImageTapUpCallback,
        PhotoViewImageScaleEndCallback,
        ScaleStateCycle;
import 'package:photo_view/src/controller/photo_view_controller.dart';
import 'package:photo_view/src/controller/photo_view_controller_delegate.dart';
import 'package:photo_view/src/controller/photo_view_scalestate_controller.dart';
import 'package:photo_view/src/core/base_position.dart';
import 'package:photo_view/src/core/photo_view_gesture_detector.dart';
import 'package:photo_view/src/core/photo_view_hit_corners.dart';
import 'package:photo_view/src/photo_view_computed_scale.dart';
import 'package:photo_view/src/utils/photo_view_utils.dart';

const _defaultDecoration = const BoxDecoration(
  color: const Color.fromRGBO(0, 0, 0, 1.0),
);

/// Internal widget in which controls all animations lifecycle, core responses
/// to user gestures, updates to  the controller state and mounts the entire PhotoView Layout
class PhotoViewCore extends StatefulWidget {
  const PhotoViewCore({
    Key? key,
    required this.imageProvider,
    required this.backgroundDecoration,
    required this.semanticLabel,
    required this.gaplessPlayback,
    required this.heroAttributes,
    required this.enableRotation,
    required this.onTapUp,
    required this.onTapDown,
    required this.onScaleEnd,
    required this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.filterQuality,
    required this.disableGestures,
    required this.enablePanAlways,
    required this.strictScale,
    required this.initialScale,
    this.onCloseCallback,
    this.onOpacityChanged,
  })  : customChild = null,
        super(key: key);

  const PhotoViewCore.customChild({
    Key? key,
    required this.customChild,
    required this.backgroundDecoration,
    this.heroAttributes,
    required this.enableRotation,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
    this.gestureDetectorBehavior,
    required this.controller,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.scaleStateController,
    required this.basePosition,
    required this.tightMode,
    required this.filterQuality,
    required this.disableGestures,
    required this.enablePanAlways,
    required this.strictScale,
    required this.initialScale,
    this.onCloseCallback,
    this.onOpacityChanged,
  })  : imageProvider = null,
        semanticLabel = null,
        gaplessPlayback = false,
        super(key: key);

  final Decoration? backgroundDecoration;
  final ImageProvider? imageProvider;
  final String? semanticLabel;
  final bool? gaplessPlayback;
  final PhotoViewHeroAttributes? heroAttributes;
  final bool enableRotation;
  final Widget? customChild;

  final PhotoViewControllerBase controller;
  final PhotoViewScaleStateController scaleStateController;
  final ScaleBoundaries scaleBoundaries;
  final ScaleStateCycle scaleStateCycle;
  final Alignment basePosition;

  final PhotoViewImageTapUpCallback? onTapUp;
  final PhotoViewImageTapDownCallback? onTapDown;
  final PhotoViewImageScaleEndCallback? onScaleEnd;
  final Function()? onCloseCallback;
  final ValueChanged<double>? onOpacityChanged;

  final HitTestBehavior? gestureDetectorBehavior;
  final bool tightMode;
  final bool disableGestures;
  final bool enablePanAlways;
  final bool strictScale;
  final dynamic initialScale;

  final FilterQuality filterQuality;

  @override
  State<StatefulWidget> createState() {
    return PhotoViewCoreState();
  }

  bool get hasCustomChild => customChild != null;
}

class PhotoViewCoreState extends State<PhotoViewCore>
    with
        TickerProviderStateMixin,
        PhotoViewControllerDelegate,
        HitCornersDetector {
  Offset? _normalizedPosition;
  double? _scaleBefore;
  double? _rotationBefore;

  late final AnimationController _scaleAnimationController;
  Animation<double>? _scaleAnimation;

  late final AnimationController _positionAnimationController;
  Animation<Offset>? _positionAnimation;

  late final AnimationController _rotationAnimationController =
      AnimationController(vsync: this)..addListener(handleRotationAnimation);
  Animation<double>? _rotationAnimation;

  late final AnimationController _opacityAnimationController;
  Animation<double>? _opacityAnimation;

  PhotoViewHeroAttributes? get heroAttributes => widget.heroAttributes;

  late ScaleBoundaries cachedScaleBoundaries = widget.scaleBoundaries;

  void handleScaleAnimation() {
    scale = _scaleAnimation!.value;
  }

  void handlePositionAnimate() {
    controller.position = _positionAnimation!.value;
  }

  void handleRotationAnimation() {
    controller.rotation = _rotationAnimation!.value;
  }

  void handleOpacityAnimation() {
    opacity.value = _opacityAnimation!.value;
  }

  void onScaleStart(ScaleStartDetails details) {
    // isScrolling = false;
    // isDraging = false;
    _rotationBefore = controller.rotation;
    _scaleBefore = scale;
    _normalizedPosition = details.focalPoint - controller.position;
    _scaleAnimationController.stop();
    _positionAnimationController.stop();
    _rotationAnimationController.stop();
    _opacityAnimationController.stop();
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // debugPrint('onScaleUpdate: $details');

    // Offset offset = posOffset.value;
    // offset = Offset(offset.dx + details.focalPointDelta.dx,
    //     offset.dy + details.focalPointDelta.dy);
    // posOffset.value = offset;

    final double newScale = _scaleBefore! * details.scale;
    final Offset delta = details.focalPoint - _normalizedPosition!;

    if (widget.strictScale &&
        (newScale > widget.scaleBoundaries.maxScale ||
            newScale < widget.scaleBoundaries.minScale)) {
      return;
    }

    updateScaleStateFromNewScale(newScale);

    updateMultiple(
      scale: newScale,
      position: widget.enablePanAlways
          ? calOpacity(position: delta * details.scale)
          : clampPosition(position: delta * details.scale),
      rotation:
          widget.enableRotation ? _rotationBefore! + details.rotation : null,
      rotationFocusPoint: widget.enableRotation ? details.focalPoint : null,
    );
  }

  Timer? timer;

  void onScaleEnd(ScaleEndDetails details) {
    // debugPrint('onScaleEnd: $details');

    final double _scale = scale;
    Offset _position = controller.position;
    final double maxScale = scaleBoundaries.maxScale;
    final double minScale = scaleBoundaries.minScale;

    if (widget.enablePanAlways) {
      if (opacity.value <= 0.3) {
        animateOpacity(opacity.value, 0.0);
        widget.onCloseCallback?.call();
      } else {
        animateOpacity(opacity.value, 1.0);
        animatePosition(_position, clampPosition());
      }
    }

    widget.onScaleEnd?.call(context, details, controller.value);

    //animate back to maxScale if gesture exceeded the maxScale specified
    if (_scale > maxScale) {
      final double scaleComebackRatio = maxScale / _scale;
      animateScale(_scale, maxScale);
      final Offset clampedPosition = clampPosition(
        position: _position * scaleComebackRatio,
        scale: maxScale,
      );
      animatePosition(_position, clampedPosition);
      return;
    }

    //animate back to minScale if gesture fell smaller than the minScale specified
    if (_scale < minScale) {
      final double scaleComebackRatio = minScale / _scale;
      animateScale(_scale, minScale);
      animatePosition(
        _position,
        clampPosition(
          position: _position * scaleComebackRatio,
          scale: minScale,
        ),
      );
      return;
    }
    // get magnitude from gesture velocity
    final double magnitude = details.velocity.pixelsPerSecond.distance;

    // animate velocity only if there is no scale change and a significant magnitude
    if (_scaleBefore! / _scale == 1.0 && magnitude >= 400.0) {
      final Offset direction = details.velocity.pixelsPerSecond / magnitude;
      animatePosition(
        _position,
        clampPosition(position: _position + direction * 100.0),
      );
    }

    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 500), () {
      isScrolling = false;
      isDraging = false;
    });
  }

  void onDoubleTap(TapDownDetails details) {
    isScrolling = false;
    isDraging = false;
    if (widget.initialScale == PhotoViewComputedScale.adaptived) {
      final Size size = scaleBoundaries.outerSize;
      final Size childSize = scaleBoundaries.childSize;
      final double containedRaw = math.min(
          size.width / childSize.width, size.height / childSize.height);
      final double coveredRaw = math.max(
          size.width / childSize.width, size.height / childSize.height);
      final double contained = containedRaw.clamp(
          scaleBoundaries.minScale, scaleBoundaries.maxScale);
      final double covered =
          coveredRaw.clamp(scaleBoundaries.minScale, scaleBoundaries.maxScale);

      final double current = scale;
      final double target =
          (current - covered).abs() < 0.001 ? contained : covered;

      animateScale(current, target);
      animateRotation(controller.rotation, 0.0);

      final center = Offset(context.size!.width / 2, context.size!.height / 2);
      final tapPosition = details.localPosition;
      final toPosition =
          (controller.position + center - tapPosition) * target / current;
      animatePosition(controller.position, toPosition);
      return;
    }

    nextScaleState();

    final currentState = scaleStateController.scaleState;
    if (currentState != PhotoViewScaleState.initial) {
      final prevScaleState = scaleStateController.prevScaleState;
      final preScale = getScaleForScaleState(
        prevScaleState,
        scaleBoundaries,
      );
      final nextScale = getScaleForScaleState(
        currentState,
        scaleBoundaries,
      );
      final center = Offset(context.size!.width / 2, context.size!.height / 2);
      final tapPosition = details.localPosition;
      final toPosition =
          (controller.position + center - tapPosition) * nextScale / preScale;
      animatePosition(controller.position, toPosition);
    }
  }

  void animateScale(double from, double to) {
    _scaleAnimation = Tween<double>(
      begin: from,
      end: to,
    ).animate(_scaleAnimationController);
    _scaleAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animatePosition(Offset from, Offset to) {
    _positionAnimation = Tween<Offset>(begin: from, end: to)
        .animate(_positionAnimationController);
    _positionAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animateOpacity(double from, double to) {
    _opacityAnimation = Tween<double>(begin: from, end: to)
        .animate(_opacityAnimationController);
    _opacityAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void animateRotation(double from, double to) {
    _rotationAnimation = Tween<double>(begin: from, end: to)
        .animate(_rotationAnimationController);
    _rotationAnimationController
      ..value = 0.0
      ..fling(velocity: 0.4);
  }

  void onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      onAnimationStatusCompleted();
    }
  }

  /// Check if scale is equal to initial after scale animation update
  void onAnimationStatusCompleted() {
    if (scaleStateController.scaleState != PhotoViewScaleState.initial &&
        scale == scaleBoundaries.initialScale) {
      scaleStateController.setInvisibly(PhotoViewScaleState.initial);
    }
  }

  @override
  void initState() {
    super.initState();
    initDelegate();
    addAnimateOnScaleStateUpdate(animateOnScaleStateUpdate);

    cachedScaleBoundaries = widget.scaleBoundaries;

    _scaleAnimationController = AnimationController(vsync: this)
      ..addListener(handleScaleAnimation)
      ..addStatusListener(onAnimationStatus);
    _positionAnimationController = AnimationController(vsync: this)
      ..addListener(handlePositionAnimate);
    _opacityAnimationController = AnimationController(vsync: this)
      ..addListener(handleOpacityAnimation);
  }

  void animateOnScaleStateUpdate(double prevScale, double nextScale) {
    animateScale(prevScale, nextScale);
    animatePosition(controller.position, Offset.zero);
    animateRotation(controller.rotation, 0.0);
  }

  @override
  void dispose() {
    _scaleAnimationController.removeStatusListener(onAnimationStatus);
    _scaleAnimationController.dispose();
    _positionAnimationController.dispose();
    _opacityAnimationController.dispose();
    _rotationAnimationController.dispose();
    super.dispose();
  }

  void onTapUp(TapUpDetails details) {
    widget.onTapUp?.call(context, details, controller.value);
  }

  void onTapDown(TapDownDetails details) {
    widget.onTapDown?.call(context, details, controller.value);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need a recalc on the scale
    if (widget.scaleBoundaries != cachedScaleBoundaries) {
      markNeedsScaleRecalc = true;
      cachedScaleBoundaries = widget.scaleBoundaries;
    }

    return StreamBuilder(
        stream: controller.outputStateStream,
        initialData: controller.prevValue,
        builder: (
          BuildContext context,
          AsyncSnapshot<PhotoViewControllerValue> snapshot,
        ) {
          if (snapshot.hasData) {
            final PhotoViewControllerValue value = snapshot.data!;
            final useImageScale = widget.filterQuality != FilterQuality.none;

            final computedScale = useImageScale ? 1.0 : scale;

            final matrix = Matrix4.identity()
              ..translate(value.position.dx, value.position.dy)
              ..scale(computedScale)
              ..rotateZ(value.rotation);

            final Widget customChildLayout = CustomSingleChildLayout(
              delegate: _CenterWithOriginalSizeDelegate(
                scaleBoundaries.childSize,
                basePosition,
                useImageScale,
                widget.initialScale,
              ),
              child: _buildHero(),
            );

            final child = Container(
              constraints: widget.tightMode
                  ? BoxConstraints.tight(scaleBoundaries.childSize * scale)
                  : null,
              // child: Center(
              //   child: Transform(
              //     child: customChildLayout,
              //     transform: matrix,
              //     alignment: calTransformAlignment(),
              //   ),
              // ),
              child: ValueListenableBuilder<double>(
                valueListenable: opacity,
                builder: (context, opacity, child) {
                  return Container(
                    decoration: widget.enablePanAlways
                        ? null
                        : widget.backgroundDecoration ?? _defaultDecoration,
                    color: !widget.enablePanAlways ||
                            widget.onOpacityChanged == null
                        ? null
                        : Colors.black.withOpacity(opacity),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * opacity,
                      alignment: Alignment.center,
                      child: child,
                    ),
                  );
                },
                child: Center(
                  child: Transform(
                    child: customChildLayout,
                    transform: matrix,
                    alignment: calTransformAlignment(),
                  ),
                ),
              ),
              // decoration: widget.backgroundDecoration ?? _defaultDecoration,
            );

            if (widget.disableGestures) {
              return child;
            }

            return PhotoViewGestureDetector(
              child: child,
              onDoubleTap: onDoubleTap,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onScaleEnd: onScaleEnd,
              hitDetector: this,
              onTapUp: widget.onTapUp != null
                  ? (details) => widget.onTapUp!(context, details, value)
                  : null,
              onTapDown: widget.onTapDown != null
                  ? (details) => widget.onTapDown!(context, details, value)
                  : null,
            );
          } else {
            return Container();
          }
        });
  }

  Alignment calTransformAlignment() {
    if (widget.initialScale == PhotoViewComputedScale.adaptived) {
      final Size size = scaleBoundaries.outerSize;
      final Size childSize = scaleBoundaries.childSize;
      final double deviceRatio = size.width / size.height;
      final double picRatio = childSize.width / childSize.height;
      return deviceRatio > picRatio ? Alignment.topCenter : Alignment.center;
    } else {
      return basePosition;
    }
  }

  Widget _buildHero() {
    return heroAttributes != null
        ? Hero(
            tag: heroAttributes!.tag,
            createRectTween: heroAttributes!.createRectTween,
            flightShuttleBuilder: heroAttributes!.flightShuttleBuilder,
            placeholderBuilder: heroAttributes!.placeholderBuilder,
            transitionOnUserGestures: heroAttributes!.transitionOnUserGestures,
            child: _buildChild(),
          )
        : _buildChild();
  }

  Widget _buildChild() {
    return widget.hasCustomChild
        ? widget.customChild!
        : Image(
            image: widget.imageProvider!,
            semanticLabel: widget.semanticLabel,
            gaplessPlayback: widget.gaplessPlayback ?? false,
            filterQuality: widget.filterQuality,
            width: scaleBoundaries.childSize.width * scale,
            fit: BoxFit.contain,
          );
  }
}

class _CenterWithOriginalSizeDelegate extends SingleChildLayoutDelegate {
  const _CenterWithOriginalSizeDelegate(
    this.subjectSize,
    this.basePosition,
    this.useImageScale,
    this.initialScale,
  );

  final Size subjectSize;
  final Alignment basePosition;
  final bool useImageScale;
  final dynamic initialScale;

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final deviceRatio = size.width / size.height;
    final picRatio = childSize.width / childSize.height;
    if (initialScale == PhotoViewComputedScale.adaptived) {
      Alignment position;
      if (deviceRatio > picRatio) {
        position = Alignment.topCenter;
      } else {
        position = Alignment.center;
      }
      final childWidth = useImageScale ? childSize.width : subjectSize.width;
      final childHeight = useImageScale ? childSize.height : subjectSize.height;
      final halfWidth = (size.width - childWidth) / 2;
      final halfHeight = (size.height - childHeight) / 2;
      final double offsetX = halfWidth * (position.x + 1);
      final double offsetY = halfHeight * (position.y + 1);
      // debugPrint(
      //     'initialScale: ${initialScale}, subjectSize: $subjectSize, childSize: $childSize, offsetY: $offsetY');
      return Offset(offsetX, offsetY);
    } else {
      final childWidth = useImageScale ? childSize.width : subjectSize.width;
      final childHeight = useImageScale ? childSize.height : subjectSize.height;

      final halfWidth = (size.width - childWidth) / 2;
      final halfHeight = (size.height - childHeight) / 2;

      final double offsetX = halfWidth * (basePosition.x + 1);
      final double offsetY = halfHeight * (basePosition.y + 1);
      // debugPrint(
      //     'initialScale: ${initialScale}, subjectSize: $subjectSize, childSize: $childSize, offsetY: $offsetY');
      return Offset(offsetX, offsetY);
    }
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return useImageScale
        ? const BoxConstraints()
        : BoxConstraints.tight(subjectSize);
  }

  @override
  bool shouldRelayout(_CenterWithOriginalSizeDelegate oldDelegate) {
    return oldDelegate != this;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CenterWithOriginalSizeDelegate &&
          runtimeType == other.runtimeType &&
          subjectSize == other.subjectSize &&
          basePosition == other.basePosition &&
          useImageScale == other.useImageScale;

  @override
  int get hashCode =>
      subjectSize.hashCode ^ basePosition.hashCode ^ useImageScale.hashCode;
}

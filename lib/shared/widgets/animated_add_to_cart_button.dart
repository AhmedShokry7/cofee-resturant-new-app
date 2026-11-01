import 'dart:async';

import 'package:flutter/material.dart';

import 'package:new_coffee/core/theme/app_icons.dart';
import 'package:new_coffee/core/locale/app_strings.dart';
import 'package:new_coffee/core/theme/app_color.dart';
import 'package:new_coffee/core/theme/typography.dart';
import 'package:new_coffee/shared/widgets/custom_btn.dart';
import 'package:new_coffee/core/theme/tokens.dart';

/// Phase of one add-to-cart run, reflected inside the button itself.
enum _AddToCartStatus { idle, adding, added, error }

/// Shortest time the "Adding" phase stays on screen. The cart operation is
/// local and synchronous, so this only paces the animation; the success state
/// is still entered only after [onAdd] completes without throwing.
const _addingHold = Duration(milliseconds: 600);
const _successHold = Duration(milliseconds: 1600);
const _errorHold = Duration(milliseconds: 1000);
const _transitionDuration = Duration(milliseconds: 280);
const _contentDuration = Duration(milliseconds: 220);

/// Shared tap logic for the labeled and compact add-to-cart controls.
///
/// Guards against repeated submissions, reflects the real result of [onAdd],
/// and never leaves the control stuck: a failure restores the idle state after
/// a short error state and reports through [onAddError] (or a SnackBar).
mixin _AddToCartInteraction<T extends StatefulWidget> on State<T> {
  Future<void> Function() get onAdd;
  bool get addEnabled;
  VoidCallback? get onAddSuccess;
  void Function(Object error)? get onAddError;

  _AddToCartStatus _status = _AddToCartStatus.idle;

  final List<Timer> _timers = [];

  _AddToCartStatus get status => _status;

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  /// Cancellable delay so a disposed button never leaves a timer pending.
  Future<void> _delay(Duration duration) {
    if (duration <= Duration.zero) return Future<void>.value();
    final completer = Completer<void>();
    _timers.add(
      Timer(duration, () {
        if (!completer.isCompleted) completer.complete();
      }),
    );
    return completer.future;
  }

  Future<void> handleAddToCartTap() async {
    if (_status != _AddToCartStatus.idle || !addEnabled) return;

    setState(() => _status = _AddToCartStatus.adding);
    final stopwatch = Stopwatch()..start();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    try {
      await onAdd();

      final remaining = _addingHold - stopwatch.elapsed;
      if (!reduceMotion && remaining > Duration.zero) {
        await _delay(remaining);
      }
      if (!mounted || _status != _AddToCartStatus.adding) return;

      setState(() => _status = _AddToCartStatus.added);
      onAddSuccess?.call();

      await _delay(_successHold);
      if (mounted && _status == _AddToCartStatus.added) {
        setState(() => _status = _AddToCartStatus.idle);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _AddToCartStatus.error);

      final handler = onAddError;
      if (handler != null) {
        handler(error);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.failedToAddToCart)));
      }

      await _delay(_errorHold);
      if (mounted && _status == _AddToCartStatus.error) {
        setState(() => _status = _AddToCartStatus.idle);
      }
    }
  }
}

/// Full-width "Add to Cart" button with an in-place success animation.
///
/// Reuses [CustomBtn]'s primary gradient, radius and typography so the idle
/// button is visually identical to the previous one; only the feedback after
/// a tap changes.
class AnimatedAddToCartButton extends StatefulWidget {
  const AnimatedAddToCartButton({
    super.key,
    required this.onAdd,
    required this.label,
    this.enabled = true,
    this.onSuccess,
    this.onError,
  });

  final Future<void> Function() onAdd;
  final String label;
  final bool enabled;
  final VoidCallback? onSuccess;
  final void Function(Object error)? onError;

  @override
  State<AnimatedAddToCartButton> createState() =>
      _AnimatedAddToCartButtonState();
}

class _AnimatedAddToCartButtonState extends State<AnimatedAddToCartButton>
    with _AddToCartInteraction<AnimatedAddToCartButton> {
  @override
  Future<void> Function() get onAdd => widget.onAdd;

  @override
  bool get addEnabled => widget.enabled;

  @override
  VoidCallback? get onAddSuccess => widget.onSuccess;

  @override
  void Function(Object error)? get onAddError => widget.onError;

  @override
  Widget build(BuildContext context) => _AddToCartButtonVisual(
    status: status,
    enabled: widget.enabled,
    label: widget.label,
    onTap: handleAddToCartTap,
  );
}

/// Circular add-to-cart icon used by product cards and the assistant.
///
/// Same contract as [AnimatedAddToCartButton], without the label.
class AnimatedAddToCartIconButton extends StatefulWidget {
  const AnimatedAddToCartIconButton({
    super.key,
    required this.onAdd,
    this.size = AppDimensions.addToCartButtonCard,
    this.enabled = true,
    this.onSuccess,
    this.onError,
  });

  final Future<void> Function() onAdd;
  final double size;
  final bool enabled;
  final VoidCallback? onSuccess;
  final void Function(Object error)? onError;

  @override
  State<AnimatedAddToCartIconButton> createState() =>
      _AnimatedAddToCartIconButtonState();
}

class _AnimatedAddToCartIconButtonState
    extends State<AnimatedAddToCartIconButton>
    with _AddToCartInteraction<AnimatedAddToCartIconButton> {
  @override
  Future<void> Function() get onAdd => widget.onAdd;

  @override
  bool get addEnabled => widget.enabled;

  @override
  VoidCallback? get onAddSuccess => widget.onSuccess;

  @override
  void Function(Object error)? get onAddError => widget.onError;

  @override
  Widget build(BuildContext context) => _AddToCartButtonVisual(
    status: status,
    enabled: widget.enabled,
    label: '',
    compact: true,
    size: widget.size,
    onTap: handleAddToCartTap,
  );
}

class _AddToCartButtonVisual extends StatelessWidget {
  const _AddToCartButtonVisual({
    required this.status,
    required this.enabled,
    required this.label,
    required this.onTap,
    this.compact = false,
    this.size,
  });

  final _AddToCartStatus status;
  final bool enabled;
  final String label;
  final VoidCallback onTap;
  final bool compact;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : _transitionDuration;
    final iconSize = compact ? (size ?? AppSizes.px36) * 0.5 : AppSizes.px20;
    final idleIcon = compact ? AppIcons.add : AppIcons.cart;

    final BoxDecoration decoration;
    if (!enabled) {
      decoration = BoxDecoration(
        color: AppColor.primaryColor.withValues(alpha: 0.5),
        borderRadius: _radius,
      );
    } else if (status == _AddToCartStatus.added) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColor.successColorDeep, AppColor.successColor],
        ),
        borderRadius: _radius,
      );
    } else if (status == _AddToCartStatus.error) {
      decoration = BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColor.errorColorDeep, AppColor.errorColor],
        ),
        borderRadius: _radius,
      );
    } else {
      decoration = BoxDecoration(
        gradient: CustomBtn.primaryGradient,
        borderRadius: _radius,
      );
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: compact ? (size ?? AppSizes.px36) : double.infinity,
        height: compact ? (size ?? AppSizes.px36) : AppDimensions.buttonHeight,
        decoration: decoration,
        child: Center(
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : _contentDuration,
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.72, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: _buildContent(context, iconSize, idleIcon),
          ),
        ),
      ),
    );
  }

  BorderRadius get _radius => compact
      ? const BorderRadius.all(Radius.circular(999))
      : BorderRadius.circular(AppRadius.r14);

  Widget _buildContent(
    BuildContext context,
    double iconSize,
    IconData idleIcon,
  ) {
    final color = AppColor.whiteColor;
    final textStyle = AppFonts.semiBold16(context).copyWith(color: color);

    // Every phase renders the same row; only the key, the glyph and the words
    // differ, so the differences are what the switch has to say.
    final ({String key, IconData icon, String text}) phase = switch (status) {
      _AddToCartStatus.adding => (
        key: 'adding',
        icon: idleIcon,
        text: S.adding,
      ),
      _AddToCartStatus.added => (
        key: 'added',
        icon: AppIcons.checkmarkCircle,
        text: S.added,
      ),
      _AddToCartStatus.error => (
        key: 'error',
        icon: AppIcons.alertCircle,
        text: label,
      ),
      _AddToCartStatus.idle => (key: 'idle', icon: idleIcon, text: label),
    };

    return Row(
      key: ValueKey(phase.key),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == _AddToCartStatus.adding)
          _AddingIcon(icon: phase.icon, size: iconSize, color: color)
        else
          Icon(phase.icon, size: iconSize, color: color),
        if (!compact) ...[
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              phase.text,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

/// One-shot "item dropping into the cart" movement, reused for the adding
/// phase of both button sizes. Respects reduced-motion by skipping the tween.
class _AddingIcon extends StatelessWidget {
  const _AddingIcon({
    required this.icon,
    required this.size,
    required this.color,
  });

  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : _addingHold,
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, -6 * (1 - t)),
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: Icon(icon, size: size, color: color),
    );
  }
}

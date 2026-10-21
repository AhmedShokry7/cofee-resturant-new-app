import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:new_coffee/shared/widgets/db_image.dart';
import 'package:new_coffee/shared/widgets/shimmer/shimmer.dart';

/// Renders a subscription plan picture in full, without cropping it.
///
/// The picture keeps its own aspect ratio: the width fills the space handed
/// to the widget and the height follows the image, capped by [maxHeight] so a
/// very tall picture cannot push the rest of the page off the screen.
class SubscriptionPlanImage extends StatefulWidget {
  const SubscriptionPlanImage({
    super.key,
    required this.imageUrl,
    this.maxHeight = 320,
  });

  /// Raw value from the database column: an http(s) URL or a bundled asset
  /// path.
  final String imageUrl;

  /// Upper bound for the rendered height.
  final double maxHeight;

  @override
  State<SubscriptionPlanImage> createState() => _SubscriptionPlanImageState();
}

class _SubscriptionPlanImageState extends State<SubscriptionPlanImage> {
  /// Width over height of the source picture, known once the bytes land.
  double? _ratio;

  /// Set when the picture cannot be read at all.
  bool _failed = false;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// The picture is resolved once, the first time the dependencies are ready.
  bool _resolved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The image configuration needs the inherited widgets, so the picture is
    // resolved here and not in initState.
    if (_resolved) return;
    _resolved = true;
    _resolveRatio();
  }

  @override
  void didUpdateWidget(covariant SubscriptionPlanImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _releaseStream();
      setState(() {
        _ratio = null;
        _failed = false;
      });
      _resolveRatio();
    }
  }

  @override
  void dispose() {
    _releaseStream();
    super.dispose();
  }

  void _releaseStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  ImageProvider? _providerFor(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CachedNetworkImageProvider(trimmed);
    }
    return AssetImage(trimmed);
  }

  void _resolveRatio() {
    final provider = _providerFor(widget.imageUrl);
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _ratio = info.image.width / info.image.height);
      },
      onError: (object, stackTrace) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        if (width <= 0) return const SizedBox.shrink();

        final ratio = _ratio;
        if (ratio == null || ratio <= 0) {
          // The picture is still loading (or unreadable): hold a stable box so
          // the page does not jump once the real size arrives.
          final height = math.min(widget.maxHeight, width);
          return _frame(
            height: height,
            child: _failed
                ? DbImage(
                    image: widget.imageUrl,
                    fit: BoxFit.contain,
                    width: width,
                    height: height,
                  )
                : Shimmer(child: ShimmerBox(width: width, height: height)),
          );
        }

        final height = math.min(widget.maxHeight, width / ratio);
        return _frame(
          height: height,
          child: DbImage(
            image: widget.imageUrl,
            fit: BoxFit.contain,
            width: width,
            height: height,
          ),
        );
      },
    );
  }

  Widget _frame({required double height, required Widget child}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(width: double.infinity, height: height, child: child),
      );
}

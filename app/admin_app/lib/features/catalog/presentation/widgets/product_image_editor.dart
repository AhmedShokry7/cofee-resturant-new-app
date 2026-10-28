import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';

/// Editor state snapshot for undo/redo
class _EditorState {
  const _EditorState({
    required this.crop,
    required this.scale,
    required this.offset,
    required this.rotation,
    required this.aspect,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.exposure,
    required this.highlights,
    required this.shadows,
    required this.warmth,
    required this.sharpness,
    required this.filter,
    required this.filterIntensity,
    required this.flipHorizontal,
    required this.flipVertical,
  });

  final Rect crop;
  final double scale;
  final Offset offset;
  final double rotation;
  final ImageAspectPreset aspect;
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double highlights;
  final double shadows;
  final double warmth;
  final double sharpness;
  final String filter;
  final double filterIntensity;
  final bool flipHorizontal;
  final bool flipVertical;
}

/// The shapes the picture can be cut in.
enum ImageAspectPreset {
  original('original'),
  square('1:1'),
  landscape('4:3'),
  portrait('3:4'),
  wide('16:9');

  const ImageAspectPreset(this.label);

  final String label;

  /// The ratio of the shape, or null for the shape of the picture itself.
  double? get ratio {
    switch (this) {
      case ImageAspectPreset.original:
        return null;
      case ImageAspectPreset.square:
        return 1;
      case ImageAspectPreset.landscape:
        return 4 / 3;
      case ImageAspectPreset.portrait:
        return 3 / 4;
      case ImageAspectPreset.wide:
        return 16 / 9;
    }
  }
}

/// The result of the editor: the new file and the picture it belongs to.
///
/// The file is only produced when the admin saves, so the picture that is
/// already saved is never touched before the new one is ready.
class ImageEditResult {
  const ImageEditResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Cuts and turns a picture, and encodes the result again.
///
/// The work is done on the real file, not only on the preview: the result is
/// a new picture that carries the cut and the turn of the admin. The picture
/// that is already saved is not touched here.
Uint8List processImageBytes(
  Uint8List bytes, {
  Rect? crop,
  double rotation = 0,
  double scale = 1,
  // Adjustments
  double brightness = 1.0,
  double contrast = 1.0,
  double saturation = 1.0,
  double exposure = 0.0,
  double highlights = 0.0,
  double shadows = 0.0,
  double warmth = 0.0,
  double sharpness = 0.0,
  // Filters
  String filter = 'none',
  double filterIntensity = 1.0,
}) {
  final original = img.decodeImage(bytes);
  if (original == null) {
    throw FormatException(S.imageCouldNotBeRead);
  }

  var picture = original;
  if (rotation != 0) {
    picture = img.copyRotate(picture, angle: rotation.round());
  }

  var cropped = picture;
  if (crop != null) {
    final left = crop.left.round().clamp(0, picture.width - 1);
    final top = crop.top.round().clamp(0, picture.height - 1);
    final width = crop.width.round().clamp(1, picture.width - left);
    final height = crop.height.round().clamp(1, picture.height - top);
    cropped = img.copyCrop(
      picture,
      x: left,
      y: top,
      width: width,
      height: height,
    );
  }

  if (scale != 1) {
    cropped = img.copyResize(
      cropped,
      width: (cropped.width * scale).round().clamp(1, 4000),
      height: (cropped.height * scale).round().clamp(1, 4000),
      interpolation: img.Interpolation.average,
    );
  }

  // Apply adjustments using the image package's adjustColor
  if (brightness != 1.0 ||
      contrast != 1.0 ||
      saturation != 1.0 ||
      exposure != 0.0 ||
      highlights != 0.0 ||
      shadows != 0.0 ||
      warmth != 0.0) {
    cropped = img.adjustColor(
      cropped,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
      exposure: exposure,
      // The image package uses hue for warmth/temperature
      // Positive warmth = warmer (orange), negative = cooler (blue)
      hue: warmth * 30, // Scale warmth to reasonable degrees
      // Apply highlights and shadows via gamma approximation
      gamma: (highlights - shadows).clamp(-0.5, 0.5) + 1.0,
    );
  }

  // Apply sharpness
  if (sharpness > 0) {
    cropped = img.convolution(
      cropped,
      filter: [0, -1, 0, -1, 4 + sharpness * 4, -1, 0, -1, 0],
      div: 1.0 + sharpness,
    );
  }

  // Apply filter presets
  switch (filter) {
    case 'vivid':
      cropped = img.adjustColor(
        cropped,
        saturation: 1.3,
        contrast: 1.15,
        amount: filterIntensity,
      );
      break;
    case 'warm':
      cropped = img.adjustColor(
        cropped,
        hue: 30,
        saturation: 1.1,
        amount: filterIntensity,
      );
      break;
    case 'cool':
      cropped = img.adjustColor(
        cropped,
        hue: -30,
        saturation: 1.05,
        amount: filterIntensity,
      );
      break;
    case 'vintage':
      cropped = img.sepia(cropped, amount: 0.6 * filterIntensity);
      cropped = img.adjustColor(
        cropped,
        contrast: 0.9,
        saturation: 0.8,
        amount: filterIntensity,
      );
      break;
    case 'bw':
    case 'blackwhite':
      cropped = img.grayscale(cropped, amount: filterIntensity);
      cropped = img.adjustColor(
        cropped,
        contrast: 1.2,
        amount: filterIntensity,
      );
      break;
    case 'bleach':
      cropped = img.bleachBypass(cropped, amount: filterIntensity);
      break;
    case 'sketch':
      cropped = img.sketch(cropped, amount: filterIntensity);
      break;
    case 'vignette':
      cropped = img.vignette(cropped, amount: 0.7 * filterIntensity);
      break;
    case 'original':
    case 'none':
    default:
      break;
  }

  return Uint8List.fromList(img.encodePng(cropped, level: 6));
}

/// The editor of one picture of a product.
///
/// The admin can cut the picture, turn it, zoom it and move it inside the
/// frame, and can see the result before saving. Nothing is written until the
/// admin saves: the file of the picture stays as it is until then.
class ProductImageEditor extends StatefulWidget {
  const ProductImageEditor({
    super.key,
    required this.imageUrl,
    required this.fileName,
    this.onSave,
  });

  /// The picture that is edited.
  final String imageUrl;

  /// The name of the file, used for the file that is written.
  final String fileName;

  /// Saves the result. When it is null the editor only previews.
  final Future<void> Function(ImageEditResult result)? onSave;

  @override
  State<ProductImageEditor> createState() => _ProductImageEditorState();
}

class _ProductImageEditorState extends State<ProductImageEditor> {
  /// The picture as it is now, before the changes of the admin.
  img.Image? _original;

  /// A small copy of the picture, made once when it was opened.
  ///
  /// The canvas is painted again on every move of the frame: encoding the
  /// whole picture on every one of those paints is what stopped the panel.
  Uint8List? _previewBytes;

  /// The size of the picture as it is now.
  Size _imageSize = Size.zero;

  /// The frame of the cut, in the coordinates of the picture.
  Rect _crop = Rect.zero;

  /// How much the picture is zoomed in.
  double _scale = 1;

  /// Where the picture sits inside the frame.
  Offset _offset = Offset.zero;

  /// How much the picture is turned, in degrees.
  double _rotation = 0;

  ImageAspectPreset _aspect = ImageAspectPreset.original;

  /// Adjustment state
  double _brightness = 1.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _exposure = 0.0;
  double _highlights = 0.0;
  double _shadows = 0.0;
  double _warmth = 0.0;
  double _sharpness = 0.0;

  /// Filter state
  String _filter = 'none';
  double _filterIntensity = 1.0;

  /// Flip state
  bool _isFlipHorizontal = false;
  bool _isFlipVertical = false;

  /// UI state
  bool _showAdjustments = false;
  bool _showFilters = false;
  bool _showBeforeAfter = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// History for undo/redo
  final List<_EditorState> _history = [];
  int _historyIndex = -1;
  static const int _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _readBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw FormatException(S.imageCouldNotBeRead);
      }
      final preview = _previewOf(decoded);
      if (!mounted) return;
      setState(() {
        _original = decoded;
        _previewBytes = preview;
        _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());
        _crop = Rect.fromLTWH(
          0,
          0,
          decoded.width.toDouble(),
          decoded.height.toDouble(),
        );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = S.imageCouldNotBeOpened;
      });
    }
  }

  Future<Uint8List> _readBytes() async {
    final response = await http.get(Uri.parse(widget.imageUrl));
    if (response.statusCode != 200) {
      throw StateError(S.imageCouldNotBeRead);
    }
    return response.bodyBytes;
  }

  /// The copy the canvas paints, at the size a preview is shown in.
  ///
  /// The cut and the turn are still done on the real file when the admin
  /// saves: this copy only shows the picture while it is being framed.
  Uint8List _previewOf(img.Image picture) {
    final edge = AppDimensions.imagePreviewCacheWidth.round();
    final scaled = picture.width > edge
        ? img.copyResize(
            picture,
            width: edge,
            interpolation: img.Interpolation.average,
          )
        : picture;
    return Uint8List.fromList(img.encodeJpg(scaled, quality: 90));
  }

  /// The frame of the cut, in the coordinates of the picture.
  Rect get _frame {
    final ratio = _aspect.ratio;
    if (ratio == null || _imageSize.isEmpty) return _crop;

    final width = _crop.width;
    final height = width / ratio;
    if (height <= _imageSize.height) {
      return Rect.fromLTWH(_crop.left, _crop.top, width, height);
    }
    final newHeight = _imageSize.height;
    final newWidth = newHeight * ratio;
    return Rect.fromLTWH(_crop.left, _crop.top, newWidth, newHeight);
  }

  /// Puts the picture back the way it was.
  void _reset() {
    if (_original == null) return;
    setState(() {
      _crop = Rect.fromLTWH(
        0,
        0,
        _original!.width.toDouble(),
        _original!.height.toDouble(),
      );
      _scale = 1;
      _offset = Offset.zero;
      _rotation = 0;
      _aspect = ImageAspectPreset.original;
      _brightness = 1.0;
      _contrast = 1.0;
      _saturation = 1.0;
      _exposure = 0.0;
      _highlights = 0.0;
      _shadows = 0.0;
      _warmth = 0.0;
      _sharpness = 0.0;
      _filter = 'none';
      _filterIntensity = 1.0;
      _clearHistory();
    });
  }

  /// Turns the picture a quarter of a turn.
  void _rotate() {
    _saveToHistory();
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  void _flipHorizontal() {
    _saveToHistory();
    setState(() {
      _isFlipHorizontal = !_isFlipHorizontal;
    });
  }

  void _flipVertical() {
    _saveToHistory();
    setState(() {
      _isFlipVertical = !_isFlipVertical;
    });
  }

  void _clearHistory() {
    _history.clear();
    _historyIndex = -1;
  }

  void _saveToHistory() {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(
      _EditorState(
        crop: _crop,
        scale: _scale,
        offset: _offset,
        rotation: _rotation,
        aspect: _aspect,
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        exposure: _exposure,
        highlights: _highlights,
        shadows: _shadows,
        warmth: _warmth,
        sharpness: _sharpness,
        filter: _filter,
        filterIntensity: _filterIntensity,
        flipHorizontal: _isFlipHorizontal,
        flipVertical: _isFlipVertical,
      ),
    );
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    _restoreFromHistory();
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    _restoreFromHistory();
  }

  void _restoreFromHistory() {
    if (_historyIndex < 0 || _historyIndex >= _history.length) return;
    final state = _history[_historyIndex];
    setState(() {
      _crop = state.crop;
      _scale = state.scale;
      _offset = state.offset;
      _rotation = state.rotation;
      _aspect = state.aspect;
      _brightness = state.brightness;
      _contrast = state.contrast;
      _saturation = state.saturation;
      _exposure = state.exposure;
      _highlights = state.highlights;
      _shadows = state.shadows;
      _warmth = state.warmth;
      _sharpness = state.sharpness;
      _filter = state.filter;
      _filterIntensity = state.filterIntensity;
      _isFlipHorizontal = state.flipHorizontal;
      _isFlipVertical = state.flipVertical;
    });
  }

  bool _canUndo() => _historyIndex > 0;
  bool _canRedo() => _historyIndex < _history.length - 1;

  /// Cuts the picture and writes the result.
  Future<void> _save() async {
    if (_saving || _original == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final bytes = await _process();
      final onSave = widget.onSave;
      if (onSave != null) {
        await onSave(ImageEditResult(bytes: bytes, fileName: widget.fileName));
      }
      if (!mounted) return;
      setState(() => _saving = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = S.imageCouldNotBeSaved;
      });
    }
  }

  /// The real work: the picture is cut and turned, and the result is
  /// encoded again.
  Future<Uint8List> _process() async {
    return processImageBytes(
      await _readBytes(),
      crop: _frame,
      rotation: _rotation,
      scale: _scale,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      exposure: _exposure,
      highlights: _highlights,
      shadows: _shadows,
      warmth: _warmth,
      sharpness: _sharpness,
      filter: _filter,
      filterIntensity: _filterIntensity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isNarrow = size.width < AppBreakpoints.imageWorkspace;

    return AlertDialog(
      title: Text(S.editImage),
      content: SizedBox(
        width: isNarrow ? size.width - 32 : 760,
        height: isNarrow ? size.height * 0.7 : 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColor.errorColor,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: AppDimensions.spinnerSizeLg,
                        height: AppDimensions.spinnerSizeLg,
                        child: CircularProgressIndicator(
                          strokeWidth: AppDimensions.spinnerStroke,
                          color: AppColor.primaryColor,
                        ),
                      ),
                    )
                  : _previewBytes == null
                  ? const SizedBox.shrink()
                  : _EditorCanvas(
                      previewBytes: _previewBytes!,
                      imageSize: _imageSize,
                      crop: _crop,
                      frame: _frame,
                      scale: _scale,
                      offset: _offset,
                      rotation: _rotation,
                      onCropChanged: (value) => setState(() => _crop = value),
                      onScaleChanged: (value) => setState(() => _scale = value),
                      onOffsetChanged: (value) =>
                          setState(() => _offset = value),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            _EditorToolbar(
              aspect: _aspect,
              rotation: _rotation,
              onAspectChanged: (value) => setState(() => _aspect = value),
              onRotate: _rotate,
              onReset: _reset,
              onZoomIn: () => setState(() {
                _scale = math.min(_scale * 1.2, 6);
              }),
              onZoomOut: () => setState(() {
                _scale = math.max(_scale / 1.2, 1);
              }),
              onFlipHorizontal: _flipHorizontal,
              onFlipVertical: _flipVertical,
              onUndo: _undo,
              onRedo: _redo,
              canUndo: _canUndo(),
              canRedo: _canRedo(),
              showAdjustments: _showAdjustments,
              showFilters: _showFilters,
              showBeforeAfter: _showBeforeAfter,
              onToggleAdjustments: () =>
                  setState(() => _showAdjustments = !_showAdjustments),
              onToggleFilters: () =>
                  setState(() => _showFilters = !_showFilters),
              onToggleBeforeAfter: () =>
                  setState(() => _showBeforeAfter = !_showBeforeAfter),
              brightness: _brightness,
              contrast: _contrast,
              saturation: _saturation,
              exposure: _exposure,
              highlights: _highlights,
              shadows: _shadows,
              warmth: _warmth,
              sharpness: _sharpness,
              onBrightnessChanged: (v) => setState(() => _brightness = v),
              onContrastChanged: (v) => setState(() => _contrast = v),
              onSaturationChanged: (v) => setState(() => _saturation = v),
              onExposureChanged: (v) => setState(() => _exposure = v),
              onHighlightsChanged: (v) => setState(() => _highlights = v),
              onShadowsChanged: (v) => setState(() => _shadows = v),
              onWarmthChanged: (v) => setState(() => _warmth = v),
              onSharpnessChanged: (v) => setState(() => _sharpness = v),
              filter: _filter,
              filterIntensity: _filterIntensity,
              onFilterChanged: (v) => setState(() => _filter = v),
              onFilterIntensityChanged: (v) =>
                  setState(() => _filterIntensity = v),
              onFilterIntensityReset: () =>
                  setState(() => _filterIntensity = 1.0),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(S.cancel),
        ),
        FilledButton(
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: AppDimensions.spinnerSize,
                  height: AppDimensions.spinnerSize,
                  child: CircularProgressIndicator(
                    strokeWidth: AppDimensions.spinnerStroke,
                    color: AppColor.whiteColor,
                  ),
                )
              : Text(S.save),
        ),
      ],
    );
  }
}

/// The picture with the frame of the cut on it.
class _EditorCanvas extends StatefulWidget {
  const _EditorCanvas({
    required this.previewBytes,
    required this.imageSize,
    required this.crop,
    required this.frame,
    required this.scale,
    required this.offset,
    required this.rotation,
    required this.onCropChanged,
    required this.onScaleChanged,
    required this.onOffsetChanged,
  });

  /// A small copy of the picture, made once when it was opened.
  final Uint8List previewBytes;

  /// The size of the picture being edited, in its own pixels.
  final Size imageSize;
  final Rect crop;
  final Rect frame;
  final double scale;
  final Offset offset;
  final double rotation;
  final ValueChanged<Rect> onCropChanged;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<Offset> onOffsetChanged;

  @override
  State<_EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<_EditorCanvas> {
  /// Where the finger went down on the frame.
  _CropDrag? _dragStart;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) => _dragStart = _CropDrag(
            point: details.localFocalPoint,
            frame: widget.frame,
            canvas: canvasSize,
            imageSize: widget.imageSize,
          ),
          onScaleUpdate: (details) {
            // Two fingers zoom the picture, one finger moves the frame.
            if (details.pointerCount > 1) {
              widget.onScaleChanged(details.scale.clamp(1, 6));
              widget.onOffsetChanged(details.focalPointDelta);
              return;
            }
            final drag = _dragStart;
            if (drag == null) return;
            widget.onCropChanged(drag.apply(details.localFocalPoint));
          },
          onScaleEnd: (_) => _dragStart = null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColor.recordCellBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Transform.rotate(
                    angle: widget.rotation * math.pi / 180,
                    child: Transform.scale(
                      scale: widget.scale,
                      child: Image.memory(
                        widget.previewBytes,
                        fit: BoxFit.contain,
                        cacheWidth: AppDimensions.imagePreviewCacheWidth
                            .round(),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropPainter(
                      frame: widget.frame,
                      imageSize: widget.imageSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// What the finger is doing with the frame of the cut.
class _CropDrag {
  _CropDrag({
    required this.point,
    required this.frame,
    required this.canvas,
    required this.imageSize,
  });

  /// Where the finger went down.
  final Offset point;

  /// The frame when the finger went down.
  final Rect frame;
  final Size canvas;
  final Size imageSize;

  /// Moves or resizes the frame, and returns the new one.
  Rect apply(Offset position) {
    final scaleX = imageSize.width / canvas.width;
    final scaleY = imageSize.height / canvas.height;
    final delta = Offset(
      (position.dx - point.dx) * scaleX,
      (position.dy - point.dy) * scaleY,
    );

    final moved = frame.shift(delta);
    return Rect.fromLTRB(
      moved.left.clamp(0, imageSize.width - frame.width),
      moved.top.clamp(0, imageSize.height - frame.height),
      moved.right.clamp(frame.width, imageSize.width),
      moved.bottom.clamp(frame.height, imageSize.height),
    );
  }
}

/// The frame of the cut.
class _CropPainter extends CustomPainter {
  _CropPainter({required this.frame, required this.imageSize});

  final Rect frame;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColor.whiteColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final shade = Paint()
      ..color = AppColor.blackColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(
      frame.left / imageSize.width * size.width,
      frame.top / imageSize.height * size.height,
      frame.width / imageSize.width * size.width,
      frame.height / imageSize.height * size.height,
    );

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect.top), shade);
    canvas.drawRect(
      Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom),
      shade,
    );
    canvas.drawRect(Rect.fromLTWH(0, rect.top, rect.left, rect.height), shade);
    canvas.drawRect(
      Rect.fromLTWH(rect.right, rect.top, size.width - rect.right, rect.height),
      shade,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.imageSize != imageSize;
  }
}

/// The tools of the editor.
class _EditorToolbar extends StatelessWidget {
  const _EditorToolbar({
    required this.aspect,
    required this.rotation,
    required this.onAspectChanged,
    required this.onRotate,
    required this.onReset,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFlipHorizontal,
    required this.onFlipVertical,
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.showAdjustments,
    required this.showFilters,
    required this.showBeforeAfter,
    required this.onToggleAdjustments,
    required this.onToggleFilters,
    required this.onToggleBeforeAfter,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.exposure,
    required this.highlights,
    required this.shadows,
    required this.warmth,
    required this.sharpness,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onExposureChanged,
    required this.onHighlightsChanged,
    required this.onShadowsChanged,
    required this.onWarmthChanged,
    required this.onSharpnessChanged,
    required this.filter,
    required this.filterIntensity,
    required this.onFilterChanged,
    required this.onFilterIntensityChanged,
    required this.onFilterIntensityReset,
  });

  final ImageAspectPreset aspect;
  final double rotation;
  final ValueChanged<ImageAspectPreset> onAspectChanged;
  final VoidCallback onRotate;
  final VoidCallback onReset;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFlipHorizontal;
  final VoidCallback onFlipVertical;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool showAdjustments;
  final bool showFilters;
  final bool showBeforeAfter;
  final VoidCallback onToggleAdjustments;
  final VoidCallback onToggleFilters;
  final VoidCallback onToggleBeforeAfter;
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double highlights;
  final double shadows;
  final double warmth;
  final double sharpness;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onExposureChanged;
  final ValueChanged<double> onHighlightsChanged;
  final ValueChanged<double> onShadowsChanged;
  final ValueChanged<double> onWarmthChanged;
  final ValueChanged<double> onSharpnessChanged;
  final String filter;
  final double filterIntensity;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<double> onFilterIntensityChanged;
  final VoidCallback onFilterIntensityReset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Aspect ratio presets
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final preset in ImageAspectPreset.values)
              ChoiceChip(
                label: Text(preset.label),
                selected: preset == aspect,
                onSelected: (_) => onAspectChanged(preset),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Toolbar actions
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            IconButton(
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: S.zoomOut,
            ),
            IconButton(
              onPressed: onZoomIn,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: S.zoomIn,
            ),
            TextButton.icon(
              onPressed: onRotate,
              icon: const Icon(Icons.rotate_right),
              label: Text('$rotationط¢آ°'),
            ),
            TextButton.icon(
              onPressed: onFlipHorizontal,
              icon: const Icon(Icons.flip),
              label: Text(S.flipHorizontal),
            ),
            TextButton.icon(
              onPressed: onFlipVertical,
              icon: const Icon(Icons.flip_camera_android),
              label: Text(S.flipVertical),
            ),
            TextButton.icon(
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: Text(S.undo),
            ),
            TextButton.icon(
              onPressed: onRedo,
              icon: const Icon(Icons.redo),
              label: Text(S.redo),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt),
              label: Text(S.resetImage),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Toggle panels
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilterChip(
              label: Text(S.adjustments),
              selected: showAdjustments,
              onSelected: (_) => onToggleAdjustments(),
            ),
            FilterChip(
              label: Text(S.filters),
              selected: showFilters,
              onSelected: (_) => onToggleFilters(),
            ),
            FilterChip(
              label: Text(S.beforeAfter),
              selected: showBeforeAfter,
              onSelected: (_) => onToggleBeforeAfter(),
            ),
          ],
        ),
        // Adjustments panel
        if (showAdjustments) ...[
          const SizedBox(height: AppSpacing.md),
          _AdjustmentSlider(
            label: S.brightness,
            value: brightness,
            min: 0.0,
            max: 2.0,
            onChanged: onBrightnessChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.contrast,
            value: contrast,
            min: 0.0,
            max: 2.0,
            onChanged: onContrastChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.saturation,
            value: saturation,
            min: 0.0,
            max: 2.0,
            onChanged: onSaturationChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.exposure,
            value: exposure,
            min: -1.0,
            max: 1.0,
            onChanged: onExposureChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.highlights,
            value: highlights,
            min: -1.0,
            max: 1.0,
            onChanged: onHighlightsChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.shadows,
            value: shadows,
            min: -1.0,
            max: 1.0,
            onChanged: onShadowsChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.warmth,
            value: warmth,
            min: -1.0,
            max: 1.0,
            onChanged: onWarmthChanged,
            divisions: 20,
          ),
          _AdjustmentSlider(
            label: S.sharpness,
            value: sharpness,
            min: 0.0,
            max: 1.0,
            onChanged: onSharpnessChanged,
            divisions: 20,
          ),
        ],
        // Filters panel
        if (showFilters) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final preset in _FilterPreset.values)
                ChoiceChip(
                  label: Text(preset.label),
                  selected: filter == preset.value,
                  onSelected: (_) => onFilterChanged(preset.value),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _AdjustmentSlider(
            label: S.intensity,
            value: filterIntensity,
            min: 0.0,
            max: 1.0,
            onChanged: onFilterIntensityChanged,
            divisions: 10,
            onReset: onFilterIntensityReset,
          ),
        ],
      ],
    );
  }
}

/// Filter presets
enum _FilterPreset {
  none('none', 'Original'),
  vivid('vivid', 'Vivid'),
  warm('warm', 'Warm'),
  cool('cool', 'Cool'),
  vintage('vintage', 'Vintage'),
  bw('bw', 'B&W'),
  bleach('bleach', 'Bleach'),
  sketch('sketch', 'Sketch'),
  vignette('vignette', 'Vignette');

  const _FilterPreset(this.value, this.label);
  final String value;
  final String label;
}

/// A slider for an adjustment parameter.
class _AdjustmentSlider extends StatelessWidget {
  const _AdjustmentSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.divisions,
    this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int divisions;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodySmall),
              if (onReset != null)
                TextButton(
                  onPressed: onReset!,
                  child: Text(
                    S.reset,
                    style: const TextStyle(fontSize: AppFontSizes.size12),
                  ),
                ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

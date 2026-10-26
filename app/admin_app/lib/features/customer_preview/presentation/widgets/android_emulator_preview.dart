import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/data/emulator_bridge_client.dart';

class AndroidEmulatorPreview extends StatefulWidget {
  const AndroidEmulatorPreview({super.key, this.bridge});

  final EmulatorBridgeClient? bridge;

  @override
  State<AndroidEmulatorPreview> createState() => _AndroidEmulatorPreviewState();
}

class _AndroidEmulatorPreviewState extends State<AndroidEmulatorPreview> {
  late final EmulatorBridgeClient _bridge =
      widget.bridge ?? EmulatorBridgeClient();
  final _tokenController = TextEditingController();
  final _textController = TextEditingController();
  Timer? _frameTimer;
  Timer? _healthTimer;
  Uint8List? _frame;
  bool _connected = false;
  bool _frameLoading = false;
  bool _working = false;
  bool _showKeyboardInput = false;
  String? _error;
  Offset? _pointerDown;
  DateTime? _pointerDownAt;

  String get _token => _tokenController.text.trim();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _healthTimer?.cancel();
    _tokenController.dispose();
    _textController.dispose();
    if (widget.bridge == null) _bridge.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_token.isEmpty || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final connected = await _bridge.check(_token);
      if (!connected) throw StateError(S.bridgeNotReady);
      _frameTimer?.cancel();
      _healthTimer?.cancel();
      if (!mounted) return;
      setState(() => _connected = true);
      await _captureFrame();
      _frameTimer = Timer.periodic(
        const Duration(milliseconds: 550),
        (_) => _captureFrame(),
      );
      _healthTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _checkHealth(),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _checkHealth() async {
    try {
      final connected = await _bridge.check(_token);
      if (mounted && connected != _connected) {
        setState(() => _connected = connected);
      }
    } catch (_) {
      if (mounted && _connected) setState(() => _connected = false);
    }
  }

  Future<void> _captureFrame() async {
    if (_frameLoading || _token.isEmpty) return;
    _frameLoading = true;
    try {
      final image = await _bridge.screenshot(_token);
      if (mounted) {
        setState(() {
          _frame = image;
          _connected = true;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _connected = false;
          _error = error.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      _frameLoading = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await _captureFrame();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
  }

  Future<void> _refreshApp() async {
    if (_token.isEmpty) return;
    setState(() => _working = true);
    await _run(() => _bridge.refresh(_token));
    if (mounted) setState(() => _working = false);
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.isEmpty) return;
    await _run(() => _bridge.sendText(_token, text));
    if (mounted) _textController.clear();
  }

  Offset _devicePoint(Offset local, Size size) => Offset(
    (local.dx / size.width * 1440).round().clamp(0, 1439).toDouble(),
    (local.dy / size.height * 3120).round().clamp(0, 3119).toDouble(),
  );

  void _handlePointerDown(PointerDownEvent event) {
    _pointerDown = event.localPosition;
    _pointerDownAt = DateTime.now();
  }

  Future<void> _handlePointerUp(PointerUpEvent event, Size size) async {
    final start = _pointerDown;
    final startedAt = _pointerDownAt;
    if (start == null || startedAt == null || !_connected) return;
    _pointerDown = null;
    _pointerDownAt = null;
    final end = event.localPosition;
    final a = _devicePoint(start, size);
    final b = _devicePoint(end, size);
    if ((end - start).distance < 10) {
      await _run(() => _bridge.tap(_token, a.dx.round(), a.dy.round()));
    } else {
      final duration = DateTime.now().difference(startedAt).inMilliseconds;
      await _run(
        () => _bridge.swipe(
          _token,
          a.dx.round(),
          a.dy.round(),
          b.dx.round(),
          b.dy.round(),
          duration.clamp(80, 1500).toInt(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.pageHorizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.emulatorPreviewTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppDimensions.xs),
          Text(
            S.emulatorPreviewDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColor.greyColor,
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 820;
              final device = _buildDevice(theme);
              final controls = _buildConnectionPanel(theme);
              if (compact) {
                return Column(
                  children: [device, const SizedBox(height: 20), controls],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: device),
                  const SizedBox(width: 24),
                  Expanded(flex: 5, child: controls),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDevice(ThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          children: [
            Row(
              children: [
                _statusDot(_connected),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _connected ? S.emulatorConnected : S.emulatorDisconnected,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: S.reloadSavedAppData,
                  onPressed: _connected && !_working ? _refreshApp : null,
                  icon: const Icon(HugeIcons.strokeRoundedRefresh),
                ),
                IconButton(
                  tooltip: S.back,
                  onPressed: _connected
                      ? () => _run(() => _bridge.key(_token, 'back'))
                      : null,
                  icon: const Icon(HugeIcons.strokeRoundedArrowLeft01),
                ),
                IconButton(
                  tooltip: S.homeScreen,
                  onPressed: _connected
                      ? () => _run(() => _bridge.key(_token, 'home'))
                      : null,
                  icon: const Icon(HugeIcons.strokeRoundedHome01),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff111318),
                borderRadius: BorderRadius.circular(36),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(29),
                child: AspectRatio(
                  aspectRatio: 1440 / 3120,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handlePointerDown,
                        onPointerUp: (event) =>
                            _handlePointerUp(event, constraints.biggest),
                        child: _frame == null
                            ? ColoredBox(
                                color: const Color(0xfff7f8fa),
                                child: Center(child: _connectionMessage(theme)),
                              )
                            : Image.memory(
                                _frame!,
                                fit: BoxFit.fill,
                                gaplessPlayback: true,
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_connected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _showKeyboardInput
                        ? TextField(
                            controller: _textController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: S.typeIntoApp,
                              suffixIcon: IconButton(
                                tooltip: S.send,
                                onPressed: _sendText,
                                icon: const Icon(HugeIcons.strokeRoundedSent),
                              ),
                            ),
                            onSubmitted: (_) => _sendText(),
                          )
                        : OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showKeyboardInput = true),
                            icon: const Icon(
                              HugeIcons.strokeRoundedKeyboard,
                              size: 18,
                            ),
                            label: Text(S.typeIntoAppButton),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPanel(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.pageCardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  HugeIcons.strokeRoundedSmartPhone01,
                  color: AppColor.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.connectRealEmulator,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppFontWeights.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(S.emulatorBridgeHint),
            const SizedBox(height: 10),
            const SelectableText(
              r'powershell -ExecutionPolicy Bypass -File "app\admin_app\tools\android_emulator_bridge.ps1"',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: AppFontSizes.size12,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _tokenController,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: S.bridgeTokenLabel,
                hintText: S.bridgeTokenHint,
                border: OutlineInputBorder(),
                prefixIcon: Icon(HugeIcons.strokeRoundedKey01, size: 18),
              ),
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _working ? null : _connect,
                icon: _working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(HugeIcons.strokeRoundedLink01, size: 18),
                label: Text(_working ? S.connecting : S.connectToEmulator),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const Divider(height: 28),
            _helpRow(theme, '1', S.emulatorStepSave),
            _helpRow(theme, '2', S.emulatorStepReload),
            _helpRow(theme, '3', S.emulatorStepInteract),
            const SizedBox(height: 4),
            Text(
              S.emulatorBridgeNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColor.greyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(ThemeData theme, String number, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: AppColor.secondaryColor,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: AppFontSizes.size11,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    ),
  );

  Widget _connectionMessage(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _connected
              ? HugeIcons.strokeRoundedLoading03
              : HugeIcons.strokeRoundedSmartPhone01,
          size: 30,
          color: AppColor.greyColor,
        ),
        const SizedBox(height: 10),
        Text(
          _connected ? S.loadingEmulatorScreen : S.startBridgeThenConnect,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _statusDot(bool connected) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: connected ? AppColor.primaryColor : AppColor.greyColor,
      shape: BoxShape.circle,
    ),
  );
}

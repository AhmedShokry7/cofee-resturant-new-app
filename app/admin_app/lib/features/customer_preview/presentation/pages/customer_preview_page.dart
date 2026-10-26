import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:hugeicons/hugeicons.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/core/constants/app_dimensions.dart';
import 'package:admin_app/core/theme/typography.dart';
import 'package:admin_app/features/customer_preview/presentation/manager/customer_preview_cubit.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/phone_frame.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/android_emulator_preview.dart';
import 'package:admin_app/features/customer_preview/presentation/widgets/preview_surface/preview_surface.dart';

class CustomerPreviewPage extends StatelessWidget {
  const CustomerPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerPreviewCubit(),
      child: const _CustomerPreviewView(),
    );
  }
}

class _CustomerPreviewView extends StatelessWidget {
  const _CustomerPreviewView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerPreviewCubit, CustomerPreviewState>(
      builder: (context, state) {
        final cubit = context.read<CustomerPreviewCubit>();
        final url = _buildUrl(state);
        final width = _viewportWidth(state.viewport);

        return DefaultTabController(
          length: 2,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(isDirty: state.isDirty),
                const SizedBox(height: AppDimensions.md),
                TabBar(
                  tabs: [
                    Tab(text: S.browserPreview),
                    Tab(text: S.androidEmulator),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                Expanded(
                  child: TabBarView(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;
                          final controls = _Controls(
                            cubit: cubit,
                            state: state,
                          );
                          final preview = SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.sm,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColor.lightGreyColor,
                                    borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusPill,
                                    ),
                                  ),
                                  child: Text(
                                    state.isDirty
                                        ? S.previewDraftMode
                                        : S.previewPublishedMode,
                                    style: const TextStyle(
                                      fontSize: AppFontSizes.size12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.md),
                                PhoneFrame(
                                  width: width,
                                  child: url.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(
                                              AppDimensions.md,
                                            ),
                                            child: Text(
                                              '${S.previewCustomerAppUrl}\n'
                                              'Run: flutter run -d web-server '
                                              '--web-port 8080',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        )
                                      : PreviewSurface(url: url),
                                ),
                              ],
                            ),
                          );

                          if (wide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: SingleChildScrollView(child: controls),
                                ),
                                const SizedBox(width: AppDimensions.lg),
                                Expanded(child: preview),
                              ],
                            );
                          }
                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                controls,
                                const SizedBox(height: AppDimensions.lg),
                                preview,
                              ],
                            ),
                          );
                        },
                      ),
                      const AndroidEmulatorPreview(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _viewportWidth(PreviewViewport viewport) {
    switch (viewport) {
      case PreviewViewport.small:
        return 280;
      case PreviewViewport.medium:
        return 260;
      case PreviewViewport.large:
        return 360;
    }
  }

  String _buildUrl(CustomerPreviewState state) {
    final base = state.customerAppUrl.trim();
    if (base.isEmpty) return '';
    Uri uri;
    try {
      uri = Uri.parse(base);
    } catch (_) {
      return '';
    }
    final params = Map<String, String>.from(uri.queryParameters);
    params['preview'] = '1';
    params['screen'] = state.screen.name;
    params['primary'] = _hex(state.draft.primaryColor);
    params['secondary'] = _hex(state.draft.secondaryColor);
    params['background'] = _hex(state.draft.backgroundColor);
    params['surface'] = _hex(state.draft.surfaceColor);
    params['refresh'] = '';
    return uri.replace(queryParameters: params).toString();
  }

  String _hex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
}

class _Header extends StatelessWidget {
  const _Header({required this.isDirty});

  final bool isDirty;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(HugeIcons.strokeRoundedSmartPhone01, size: 20),
        const SizedBox(width: AppDimensions.sm),
        Text(S.customerPreview, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Text(
          isDirty ? S.previewDraftMode : S.previewPublishedMode,
          style: TextStyle(
            color: isDirty ? AppColor.errorColor : AppColor.greenColor,
            fontSize: AppFontSizes.size12,
          ),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.cubit, required this.state});

  final CustomerPreviewCubit cubit;
  final CustomerPreviewState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(labelText: S.previewCustomerAppUrl),
              controller: TextEditingController(text: state.customerAppUrl),
              onChanged: cubit.updateCustomerAppUrl,
            ),
            const SizedBox(height: AppDimensions.md),
            DropdownButtonFormField<PreviewScreen>(
              initialValue: state.screen,
              decoration: InputDecoration(labelText: S.previewScreen),
              items: PreviewScreen.values
                  .map(
                    (s) => DropdownMenuItem<PreviewScreen>(
                      value: s,
                      child: Text(s.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) cubit.updateScreen(v);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            DropdownButtonFormField<PreviewViewport>(
              initialValue: state.viewport,
              decoration: InputDecoration(labelText: S.previewViewport),
              items: PreviewViewport.values
                  .map(
                    (v) => DropdownMenuItem<PreviewViewport>(
                      value: v,
                      child: Text(v.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) cubit.updateViewport(v);
              },
            ),
            const SizedBox(height: AppDimensions.md),
            _ColorField(
              label: S.previewPrimaryColor,
              color: state.draft.primaryColor,
              onChanged: cubit.updatePrimaryColor,
            ),
            _ColorField(
              label: S.previewSecondaryColor,
              color: state.draft.secondaryColor,
              onChanged: cubit.updateSecondaryColor,
            ),
            _ColorField(
              label: S.previewBackgroundColor,
              color: state.draft.backgroundColor,
              onChanged: cubit.updateBackgroundColor,
            ),
            _ColorField(
              label: S.previewSurfaceColor,
              color: state.draft.surfaceColor,
              onChanged: cubit.updateSurfaceColor,
            ),
            const SizedBox(height: AppDimensions.md),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                ElevatedButton.icon(
                  onPressed: cubit.refresh,
                  icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 16),
                  label: Text(S.previewRefresh),
                ),
                OutlinedButton(
                  onPressed: cubit.resetDraft,
                  child: Text(S.previewResetDraft),
                ),
                OutlinedButton(
                  onPressed: state.isSaving ? null : cubit.saveDraft,
                  child: Text(S.previewSaveDraft),
                ),
                OutlinedButton(onPressed: null, child: Text(S.previewPublish)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorField extends StatefulWidget {
  const _ColorField({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onChanged;

  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _hex(widget.color));
  }

  @override
  void didUpdateWidget(covariant _ColorField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _controller.text = _hex(widget.color);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) {
          final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
          if (parsed != null) {
            widget.onChanged(Color(parsed | 0xFF000000));
          }
        },
      ),
    );
  }

  String _hex(Color color) => '#';
}

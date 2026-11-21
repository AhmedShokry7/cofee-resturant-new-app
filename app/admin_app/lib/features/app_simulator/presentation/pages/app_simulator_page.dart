import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/theme/app_color.dart';
import 'package:admin_app/features/visual_editor/domain/visual_editor_models.dart';
import 'package:admin_app/features/visual_editor/presentation/manager/visual_editor_cubit.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/preview_panel.dart';
import 'package:admin_app/features/visual_editor/presentation/widgets/visual_editor_theme_tokens.dart';
import 'package:admin_app/shared/widgets/admin_state_view.dart';

/// Read-only, full customer-app simulator. Feature pages can pass an in-memory
/// design document so unsaved edits render in the real customer application.
class AppSimulatorPage extends StatefulWidget {
  const AppSimulatorPage({
    super.key,
    this.designDocument,
    this.initialPageId = 'home',
  });

  final Map<String, dynamic>? designDocument;
  final String initialPageId;

  @override
  State<AppSimulatorPage> createState() => _AppSimulatorPageState();
}

class _AppSimulatorPageState extends State<AppSimulatorPage> {
  late final VisualEditorCubit _cubit;
  late String _pageId;
  int _reload = 0;
  PreviewDevice _device = PreviewDevice.phone;

  @override
  void initState() {
    super.initState();
    _pageId = widget.initialPageId;
    _cubit = VisualEditorCubit();
    _cubit.setExternalPreviewDocument(widget.designDocument, pageId: _pageId);
    _cubit.initialize();
  }

  @override
  void didUpdateWidget(covariant AppSimulatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldDocument = oldWidget.designDocument;
    final nextDocument = widget.designDocument;
    final documentChanged = oldDocument == null
        ? nextDocument != null
        : nextDocument == null ||
              jsonEncode(oldDocument) != jsonEncode(nextDocument);
    if (documentChanged) {
      _cubit.setExternalPreviewDocument(nextDocument, pageId: _pageId);
    }
    if (oldWidget.initialPageId != widget.initialPageId) {
      _pageId = widget.initialPageId;
      _cubit.loadPage(_pageId);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: _cubit,
    child: BlocBuilder<VisualEditorCubit, VisualEditorState>(
      builder: (context, state) {
        if (state.status == VisualEditorStatus.loading) {
          return const AdminLoadingView();
        }
        if (state.status == VisualEditorStatus.failure) {
          return AdminFailureView(
            message: state.errorMessage,
            onRetry: _cubit.initialize,
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 850;
            return Container(
              color: VisualEditorTokens.bg(context),
              child: Column(
                children: [
                  _topBar(),
                  Expanded(
                    child: narrow
                        ? Column(
                            children: [
                              _pageSelector(horizontal: true),
                              Expanded(child: _preview(state)),
                            ],
                          )
                        : Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              SizedBox(width: 250, child: _pageSelector()),
                              Expanded(child: _preview(state)),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  Widget _topBar() {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppColor.darkText
        : AppColor.adminHeading;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        border: Border(
          bottom: BorderSide(color: VisualEditorTokens.border(context)),
        ),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.smartphone_rounded,
            color: VisualEditorTokens.primaryOliveGreen,
          ),
          Text(
            S.splashCopy(
              '\u0645\u0639\u0627\u064a\u0646\u0629 \u0627\u0644\u062a\u0637\u0628\u064a\u0642 \u0628\u0627\u0644\u0643\u0627\u0645\u0644',
              'Full customer app preview',
            ),
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          DropdownButton<PreviewDevice>(
            value: _device,
            onChanged: (value) {
              if (value != null) setState(() => _device = value);
            },
            items: [
              for (final d in PreviewDevice.values)
                DropdownMenuItem(value: d, child: Text(d.label)),
            ],
          ),
          IconButton(
            tooltip: S.splashCopy(
              '\u0625\u0639\u0627\u062f\u0629 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0639\u0627\u064a\u0646\u0629',
              'Reload preview',
            ),
            onPressed: () => setState(() => _reload++),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _pageSelector({bool horizontal = false}) {
    final list = ListView(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: const EdgeInsets.all(12),
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            S.splashCopy(
              '\u0634\u0627\u0634\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642',
              'App screens',
            ),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: VisualEditorTokens.text(context),
            ),
          ),
        ),
        for (final page in PreviewPages.all)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: horizontal ? 150 : null,
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  selected: page.pageId == _pageId,
                  leading: const Icon(Icons.phone_android_rounded, size: 18),
                  title: Text(
                    page.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    setState(() => _pageId = page.pageId);
                    _cubit.loadPage(page.pageId);
                  },
                ),
              ),
            ),
          ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        color: VisualEditorTokens.surface(context),
        border: Border(
          left: BorderSide(color: VisualEditorTokens.border(context)),
        ),
      ),
      height: horizontal ? 80 : null,
      child: list,
    );
  }

  Widget _preview(VisualEditorState state) => Container(
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: VisualEditorTokens.canvas(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: VisualEditorTokens.border(context)),
    ),
    child: Center(
      child: AspectRatio(
        aspectRatio: _device.width / _device.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: PreviewPanel(
            pageId: _pageId,
            sessionId: state.sessionId,
            zoom: 1,
            device: _device,
            components: state.getComponentsForPage(_pageId),
            theme: _cubit.theme,
            selectedComponentId: state.selectedComponentId,
            reloadToken: _reload,
            previewLanguage: state.previewLanguage,
            previewThemeMode: state.previewThemeMode,
            onConnectionChanged: (connection, reason) =>
                _cubit.updatePreviewConnection(connection, reason: reason),
            onElementSelected: _cubit.handleElementSelected,
            onPreviewReady: _cubit.handlePreviewReady,
            onPreviewError: _cubit.handlePreviewError,
            onPropertyUpdated: _cubit.handlePropertyUpdated,
            onTreeUpdated: _cubit.handleTreeUpdated,
            outboundMessageType: _cubit.pendingMessage?.type,
            outboundPayload: _cubit.pendingMessage?.payload,
            outboundMessageId: _cubit.pendingMessage?.messageId,
            takePreviewMessages: _cubit.takePreviewMessages,
          ),
        ),
      ),
    ),
  );
}

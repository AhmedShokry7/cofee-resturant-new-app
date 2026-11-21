import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/core/theme/app_color.dart';

import '../../data/models/studio_registry.dart';
import '../../data/repositories/studio_draft_repository.dart';
import '../widgets/preview_frame.dart';
import '../manager/studio_cubit.dart';

class CustomerAppStudioPage extends StatelessWidget {
  const CustomerAppStudioPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StudioCubit(StudioDraftRepository())..restore(),
    child: const _StudioWorkspace(),
  );
}

class _StudioWorkspace extends StatefulWidget {
  const _StudioWorkspace();

  @override
  State<_StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends State<_StudioWorkspace> {
  double _canvasScale = 1;
  bool _darkSurface = false;
  int _deviceWidth = 390;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudioCubit, StudioState>(
      builder: (context, state) => Container(
        color: const Color(0xffF3F5F4),
        child: Column(
          children: [
            _StudioToolbar(
              state: state,
              onDarkToggle: () => setState(() => _darkSurface = !_darkSurface),
              dark: _darkSurface,
            ),
            if (state.validationError != null)
              MaterialBanner(
                content: Text(state.validationError!),
                leading: const Icon(Icons.error_outline, color: Colors.red),
                actions: const [SizedBox.shrink()],
              ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(width: 240, child: _PagesAndLayers(state: state)),
                  Expanded(
                    child: _CanvasWorkspace(
                      state: state,
                      width: _deviceWidth,
                      scale: _canvasScale,
                      dark: _darkSurface,
                      onDevice: (width) => setState(() => _deviceWidth = width),
                      onZoom: (delta) => setState(
                        () => _canvasScale = (_canvasScale + delta)
                            .clamp(.55, 1.35)
                            .toDouble(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 300,
                    child: _PropertiesInspector(state: state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioToolbar extends StatelessWidget {
  const _StudioToolbar({
    required this.state,
    required this.onDarkToggle,
    required this.dark,
  });
  final StudioState state;
  final VoidCallback onDarkToggle;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffE5E9EE))),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_rounded, color: AppColor.primaryColor),
          const SizedBox(width: 10),
          const Text(
            'Customer App Studio',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColor.adminHeading,
            ),
          ),
          const SizedBox(width: 18),
          Container(width: 1, height: 28, color: AppColor.borderColor),
          const SizedBox(width: 16),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: state.pageId,
              items: [
                for (final page in studioPages)
                  DropdownMenuItem(
                    value: page.id,
                    child: Text(page.title, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) {
                if (value != null) cubit.selectPage(value);
              },
            ),
          ),
          const Spacer(),
          Icon(
            state.dirty ? Icons.circle : Icons.check_circle,
            size: 11,
            color: state.dirty
                ? const Color(0xffD28A2E)
                : AppColor.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            state.loading
                ? 'Loading local draft…'
                : state.saving
                ? 'Saving locally…'
                : state.dirty
                ? 'Unsaved draft'
                : 'Local draft saved',
            style: const TextStyle(fontSize: 12, color: AppColor.adminMuted),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Undo',
            onPressed: state.canUndo ? cubit.undo : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Redo',
            onPressed: state.canRedo ? cubit.redo : null,
            icon: const Icon(Icons.redo),
          ),
          OutlinedButton.icon(
            onPressed: () => cubit.saveDraft(),
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Save draft'),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Runtime preview is locked until the deployed app has an isolated preview dependency graph.',
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Preview'),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Version history becomes available after server-side versions are connected.',
            child: IconButton(
              onPressed: null,
              icon: const Icon(Icons.history),
              tooltip: 'Version history',
            ),
          ),
          Tooltip(
            message: 'Identity controls are not connected to a validated design contract yet.',
            child: IconButton(
              onPressed: null,
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'App identity',
            ),
          ),
          Tooltip(
            message: 'Publishing is disabled until server-side validation and atomic publishing are connected.',
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.publish, size: 16),
              label: const Text('Publish'),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Scheduling requires the server publishing worker.',
            child: OutlinedButton(
              onPressed: null,
              child: const Text('Schedule'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Light / dark canvas surface',
            onPressed: onDarkToggle,
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
    );
  }
}

class _PagesAndLayers extends StatelessWidget {
  const _PagesAndLayers({required this.state});
  final StudioState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final canEdit = cubit.canEditCurrentPage;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xffE5E9EE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeading('PAGES', Icons.dashboard_outlined),
          Expanded(
            child: ListView.builder(
              itemCount: studioPages.length,
              itemBuilder: (context, index) {
                final page = studioPages[index];
                final selected = page.id == state.pageId;
                return ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(
                    page.support == 'Partially Editable'
                        ? Icons.tune
                        : Icons.visibility_outlined,
                    size: 16,
                    color: selected
                        ? AppColor.primaryColor
                        : AppColor.adminMuted,
                  ),
                  title: Text(
                    page.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    page.support,
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: () => cubit.selectPage(page.id),
                );
              },
            ),
          ),
          const Divider(height: 1),
          const _PanelHeading('LAYERS · HOME FIXTURE', Icons.layers_outlined),
          Expanded(
            flex: 0,
            child: SizedBox(
              height: 180,
              child: state.nodes.isEmpty
                  ? const Center(
                      child: Text(
                        'No custom sections on this page.',
                        style: TextStyle(fontSize: 11),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final node in state.nodes)
                          _LayerTree(node: node, state: state, depth: 0),
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final type in const [
                  'section.heading',
                  'section.text',
                  'section.button',
                  'section.image',
                  'section.product_grid',
                  'section.column',
                  'section.row',
                  'section.spacer',
                  'section.divider',
                ])
                  Tooltip(
                    message: canEdit
                        ? 'Add $type'
                        : 'This page is preview only',
                    child: IconButton.filledTonal(
                      onPressed: canEdit ? () => cubit.addNode(type) : null,
                      icon: Icon(_iconFor(type), size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasWorkspace extends StatelessWidget {
  const _CanvasWorkspace({
    required this.state,
    required this.width,
    required this.scale,
    required this.dark,
    required this.onDevice,
    required this.onZoom,
  });
  final StudioState state;
  final int width;
  final double scale;
  final bool dark;
  final ValueChanged<int> onDevice;
  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xffE5E9EE))),
          ),
          child: Row(
            children: [
              const Icon(Icons.security, size: 15, color: AppColor.adminAccent),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Published customer app · preview locked pending isolation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColor.adminBody),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: width,
                  items: const [
                    DropdownMenuItem(value: 390, child: Text('Phone')),
                    DropdownMenuItem(value: 768, child: Text('Tablet')),
                    DropdownMenuItem(value: 1280, child: Text('Desktop')),
                  ],
                  onChanged: (value) {
                    if (value != null) onDevice(value);
                  },
                ),
              ),
              IconButton(
                onPressed: () => onZoom(-.1),
                icon: const Icon(Icons.remove, size: 16),
              ),
              Text(
                '${(scale * 100).round()}%',
                style: const TextStyle(fontSize: 11),
              ),
              IconButton(
                onPressed: () => onZoom(.1),
                icon: const Icon(Icons.add, size: 16),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Center(
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width.toDouble(),
                    height: (constraints.maxHeight - 52)
                        .clamp(260, 1200)
                        .toDouble(),
                    child: StudioPreviewFrame(
                      pageId: state.pageId,
                      designDocument: context
                          .read<StudioCubit>()
                          .previewDocument,
                      selectedElementId: state.selectedNodeId,
                      darkMode: dark,
                      width: width,
                      runtimeReleaseAvailable: const bool.fromEnvironment(
                        'STUDIO_PREVIEW_ENABLED',
                        defaultValue: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LayerTree extends StatelessWidget {
  const _LayerTree({
    required this.node,
    required this.state,
    required this.depth,
  });
  final StudioNode node;
  final StudioState state;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final selected = node.id == state.selectedNodeId;
    final tile = ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      selected: selected,
      leading: Icon(
        _iconFor(node.type),
        size: 16,
        color: node.visible ? null : Colors.grey,
      ),
      title: Text(
        node.type.replaceFirst('section.', ''),
        style: TextStyle(
          fontSize: 11,
          color: node.visible ? null : Colors.grey,
        ),
      ),
      subtitle:
          node.props['text'] is String ||
              node.props['label'] is String ||
              node.props['title'] is String
          ? Text(
              (node.props['text'] ?? node.props['label'] ?? node.props['title'])
                  .toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10),
            )
          : null,
      trailing: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert, size: 16),
        onSelected: (action) {
          switch (action) {
            case 'visible':
              cubit.toggleVisibility(node.id);
            case 'up':
              cubit.selectNode(node.id);
              cubit.moveSelected(-1);
            case 'down':
              cubit.selectNode(node.id);
              cubit.moveSelected(1);
            case 'duplicate':
              cubit.selectNode(node.id);
              cubit.duplicateSelected();
            case 'delete':
              cubit.selectNode(node.id);
              cubit.removeSelected();
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'visible',
            child: Text(node.visible ? 'Hide' : 'Show'),
          ),
          const PopupMenuItem(value: 'up', child: Text('Move up')),
          const PopupMenuItem(value: 'down', child: Text('Move down')),
          const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      onTap: () => cubit.selectNode(node.id),
    );
    if (node.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 10.0),
        child: tile,
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: depth * 8.0),
      child: ExpansionTile(
        key: PageStorageKey(node.id),
        initiallyExpanded: true,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: tile,
        children: [
          for (final child in node.children)
            _LayerTree(node: child, state: state, depth: depth + 1),
        ],
      ),
    );
  }
}

class _PropertiesInspector extends StatelessWidget {
  const _PropertiesInspector({required this.state});
  final StudioState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StudioCubit>();
    final node = state.selectedNode;
    final definition = node == null
        ? null
        : studioComponents.where((item) => item.type == node.type).firstOrNull;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xffE5E9EE))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeading('PROPERTIES', Icons.tune),
          if (node == null || definition == null)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Select a supported layer to edit its validated properties.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColor.adminMuted),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                '${definition.title} · schema ${definition.schemaVersion}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColor.adminHeading,
                ),
              ),
            ),
            const Divider(height: 18),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final property in definition.properties)
                    _PropertyEditor(
                      property: property,
                      value: node.props[property.key] ?? property.initialValue,
                      onChanged: (value) =>
                          cubit.updateProperty(property.key, value),
                    ),
                  if (definition.properties.isEmpty)
                    const Text(
                      'This component has no editable properties.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColor.adminMuted,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                children: [
                  if (definition.allowedChildren.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: 'Add nested component',
                      onSelected: (type) =>
                          cubit.addNode(type, parentId: node.id),
                      itemBuilder: (_) => [
                        for (final type in definition.allowedChildren)
                          PopupMenuItem(
                            value: type,
                            child: Text(type.replaceFirst('section.', '')),
                          ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('Add child'),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: cubit.canEditCurrentPage
                        ? cubit.duplicateSelected
                        : null,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Duplicate'),
                  ),
                  OutlinedButton.icon(
                    onPressed: cubit.canEditCurrentPage
                        ? cubit.removeSelected
                        : null,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PropertyEditor extends StatelessWidget {
  const _PropertyEditor({
    required this.property,
    required this.value,
    required this.onChanged,
  });
  final StudioPropertyDefinition property;
  final Object value;
  final ValueChanged<Object> onChanged;

  @override
  Widget build(BuildContext context) {
    if (property.inspector == 'switch') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(property.label, style: const TextStyle(fontSize: 12)),
        value: value == true,
        onChanged: onChanged,
      );
    }
    if (property.inspector == 'select') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: DropdownButtonFormField<String>(
          initialValue: value.toString(),
          decoration: InputDecoration(
            labelText: property.label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            for (final option in property.allowedValues)
              DropdownMenuItem(
                value: option.toString(),
                child: Text(option.toString()),
              ),
          ],
          onChanged: (next) {
            if (next != null && validateStudioValue(property, next) == null) {
              onChanged(next);
            }
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            property.label,
            style: const TextStyle(fontSize: 11, color: AppColor.adminMuted),
          ),
          const SizedBox(height: 5),
          TextFormField(
            key: ValueKey('${property.key}:${value.hashCode}'),
            initialValue: value.toString(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              suffixText: property.type == 'color' ? 'HEX' : null,
            ),
            keyboardType: property.type == 'number'
                ? TextInputType.number
                : TextInputType.text,
            onFieldSubmitted: (text) {
              final Object next = property.type == 'number'
                  ? (num.tryParse(text) ?? value as num)
                  : text;
              if (validateStudioValue(property, next) == null) onChanged(next);
            },
          ),
        ],
      ),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading(this.title, this.icon);
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 15, 12, 8),
    child: Row(
      children: [
        Icon(icon, size: 15, color: AppColor.adminAccent),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
            color: AppColor.adminMuted,
          ),
        ),
      ],
    ),
  );
}

IconData _iconFor(String type) => switch (type) {
  'section.text' => Icons.text_fields,
  'section.button' => Icons.smart_button_outlined,
  'section.image' => Icons.image_outlined,
  'section.spacer' => Icons.height,
  'section.divider' => Icons.horizontal_rule,
  _ => Icons.widgets_outlined,
};

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:new_coffee/features/design/data/design_preview_store.dart';
import 'package:new_coffee/features/design/data/model/published_design.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_cubit.dart';

void main() {
  tearDown(() => DesignPreviewStore.instance.setDocument(null));

  test('an older design read cannot overwrite a newer editor update', () async {
    const stale = PublishedDesign(
      schemaVersion: 2,
      extraSections: {
        'welcome': [
          PublishedSection(
            id: 'welcome-title',
            type: 'welcome.title',
            properties: {'highlight': 'old'},
          ),
        ],
      },
    );
    const latest = PublishedDesign(
      schemaVersion: 2,
      extraSections: {
        'welcome': [
          PublishedSection(
            id: 'welcome-title',
            type: 'welcome.title',
            properties: {'highlight': 'new'},
          ),
        ],
      },
    );
    final repository = _OutOfOrderRepository(stale: stale, latest: latest);
    final cubit = DesignCubit(repository: repository);
    addTearDown(cubit.close);

    // Simulate an editor update arriving before the startup network read ends.
    final startupRead = cubit.initialLoad;
    await cubit.load(forceRefresh: true);
    expect(
      cubit.state.pageSections('welcome').single.property('highlight'),
      'new',
    );

    repository.completeStartupRead();
    await startupRead;
    expect(
      cubit.state.pageSections('welcome').single.property('highlight'),
      'new',
      reason: 'the old startup response must not replace the editor preview',
    );
  });

  test(
    'a forced refresh re-reads and repaints the published document',
    () async {
      const before = PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'welcome': [
            PublishedSection(
              id: 'welcome-title',
              type: 'welcome.title',
              properties: {'highlight': 'before'},
            ),
          ],
        },
      );
      const after = PublishedDesign(
        schemaVersion: 2,
        extraSections: {
          'welcome': [
            PublishedSection(
              id: 'welcome-title',
              type: 'welcome.title',
              properties: {'highlight': 'after'},
            ),
          ],
        },
      );
      final repository = _RefreshRepository(designs: [before, after]);
      final cubit = DesignCubit(repository: repository);
      addTearDown(cubit.close);

      await cubit.initialLoad;
      expect(repository.forcedReads, isZero);
      expect(
        cubit.state.pageSections('welcome').single.property('highlight'),
        'before',
      );

      await cubit.load(forceRefresh: true);
      expect(repository.forcedReads, 1);
      expect(
        cubit.state.pageSections('welcome').single.property('highlight'),
        'after',
      );
    },
  );
}

class _RefreshRepository implements DesignRepository {
  _RefreshRepository({required this._designs});

  final List<PublishedDesign> _designs;
  int _calls = 0;
  int forcedReads = 0;

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) {
    if (forceRefresh) forcedReads++;
    final index = _calls++ == 0 ? 0 : _designs.length - 1;
    return Future.value(_designs[index]);
  }

  @override
  Future<PublishedDesign?> lastKnown() async => _designs.first;
}

class _OutOfOrderRepository implements DesignRepository {
  _OutOfOrderRepository({required this.stale, required this.latest});

  final PublishedDesign stale;
  final PublishedDesign latest;
  final Completer<PublishedDesign?> _startup = Completer<PublishedDesign?>();
  int _calls = 0;

  void completeStartupRead() => _startup.complete(stale);

  @override
  Future<PublishedDesign?> published({bool forceRefresh = false}) {
    _calls++;
    return _calls == 1 ? _startup.future : Future.value(latest);
  }

  @override
  Future<PublishedDesign?> lastKnown() async => stale;
}

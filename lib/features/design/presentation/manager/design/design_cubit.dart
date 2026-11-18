import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        PostgresChangeEvent,
        PostgresChangeFilter,
        PostgresChangeFilterType,
        RealtimeChannel;

import 'package:new_coffee/core/services/supabase_service.dart';
import 'package:new_coffee/features/design/data/design_applier.dart';
import 'package:new_coffee/features/design/data/repositories/design_repository.dart';
import 'package:new_coffee/features/design/presentation/manager/design/design_state.dart';

/// يقرأ التصميم المنشور ويرسمه على رموز الألوان.
///
/// القراءة لا تُرمى عند أول عطل: المستودع يجيب بآخر طبعة صالحة عرفها الهاتف، أو
/// بلا جواب حين لم يعرف واحدة. عند بلا جواب يُترك ما على الشاشة من شكل — لأن
/// إقلاعًا طبّق منشورًا ثم انقطعت الشبكة في تحديث لا يعود بالتطبيق إلى الأصل.
class DesignCubit extends Cubit<DesignState> {
  DesignCubit({required this._repository}) : super(const DesignState()) {
    initialLoad = load();
    _openPublishedChannel();
  }

  final DesignRepository _repository;
  int _loadGeneration = 0;
  RealtimeChannel? _publishedChannel;

  /// First published-design read, exposed to screens whose behavior depends on
  /// the initial document rather than only its eventual rebuild.
  late final Future<void> initialLoad;

  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_loadGeneration;
    final design = await _repository.published(forceRefresh: forceRefresh);
    // A slower earlier read (for example the startup network request) must
    // never overwrite a newer preview document or a more recent refresh.
    if (isClosed || generation != _loadGeneration || design == null) return;
    applyPublishedTheme(design.theme);
    if (design == state.design) {
      if (!state.isLoaded) emit(state.copyWith(isLoaded: true));
      return;
    }
    emit(DesignState(design: design, isLoaded: true));
  }

  /// A publish writes `app_design_published` in `core.app_settings` (read by the
  /// client through the public bridge view). Without this channel a phone that
  /// already runs the customer app keeps the
  /// document it read at launch until a cold restart, which makes an edit look
  /// as if it never arrived. The callback re-reads (bypassing only the short
  /// in-memory cache) and emits a new state, so the whole tree repaints.
  void _openPublishedChannel() {
    if (!SupabaseService.isReady) return;
    try {
      _publishedChannel = SupabaseService.client
          .channel('design:published')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            // 226 writes core.app_settings; public.app_settings is only a
            // bridge view and views do not emit Postgres changes.
            schema: 'core',
            table: 'app_settings',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'key',
              value: SupabaseDesignRepository.settingsKey,
            ),
            callback: (_) => load(forceRefresh: true),
          )
          .subscribe();
    } catch (error) {
      if (kDebugMode) debugPrint('[Design] realtime failed: $error');
    }
  }

  @override
  Future<void> close() {
    final channel = _publishedChannel;
    _publishedChannel = null;
    if (channel != null && SupabaseService.isReady) {
      try {
        SupabaseService.client.removeChannel(channel);
      } catch (error) {
        if (kDebugMode) debugPrint('[Design] realtime close failed: $error');
      }
    }
    return super.close();
  }
}

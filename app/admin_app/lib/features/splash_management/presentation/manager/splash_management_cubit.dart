import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:admin_app/features/splash_management/data/splash_management_repository.dart';
import 'package:admin_app/features/splash_management/domain/splash_settings.dart';
import 'package:admin_app/features/splash_management/presentation/manager/splash_management_state.dart';

class SplashManagementCubit extends Cubit<SplashManagementState> {
  SplashManagementCubit({SplashManagementRepository? repository})
    : _repository = repository ?? SplashManagementRepository(),
      super(const SplashManagementState());

  final SplashManagementRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true, clearNotice: true));
    try {
      final snapshot = await _repository.load();
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          snapshot: snapshot,
          settings: snapshot.settings,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  void updateSettings(SplashSettings settings) {
    if (isClosed) return;
    emit(
      state.copyWith(settings: settings, clearError: true, clearNotice: true),
    );
  }

  void showValidationError(String code) {
    if (isClosed) return;
    emit(state.copyWith(error: code, clearNotice: true));
  }

  Future<void> saveDraft() async {
    final invalid = state.settings.validationIssue;
    if (invalid != null) {
      emit(state.copyWith(error: invalid));
      return;
    }
    await _runAction(() async {
      final document = SplashSettings.writeToDocument(
        state.snapshot?.document,
        state.settings,
      );
      await _repository.saveDraft(document);
      final old = state.snapshot;
      if (old != null) {
        emit(
          state.copyWith(
            snapshot: SplashManagementSnapshot(
              settings: state.settings,
              document: document,
              hasDraft: true,
              publishedVersion: old.publishedVersion,
              publishedAt: old.publishedAt,
            ),
            notice: 'saved',
          ),
        );
      }
    });
  }

  Future<void> publish() async {
    final invalid = state.settings.validationIssue;
    if (invalid != null) {
      emit(state.copyWith(error: invalid));
      return;
    }
    await _runAction(() async {
      final document = SplashSettings.writeToDocument(
        state.snapshot?.document,
        state.settings,
      );
      await _repository.saveDraft(document);
      final version = await _repository.publish(document);
      final published = await _repository.loadPublishedDocument();
      if (published == null ||
          jsonEncode(SplashSettings.fromDocument(published).toProperties()) !=
              jsonEncode(state.settings.toProperties())) {
        throw StateError('published_readback_mismatch');
      }
      final refreshed = await _repository.load();
      if (isClosed) return;
      emit(
        state.copyWith(
          snapshot: refreshed,
          settings: SplashSettings.fromDocument(published),
          notice: 'published:${version['version_number']}',
        ),
      );
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    emit(state.copyWith(isBusy: true, clearError: true, clearNotice: true));
    try {
      await action();
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: error.toString()));
    } finally {
      if (!isClosed) emit(state.copyWith(isBusy: false));
    }
  }
}

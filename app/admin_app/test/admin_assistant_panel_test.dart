import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/features/admin_assistant/data/admin_assistant_repository.dart';
import 'package:admin_app/features/admin_assistant/presentation/manager/admin_assistant_cubit.dart';
import 'package:admin_app/features/admin_assistant/presentation/widgets/admin_assistant_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class _ReplyingRepository extends AdminAssistantRepository {
  @override
  Future<String> reply({
    required List<Map<String, String>> history,
    required String query,
  }) async => 'رد تجريبي: $query';
}

class _OfflineRepository extends AdminAssistantRepository {
  @override
  Future<String> reply({
    required List<Map<String, String>> history,
    required String query,
  }) async => throw const AdminAssistantProviderException();

  @override
  Future<String> offlineReply(
    String query, {
    List<Map<String, String>> history = const [],
  }) async => 'إجابة محلية بدون الاتصال بالنموذج.';
}

void main() {
  setUp(() => AppLocale.instance.debugSet(AppLanguage.arabic));

  testWidgets('shows scope notice and sends a chat message', (tester) async {
    final cubit = AdminAssistantCubit(repository: _ReplyingRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 600,
              child: BlocProvider.value(
                value: cubit,
                child: AdminAssistantPanel(onClose: () {}),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('المنتجات والطلبات'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'اكتب وصفًا للمشروب');
    await tester.tap(find.byTooltip('إرسال'));
    await tester.pumpAndSettle();

    expect(find.text('اكتب وصفًا للمشروب'), findsOneWidget);
    expect(find.text('رد تجريبي: اكتب وصفًا للمشروب'), findsOneWidget);
  });

  test('uses an offline answer when the provider is unavailable', () async {
    final cubit = AdminAssistantCubit(repository: _OfflineRepository());
    addTearDown(cubit.close);

    await cubit.send('ما الفرق بين اللاتيه والكابتشينو؟');

    expect(cubit.state.hasError, isFalse);
    expect(
      cubit.state.messages.last.text,
      'إجابة محلية بدون الاتصال بالنموذج.',
    );
  });
}

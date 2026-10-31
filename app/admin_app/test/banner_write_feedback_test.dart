import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/locale/app_strings.dart';
import 'package:admin_app/core/search/admin_search_controller.dart';
import 'package:admin_app/core/theme/app_icons.dart';
import 'package:admin_app/features/banners/data/repositories/admin_banner_repository.dart';
import 'package:admin_app/features/banners/domain/entities/admin_banner.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/features/banners/presentation/pages/banner_page.dart';
import 'package:admin_app/features/banners/presentation/widgets/banner_data_dialog.dart';

/// كتابات البانر التي كان الرفض فيها يختفي: الإنشاء يُبتلع في نوع الدالة،
/// والحذف يبتلعه `catchError` فارغ. القاعدة ترفض — والرفض يجب أن يصل.
class _FakeBannerRepository extends AdminBannerRepository {
  _FakeBannerRepository({
    this.banners = const <AdminBanner>[],
    this.rejectCreate = false,
    this.rejectDelete = false,
  });

  final List<AdminBanner> banners;
  final bool rejectCreate;
  final bool rejectDelete;

  final List<AdminBanner> created = <AdminBanner>[];
  final List<String> deleted = <String>[];

  @override
  Future<List<AdminBanner>> loadBanners() async =>
      List<AdminBanner>.from(banners);

  @override
  Future<AdminBanner> createBanner(AdminBanner banner) async {
    // 022 يجعل كتابة البانر كلها لـ settings.write، فرفضها يصل بشيفرة 42501.
    if (rejectCreate) {
      throw const PostgrestException(
        message: 'missing permission: settings.write',
        code: '42501',
      );
    }
    created.add(banner);
    return AdminBanner(
      id: 'b1',
      titleAr: banner.titleAr,
      titleEn: banner.titleEn,
      imageUrl: banner.imageUrl,
      targetType: banner.targetType,
    );
  }

  @override
  Future<void> updateBanner(AdminBanner banner) async {}

  @override
  Future<void> deleteBanner(String id) async {
    // قيدٌ يرفض حذف بانر ما زال معلّقًا في واجهة العميل.
    if (rejectDelete) {
      throw const PostgrestException(
        message: 'banner is still pinned',
        code: '23514',
      );
    }
    deleted.add(id);
  }

  @override
  Future<void> setPublished(String id, bool value) async {}
}

const AdminBanner _banner = AdminBanner(
  id: 'b1',
  titleAr: 'عنوان',
  titleEn: 'Title',
  imageUrl: 'https://example.com/b.png',
  targetType: 'none',
);

void main() {
  test('رفض القاعدة للإنشاء يصل إلى المستدعي ولا يترك قائمة صامتة', () async {
    final cubit = AdminBannerCubit(
      repository: _FakeBannerRepository(rejectCreate: true),
    );
    addTearDown(cubit.close);

    await cubit.load();

    await expectLater(
      cubit.createBanner(_banner),
      throwsA(isA<PostgrestException>()),
    );
    expect(cubit.state.banners, isEmpty);
  });

  testWidgets('حفظٌ مرفوض يبقى الحوار مفتوحًا ويقول السبب', (tester) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = AdminBannerCubit(repository: _FakeBannerRepository());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerDataDialog(
            cubit: cubit,
            initialBanner: _banner,
            onSave: (banner) async => throw const PostgrestException(
              message: 'missing permission: settings.write',
              code: '42501',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, S.save));
    await tester.pumpAndSettle();

    expect(find.byType(BannerDataDialog), findsOneWidget);
    expect(find.text(S.errorNoPermission), findsOneWidget);
    expect(find.textContaining('settings.write'), findsNothing);
  });

  testWidgets('حذفٌ مرفوض يقول السبب لمن ضغط ولا يترك البانر بلا كلمة', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cubit = AdminBannerCubit(
      repository: _FakeBannerRepository(
        banners: const <AdminBanner>[_banner],
        rejectDelete: true,
      ),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BannerPage(
            searchController: AdminSearchController(),
            cubit: cubit,
            canManage: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.delete01).first);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(S.errorRejectedValues), findsOneWidget);
    expect(find.textContaining('banner is still pinned'), findsNothing);
    expect(cubit.state.banners, hasLength(1));
  });
}

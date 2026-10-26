import 'package:flutter_test/flutter_test.dart';

import 'package:admin_app/features/banners/data/models/admin_banner.dart';
import 'package:admin_app/features/banners/data/repositories/admin_banner_repository.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_cubit.dart';
import 'package:admin_app/features/banners/presentation/manager/admin_banner_state.dart';

class _FakeBannerRepository extends AdminBannerRepository {
  _FakeBannerRepository({this.banners = const <AdminBanner>[]});

  final List<AdminBanner> banners;
  final List<AdminBanner> created = <AdminBanner>[];
  final List<String> deleted = <String>[];

  @override
  Future<List<AdminBanner>> loadBanners() async =>
      List<AdminBanner>.from(banners);

  @override
  Future<AdminBanner> createBanner(AdminBanner banner) async {
    created.add(banner);
    return AdminBanner(
      id: 'b${created.length}',
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
  test('the cubit loads the banners', () async {
    final cubit = AdminBannerCubit(
      repository: _FakeBannerRepository(banners: const <AdminBanner>[_banner]),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AdminBannerStatus.ready);
    expect(cubit.state.banners, hasLength(1));
    expect(cubit.state.banners.first.titleEn, 'Title');
  });

  test('a banner is created and added to the list', () async {
    final repository = _FakeBannerRepository();
    final cubit = AdminBannerCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    final created = await cubit.createBanner(_banner);

    expect(created, isNotNull);
    expect(repository.created, hasLength(1));
    expect(cubit.state.banners, hasLength(1));
    expect(cubit.state.banners.first.id, 'b1');
  });

  test('a banner is deleted from the list', () async {
    final repository = _FakeBannerRepository(
      banners: const <AdminBanner>[_banner],
    );
    final cubit = AdminBannerCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();
    await cubit.deleteBanner('b1');

    expect(repository.deleted, <String>['b1']);
    expect(cubit.state.banners, isEmpty);
  });
}

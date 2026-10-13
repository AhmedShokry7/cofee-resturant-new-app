part of 'favorites_cubit.dart';

@immutable
class FavoritesState {
  const FavoritesState({required this.ids});

  final Set<String> ids;

  bool get isEmpty => ids.isEmpty;
}

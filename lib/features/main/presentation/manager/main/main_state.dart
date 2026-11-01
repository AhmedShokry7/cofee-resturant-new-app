part of 'main_cubit.dart';

@immutable
class MainState {
  const MainState({required this.index, this.visited = const {0}});

  final int index;

  /// The tabs that were opened at least once. A tab is built only after it is
  /// visited, so the first frame does not drag every page into it, and a page
  /// once built stays built so its state survives switching away.
  final Set<int> visited;

  bool isBuilt(int tab) => visited.contains(tab);

  MainState withTab(int index) =>
      MainState(index: index, visited: {...visited, index});
}

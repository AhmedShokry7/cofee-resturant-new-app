// Debug entry: boots the app exactly like the visual editor's simulator does
// when the editor asks for the categories page — the main shell with tab 1
// open — on the Windows desktop, where debug builds print every layout
// exception to the console. Used to diagnose the white categories page the
// editor's preview shows.
//
// نقطة إقلاع للتشخيص فقط: تفتح التطبيق على تبويبة التصنيفات كما يفعل
// المحرّر المرئي، فيوضح ويندوز (بوضع debug) سبب الشاشة البيضاء في السجل.
import 'package:new_coffee/features/main/presentation/manager/main/main_cubit.dart';

import 'package:new_coffee/main_preview.dart' as preview;

Future<void> main() async {
  MainCubit.initialTab = 1;
  // main_preview.main يعيد void — الإقلاع يبدأ من هنا ولا انتظار بعده.
  preview.main();
}
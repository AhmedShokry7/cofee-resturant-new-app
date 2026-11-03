import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:admin_app/core/error/failure.dart';
import 'package:admin_app/core/locale/app_locale.dart';
import 'package:admin_app/core/result/result.dart';
import 'package:admin_app/core/services/supabase_service.dart';
import 'package:admin_app/features/auth/data/models/admin_session_model.dart';
import 'package:admin_app/features/auth/domain/entities/invitation_accept_outcome.dart';
import 'package:admin_app/core/auth/admin_session.dart';
import 'package:admin_app/features/auth/domain/repositories/auth_repository.dart';

/// تنفيذ [AuthRepository] فوق Supabase Auth ووظيفة سجل الموظف.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository([this._client]);

  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? SupabaseService.client;

  /// صيغة الرمز كما تولده القاعدة: UUID واحد، لا نصّ حرّ يُرمى على الشبكة.
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  Future<Result<AdminSession>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.user == null) {
        return const ResultFailure<AdminSession>(UnknownFailure());
      }
      return Success<AdminSession>(await _loadStaffRecord());
    } on AuthException catch (error) {
      // رفض بيانات الدخول له رمز واضح؛ أي خطأ آخر لا يُعرض كبيانات خاطئة.
      // بعض إصدارات الخادم ترسل الحالة فقط بلا رمز، فتُعامل كرفض دخول أيضًا.
      final rejected =
          error.code == 'invalid_credentials' ||
          (error.code == null &&
              (error.statusCode == '400' || error.statusCode == '401'));
      if (rejected) {
        return const ResultFailure<AdminSession>(InvalidCredentialsFailure());
      }
      return ResultFailure<AdminSession>(UnknownFailure(error.message));
    } catch (error) {
      // بلا سجل موظف صالح لا معنى لجلسة Auth، فتُغلق قبل إبلاغ الواجهة.
      await _signOutQuietly();
      return ResultFailure<AdminSession>(_failureFor(error));
    }
  }

  @override
  Future<Result<AdminSession?>> restoreSession() async {
    if (!SupabaseService.isReady) {
      return const Success<AdminSession?>(null);
    }

    final supabase = _supabase;
    if (supabase.auth.currentSession == null) {
      return const Success<AdminSession?>(null);
    }

    try {
      return Success<AdminSession?>(await _loadStaffRecord());
    } catch (_) {
      // جلسة Auth موجودة لكن سجل الموظف غير صالح: تُغلق بهدوء، وهو السلوك
      // نفسه الذي كان متبعًا قبل الفصل بين الطبقات.
      await supabase.auth.signOut();
      return const Success<AdminSession?>(null);
    }
  }

  @override
  Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    await _supabase.auth.signOut();
  }

  @override
  Future<InvitationLookup> lookupInvitation(String token) async {
    final code = token.trim();
    // الرمز UUID تقرأه القاعدة وحدها؛ الفراغ أو ما ليس UUID لا يُرسل إليها أصلاً,
    // فيبقى الرفض محليًّا بدل خطأ network غامض على شاشة الدخول.
    if (!_uuidPattern.hasMatch(code)) {
      return const InvitationLookup.refused(InvitationAcceptOutcome.unknown);
    }
    try {
      final response = await _supabase.rpc(
        'admin_invitation_lookup',
        params: {'p_token': code},
      );
      return _invitationAnswer(response);
    } on PostgrestException {
      return const InvitationLookup.refused(InvitationAcceptOutcome.failed);
    }
  }

  @override
  Future<InvitationAcceptOutcome> acceptInvitation({
    required String token,
    required String email,
    required String password,
  }) async {
    final account = email.trim();
    final code = token.trim();
    // لا يُفتح حساب قبل أن يكون الرمز على صيغة مقبولة: وإلا بقي صاحبُه حسابًا
    // بلا سجلّ موظف، ولا دعوة تعمله.
    if (!_uuidPattern.hasMatch(code)) {
      return InvitationAcceptOutcome.unknown;
    }
    try {
      // الحساب لصاحبه: التطبيق ينشئه بكلمة مرور يختارها هو، والقاعدة وحدها
      // تقرر أن هذا الرمز يعمله موظفًا أم لا.
      final signUp = await _supabase.auth.signUp(
        email: account,
        password: password,
      );
      if (signUp.session == null) {
        // تأكيد البريد متوقّد، فلا جلسة تُسلَّم لها الدعوة.
        return InvitationAcceptOutcome.emailConfirmationNeeded;
      }
    } on AuthException catch (error) {
      if (!_isExistingAccount(error)) {
        return _isWeakPassword(error)
            ? InvitationAcceptOutcome.weakPassword
            : InvitationAcceptOutcome.failed;
      }
      // حساب سابق لنفس البريد: يُفتح بجلسة عادية قبل تسليم الرمز.
      try {
        await _supabase.auth.signInWithPassword(
          email: account,
          password: password,
        );
      } on AuthException {
        return InvitationAcceptOutcome.failed;
      }
    } catch (_) {
      return InvitationAcceptOutcome.failed;
    }

    try {
      final response = await _supabase.rpc(
        'admin_accept_invitation',
        params: {'p_token': code},
      );
      final outcome = _acceptAnswer(response);
      if (outcome != InvitationAcceptOutcome.accepted) {
        // رفضت القاعدة الرمز: لا تُترك جلسة مفتوحة بلا معنى.
        await _signOutQuietly();
      }
      return outcome;
    } on PostgrestException {
      await _signOutQuietly();
      return InvitationAcceptOutcome.failed;
    }
  }

  /// يجيب عن قراءة الرمز بنفس الأسماء التي تخرج من الدالتين.
  InvitationLookup _invitationAnswer(dynamic response) {
    if (response is! Map) {
      return const InvitationLookup.refused(InvitationAcceptOutcome.unknown);
    }
    if (response['ok'] != true) {
      return InvitationLookup.refused(_reasonFor('${response['reason']}'));
    }
    final role = _text(response['role_name_ar'], response['role_name_en']);
    final branch = _text(
      response['branch_name_ar'],
      response['branch_name_en'],
    );
    return InvitationLookup.found(
      InvitationPreview(
        email: '${response['email'] ?? ''}',
        fullName: '${response['full_name'] ?? ''}',
        // الدور بلا اسم محفوظ يُعرض برمزّه: أفضل من اختراع تسمية لا تعرفها
        // الشاشة، وأصدق من إخفائه.
        roleName: role.isNotEmpty ? role : '${response['role_code'] ?? ''}',
        branchName: branch.isEmpty ? null : branch,
      ),
    );
  }

  InvitationAcceptOutcome _acceptAnswer(dynamic response) {
    if (response is! Map) return InvitationAcceptOutcome.failed;
    if (response['ok'] == true) return InvitationAcceptOutcome.accepted;
    return _reasonFor('${response['reason']}');
  }

  static InvitationAcceptOutcome _reasonFor(String reason) => switch (reason) {
    'unknown' => InvitationAcceptOutcome.unknown,
    'accepted' => InvitationAcceptOutcome.alreadyAccepted,
    'cancelled' => InvitationAcceptOutcome.cancelled,
    'expired' => InvitationAcceptOutcome.expired,
    'email_mismatch' => InvitationAcceptOutcome.emailMismatch,
    'already_staff' => InvitationAcceptOutcome.alreadyStaff,
    'customer_history' => InvitationAcceptOutcome.customerHistory,
    _ => InvitationAcceptOutcome.failed,
  };

  static bool _isExistingAccount(AuthException error) {
    final message = error.message.toLowerCase();
    return message.contains('already registered') ||
        message.contains('already exists') ||
        message.contains('user already');
  }

  static bool _isWeakPassword(AuthException error) =>
      error.message.toLowerCase().contains('password');

  static String _text(Object? arabic, Object? english) {
    // الاسم بلغته، والأخرى احتياطًا حين تنقص إحداهما في القاعدة: لا تُعرض
    // تسمية عربية على شاشة إنجليزية ولا العكس.
    final prefersArabic = AppLocale.instance.isArabic;
    final first = '${(prefersArabic ? arabic : english) ?? ''}'.trim();
    if (first.isNotEmpty) return first;
    return '${(prefersArabic ? english : arabic) ?? ''}'.trim();
  }

  Future<AdminSession> _loadStaffRecord() async {
    // الدالة التي تنشئها سلسلة الترحيلات وتمنحها للموظف المسجّل.
    final raw = await _supabase.rpc('admin_get_my_staff_record');
    return AdminSessionModel.fromRpc(raw).toEntity();
  }

  Future<void> _signOutQuietly() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {
      // الجلسة قد تكون لم تُنشأ أصلًا؛ لا شيء يجب تصحيحه هنا.
    }
  }

  /// يترجم أخطاء الشبكة إلى أنواع [Failure] التي تعرفها الواجهة.
  Failure _failureFor(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      final notStaff =
          message.contains('not an active staff') ||
          message.contains('staff record not found') ||
          message.contains('not authenticated');
      if (notStaff) return const NotActiveStaffFailure();
      return UnknownFailure(error.message);
    }
    if (error is StateError) return const ConfigurationFailure();
    return UnknownFailure(error.toString());
  }
}

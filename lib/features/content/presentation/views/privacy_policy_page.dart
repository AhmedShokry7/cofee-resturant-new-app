import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:new_coffee/features/content/data/repositories/content_repository.dart';
import 'package:new_coffee/features/content/presentation/manager/legal_document/legal_document_cubit.dart';
import 'package:new_coffee/features/content/presentation/views/widgets/legal_document_view.dart';

/// The entry point of the privacy policy: it owns the cubit and the slug.
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const routeName = "privacyPolicyRoute";

  /// The slug the branch publishes this text under. The screen shows whatever
  /// that document holds, so the copy never has to ship with the app.
  static const documentSlug = 'privacy';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LegalDocumentCubit(
        repository: context.read<ContentRepository>(),
        slug: documentSlug,
      ),
      child: const LegalDocumentView(),
    );
  }
}

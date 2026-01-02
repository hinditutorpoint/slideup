import 'package:flutter/material.dart';
import '../../../../core/constants/legal_content.dart';
import '../widgets/legal_document_viewer.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentViewer(
      title: 'Terms of Service',
      content: LegalContent.termsOfService,
    );
  }
}

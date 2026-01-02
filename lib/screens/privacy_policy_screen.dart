import 'package:flutter/material.dart';
import '../../../../core/constants/legal_content.dart';
import '../widgets/legal_document_viewer.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentViewer(
      title: 'Privacy Policy',
      content: LegalContent.privacyPolicy,
    );
  }
}

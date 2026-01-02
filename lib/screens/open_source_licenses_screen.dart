import 'package:flutter/material.dart';
import '../../../../core/constants/legal_content.dart';
import '../widgets/legal_document_viewer.dart';

class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentViewer(
      title: 'Open Source Licenses',
      content: LegalContent.openSourceLicenses,
    );
  }
}

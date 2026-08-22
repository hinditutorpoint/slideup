import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/reel_editor/ui/reel_editor_screen.dart';
import '../features/video_editor/video_editor_screen.dart';

/// Premium editor picker: lets the user open [videoPath] in the Reel or
/// Video editor. Does nothing when dismissed.
Future<void> showEditorChooser(BuildContext context, String videoPath) async {
  final choice = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Edit Video',
    barrierColor: Colors.black.withAlpha(216),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, _, __) => _EditorChooserDialog(
      onPick: (value) => Navigator.pop(dialogContext, value),
      onCancel: () => Navigator.pop(dialogContext),
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.86, end: 1).animate(curved),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );

  if (choice == null || !context.mounted) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => choice == 'reel'
          ? ReelEditorScreen(mode: EditorMode.video, videoPath: videoPath)
          : VideoEditorScreen(videoPath: videoPath),
    ),
  );
}

class _EditorChooserDialog extends StatelessWidget {
  final ValueChanged<String> onPick;
  final VoidCallback onCancel;

  const _EditorChooserDialog({required this.onPick, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF14141B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(115),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 17, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 46),
                child: Text(
                  'Choose how you want to edit this clip',
                  style: TextStyle(color: Colors.white38, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 18),
              _OptionCard(
                gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                icon: Icons.movie_edit,
                title: 'Video Editor',
                subtitle: 'Full studio timeline, effects & export',
                onTap: () => onPick('video'),
              ),
              const SizedBox(height: 10),
              _OptionCard(
                gradient: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                icon: Icons.view_carousel_rounded,
                title: 'Reel Editor',
                subtitle: '9:16 canvas for quick reels & shorts',
                onTap: () => onPick('reel'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onCancel();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white38,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final List<Color> gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withAlpha(23),
        highlightColor: Colors.white.withAlpha(13),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withAlpha(89),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 21, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

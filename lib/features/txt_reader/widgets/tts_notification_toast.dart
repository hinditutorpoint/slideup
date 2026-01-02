import 'dart:async';
import 'package:flutter/material.dart';
import '../../speaker_player/tts_controller.dart';
import '../../speaker_player/services/tts_queue_manager.dart';

class TtsNotificationToast extends StatefulWidget {
  final EdgeInsets safeArea;

  const TtsNotificationToast({super.key, required this.safeArea});

  @override
  State<TtsNotificationToast> createState() => _TtsNotificationToastState();
}

class _TtsNotificationToastState extends State<TtsNotificationToast>
    with TickerProviderStateMixin {
  final List<_ToastItem> _toasts = [];
  StreamSubscription? _subscription;
  int _toastIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _subscription = TtsController.instance.notificationStream.listen(
      _onNotification,
    );
  }

  void _onNotification(TtsQueueNotification notification) {
    // Skip completed notifications (less noise)
    if (notification.type == TtsNotificationType.completed) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final toastItem = _ToastItem(
      id: _toastIdCounter++,
      notification: notification,
      controller: controller,
    );

    setState(() {
      _toasts.insert(0, toastItem);
      if (_toasts.length > 3) {
        final old = _toasts.removeLast();
        old.controller.dispose();
      }
    });

    controller.forward();

    // Auto dismiss - longer for "ready" notifications
    final duration = notification.type == TtsNotificationType.ready
        ? const Duration(seconds: 8)
        : const Duration(seconds: 4);

    Future.delayed(duration, () {
      _dismissToast(toastItem.id);
    });
  }

  void _dismissToast(int id) {
    final index = _toasts.indexWhere((t) => t.id == id);
    if (index == -1 || !mounted) return;

    final toast = _toasts[index];
    toast.controller.reverse().then((_) {
      if (mounted) {
        setState(() {
          _toasts.removeWhere((t) => t.id == id);
        });
        toast.controller.dispose();
      }
    });
  }

  void _onToastTap(_ToastItem toast) {
    final notification = toast.notification;

    if (notification.type == TtsNotificationType.ready &&
        notification.taskId != null) {
      TtsController.instance.playReadyTask(notification.taskId!);
    }

    _dismissToast(toast.id);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final toast in _toasts) {
      toast.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: widget.safeArea.top + 60,
      right: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _toasts.map((toast) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: toast.controller,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: toast.controller,
              child: _buildToastCard(toast),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToastCard(_ToastItem toast) {
    final notification = toast.notification;
    final color = _getColor(notification.type);
    final icon = _getIcon(notification.type);
    final isReady = notification.type == TtsNotificationType.ready;
    final isProcessing = notification.type == TtsNotificationType.processing;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isReady ? () => _onToastTap(toast) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner for processing, icon otherwise
                if (isProcessing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                else
                  Icon(icon, size: 18, color: Colors.white),

                const SizedBox(width: 10),

                // Message
                Flexible(
                  child: Text(
                    notification.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Play button for ready
                if (isReady) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Play',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Dismiss button
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _dismissToast(toast.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getColor(TtsNotificationType type) {
    switch (type) {
      case TtsNotificationType.queued:
        return Colors.blueGrey;
      case TtsNotificationType.processing:
        return Colors.blue;
      case TtsNotificationType.ready:
        return Colors.green;
      case TtsNotificationType.playing:
        return Colors.purple;
      case TtsNotificationType.completed:
        return Colors.teal;
      case TtsNotificationType.error:
        return Colors.red;
      case TtsNotificationType.cancelled:
        return Colors.grey;
    }
  }

  IconData _getIcon(TtsNotificationType type) {
    switch (type) {
      case TtsNotificationType.queued:
        return Icons.queue_music;
      case TtsNotificationType.processing:
        return Icons.hourglass_top;
      case TtsNotificationType.ready:
        return Icons.check_circle;
      case TtsNotificationType.playing:
        return Icons.volume_up;
      case TtsNotificationType.completed:
        return Icons.done_all;
      case TtsNotificationType.error:
        return Icons.error_outline;
      case TtsNotificationType.cancelled:
        return Icons.cancel_outlined;
    }
  }
}

class _ToastItem {
  final int id;
  final TtsQueueNotification notification;
  final AnimationController controller;

  _ToastItem({
    required this.id,
    required this.notification,
    required this.controller,
  });
}

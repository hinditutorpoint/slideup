import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../widgets/privacy_policy_dialog.dart';
import '../services/permission_service.dart';
import '../providers/media_provider.dart';
import 'main_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  /// Set to `true` after the first successful navigation to [MainScreen].
  /// Prevents the splash from re-appearing when [MaterialApp] rebuilds
  /// (e.g. on provider/theme change while the app is in the foreground or
  /// resumed from background).
  static bool splashCompleted = false;

  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _statusMessage = 'Initializing...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    // If splash already completed in this process (e.g. app resumed from
    // background and MaterialApp rebuilt), skip straight to MainScreen.
    if (SplashScreen.splashCompleted) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          }
        });
      }
      return;
    }

    final startTime = DateTime.now();
    const minSplashDuration = Duration(milliseconds: 2200);

    try {
      if (mounted) {
        setState(() {
          _statusMessage = 'Starting SlideUp...';
          _progress = 0.25;
        });
      }

      // 1. Mandatory First-Launch Privacy Policy & User Agreement consent (OPPO guideline)
      if (mounted) {
        final agreed = await PrivacyPolicyManager.ensurePrivacyAgreed(context);
        if (!agreed) {
          // User declined consent - leave the app gracefully instead of
          // freezing on the splash screen.
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SystemNavigator.pop();
            });
          }
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading media engine...';
          _progress = 0.55;
        });
      }

      // 2. Request permissions ONLY after privacy policy consent
      await PermissionService.instance.requestPermissions();

      if (mounted) {
        setState(() {
          _statusMessage = 'Ready';
          _progress = 0.90;
        });
      }

      // Trigger media scan in background without blocking screen transition.
      // The notifier is captured before navigation and the scan is started
      // only after MainScreen is on screen so the heavy FFprobe/FFmpeg work
      // never competes with the first frame (avoids ANR on low-end devices).
      final mediaNotifier = ref.read(mediaProvider.notifier);

      // Ensure splash screen remains visible for a comfortable duration
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }

      if (mounted) {
        setState(() => _progress = 1.0);
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          await Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 450),
              pageBuilder: (_, __, ___) => const MainScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );

          // Mark splash as completed so it never re-appears in this process.
          SplashScreen.splashCompleted = true;

          // Start the scan after MainScreen has been given a frame to render.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 800), () {
              unawaited(mediaNotifier.scanMedia().catchError((e) {
                debugPrint('Media scan background error: $e');
              }));
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Splash error: $e');
      if (mounted) {
        SplashScreen.splashCompleted = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Image.asset(
                                  'assets/icons/app_icon_foreground.png',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Slideup Media Player',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Professional Media Experience',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 64),
                            SizedBox(
                              width: 250,
                              child: Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _progress,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _statusMessage,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

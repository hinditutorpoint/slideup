import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../providers/media_provider.dart';
import 'main_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
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
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize database
      setState(() => _statusMessage = 'Setting up database...');
      await DatabaseService.instance.database;
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _progress = 0.3);

      // Request permissions
      setState(() => _statusMessage = 'Requesting permissions...');
      final hasPermission = await PermissionService.instance
          .requestPermissions();

      if (hasPermission) {
        debugPrint('✅ Permissions granted');
        setState(() => _progress = 0.6);
      } else {
        debugPrint('⚠️ Permissions denied - scanning may have limited access');
        setState(() => _statusMessage = 'Permissions limited - scanning...');
        setState(() => _progress = 0.6);
        // Continue anyway - user can still browse available files
      }

      // Scan media files (will work with available permissions)
      setState(() => _statusMessage = 'Scanning media files...');
      try {
        await ref.read(mediaProvider.notifier).scanMedia();
        setState(() => _progress = 1.0);
        debugPrint('✅ Media scan completed');
      } catch (e) {
        debugPrint('⚠️ Media scan error: $e');
        setState(() => _statusMessage = 'Media scan incomplete');
        setState(() => _progress = 0.9);
        // Continue - user can still use the app
      }

      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 500));

      // Navigate to main screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ Splash screen error: $e');
      setState(() => _statusMessage = 'Initializing...');
      // Still navigate after error - allow app to continue
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
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
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.slideshow,
                        size: 100,
                        color: Colors.white,
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
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                    const SizedBox(height: 64),
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
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
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'core/theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/authenticated_shell.dart';
import 'screens/trip_details_screen.dart';
import 'services/auth_service.dart';
import 'widgets/tripmate_bottom_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TripMateApp());
}

class TripMateApp extends StatelessWidget {
  const TripMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: AppTheme.lightPageSystemUi,
        ),
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.lightPageSystemUi,
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SessionScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/register': (context) => const RegisterScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const AuthenticatedShell(),
        '/friends': (context) =>
            const AuthenticatedShell(initialTab: TripMateTab.friends),
        '/profile': (context) =>
            const AuthenticatedShell(initialTab: TripMateTab.profile),
      },
      onGenerateRoute: (settings) {
        final segments = Uri.tryParse(settings.name ?? '')?.pathSegments;
        if (segments != null &&
            segments.length == 2 &&
            segments.first == 'trips') {
          final tripId = int.tryParse(segments[1]);
          if (tripId != null) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => TripDetailsScreen(tripId: tripId),
            );
          }
        }
        return null;
      },
    );
  }
}

class SessionScreen extends StatefulWidget {
  final AuthService? authService;

  const SessionScreen({super.key, this.authService});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final AuthService _authService = widget.authService ?? AuthService();
  late final AnimationController _animationController = AnimationController(
    vsync: this,
  );

  bool _sessionReady = false;
  bool _animationReady = false;
  bool _animationStarted = false;
  bool _reduceMotion = false;
  bool _hasNavigated = false;
  String _destination = '/welcome';
  Map<String, dynamic>? _routeArguments;

  @override
  void initState() {
    super.initState();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finishAnimation();
    });
    _checkSession();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations && !_reduceMotion) {
      _reduceMotion = true;
      if (_animationStarted) {
        _animationController.stop();
        _animationController.value = 1;
        _finishAnimation();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onAnimationLoaded(LottieComposition composition) {
    if (_animationStarted || _hasNavigated) return;
    _animationStarted = true;
    _animationController.duration = composition.duration;
    if (_reduceMotion || composition.duration == Duration.zero) {
      _animationController.value = 1;
      _finishAnimation();
    } else {
      _animationController.forward(from: 0);
    }
  }

  Widget _onAnimationError(
    BuildContext context,
    Object error,
    StackTrace? stack,
  ) {
    _animationStarted = true;
    _finishAnimation();
    return const Icon(Icons.send_rounded, size: 72, color: Color(0xFF634CD4));
  }

  void _finishAnimation() {
    if (_animationReady) return;
    _animationReady = true;
    _navigateWhenReady();
  }

  Future<void> _checkSession() async {
    bool authenticated = false;
    Map<String, dynamic>? user;

    try {
      final hasSession = await _authService.hasSavedSession();

      if (hasSession) {
        authenticated = await _authService.refreshSession();

        if (authenticated) {
          user = await _authService.getSavedUser();

          if (user == null) {
            authenticated = false;
          }
        }
      }
    } catch (_) {
      authenticated = false;
    }

    if (authenticated && user != null) {
      final name = user['name']?.toString() ?? 'viajante';
      _destination = '/home';
      _routeArguments = {'name': name};
    } else {
      _destination = '/welcome';
      _routeArguments = null;
    }
    if (!mounted) return;
    setState(() => _sessionReady = true);
    _navigateWhenReady();
  }

  void _navigateWhenReady() {
    if (!mounted || !_sessionReady || !_animationReady || _hasNavigated) {
      return;
    }
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        _destination,
        (route) => false,
        arguments: _routeArguments,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColorFiltered(
              key: const ValueKey('tripmate-splash-purple-tint'),
              colorFilter: const ColorFilter.mode(
                Color(0xFF634CD4),
                BlendMode.srcIn,
              ),
              child: Lottie.asset(
                'assets/animations/send_animated_icon.json',
                key: const ValueKey('tripmate-splash-lottie'),
                controller: _animationController,
                repeat: false,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                onLoaded: _onAnimationLoaded,
                errorBuilder: _onAnimationError,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'TripMate',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xFF191928),
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

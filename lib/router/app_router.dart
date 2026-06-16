import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/main_shell.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/camera/camera_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/history/event_detail_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/profile_screen.dart';
import '../screens/settings/developer_screen.dart';
import '../screens/settings/cameras_list_screen.dart';
import '../screens/settings/camera_setup_screen.dart';
import '../screens/settings/faces_screen.dart';
import '../screens/settings/face_enrollment_screen.dart';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final auth = authProvider.state;
        final path = state.uri.path;

        if (auth == AuthState.initial || path == '/splash') return null;

        final publicPaths = ['/login', '/register'];
        final isAuth = auth == AuthState.authenticated;

        if (!isAuth && !publicPaths.contains(path)) return '/login';
        if (isAuth && publicPaths.contains(path)) return '/dashboard';

        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (ctx, st) => const SplashScreen()),
        GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
        GoRoute(path: '/register', builder: (ctx, st) => const RegisterScreen()),

        // Profile + hidden developer tools (outside shell — full-screen pages)
        GoRoute(path: '/profile', builder: (ctx, st) => const ProfileScreen()),
        GoRoute(
          path: '/settings/developer',
          builder: (ctx, st) => const DeveloperScreen(),
        ),

        // Camera management (outside shell so the app bar works independently)
        GoRoute(
          path: '/settings/cameras',
          builder: (ctx, st) => const CamerasListScreen(),
        ),
        GoRoute(
          path: '/settings/cameras/add',
          builder: (ctx, st) => const CameraSetupScreen(),
        ),
        GoRoute(
          path: '/settings/cameras/:id',
          builder: (ctx, st) =>
              CameraSetupScreen(cameraId: st.pathParameters['id']),
        ),
        GoRoute(
          path: '/settings/faces',
          builder: (ctx, st) => const FacesScreen(),
        ),
        GoRoute(
          path: '/settings/faces/enroll',
          builder: (ctx, st) =>
              FaceEnrollmentScreen(personName: st.extra as String? ?? ''),
        ),

        StatefulShellRoute.indexedStack(
          builder: (ctx, st, nav) => MainShell(navigationShell: nav),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/dashboard',
                  builder: (ctx, st) => const DashboardScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/camera',
                  builder: (ctx, st) => const CameraScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/history',
                builder: (ctx, st) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (ctx, st) =>
                        EventDetailScreen(eventId: st.pathParameters['id']!),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/settings',
                  builder: (ctx, st) => const SettingsScreen()),
            ]),
          ],
        ),
      ],
    );

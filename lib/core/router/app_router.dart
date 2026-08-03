import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/ai/presentation/ai_analytics_screen.dart';
import '../../features/ai/presentation/assistant_screen.dart';
import '../../features/ai/presentation/insights_screen.dart';
import '../../features/ai/presentation/knowledge_screen.dart';
import '../../features/ai/presentation/plant_doctor_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/billing/presentation/upgrade_screen.dart';
import '../../features/settings/presentation/account_settings_screen.dart';
import '../../features/equipment/presentation/equipment_screen.dart';
import '../../features/expenses/presentation/add_expense_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/help/presentation/help_center_screen.dart';
import '../../features/harvests/presentation/add_harvest_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/knowledge_hub/presentation/articles_screen.dart';
import '../../features/livestock/presentation/livestock_screen.dart';
import '../../features/map/presentation/farm_map_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/nursery/presentation/nursery_screen.dart';
import '../../features/pests/presentation/pests_screen.dart';
import '../../features/records/presentation/records_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/sales/presentation/add_sale_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../../features/water/presentation/water_screen.dart';
import '../../features/weather/presentation/weather_screen.dart';
import '../../features/workers/presentation/workers_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final refresh = _GoRouterRefreshStream(client);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = client.auth.currentSession != null;
      final loc = state.matchedLocation;
      final onAuthRoute =
          loc == '/login' || loc == '/register' || loc == '/forgot-password';

      // A password-recovery link signs the user in with a temporary session;
      // funnel them to the reset screen until they set a new password.
      if (refresh.recovering) {
        return loc == '/reset-password' ? null : '/reset-password';
      }
      if (loc == '/reset-password') return loggedIn ? '/' : '/login';

      if (!loggedIn && !onAuthRoute) return '/login';
      if (loggedIn && onAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/add-expense',
        builder: (_, __) => const AddExpenseScreen(),
      ),
      GoRoute(
        path: '/add-harvest',
        builder: (_, __) => const AddHarvestScreen(),
      ),
      GoRoute(
        path: '/add-sale',
        builder: (_, __) => const AddSaleScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (_, __) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/records',
        builder: (_, __) => const RecordsScreen(),
      ),
      GoRoute(
        path: '/tasks',
        builder: (_, __) => const TasksScreen(),
      ),
      GoRoute(
        path: '/workers',
        builder: (_, __) => const WorkersScreen(),
      ),
      GoRoute(
        path: '/equipment',
        builder: (_, __) => const EquipmentScreen(),
      ),
      GoRoute(
        path: '/water',
        builder: (_, __) => const WaterScreen(),
      ),
      GoRoute(
        path: '/weather',
        builder: (_, __) => const WeatherScreen(),
      ),
      GoRoute(
        path: '/nursery',
        builder: (_, __) => const NurseryScreen(),
      ),
      GoRoute(
        path: '/livestock',
        builder: (_, __) => const LivestockScreen(),
      ),
      GoRoute(
        path: '/pests',
        builder: (_, __) => const PestsScreen(),
      ),
      GoRoute(
        path: '/map',
        builder: (_, __) => const FarmMapScreen(),
      ),
      GoRoute(
        path: '/plant-doctor',
        builder: (_, __) => const PlantDoctorScreen(),
      ),
      GoRoute(
        path: '/assistant',
        builder: (_, __) => const AssistantScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (_, __) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/ai-analytics',
        builder: (_, __) => const AiAnalyticsScreen(),
      ),
      GoRoute(
        path: '/knowledge',
        builder: (_, __) => const KnowledgeScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/knowledge-hub',
        builder: (_, __) => const ArticlesScreen(mode: KbMode.read),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (_, __) => const FeedbackScreen(),
      ),
      GoRoute(
        path: '/help',
        builder: (_, __) => const HelpCenterScreen(),
      ),
      GoRoute(
        path: '/upgrade',
        builder: (_, __) => const UpgradeScreen(),
      ),
      GoRoute(
        path: '/account',
        builder: (_, __) => const AccountSettingsScreen(),
      ),
    ],
  );
});

/// Refreshes go_router only when the signed-in *status* actually flips
/// (sign-in / sign-out). Ignoring routine `tokenRefreshed` / `userUpdated`
/// events keeps the router from rebuilding — and popping imperatively pushed
/// routes — during long operations like an AI request.
class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(this._client) {
    _loggedIn = _client.auth.currentSession != null;
    _sub = _client.auth.onAuthStateChange.listen((state) {
      final loggedIn = _client.auth.currentSession != null;
      final event = state.event;

      // Enter recovery mode on the recovery link; leave it once the password
      // has been updated (userUpdated) or the user signs out.
      var changed = false;
      if (event == AuthChangeEvent.passwordRecovery && !recovering) {
        recovering = true;
        changed = true;
      } else if (recovering &&
          (event == AuthChangeEvent.userUpdated ||
              event == AuthChangeEvent.signedOut)) {
        recovering = false;
        changed = true;
      }

      if (loggedIn != _loggedIn) {
        _loggedIn = loggedIn;
        changed = true;
      }
      if (changed) notifyListeners();
    });
  }

  final SupabaseClient _client;
  late bool _loggedIn;

  /// True between following a recovery link and setting a new password.
  bool recovering = false;
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

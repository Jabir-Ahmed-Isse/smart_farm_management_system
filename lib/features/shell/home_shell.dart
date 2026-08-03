import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/auth/roles.dart';
import '../../core/config/public_flags.dart';
import '../../core/l10n/l10n.dart';
import '../../core/offline/sync_banner.dart';
import '../../core/offline/sync_service.dart';
import '../ai/presentation/plant_doctor_screen.dart';
import '../auth/presentation/maintenance_screen.dart';
import '../auth/presentation/suspended_screen.dart';
import '../community/presentation/community_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../farms/farms_screen.dart';
import '../profile/data/profile_repository.dart';
import '../profile/profile_screen.dart';

/// The primary authenticated shell with a bottom navigation bar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Watch connectivity and flush anything queued from a previous session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncServiceProvider)
        ..start()
        ..drain();
    });
  }

  static const _screens = [
    DashboardScreen(),
    FarmsScreen(),
    PlantDoctorScreen(),
    CommunityScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);

    // Block suspended accounts from the whole app. While the profile is still
    // loading (or on error) we fall through to the normal shell rather than
    // flashing the block screen.
    final suspended = ref.watch(myProfileProvider).valueOrNull?.suspended ?? false;
    if (suspended) return const SuspendedScreen();

    // During maintenance, block everyone except admins (who need in to turn it
    // off). Defaults to open if the flag hasn't loaded yet.
    final maintenance =
        ref.watch(publicFlagsProvider).valueOrNull?.maintenanceMode ?? false;
    if (maintenance && !ref.watch(isAdminProvider)) {
      return const MaintenanceScreen();
    }

    return Scaffold(
      body: Column(
        children: [
          const SyncBanner(),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Symbols.home),
            selectedIcon: const Icon(Symbols.home, fill: 1),
            label: t.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.agriculture),
            selectedIcon: const Icon(Symbols.agriculture, fill: 1),
            label: t.navFarms,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.psychiatry),
            selectedIcon: const Icon(Symbols.psychiatry, fill: 1),
            label: t.navAiDoctor,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.groups),
            selectedIcon: const Icon(Symbols.groups, fill: 1),
            label: t.navCommunity,
          ),
          NavigationDestination(
            icon: const Icon(Symbols.person),
            selectedIcon: const Icon(Symbols.person, fill: 1),
            label: t.navProfile,
          ),
        ],
      ),
    );
  }
}

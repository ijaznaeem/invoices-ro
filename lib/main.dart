import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/clients_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/payment_options_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/templates_screen.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const LedgerApp());
}

class LedgerApp extends StatefulWidget {
  const LedgerApp({super.key});

  @override
  State<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends State<LedgerApp> {
  final AppState _appState = AppState();
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _appState.bootstrap();
  }

  void _toggleTheme() {
    setState(() => _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _appState,
      child: MaterialApp(
        title: 'Ledger',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: HomeShell(onToggleTheme: _toggleTheme, themeMode: _themeMode),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const HomeShell(
      {super.key, required this.onToggleTheme, required this.themeMode});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _titles = ['Dashboard', 'Recurring', 'Invoices', 'Clients'];
  static const _screens = [
    DashboardScreen(),
    TemplatesScreen(),
    InvoicesScreen(),
    ClientsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Catch up on any recurring invoices that came due while the app was
    // backgrounded — the mobile equivalent of the web app's hourly server check.
    if (state == AppLifecycleState.resumed) {
      AppStateScope.of(context).runGenerationCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Run generation check',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final generated = await state.runGenerationCheck();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(generated > 0
                          ? 'Generated $generated invoice(s).'
                          : 'No invoices were due.')),
                );
              }
            },
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Activity',
                icon: const Icon(Icons.notifications_active_rounded),
                onPressed: () {
                  setState(() => _index = 0);
                  state.markNotificationsRead();
                },
              ),
              if (state.unreadNotifications > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '${state.unreadNotifications}',
                      style: const TextStyle(fontSize: 9, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: _LedgerDrawer(
        currentIndex: _index,
        themeMode: widget.themeMode,
        onSelectTab: (i) {
          setState(() => _index = i);
          Navigator.pop(context);
        },
        onToggleTheme: widget.onToggleTheme,
      ),
      body: DecoratedBox(
        decoration: AppTheme.backgroundDecoration(context),
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_rounded),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Recurring'),
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_checkout_rounded),
              selectedIcon: Icon(Icons.shopping_cart_checkout_rounded),
              label: 'Invoices'),
          NavigationDestination(
              icon: Icon(Icons.people_alt_rounded),
              selectedIcon: Icon(Icons.people_alt_rounded),
              label: 'Clients'),
        ],
      ),
    );
  }
}

// ─── Professional nav drawer ─────────────────────────────────────────────────

class _LedgerDrawer extends StatelessWidget {
  final int currentIndex;
  final ThemeMode themeMode;
  final ValueChanged<int> onSelectTab;
  final VoidCallback onToggleTheme;

  const _LedgerDrawer({
    required this.currentIndex,
    required this.themeMode,
    required this.onSelectTab,
    required this.onToggleTheme,
  });

  static const _navItems = [
    (
      icon: Icons.dashboard_rounded,
      activeIcon: Icons.dashboard_rounded,
      label: 'Dashboard'
    ),
    (
      icon: Icons.account_balance_wallet_rounded,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Recurring'
    ),
    (
      icon: Icons.shopping_cart_checkout_rounded,
      activeIcon: Icons.shopping_cart_checkout_rounded,
      label: 'Invoices'
    ),
    (
      icon: Icons.people_alt_rounded,
      activeIcon: Icons.people_alt_rounded,
      label: 'Clients'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isDark = themeMode == ThemeMode.dark;
    final optionCount = state.paymentOptions.length;

    return Drawer(
      child: Column(
        children: [
          // ─── Branded header ──────────────────────────────────────
          _DrawerHeader(businessName: state.businessSettings.businessName),

          const SizedBox(height: 8),

          // ─── Main navigation ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'NAVIGATION',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ...List.generate(_navItems.length, (i) {
            final item = _navItems[i];
            final selected = currentIndex == i;
            return ListTile(
              leading: Icon(selected ? item.activeIcon : item.icon,
                  color:
                      selected ? Theme.of(context).colorScheme.primary : null),
              title: Text(item.label),
              selected: selected,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              onTap: () => onSelectTab(i),
            );
          }),

          const Divider(indent: 16, endIndent: 16, height: 24),

          // ─── Business tools ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'BUSINESS',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_rounded),
            title: const Text('Payment Options'),
            trailing: optionCount > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$optionCount',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer),
                    ),
                  )
                : null,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaymentOptionsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded),
            title: const Text('Settings'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    initialSettings: AppStateScope.of(context).businessSettings,
                  ),
                ),
              );
            },
          ),

          const Spacer(),
          const Divider(indent: 16, endIndent: 16, height: 1),

          // ─── Appearance toggle ───────────────────────────────────
          SwitchListTile(
            secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            title: const Text('Dark mode'),
            value: isDark,
            onChanged: (_) => onToggleTheme(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Drawer header with brand mark ───────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final String businessName;
  const _DrawerHeader({required this.businessName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LedgerColors.primary, LedgerColors.secondary],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand mark
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Center(
              child: Text(
                'L',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1,
                  // Use the serif font for the brand mark if cached
                  fontFamily: GoogleFonts.fraunces().fontFamily,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // App name
          Text(
            'LEDGER',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
              fontFamily: GoogleFonts.fraunces().fontFamily,
            ),
          ),
          const SizedBox(height: 2),
          // Business name (dynamic)
          Text(
            businessName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

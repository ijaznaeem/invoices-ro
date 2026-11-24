import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'db/database_helper.dart';
import 'models/models.dart';
import 'services/firebase_sync_service.dart';
import 'screens/clients_screen.dart';
import 'screens/backup_restore_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/accounts_screens.dart';
import 'screens/invoices_screen.dart';
import 'screens/payment_options_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/templates_screen.dart';
import 'state/app_state.dart';
import 'state/app_state_scope.dart';
import 'theme/app_theme.dart';
import 'widgets/ledger_glass_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await FirebaseSyncService.instance.ensureInitialized();
  DatabaseHelper.instance
      .addChangeListener(FirebaseSyncService.instance.schedulePush);
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
      AppStateScope.of(context).runBackupCheck();
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
                        color: LedgerColors.accent, shape: BoxShape.circle),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const LedgerGlassBackground(),
          IndexedStack(index: _index, children: _screens),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? LedgerColors.darkRule
                  : LedgerColors.border,
            ),
          ),
        ),
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.autorenew_rounded),
            selectedIcon: Icon(Icons.autorenew_rounded),
            label: 'Recurring',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Invoices',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'Clients',
          ),
        ],
        ),
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
    final drawerTextColor =
        isDark ? LedgerColors.darkInk : LedgerColors.textPrimary;
    final drawerSectionColor =
        isDark ? LedgerColors.darkMuted : LedgerColors.textSecondary;
    final optionCount = state.paymentOptions.length;

    return Drawer(
      child: Column(
        children: [
          _DrawerHeader(settings: state.businessSettings),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'NAVIGATION',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: drawerSectionColor,
                        ),
                  ),
                ),
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = currentIndex == i;
                  return ListTile(
                    leading: Icon(selected ? item.activeIcon : item.icon,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : null),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : drawerTextColor,
                      ),
                    ),
                    selected: selected,
                    selectedTileColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    onTap: () => onSelectTab(i),
                  );
                }),
                const Divider(indent: 16, endIndent: 16, height: 24),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'ACCOUNTS',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: drawerSectionColor,
                        ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: Text('Accounts ledger',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AccountsLedgerScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.summarize_rounded),
                  title: Text('Cash report',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CashReportScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_rounded),
                  title: Text('Cash receipts',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CashReceiptsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.money_off_csred_rounded),
                  title: Text('Expenses',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ExpensesScreen()),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16, height: 24),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'BUSINESS',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: drawerSectionColor,
                        ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: Text('Payment Options',
                      style: TextStyle(color: drawerTextColor)),
                  trailing: optionCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$optionCount',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer),
                          ),
                        )
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PaymentOptionsScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.backup_rounded),
                  title: Text('Backup & Restore',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const BackupRestoreScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_rounded),
                  title: Text('Settings',
                      style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          initialSettings:
                              AppStateScope.of(context).businessSettings,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_rounded),
                  title:
                      Text('About', style: TextStyle(color: drawerTextColor)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  onTap: () =>
                      _showAboutDialog(context, state.businessSettings),
                ),
              ],
            ),
          ),
          const Divider(indent: 16, endIndent: 16, height: 1),
          SwitchListTile(
            secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
            title: Text('Dark mode', style: TextStyle(color: drawerTextColor)),
            value: isDark,
            onChanged: (_) => onToggleTheme(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showAboutDialog(
      BuildContext context, BusinessSettings businessSettings) {
    final logoPath = businessSettings.logoPath;
    final hasLogo = logoPath != null &&
        logoPath.trim().isNotEmpty &&
        File(logoPath).existsSync();

    showAboutDialog(
      context: context,
      applicationName: 'Ledger — Invoices RO',
      applicationVersion: 'Version 1.0.0 (Build 1)',
      applicationIcon: Container(
        width: 58,
        height: 58,
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: LedgerColors.primary,
          shape: BoxShape.circle,
        ),
        child: hasLogo
            ? Image.file(File(logoPath), fit: BoxFit.cover)
            : Image.asset('assets/icons/ledger_app_icon.png',
                fit: BoxFit.cover),
      ),
      children: const [
        SizedBox(height: 10),
        Text(
          'A private, on-device invoicing application for creating one-off '
          'and recurring invoices, managing clients, producing PDFs, and '
          'backing up business records.',
        ),
        SizedBox(height: 12),
        Text(
          'Invoice and client data is stored locally on this device unless '
          'you explicitly create or upload a backup.',
        ),
      ],
    );
  }
}

// ─── Drawer header with brand mark ───────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  final BusinessSettings settings;
  const _DrawerHeader({required this.settings});

  @override
  Widget build(BuildContext context) {
    final logoPath = settings.logoPath;
    final hasLogo = logoPath != null &&
        logoPath.trim().isNotEmpty &&
        File(logoPath).existsSync();
    final contact = [
      settings.email,
      settings.phone,
    ].where((value) => value?.trim().isNotEmpty == true).join('  •  ');

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [LedgerColors.primary, Color(0xFF7A6CFF)],
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
          Container(
            width: 58,
            height: 58,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: hasLogo
                ? Image.file(
                    File(logoPath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _CompanyInitial(name: settings.businessName),
                  )
                : Image.asset(
                    'assets/icons/ledger_app_icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _CompanyInitial(name: settings.businessName),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            settings.businessName.trim().isEmpty
                ? 'INVOICES RO'
                : settings.businessName,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: .5,
              fontFamily: GoogleFonts.roboto().fontFamily,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            settings.businessSubtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              contact,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: .82),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (settings.address?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text(
              settings.address!,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: .72),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompanyInitial extends StatelessWidget {
  final String name;
  const _CompanyInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? 'L' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1,
          fontFamily: GoogleFonts.roboto().fontFamily,
        ),
      ),
    );
  }
}

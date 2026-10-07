import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_version.dart';
import '../services/app_exit.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../theme/boutix_brand.dart';
import '../theme/dos_theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/dos_dialog.dart';
import '../widgets/dos_menu.dart';
import '../widgets/dos_menu_bar.dart';
import '../widgets/dos_screen.dart';
import 'auth/login_screen.dart';
import 'movements/stock_movements_screen.dart';
import 'pos/pos_screen.dart';
import 'products/products_screen.dart';
import 'sales/sales_history_screen.dart';
import 'settings/settings_screen.dart';
import 'statistics/statistics_screen.dart';
import 'stock/stock_screen.dart';
import 'suppliers/suppliers_screen.dart';
import 'users/users_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Map<String, dynamic>? _kpis;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final _auth = AuthService.instance;
  final _menuBarKey = GlobalKey<DosMenuBarState>();
  final _mainMenuKey = GlobalKey<DosMenuState>();
  String _shopName = 'Ma Boutique';

  List<String> get _menuItems {
    final items = <String>[
      'CAISSE / POINT DE VENTE',
      'ARTICLES / CATALOGUE',
      'FOURNISSEURS',
      'STOCK RÉEL',
      'MOUVEMENTS DE STOCK',
      'HISTORIQUE DES VENTES',
    ];
    if (_auth.isAdmin) {
      items.insert(1, 'STATISTIQUES');
      items.add('UTILISATEURS');
      items.add('PARAMÈTRES');
    }
    items.addAll([
      'DÉCONNEXION',
      'QUITTER BOUTIX PRO',
    ]);
    return items;
  }

  List<DosMenuBarItem> get _topBarItems {
    final items = <DosMenuBarItem>[];
    if (_auth.isAdmin) {
      items.add(DosMenuBarItem(
        label: 'Paramètres',
        hotkey: 'P',
        onSelect: () => _open(const SettingsScreen()),
      ));
    }
    items.add(DosMenuBarItem(
      label: 'À propos',
      hotkey: 'A',
      onSelect: () => BoutixAboutDialog.show(context),
    ));
    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  void _restoreMenuFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _mainMenuKey.currentState?.focusMenu();
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _loadKpis();
    _restoreMenuFocus();
  }

  Future<void> _loadKpis() async {
    try {
      final kpis = await DatabaseHelper.instance.getDashboardKpis();
      final shop =
          await DatabaseHelper.instance.getSetting('shop_name', 'Ma Boutique');
      if (mounted) {
        setState(() {
          _kpis = kpis;
          _shopName = shop;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _kpis = const {};
          _shopName = 'Ma Boutique';
        });
      }
    }
  }

  Future<void> _logout() async {
    _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _onSelect(int index) async {
    final label = _menuItems[index];

    switch (label) {
      case 'CAISSE / POINT DE VENTE':
        await _open(const PosScreen());
      case 'STATISTIQUES':
        await _open(const StatisticsScreen());
      case 'ARTICLES / CATALOGUE':
        await _open(const ProductsScreen());
      case 'FOURNISSEURS':
        await _open(const SuppliersScreen());
      case 'STOCK RÉEL':
        await _open(const StockScreen());
      case 'MOUVEMENTS DE STOCK':
        await _open(const StockMovementsScreen());
      case 'HISTORIQUE DES VENTES':
        await _open(const SalesHistoryScreen());
      case 'UTILISATEURS':
        await _open(const UsersScreen());
      case 'PARAMÈTRES':
        await _open(const SettingsScreen());
      case 'DÉCONNEXION':
        await _logout();
        return;
      case 'QUITTER BOUTIX PRO':
        final quit = await DosDialog.confirm(
          context,
          title: 'Quitter',
          message: 'Voulez-vous vraiment quitter BOUTIX PRO ?',
        );
        if (quit == true) await AppExit.quit();
        return;
    }
    await _loadKpis();
    _restoreMenuFocus();
  }

  @override
  Widget build(BuildContext context) {
    final now = _dateFormat.format(DateTime.now());
    final k = _kpis;
    final user = _auth.currentUser;
    final currency = NumberFormat.currency(locale: 'fr_FR', symbol: '');

    return DosScreen(
      title: 'MENU PRINCIPAL — $_shopName',
      subtitle:
          'v${AppVersion.label} — Connecté: ${user?.fullName ?? user?.username ?? "?"} (${user?.roleLabel ?? "?"}) — $now',
      requestScreenFocus: false,
      menuBar: DosMenuBar(
        key: _menuBarKey,
        items: _topBarItems,
        onBlur: _restoreMenuFocus,
      ),
      helpLines: const [
        '↑↓ : Modules | ENTREE : Ouvrir | ECHAP : Quitter | F10 : Barre BIOS',
        'Alt+P/A : Paramètres / À propos',
        'F1: Caisse | F2: Articles | F3: Ventes | F4: Stock',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final bar = _menuBarKey.currentState;
        if (bar != null && bar.isActive) {
          final result = bar.handleKey(event);
          if (result == KeyEventResult.handled) return result;
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            bar.blurBar();
            _restoreMenuFocus();
            return KeyEventResult.ignored;
          }
          return result;
        }

        final alt = HardwareKeyboard.instance.isAltPressed;
        if (bar != null && bar.tryHotkey(event.logicalKey, altPressed: alt)) {
          return KeyEventResult.handled;
        }

        final items = _menuItems;
        int indexFor(String label) => items.indexOf(label);

        switch (event.logicalKey) {
          case LogicalKeyboardKey.f10:
            bar?.focusBar();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f1:
            _onSelect(indexFor('CAISSE / POINT DE VENTE'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f2:
            _onSelect(indexFor('ARTICLES / CATALOGUE'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            _onSelect(indexFor('HISTORIQUE DES VENTES'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f4:
            _onSelect(indexFor('STOCK RÉEL'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            _onSelect(indexFor('QUITTER BOUTIX PRO'));
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'GESTION BOUTIQUE & CAISSE',
              child: DosMenu(
                key: _mainMenuKey,
                items: _menuItems,
                onSelect: _onSelect,
                onCancel: () =>
                    _onSelect(_menuItems.indexOf('QUITTER BOUTIX PRO')),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'TABLEAU DE BORD',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statLine('CA aujourd\'hui',
                        currency.format(k?['ca_today'] ?? 0)),
                    _statLine('Ventes aujourd\'hui', '${k?['ventes_today'] ?? '...'}'),
                    _statLine('CA du mois', currency.format(k?['ca_month'] ?? 0)),
                    _statLine('Ventes du mois', '${k?['ventes_month'] ?? '...'}'),
                    _statLine('Articles', '${k?['products_count'] ?? '...'}'),
                    _statLine(
                      'Stock bas',
                      '${k?['low_stock_count'] ?? '...'}',
                      alert: (k?['low_stock_count'] as int? ?? 0) > 0,
                    ),
                    const SizedBox(height: 12),
                    Text('─' * 36, style: DosTheme.dim(size: 12)),
                    const SizedBox(height: 6),
                    Text(BoutixBrand.name, style: DosTheme.dim()),
                    Text(BoutixBrand.tagline, style: DosTheme.dim(size: 12)),
                    Text('Agent: ${user?.fullName ?? user?.username ?? "?"}',
                        style: DosTheme.dim(size: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, {bool alert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text('$label:', style: DosTheme.text(size: 13))),
          Text(
            value,
            style: DosTheme.text(
              size: 13,
              weight: FontWeight.bold,
              color: alert ? DosColors.warning : DosColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

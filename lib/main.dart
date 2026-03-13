import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'screens/catalog_screen.dart';
import 'screens/orders_history_screen.dart';
import 'screens/product_management_screen.dart';

const _kPrimaryColor = Color(0xFF4C6FFF);
const _kPrimaryPressedColor = Color(0xFF3D5AFE);
const _kBackgroundColor = Color(0xFFF6F7FB);
const _kCardColor = Color(0xFFFFFFFF);
const _kImageBackgroundColor = Color(0xFFF8F9FD);
const _kPrimaryTextColor = Color(0xFF1A1D1F);
const _kSecondaryTextColor = Color(0xFF6B7280);
const _kDividerColor = Color(0xFFE6E8EC);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'كتالوج المنتجات',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            primary: _kPrimaryColor,
            onPrimary: Colors.white,
            surface: _kCardColor,
            onSurface: _kPrimaryTextColor,
            onSurfaceVariant: _kSecondaryTextColor,
            outline: _kDividerColor,
            surfaceContainerHighest: _kImageBackgroundColor,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: _kBackgroundColor,
          dividerColor: _kDividerColor,
          cardTheme: CardThemeData(
            color: _kCardColor,
            elevation: 0.8,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: _kBackgroundColor,
            foregroundColor: _kPrimaryTextColor,
            scrolledUnderElevation: 2,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _kCardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kDividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kDividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kPrimaryColor),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textTheme: const TextTheme(
            titleLarge: TextStyle(color: _kPrimaryTextColor, fontWeight: FontWeight.w600),
            titleMedium: TextStyle(color: _kPrimaryTextColor, fontWeight: FontWeight.w600),
            titleSmall: TextStyle(color: _kPrimaryTextColor, fontWeight: FontWeight.w600),
            bodyLarge: TextStyle(color: _kPrimaryTextColor),
            bodyMedium: TextStyle(color: _kSecondaryTextColor),
            bodySmall: TextStyle(color: _kSecondaryTextColor),
          ),
          splashColor: _kPrimaryPressedColor.withValues(alpha: 0.10),
          highlightColor: _kPrimaryPressedColor.withValues(alpha: 0.08),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedIndex = index);
        Navigator.pop(context);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: Text(
            'كتالوج المنتجات',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        const NavigationDrawerDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('الكتالوج'),
        ),
        NavigationDrawerDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: Selector<OrderProvider, int>(
            selector: (_, orderProvider) => orderProvider.pendingOrderCount,
            builder: (context, pendingCount, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الطلبات'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          label: Text('إدارة المنتجات'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final drawer = _buildDrawer(context);
    switch (_selectedIndex) {
      case 1:
        return OrdersHistoryScreen(drawer: drawer);
      case 2:
        return ProductManagementScreen(drawer: drawer);
      default:
        return CatalogScreen(drawer: drawer);
    }
  }
}

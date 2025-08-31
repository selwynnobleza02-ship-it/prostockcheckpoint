import 'package:flutter/material.dart';
import 'package:prostock/screens/admin/admin_activity_monitor.dart';
import 'package:prostock/screens/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../pos/pos_screen.dart';
import '../inventory/inventory_screen.dart';
import '../report_tabs/reports_screen.dart';
import '../customers/customers_screen.dart';
import '../../services/offline_manager.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;

  final List<Widget> _screens = [
    const AdminActivityMonitor(),
    const POSScreen(),
    const InventoryScreen(),
    const CustomersScreen(),
    const ReportsScreen(),
  ];

  final List<IconData> _icons = [
    Icons.admin_panel_settings,
    Icons.point_of_sale,
    Icons.inventory,
    Icons.people,
    Icons.assessment,
  ];

  final List<String> _labels = [
    'Activity',
    'POS',
    'Items',
    'Clients',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(
      _screens.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      ),
    );

    _scaleAnimations = _animationControllers.map((controller) {
      return Tween<double>(
        begin: 1.0,
        end: 0.95,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onNavTap(int index) async {
    if (index == _selectedIndex) return;

    // Animate the pressed button
    await _animationControllers[index].forward();
    await _animationControllers[index].reverse();

    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Admin - ${authProvider.username}'),
        backgroundColor: Colors.indigo[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              await OfflineManager.instance.clearCache();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.3, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Container(
          key: ValueKey(_selectedIndex),
          child: _screens[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_screens.length, (index) {
                final isSelected = index == _selectedIndex;
                return Expanded(
                  child: AnimatedBuilder(
                    animation: _scaleAnimations[index],
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimations[index].value,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            splashColor: Colors.indigo.withValues(alpha: .3),
                            highlightColor: Colors.indigo.withValues(alpha: .1),
                            onTap: () => _onNavTap(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 12.0,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: isSelected
                                    ? Colors.indigo.withValues(alpha: .1)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 100),
                                    curve: Curves.easeInOutCubic,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: isSelected
                                          ? Colors.indigo[600]
                                          : Colors.transparent,
                                    ),
                                    child: AnimatedScale(
                                      scale: isSelected ? 1.1 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 100,
                                      ),
                                      curve: Curves.easeInOutBack,
                                      child: Icon(
                                        _icons[index],
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[600],
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 100),
                                    curve: Curves.easeInOutCubic,
                                    style: TextStyle(
                                      fontSize: isSelected ? 11 : 10,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.indigo[600]
                                          : Colors.grey[600],
                                    ),
                                    child: Text(
                                      _labels[index],
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

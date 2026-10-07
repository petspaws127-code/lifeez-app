import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'tasks_screen.dart';
import 'money_screen.dart';
import 'calendar_screen.dart';
import 'more_screen.dart';

/// Bottom navigation with the 5 main tabs.
class MainTabs extends StatefulWidget {
  static const route = '/home';
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    TasksScreen(),
    MoneyScreen(),
    CalendarScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline_rounded),
              label: 'Tasks'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Money'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              label: 'Calendar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded), label: 'More'),
        ],
      ),
    );
  }
}

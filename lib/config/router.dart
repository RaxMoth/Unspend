import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_screen.dart';
import '../features/app_blocker/presentation/pages/app_blocker_screen.dart';

/// App Router Configuration
final goRouter = GoRouter(
  initialLocation: '/app-blocker',
  routes: [
    GoRoute(
      path: '/app-blocker',
      name: 'app_blocker',
      builder: (context, state) => const AppBlockerScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Error')),
    body: Center(
      child: Text('Route not found: ${state.fullPath}'),
    ),
  ),
);

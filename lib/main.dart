import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'services/photo_provider.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/upload_screen.dart';
import 'screens/batch_upload_screen.dart';
import 'screens/photo_detail_screen.dart';
import 'screens/photo_edit_screen.dart';
import 'models/photo.dart';
import 'utils/debug_helper.dart';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. 定义路由
final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => AuthService.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        // 从URL中提取token
        final token = state.uri.queryParameters['token'];
        return ResetPasswordScreen(token: token);
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadScreen(),
    ),
    GoRoute(
      path: '/batch-upload',
      builder: (context, state) => const BatchUploadScreen(),
    ),
    GoRoute(
      path: '/photo-detail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null) {
          final photo = extra['photo'] as Photo?;
          final photos = extra['photos'] as List<Photo>?;
          if (photo != null && photos != null) {
            return PhotoDetailScreen(photo: photo, photos: photos);
          }
        }
        return const LoginScreen(); // 回退到登录页
      },
    ),
    GoRoute(
      path: '/photo-edit',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null) {
          final photo = extra['photo'] as Photo?;
          if (photo != null) {
            return PhotoEditScreen(photo: photo);
          }
        }
        return const LoginScreen();
      },
    ),
  ],
  redirect: (context, state) {
    // 启动画面不需要重定向
    if (state.matchedLocation == '/splash') {
      return null;
    }
    // 响应式登录状态
    final loggedIn = AuthService.loginState.value;
    final publicRoutes = [
      '/login',
      '/register',
      '/reset-password',
      '/forgot-password'
    ];
    final isPublicRoute = publicRoutes.contains(state.matchedLocation);
    if (!loggedIn && !isPublicRoute) {
      return '/login';
    }
    if (loggedIn && (state.matchedLocation == '/login' || state.matchedLocation == '/register')) {
      return '/';
    }
    return null;
  },
  refreshListenable: AuthService.loginState, // 关键：让 GoRouter 响应登录状态变化
);

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 2. 使用URL策略移除#
  usePathUrlStrategy();
  
  await Supabase.initialize(
    url: 'https://ufxuetpndfqqvuapfjli.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmeHVldHBuZGZxcXZ1YXBmamxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzkyNTEsImV4cCI6MjA2Njc1NTI1MX0.8476yI58Hvm99mo67R-Ga-AfZh9QGlFfLdX0yDavNlQ',
  );
  await _preloadData();
  runApp(const MyApp());
}

// 预加载数据
Future<void> _preloadData() async {
  try {
    // 初始化认证服务
    await AuthService.initialize();
    
    // 减少预热延迟
    await Future.delayed(const Duration(milliseconds: 50));
    
    // 在后台运行网络连接测试，不阻塞启动
    Future.microtask(() async {
      try {
    final debugResults = await DebugHelper.testNetworkConnection();
    DebugHelper.printDebugInfo(debugResults);
      } catch (e) {
        developer.log('网络测试失败: $e');
      }
    });
    
    // 在后台预热健康检查端点，不阻塞启动
    Future.microtask(() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.14.64:8080/health'),
        ).timeout(const Duration(seconds: 3));
      developer.log('API预热成功: ${response.statusCode}');
    } catch (e) {
      developer.log('API预热失败: $e');
    }
    });
  } catch (e) {
    // 静默处理错误，不影响应用启动
    developer.log('预加载数据失败: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    // 用 ValueListenableBuilder 包裹，确保 MaterialApp.router 响应登录状态变化
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.loginState,
      builder: (context, loggedIn, child) {
        return ChangeNotifierProvider(
          create: (context) {
            final provider = PhotoProvider();
            if (loggedIn) {
              Future.microtask(() async {
                await provider.loadPhotos(forceRefresh: false);
              });
            }
            return provider;
          },
          child: MaterialApp.router(
            key: navigatorKey,
            routerConfig: _router,
            title: '妈妈的照片',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2196F3),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'services/photo_provider.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'utils/debug_helper.dart';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. 定义路由
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => AuthService.isLoggedIn ? const SplashScreen() : const LoginScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
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
  ],
  redirect: (context, state) {
    // 简单的重定向逻辑，可以根据需要扩展
    final loggedIn = AuthService.isLoggedIn;
    final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/reset-password' || state.matchedLocation == '/forgot-password';

    // 如果用户未登录，且访问的不是登录、重置密码或忘记密码页，则重定向到登录页
    if (!loggedIn && !loggingIn) {
      return '/login';
    }
    // 如果用户已登录，但尝试访问登录页，则重定向到主页
    if (loggedIn && loggingIn) {
      return '/';
    }
    
    return null; // 无需重定向
  },
);


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
    
    // 预热API服务
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 运行完整的网络连接测试
    final debugResults = await DebugHelper.testNetworkConnection();
    DebugHelper.printDebugInfo(debugResults);
    
    // 在后台预热健康检查��点
    try {
      final response = await http.get(
        Uri.parse('http://192.168.14.64:8080/health'),
      ).timeout(const Duration(seconds: 5));
      developer.log('API预热成功: ${response.statusCode}');
    } catch (e) {
      developer.log('API预热失败: $e');
    }
  } catch (e) {
    // 静默处理错误，不影响应用启动
    developer.log('预加载数据失败: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = PhotoProvider();
        // 如果用户已登录，立即加载照片
        if (AuthService.isLoggedIn) {
          // 延迟加载，确保Provider已创建
          Future.microtask(() => provider.loadPhotos());
        }
        return provider;
      },
      // 3. 使用MaterialApp.router
      child: MaterialApp.router(
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
  }
}


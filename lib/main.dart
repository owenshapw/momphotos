import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'services/photo_provider.dart';
import 'screens/splash_screen.dart';
import 'dart:developer' as developer;

void main() {
  // 启用Flutter绑定
  WidgetsFlutterBinding.ensureInitialized();
  
  // 预加载数据
  _preloadData();
  
  runApp(const MyApp());
}

// 预加载数据
Future<void> _preloadData() async {
  try {
    // 预热API服务
    await Future.delayed(const Duration(milliseconds: 100));
    
    // 在后台预热健康检查端点
    try {
      final response = await http.get(
        Uri.parse('https://momphotos.onrender.com/health'),
      ).timeout(const Duration(seconds: 5));
      developer.log('API预热成功: ${response.statusCode}');
    } catch (e) {
      developer.log('API预热失败: $e');
    }
  } catch (e) {
    // 静默处理错误，不影响应用启动
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = PhotoProvider();
        return provider;
      },
      child: MaterialApp(
        title: '妈妈的照片',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

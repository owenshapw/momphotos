import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/photo_provider.dart';
import 'home_screen.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  bool _isLoading = false;
  String _loadingText = '正在准备...';
  int _loadingStep = 0;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // 设置动画
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    // 开始动画
    _startAnimations();
  }

  void _startAnimations() async {
    // 淡入动画
    await _fadeController.forward();
    
    // 缩放动画
    await _scaleController.forward();
    
    // 开始加载数据
    _startLoading();
  }

  void _startLoading() async {
    setState(() {
      _isLoading = true;
    });
    
    final photoProvider = context.read<PhotoProvider>();
    final startTime = DateTime.now();
    
    // 优化加载步骤
    _updateLoadingStep('正在准备...', 1);
    await Future.delayed(const Duration(milliseconds: 200));
    
    // 实际加载照片数据（使用缓存）
    try {
      // 检查用户是否已登录
      if (AuthService.isLoggedIn) {
        print('🔐 启动画面：用户已登录，开始加载照片');
        await photoProvider.loadPhotos();
        _updateLoadingStep('准备就绪', 2);
      } else {
        print('🔐 启动画面：用户未登录，跳过照片加载');
        _updateLoadingStep('准备就绪', 2);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      // 即使加载失败也继续进入主界面
      print('❌ 启动画面：照片加载失败: $e');
      _updateLoadingStep('准备就绪', 2);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // 减少最小显示时间到1.5秒
    final totalTime = DateTime.now().difference(startTime);
    if (totalTime.inMilliseconds < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - totalTime.inMilliseconds));
    }
    
    // 导航到主界面
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  void _updateLoadingStep(String text, int step) {
    if (mounted) {
      setState(() {
        _loadingText = text;
        _loadingStep = step;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用图标
            AnimatedBuilder(
              animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // 如果图标加载失败，显示默认图标
                            return const Icon(
                              Icons.photo_library,
                              size: 50,
                              color: Color(0xFF2196F3),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // 应用名称
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: const Text(
                    '妈妈的照片',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // 副标题
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value * 0.8,
                  child: const Text(
                    '珍藏美好回忆',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 48),
            
            // 加载指示器
            if (_isLoading) ...[
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: Column(
                      children: [
                        // 进度指示器
                        SizedBox(
                          width: 160,
                          child: LinearProgressIndicator(
                            value: _loadingStep / 2,
                            backgroundColor: Colors.white.withValues(alpha: 0.3),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // 加载文字
                        Text(
                          _loadingText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
} 
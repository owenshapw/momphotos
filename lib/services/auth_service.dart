import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static const String _userKey = 'user';
  static const String _tokenKey = 'token';
  static const String _appVersionKey = 'app_version';
  static const String _currentAppVersion = '1.0.1+3'; // 当前应用版本，匹配pubspec.yaml
  
  static User? _currentUser;
  static String? _currentToken;
  static String? _lastUserId; // 跟踪上次登录的用户ID

  // 获取当前用户
  static User? get currentUser => _currentUser;
  
  // 获取当前token
  static String? get currentToken => _currentToken;
  
  // 检查是否已登录
  static bool get isLoggedIn => _currentUser != null && _currentToken != null;

  // 初始化认证服务（从本地存储加载用户信息）
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 检查是否是新安装或版本更新
      final savedVersion = prefs.getString(_appVersionKey);
      final isNewInstall = savedVersion == null;
      final isVersionUpdate = savedVersion != null && savedVersion != _currentAppVersion;
      
      if (isNewInstall || isVersionUpdate) {
        developer.log('🆕 检测到新安装或版本更新，清除之前的登录状态');
        developer.log('  保存的版本: $savedVersion');
        developer.log('  当前版本: $_currentAppVersion');
        
        // 清除所有登录信息
        await prefs.remove(_userKey);
        await prefs.remove(_tokenKey);
        _currentUser = null;
        _currentToken = null;
        _lastUserId = null;
        ApiService.clearAuthToken();
        ApiService.clearCache();
        
        // 保存当前版本号
        await prefs.setString(_appVersionKey, _currentAppVersion);
        developer.log('✅ 新安装/版本更新处理完成');
        return;
      }
      
      // 正常加载登录信息
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      
      if (userJson != null && token != null) {
        _currentUser = User.fromJson(json.decode(userJson));
        _currentToken = token;
        _lastUserId = _currentUser!.id; // 设置最后登录的用户ID
        ApiService.setAuthToken(token);
        developer.log('🔐 自动登录用户: ${_currentUser!.username} (ID: ${_currentUser!.id})');
      } else {
        developer.log('🔐 没有找到已保存的登录信息');
      }
    } catch (e) {
      developer.log('❌ 加载登录信息失败: $e');
      // 如果加载失败，清除本地存储
      await logout();
    }
  }

  // 保存用户信息到本地存储
  static Future<void> _saveUserData(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user.toJson()));
    await prefs.setString(_tokenKey, token);
    
    _currentUser = user;
    _currentToken = token;
    _lastUserId = user.id; // 更新最后登录的用户ID
    ApiService.setAuthToken(token);
  }

  // 用户注册
  static Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await ApiService.register(
      username: username,
      email: email,
      password: password,
    );
    // 保存用户信息
    await _saveUserData(response.user, response.token);
    return response;
  }

  // 用户登录
  static Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await ApiService.login(
      username: username,
      password: password,
    );
    
    // 检查是否是不同用户登录
    final isDifferentUser = _lastUserId != null && _lastUserId != response.user.id;
    
    developer.log('🔍 用户切换检测:');
    developer.log('  上次用户ID: $_lastUserId');
    developer.log('  当前用户ID: ${response.user.id}');
    developer.log('  是否不同用户: $isDifferentUser');
    
    // 保存用户信息
    await _saveUserData(response.user, response.token);
    
    // 如果是不同用户登录，清除缓存
    if (isDifferentUser) {
      ApiService.clearCache();
      developer.log('🔄 用户切换，已清除缓存');
    } else {
      developer.log('✅ 同一用户，保持缓存');
    }
    
    return response;
  }

  // 用户登出
  static Future<void> logout() async {
    developer.log('🚪 用户登出，清除所有状态');
    developer.log('  当前用户: ${_currentUser?.username} (ID: ${_currentUser?.id})');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    
    _currentUser = null;
    _currentToken = null;
    _lastUserId = null; // 清除最后登录的用户ID
    ApiService.clearAuthToken();
    ApiService.clearCache(); // 清除缓存
    
    developer.log('✅ 登出完成，所有状态已清除');
  }

  // 验证token有效性
  static Future<bool> validateToken() async {
    if (!isLoggedIn) return false;
    
    final isValid = await ApiService.validateToken();
    if (!isValid) {
      // token无效，清除登录状态
      await logout();
    }
    return isValid;
  }

  // 忘记密码
  static Future<String> forgotPassword({required String email}) async {
    return await ApiService.forgotPassword(email: email);
  }

  // 更新用户信息
  static Future<void> updateUserInfo(User user) async {
    _currentUser = user;
    if (_currentToken != null) {
      await _saveUserData(user, _currentToken!);
    }
  }

  // 注销账户
  static Future<void> deleteAccount() async {
    try {
      await ApiService.deleteAccount();
      
      // 清除本地存储和状态
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenKey);
      
      _currentUser = null;
      _currentToken = null;
      _lastUserId = null;
      ApiService.clearAuthToken();
      ApiService.clearCache();
      
      developer.log('🗑️ 账户已注销，所有数据已清除');
    } catch (e) {
      developer.log('❌ 注销账户失败: $e');
      rethrow;
    }
  }
} 
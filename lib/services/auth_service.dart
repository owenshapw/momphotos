import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  static const String _userKey = 'user';
  static const String _tokenKey = 'token';
  
  static User? _currentUser;
  static String? _currentToken;

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
      final userJson = prefs.getString(_userKey);
      final token = prefs.getString(_tokenKey);
      
      if (userJson != null && token != null) {
        _currentUser = User.fromJson(json.decode(userJson));
        _currentToken = token;
        ApiService.setAuthToken(token);
      }
    } catch (e) {
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
    ApiService.setAuthToken(token);
  }

  // 用户注册
  static Future<AuthResponse> register({
    required String phone,
    required String password,
  }) async {
    final response = await ApiService.register(
      phone: phone,
      password: password,
    );
    // 保存用户信息
    await _saveUserData(response.user, response.token);
    return response;
  }

  // 用户登录
  static Future<AuthResponse> login({
    required String phone,
    required String password,
  }) async {
    final response = await ApiService.login(
      phone: phone,
      password: password,
    );
    // 保存用户信息
    await _saveUserData(response.user, response.token);
    return response;
  }

  // 用户登出
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_tokenKey);
    
    _currentUser = null;
    _currentToken = null;
    ApiService.clearAuthToken();
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

  // 更新用户信息
  static Future<void> updateUserInfo(User user) async {
    _currentUser = user;
    if (_currentToken != null) {
      await _saveUserData(user, _currentToken!);
    }
  }
} 
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

class DebugHelper {
  static const String baseUrl = 'http://192.168.14.64:8080';
  
  /// 测试网络连接
  static Future<Map<String, dynamic>> testNetworkConnection() async {
    final results = <String, dynamic>{};
    
    try {
      // 测试健康检查
      developer.log('🔍 测试健康检查...');
      final healthResponse = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));
      
      results['health'] = {
        'statusCode': healthResponse.statusCode,
        'success': healthResponse.statusCode == 200,
        'data': healthResponse.statusCode == 200 
            ? json.decode(healthResponse.body) 
            : null,
      };
      
      // 测试照片API
      developer.log('🔍 测试照片API...');
      final photosResponse = await http.get(
        Uri.parse('$baseUrl/photos'),
      ).timeout(const Duration(seconds: 10));
      
      results['photos'] = {
        'statusCode': photosResponse.statusCode,
        'success': photosResponse.statusCode == 200,
        'count': photosResponse.statusCode == 200 
            ? json.decode(photosResponse.body).length 
            : 0,
      };
      
      // 测试数据库
      developer.log('🔍 测试数据库连接...');
      final dbResponse = await http.get(
        Uri.parse('$baseUrl/test-db'),
      ).timeout(const Duration(seconds: 10));
      
      results['database'] = {
        'statusCode': dbResponse.statusCode,
        'success': dbResponse.statusCode == 200,
        'data': dbResponse.statusCode == 200 
            ? json.decode(dbResponse.body) 
            : null,
      };
      
      results['overall'] = {
        'success': results['health']['success'] && 
                   results['photos']['success'] && 
                   results['database']['success'],
        'timestamp': DateTime.now().toIso8601String(),
      };
      
    } on SocketException catch (e) {
      results['error'] = {
        'type': 'SocketException',
        'message': '网络连接失败: $e',
        'suggestion': '请检查Flask服务器是否正在运行',
      };
    } on TimeoutException catch (e) {
      results['error'] = {
        'type': 'TimeoutException',
        'message': '请求超时: $e',
        'suggestion': '请检查网络连接或增加超时时间',
      };
    } catch (e) {
      results['error'] = {
        'type': 'Unknown',
        'message': '未知错误: $e',
        'suggestion': '请检查应用配置',
      };
    }
    
    return results;
  }
  
  /// 打印调试信息
  static void printDebugInfo(Map<String, dynamic> results) {
    developer.log('🔍 网络连接调试信息:');
    developer.log('时间: ${results['overall']?['timestamp'] ?? 'N/A'}');
    
    if (results.containsKey('error')) {
      developer.log('❌ 错误: ${results['error']['type']}');
      developer.log('   消息: ${results['error']['message']}');
      developer.log('   建议: ${results['error']['suggestion']}');
      return;
    }
    
    developer.log('✅ 健康检查: ${results['health']['success'] ? '成功' : '失败'} (${results['health']['statusCode']})');
    developer.log('✅ 照片API: ${results['photos']['success'] ? '成功' : '失败'} (${results['photos']['statusCode']}) - ${results['photos']['count']} 张照片');
    developer.log('✅ 数据库: ${results['database']['success'] ? '成功' : '失败'} (${results['database']['statusCode']})');
    
    if (results['overall']['success']) {
      developer.log('🎉 所有测试通过！');
    } else {
      developer.log('⚠️ 部分测试失败');
    }
  }
} 
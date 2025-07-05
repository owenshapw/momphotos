import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;

  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _error = "错误：重置令牌无效或缺失。\n\n请检查您的邮箱，点击邮件中的重置密码链接来访问此页面。\n\n如果您没有收到邮件，请检查垃圾邮件文件夹，或重新申请密码重置。";
        _isLoading = false;
      });
      return;
    }

    final htmlContent = _buildHtml(widget.token!);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _error = "加载页面失败: ${error.description}";
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.dataFromString(
          htmlContent,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('重置密码'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // 返回登录页
            context.go('/login');
          },
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/forgot-password');
                      },
                      child: const Text('重新申请密码重置'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  String _buildHtml(String token) {
    // 将之前独立的HTML文件内容内联到这里
    return """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>重置密码</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
                background-color: #f4f7f6;
            }
            .container {
                background-color: #fff;
                padding: 40px;
                border-radius: 8px;
                box-shadow: 0 4px 10px rgba(0,0,0,0.1);
                width: 100%;
                max-width: 400px;
                text-align: center;
            }
            h1 {
                color: #333;
                margin-bottom: 20px;
            }
            .form-group {
                margin-bottom: 20px;
                text-align: left;
            }
            label {
                display: block;
                margin-bottom: 8px;
                color: #555;
                font-weight: bold;
            }
            input[type="password"] {
                width: 100%;
                padding: 12px;
                border: 1px solid #ddd;
                border-radius: 4px;
                box-sizing: border-box;
                font-size: 16px;
            }
            button {
                width: 100%;
                padding: 12px;
                border: none;
                border-radius: 4px;
                background-color: #007bff;
                color: white;
                font-size: 16px;
                font-weight: bold;
                cursor: pointer;
                transition: background-color 0.3s;
            }
            button:hover {
                background-color: #0056b3;
            }
            button:disabled {
                background-color: #ccc;
                cursor: not-allowed;
            }
            .message {
                margin-top: 20px;
                padding: 10px;
                border-radius: 4px;
                display: none;
            }
            .message.success {
                background-color: #d4edda;
                color: #155724;
                display: block;
            }
            .message.error {
                background-color: #f8d7da;
                color: #721c24;
                display: block;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>设置新密码</h1>
            <form id="resetForm">
                <div class="form-group">
                    <label for="password">新密码</label>
                    <input type="password" id="password" name="password" required minlength="6">
                </div>
                <div class="form-group">
                    <label for="confirmPassword">确认新密码</label>
                    <input type="password" id="confirmPassword" name="confirmPassword" required minlength="6">
                </div>
                <button type="submit" id="submitButton">重置密码</button>
            </form>
            <div id="message" class="message"></div>
        </div>

        <script>
            document.addEventListener('DOMContentLoaded', () => {
                const form = document.getElementById('resetForm');
                const passwordInput = document.getElementById('password');
                const confirmPasswordInput = document.getElementById('confirmPassword');
                const messageDiv = document.getElementById('message');
                const submitButton = document.getElementById('submitButton');
                const token = "$token";

                form.addEventListener('submit', async (event) => {
                    event.preventDefault();
                    
                    if (passwordInput.value !== confirmPasswordInput.value) {
                        showMessage('错误：两次输入的密码不一致。', 'error');
                        return;
                    }

                    if (passwordInput.value.length < 6) {
                        showMessage('错误：密码至少需要6位。', 'error');
                        return;
                    }

                    submitButton.disabled = true;
                    submitButton.textContent = '正在处理...';
                    
                    try {
                        const apiUrl = 'https://momphotos.onrender.com/auth/reset-password';
                        
                        const response = await fetch(apiUrl, {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                token: token,
                                password: passwordInput.value,
                            }),
                        });

                        const data = await response.json();

                        if (response.ok) {
                            showMessage(data.message, 'success');
                            form.style.display = 'none';
                        } else {
                            showMessage(data.error || '发生未知错误。', 'error');
                            submitButton.disabled = false;
                            submitButton.textContent = '重置密码';
                        }
                    } catch (error) {
                        showMessage('无法连接到服务器，请稍后重试。', 'error');
                        submitButton.disabled = false;
                        submitButton.textContent = '重置密码';
                    }
                });

                function showMessage(msg, type) {
                    messageDiv.textContent = msg;
                    messageDiv.className = 'message ' + type;
                }
            });
        </script>
    </body>
    </html>
    """;
  }
}

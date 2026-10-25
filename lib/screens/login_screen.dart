import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = false; // false = đăng nhập, true = đăng ký
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final client = Supabase.instance.client;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    EasyLoading.show(
        status: _isRegister ? 'Đang tạo tài khoản...' : 'Đang đăng nhập...');
    try {
      if (_isRegister) {
        final res = await client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': _nameController.text.trim()},
        );
        // Nếu chưa tắt "Confirm email" thì session sẽ null
        if (res.session == null) {
          EasyLoading.showInfo('Hãy kiểm tra email để xác nhận tài khoản.');
          return;
        }
      } else {
        await client.auth.signInWithPassword(email: email, password: password);
      }
      // Đăng nhập thành công: main.dart tự chuyển sang màn chính
      EasyLoading.dismiss();
    } on AuthException catch (e) {
      EasyLoading.showError(_translateError(e.message));
    } catch (_) {
      EasyLoading.showError('Có lỗi xảy ra, vui lòng thử lại.');
    }
  }

  String _translateError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Sai email hoặc mật khẩu.';
    }
    if (msg.contains('already registered')) {
      return 'Email này đã được đăng ký.';
    }
    if (msg.contains('password should be at least')) {
      return 'Mật khẩu phải có ít nhất 6 ký tự.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.button(context),
                    child: const Icon(Icons.content_cut,
                        size: 44, color: Colors.amberAccent),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'CLASSIC BARBER SHOP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppColors.title(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister ? 'Tạo tài khoản mới' : 'Đăng nhập để đặt lịch',
                    style: TextStyle(color: AppColors.muted(context)),
                  ),
                  const SizedBox(height: 28),
                  if (_isRegister) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputStyle('Họ và tên', Icons.person),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Vui lòng nhập họ tên'
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputStyle('Email', Icons.email),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Vui lòng nhập email';
                      if (!text.contains('@') || !text.contains('.')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _hidePassword,
                    decoration: _inputStyle('Mật khẩu', Icons.lock).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_hidePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      if (value.length < 6) {
                        return 'Mật khẩu phải có ít nhất 6 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.button(context),
                        foregroundColor: Colors.amberAccent,
                      ),
                      onPressed: _submit,
                      child: Text(_isRegister ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isRegister = !_isRegister),
                    child: Text(
                      _isRegister
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                      style: TextStyle(color: AppColors.title(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.title(context)),
        filled: true,
        fillColor: AppColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}
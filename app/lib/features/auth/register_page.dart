import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/app_router.dart';
import '../../domain/providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (!context.mounted) return;
      if (next.status == AuthStatus.authenticated) {
        if (next.isOfflineMode) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('服务器连接失败，已进入离线模式。\n数据仅保存在本地，稍后可登录同步。'),
              backgroundColor: Colors.orange.shade600,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRouter.home,
          (_) => false,
        );
      }
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Semantics(
      label: '注册页面',
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            tooltip: '返回',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '创建账号',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '开始管理你的家庭财务',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: '邮箱',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入邮箱';
                      if (!v.contains('@')) return '邮箱格式不正确';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入密码';
                      if (v.length < 6) return '密码至少 6 位';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '确认密码',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return '两次密码不一致';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    label: '注册',
                    child: ElevatedButton(
                      onPressed: authState.status == AuthStatus.loading
                          ? null
                          : _handleRegister,
                      child: authState.status == AuthStatus.loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context)
                                    .elevatedButtonTheme
                                    .style
                                    ?.foregroundColor
                                    ?.resolve({}) ?? Colors.white,
                              ),
                            )
                          : const Text('注册'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    ),
    );
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }
}

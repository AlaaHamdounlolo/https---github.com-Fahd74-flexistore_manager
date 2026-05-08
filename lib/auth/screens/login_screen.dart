import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_ffi.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _errorMessage;
  bool _isLoading = false;

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Small delay to show loading state (optional, makes it feel smoother)
    await Future.delayed(const Duration(milliseconds: 400));

    final result = AuthNativeAPI.instance.attemptLogin(email, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (result == 0) {
        // Success
        context.go('/dashboard');
      } else {
        // Failure
        setState(() {
          if (result == -999) {
            _errorMessage = 'System error: Unable to load native backend (-999)';
          } else if (result == -2) {
            _errorMessage = 'Database Connection Failed. Check MySQL server and db_config.h password.';
          } else if (result == -100) {
            _errorMessage = 'Invalid username or password.';
          } else {
            _errorMessage = 'An error occurred (Code: $result)';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Very dark slate/blue background
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 440, // Fixed width to keep it neat on desktop
            margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), // Card color
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6), // Bright blue
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Titles
                const Text(
                  'FlexiStore Manager',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 32),

                // Email Input
                const Text(
                  'Username',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _emailController,
                  hintText: 'admin',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                // Password Input
                const Text(
                  'Password',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Enter your password',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureText: _obscurePassword,
                  onToggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Remember Me & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (val) {
                              setState(() {
                                _rememberMe = val ?? false;
                              });
                            },
                            fillColor: MaterialStateProperty.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return const Color(0xFF3B82F6);
                              }
                              return Colors.transparent;
                            }),
                            side: const BorderSide(color: Color(0xFF475569)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Remember me',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(color: Color(0xFF3B82F6), fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Sign In Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF3B82F6).withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ).copyWith(
                    shadowColor: MaterialStateProperty.all(const Color(0xFF3B82F6).withOpacity(0.5)),
                    elevation: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.hovered) || states.contains(MaterialState.pressed)) {
                        return 12;
                      }
                      return 8;
                    }),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 32),

                // Demo Credentials Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Credentials:',
                        style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Admin: admin / admin123',
                        style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cashier: cashier / 123456',
                        style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manager: store_mng / store123',
                        style: TextStyle(color: Color(0xFF60A5FA), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF0F172A), // Darker than card
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
  }
}

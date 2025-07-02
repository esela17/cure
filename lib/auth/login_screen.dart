import 'package:cure_app/providers/auth_provider.dart';
import 'package:cure_app/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    // Reset previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Validate form
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('يرجى تصحيح الأخطاء في النموذج');
      return;
    }

    // Add haptic feedback
    HapticFeedback.lightImpact();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Call signIn method (it handles navigation internally)
      await authProvider.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        context,
      );

      // Check for errors after the sign-in attempt
      if (mounted && authProvider.errorMessage != null) {
        _handleLoginError(authProvider.errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.');
      }
    }
  }

  void _googleSignIn() async {
    HapticFeedback.lightImpact();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Call Google sign in method
      await authProvider.signInWithGoogle();

      // Check for errors after the sign-in attempt
      if (mounted && authProvider.errorMessage != null) {
        _handleLoginError(authProvider.errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('فشل في تسجيل الدخول باستخدام Google');
      }
    }
  }

  void _handleLoginError(String? errorMessage) {
    if (errorMessage == null) return;

    // Handle specific error types
    if (errorMessage.contains('email') ||
        errorMessage.contains('user-not-found')) {
      setState(() {
        _emailError = 'البريد الإلكتروني غير مسجل';
      });
    } else if (errorMessage.contains('password') ||
        errorMessage.contains('wrong-password')) {
      setState(() {
        _passwordError = 'كلمة المرور غير صحيحة';
      });
    } else if (errorMessage.contains('too-many-requests')) {
      _showErrorSnackBar(
          'تم تجاوز عدد المحاولات المسموح. يرجى المحاولة لاحقًا.');
    } else if (errorMessage.contains('network')) {
      _showErrorSnackBar('تحقق من اتصال الإنترنت وحاول مرة أخرى');
    } else {
      _showErrorSnackBar(errorMessage);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'حسنًا',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: size.height - keyboardHeight,
                ),
                child: Column(
                  children: [
                    // --- Enhanced Header Section ---
                    _buildHeaderSection(size),

                    // --- Enhanced Form Section ---
                    SlideTransition(
                      position: _slideAnimation,
                      child: _buildFormSection(),
                    ),

                    // --- Enhanced Bottom Links Section ---
                    _buildBottomLinksSection(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSection(Size size) {
    return Container(
      height: size.height * 0.55,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kPrimaryColor,
            kPrimaryColor.withOpacity(0.95),
            kPrimaryColor.withOpacity(0.85),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1000),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Transform.scale(
                  scale: value,
                  child: Image.asset(
                    'lib/assets/2.png',
                    height: 140,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 1200),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: const Text(
                      'أول تطبيق يعمل كوسيط\nبين الممرض والمريض في مصر',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Transform.translate(
        offset: const Offset(0, -100),
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 20),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome text

                const SizedBox(height: 32),

                _buildEmailField(),
                const SizedBox(height: 24),
                _buildPasswordField(),
                const SizedBox(height: 20),
                _buildRememberMeRow(),
                const SizedBox(height: 32),
                _buildLoginButtonConsumer(),
                const SizedBox(height: 28),

                // Divider
                Row(
                  children: [
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "أو",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),

                const SizedBox(height: 28),
                _buildGoogleSignInButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLinksSection() {
    return Transform.translate(
      offset: const Offset(0, -90),
      child: Column(
        children: [
          _buildForgotPasswordButton(),
          const SizedBox(height: 12),
          _buildRegisterButton(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _emailController.selection = TextSelection.fromPosition(
            TextPosition(offset: _emailController.text.length),
          ),
          child: TextFormField(
            controller: _emailController,
            decoration: _buildInputDecoration(
              "البريد الإلكتروني",
              Icons.email_outlined,
              error: _emailError,
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              if (_emailError != null) {
                setState(() {
                  _emailError = null;
                });
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'يرجى إدخال البريد الإلكتروني';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'يرجى إدخال بريد إلكتروني صالح';
              }
              return null;
            },
          ),
        ),
        if (_emailError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 16),
              const SizedBox(width: 6),
              Text(
                _emailError!,
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitLogin(),
          onChanged: (value) {
            if (_passwordError != null) {
              setState(() {
                _passwordError = null;
              });
            }
          },
          decoration: _buildInputDecoration(
            "كلمة المرور",
            Icons.lock_outline,
            error: _passwordError,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: kPrimaryColor.withOpacity(0.7),
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'يرجى إدخال كلمة المرور';
            }
            if (value.length < 6) {
              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),
        if (_passwordError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[600], size: 16),
              const SizedBox(width: 4),
              Text(
                _passwordError!,
                style: TextStyle(
                  color: Colors.red[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'تذكرني',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            // Handle forgot password
          },
          child: Text(
            'نسيت كلمة المرور؟',
            style: TextStyle(
              color: kPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButtonConsumer() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: authProvider.isLoading ? null : _submitLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              disabledBackgroundColor: kPrimaryColor.withOpacity(0.6),
              elevation: authProvider.isLoading ? 0 : 3,
              shadowColor: kPrimaryColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: authProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'تسجيل الدخول',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: OutlinedButton.icon(
        icon: Container(
          padding: const EdgeInsets.all(2),
          child: Image.asset(
            'lib/assets/1.png',
            height: 24.0,
          ),
        ),
        label: const Text(
          'المتابعة باستخدام Google',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        onPressed: _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: () {
        // Navigate to forgot password screen
      },
      child: Text(
        "هل نسيت كلمة المرور؟",
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextButton(
        onPressed: () {
          Navigator.pushNamed(context, registerRoute);
        },
        child: const Text(
          "ليس لديك حساب؟ أنشئ حسابًا",
          style: TextStyle(
            color: kPrimaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    String? error,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: error != null ? Colors.red[600] : kPrimaryColor.withOpacity(0.7),
        size: 22,
      ),
      filled: true,
      fillColor: error != null ? Colors.red.shade50 : Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: error != null ? Colors.red.shade300 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: error != null ? Colors.red[600]! : kPrimaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.red[600]!,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: Colors.red[600]!,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

@override
bool shouldRepaint(CustomPainter oldDelegate) => false;

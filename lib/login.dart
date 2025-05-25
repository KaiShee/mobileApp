import 'package:flutter/material.dart';
import 'register.dart';
import 'forgetPassword.dart';
import 'adminLogin.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add on top
import 'homePage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = FirebaseAuth.instance;
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Successful!")),
        );
        // Navigate to HomePage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );

        // Navigate to home/dashboard screen if needed
      } on FirebaseAuthException catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
                ? [Colors.grey[900]!, Colors.grey[800]!]
                : [Colors.blue.shade800, Colors.indigo.shade900],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Card(
                  elevation: 8,
                  color: isDark ? theme.cardColor : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App Logo
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: isDark 
                                ? theme.colorScheme.primary.withOpacity(0.2)
                                : Colors.blue.shade100,
                            child: Icon(
                              Icons.hotel,
                              size: 40,
                              color: isDark 
                                  ? theme.colorScheme.primary
                                  : Colors.indigo.shade900,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // App Name
                          Text(
                            "EzyStay",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark 
                                  ? theme.colorScheme.onSurface
                                  : Colors.indigo.shade900,
                            ),
                          ),
                          Text(
                            "Your home away from home",
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? theme.colorScheme.onSurface.withOpacity(0.7)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle: TextStyle(
                                color: isDark 
                                    ? theme.colorScheme.onSurface.withOpacity(0.7)
                                    : Colors.grey.shade700,
                              ),
                              prefixIcon: Icon(Icons.email, 
                                color: isDark 
                                    ? theme.colorScheme.primary
                                    : Colors.indigo,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.2)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.2)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark 
                                  ? theme.colorScheme.surface
                                  : Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: "Password",
                              labelStyle: TextStyle(
                                color: isDark 
                                    ? theme.colorScheme.onSurface.withOpacity(0.7)
                                    : Colors.grey.shade700,
                              ),
                              prefixIcon: Icon(Icons.lock, 
                                color: isDark 
                                    ? theme.colorScheme.primary
                                    : Colors.indigo,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.7)
                                      : Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.2)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.2)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: isDark 
                                  ? theme.colorScheme.surface
                                  : Colors.grey.shade50,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),

                          // Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => ForgetPasswordPage()),
                                );
                              },
                              child: Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: isDark 
                                      ? theme.colorScheme.primary
                                      : Colors.indigo.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          _isLoading
                              ? CircularProgressIndicator(
                                  color: isDark 
                                      ? theme.colorScheme.primary
                                      : Colors.indigo,
                                )
                              : ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark 
                                        ? theme.colorScheme.primary
                                        : Colors.indigo.shade800,
                                    foregroundColor: isDark 
                                        ? theme.colorScheme.onPrimary
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 3,
                                    minimumSize: const Size(double.infinity, 0),
                                  ),
                                  child: const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 20),

                          // Register Section
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Don't have an account?",
                                style: TextStyle(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.7)
                                      : Colors.grey.shade700,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => RegisterPage()),
                                  );
                                },
                                child: Text(
                                  "Register",
                                  style: TextStyle(
                                    color: isDark 
                                        ? theme.colorScheme.primary
                                        : Colors.indigo.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Admin Login Section
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Are you an admin?",
                                style: TextStyle(
                                  color: isDark 
                                      ? theme.colorScheme.onSurface.withOpacity(0.7)
                                      : Colors.grey.shade700,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => AdminLoginPage()),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: Text(
                                  "Click here to login",
                                  style: TextStyle(
                                    color: isDark 
                                        ? theme.colorScheme.error
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    theme: ThemeData(
      primarySwatch: Colors.indigo,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
    ),
    darkTheme: ThemeData(
      primarySwatch: Colors.indigo,
      fontFamily: 'Roboto',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[400]!,
        secondary: Colors.blue[300]!,
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
      ),
      cardColor: Color(0xFF2C2C2C),
    ),
    home: const LoginPage(),
    debugShowCheckedModeBanner: false,
  ));
}
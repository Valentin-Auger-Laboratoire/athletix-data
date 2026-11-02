import 'package:flutter/material.dart';
import 'package:athletix_data/services/api.dart';
import 'verify_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController pseudoController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  String _selectedSport = 'Endurance & Cardio';
  bool _isLoading = false;

  final List<String> _sports = [
    'Endurance & Cardio',
    'Force & Intensité',
    'Duel & Collectif',
    'Milieu Aquatique',
    'Zen & Posture',
  ];

  Future<void> _handleRegister() async {
    final pseudo = pseudoController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;

    if (pseudo.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack("Remplis tous les champs !", Colors.red);
      return;
    }
    if (!email.contains('@')) {
      _showSnack("Email invalide !", Colors.red);
      return;
    }
    if (password.length < 6) {
      _showSnack("Mot de passe trop court (min. 6 caractères) !", Colors.red);
      return;
    }
    if (password != confirm) {
      _showSnack("Les mots de passe ne correspondent pas !", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    final data = await Api.current.register(pseudo, email, password, _selectedSport);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (data['status'] == 'success') {
      final mailSent = data['mail_sent'] != false;
      _showSnack(mailSent ? "Compte créé ! Bienvenue $pseudo 🎉" : data['message'],
          mailSent ? Colors.green : Colors.orange);
      // ✅ Envoi de l'email à VerifyScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => VerifyScreen(email: email)),
      );
    } else {
      _showSnack(data['message'] ?? "Erreur lors de l'inscription", Colors.red);
    }
  }

  void _showSnack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    pseudoController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: BoxDecoration(
                color: Colors.orange[800],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.emoji_events, color: Colors.white, size: 60),
                  SizedBox(height: 10),
                  Text(
                    "ATHLETIX-DATA",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Crée ton compte athlète",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  _buildLabel("Ton pseudo"),
                  _buildTextField(
                    controller: pseudoController,
                    hint: "ex: AthlètePro99",
                    icon: Icons.person,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Adresse email"),
                  _buildTextField(
                    controller: emailController,
                    hint: "exemple@mail.com",
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Mot de passe"),
                  _buildTextField(
                    controller: passwordController,
                    hint: "Min. 6 caractères",
                    icon: Icons.lock,
                    obscure: !_passwordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel("Confirmer le mot de passe"),
                  _buildTextField(
                    controller: confirmPasswordController,
                    hint: "Répète ton mot de passe",
                    icon: Icons.lock_outline,
                    obscure: !_confirmPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _confirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                    ),
                  ),
                  const SizedBox(height: 25),

                  _buildLabel("Ton sport principal"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedSport,
                      isExpanded: true,
                      dropdownColor: Colors.grey[900],
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.orange, fontSize: 15),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                      items: _sports.map((sport) =>
                        DropdownMenuItem(value: sport, child: Text(sport))
                      ).toList(),
                      onChanged: (val) => setState(() => _selectedSport = val!),
                    ),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleRegister,
                      child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "CRÉER MON COMPTE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1,
                            ),
                          ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      ),
                      child: const Text(
                        "Déjà un compte ? Se connecter",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: Colors.orange, size: 20),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_container.dart';
import 'chat_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your name.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_currentPage == 1 && _apiKeyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your OpenRouter API Key.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('openrouter_key', _apiKeyController.text.trim());
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const ChatScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1), Color(0xFF94A3B8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildPage(
                      title: 'Welcome to Raiven',
                      subtitle: 'What should I call you?',
                      controller: _nameController,
                      hint: 'Your name',
                      icon: Icons.person_outline,
                    ),
                    _buildPage(
                      title: 'Connect OpenRouter',
                      subtitle: 'Enter your API key to power up your chat.',
                      controller: _apiKeyController,
                      hint: 'sk-or-v1-...',
                      icon: Icons.vpn_key_outlined,
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child:
                    GestureDetector(
                          onTap: _nextPage,
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            width: double.infinity,
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Text(
                                  _currentPage == 0
                                      ? 'Continue'
                                      : 'Start Chatting',
                                  key: ValueKey(_currentPage),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .slideY(
                          begin: 1.0,
                          end: 0.0,
                          curve: Curves.easeOutQuart,
                          duration: 800.ms,
                        )
                        .fadeIn(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.black87),
          ).animate().scale(
            delay: 100.ms,
            duration: 600.ms,
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Colors.black87,
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0.0),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87.withValues(alpha: 0.7),
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0.0),
          const SizedBox(height: 48),
          GlassContainer(
            enableBlur: false,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(fontSize: 18, color: Colors.black87),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
              textInputAction: obscureText
                  ? TextInputAction.done
                  : TextInputAction.next,
              onSubmitted: (_) => _nextPage(),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0.0),
        ],
      ),
    );
  }
}

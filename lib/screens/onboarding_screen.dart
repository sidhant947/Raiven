import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_container.dart';
import '../widgets/main_background.dart';
import '../services/service_factory.dart';
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
  ApiProvider _selectedProvider = ApiProvider.openrouter;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_currentPage < 2) {
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
    await prefs.setString('api_provider', _selectedProvider.toString().split('.').last);
    
    String keyName = '${_selectedProvider.toString().split('.').last}_key';
    await prefs.setString(keyName, _apiKeyController.text.trim());
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const ChatScreen(),
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
      backgroundColor: Colors.transparent,
      body: MainBackground(
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
                    _buildNamePage(),
                    _buildProviderPage(),
                    _buildApiKeyPage(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: GestureDetector(
                  onTap: _nextPage,
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    width: double.infinity,
                    color: Colors.black87,
                    child: Center(
                      child: Text(
                        _currentPage < 2 ? 'Continue' : 'Start Chatting',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 1.0, duration: 800.ms, curve: Curves.easeOutQuart).fadeIn(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNamePage() {
    return _buildPageWrapper(
      icon: Icons.person_outline,
      title: 'Welcome to Raiven',
      subtitle: 'What should I call you?',
      child: GlassContainer(
        opacity: 0.1,
        enableBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: TextField(
          controller: _nameController,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Your name',
          ),
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _nextPage(),
        ),
      ),
    );
  }

  Widget _buildProviderPage() {
    return _buildPageWrapper(
      icon: Icons.psychology_outlined,
      title: 'Choose Provider',
      subtitle: 'Select your preferred AI engine.',
      child: GlassContainer(
        opacity: 0.1,
        enableBlur: false,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ApiProvider.values.map((provider) {
            final isSelected = _selectedProvider == provider;
            return ListTile(
              title: Text(
                ServiceFactory.getProviderLabel(provider),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.black87) : null,
              onTap: () => setState(() => _selectedProvider = provider),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildApiKeyPage() {
    return _buildPageWrapper(
      icon: Icons.vpn_key_outlined,
      title: 'API Key',
      subtitle: 'Enter your ${ServiceFactory.getProviderLabel(_selectedProvider)} key.',
      child: GlassContainer(
        opacity: 0.1,
        enableBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: TextField(
          controller: _apiKeyController,
          obscureText: true,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'sk-...',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _nextPage(),
        ),
      ),
    );
  }

  Widget _buildPageWrapper({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
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
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
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
          child.animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0.0),
        ],
      ),
    );
  }
}

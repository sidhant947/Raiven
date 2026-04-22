import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/glass_container.dart';
import '../widgets/main_background.dart';
import '../services/service_factory.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Map<ApiProvider, TextEditingController> _keyControllers = {};
  final TextEditingController _customUrlController = TextEditingController();
  ApiProvider _selectedProvider = ApiProvider.openrouter;

  @override
  void initState() {
    super.initState();
    for (var provider in ApiProvider.values) {
      _keyControllers[provider] = TextEditingController();
    }
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'User';
      _customUrlController.text = prefs.getString('custom_url') ?? '';
      
      final providerName = prefs.getString('api_provider') ?? 'openrouter';
      _selectedProvider = ApiProvider.values.firstWhere(
        (e) => e.toString().split('.').last == providerName,
        orElse: () => ApiProvider.openrouter,
      );

      _keyControllers[ApiProvider.openrouter]!.text = prefs.getString('openrouter_key') ?? '';
      _keyControllers[ApiProvider.openai]!.text = prefs.getString('openai_key') ?? '';
      _keyControllers[ApiProvider.google]!.text = prefs.getString('google_key') ?? '';
      _keyControllers[ApiProvider.anthropic]!.text = prefs.getString('anthropic_key') ?? '';
      _keyControllers[ApiProvider.mistral]!.text = prefs.getString('mistral_key') ?? '';
      _keyControllers[ApiProvider.nvidia]!.text = prefs.getString('nvidia_key') ?? '';
      _keyControllers[ApiProvider.custom]!.text = prefs.getString('custom_key') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('api_provider', _selectedProvider.toString().split('.').last);
    await prefs.setString('custom_url', _customUrlController.text.trim());

    await prefs.setString('openrouter_key', _keyControllers[ApiProvider.openrouter]!.text.trim());
    await prefs.setString('openai_key', _keyControllers[ApiProvider.openai]!.text.trim());
    await prefs.setString('google_key', _keyControllers[ApiProvider.google]!.text.trim());
    await prefs.setString('anthropic_key', _keyControllers[ApiProvider.anthropic]!.text.trim());
    await prefs.setString('mistral_key', _keyControllers[ApiProvider.mistral]!.text.trim());
    await prefs.setString('nvidia_key', _keyControllers[ApiProvider.nvidia]!.text.trim());
    await prefs.setString('custom_key', _keyControllers[ApiProvider.custom]!.text.trim());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully!'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customUrlController.dispose();
    for (var controller in _keyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: MainBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSectionTitle('Profile'),
              _buildGlassInput(
                controller: _nameController,
                label: 'Display Name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('AI Provider'),
              _buildProviderSelector(),
              const SizedBox(height: 24),
              _buildSectionTitle('API Configuration'),
              if (_selectedProvider == ApiProvider.custom)
                _buildGlassInput(
                  controller: _customUrlController,
                  label: 'Base URL',
                  hint: 'https://api.your-provider.com/v1',
                  icon: Icons.link,
                ),
              _buildGlassInput(
                controller: _keyControllers[_selectedProvider]!,
                label: '${ServiceFactory.getProviderLabel(_selectedProvider)} API Key',
                hint: 'AIzaSy...',
                icon: Icons.vpn_key_outlined,
                obscureText: true,
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: _saveSettings,
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  color: Colors.black87,
                  child: const Center(
                    child: Text(
                      'Save Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black54,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGlassInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.black45),
        ),
        const SizedBox(height: 8),
        GlassContainer(
          opacity: 0.1,
          enableBlur: false,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          margin: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              icon: Icon(icon, color: Colors.black54, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderSelector() {
    return GlassContainer(
      opacity: 0.1,
      enableBlur: false,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: ApiProvider.values.map((provider) {
          final isSelected = _selectedProvider == provider;
          return ListTile(
            title: Text(
              ServiceFactory.getProviderLabel(provider),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.black87,
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.black87)
                : null,
            onTap: () {
              setState(() {
                _selectedProvider = provider;
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

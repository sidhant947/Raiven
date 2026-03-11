import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/glass_container.dart';
import '../widgets/liquid_orb.dart';
import '../services/openrouter_api.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'onboarding_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  String _userName = 'User';
  final TextEditingController _msgController = TextEditingController();
  final OpenRouterService _apiService = OpenRouterService();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  bool _isChatActive = false;
  Map<String, String>? _replyMessage;

  String? _chatId;
  final Box _chatsBox = Hive.box('chats');
  final _uuid = const Uuid();

  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _filteredModels = [];
  String _selectedModelId = 'openrouter/free';
  bool _isLoadingModels = false;

  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadUser();
    _fetchModels();
    _createNewChat();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _loadChat(String id) {
    setState(() {
      _chatId = id;
      final chatData = _chatsBox.get(id);
      _messages.clear();
      if (chatData != null) {
        try {
          if (chatData['messages'] is String) {
            final List<dynamic> savedMsgs = jsonDecode(chatData['messages']);
            _messages.addAll(
              savedMsgs
                  .map(
                    (e) => {
                      'role': e['role'].toString(),
                      'content': e['content'].toString(),
                    },
                  )
                  .toList(),
            );
          } else if (chatData['messages'] is List) {
            final List<dynamic> savedMsgs = chatData['messages'];
            _messages.addAll(
              savedMsgs
                  .map(
                    (e) => {
                      'role': e['role'].toString(),
                      'content': e['content'].toString(),
                    },
                  )
                  .toList(),
            );
          }
        } catch (e) {
          debugPrint('Error loading chat: $e');
        }
        _isChatActive = _messages.isNotEmpty;
      } else {
        _isChatActive = false;
      }
    });

    if (_isChatActive) {
      _scrollToBottom();
    }
  }

  void _createNewChat() {
    setState(() {
      _chatId = _uuid.v4();
      _messages.clear();
      _replyMessage = null;
      _isChatActive = false;
    });
  }

  void _saveChat() {
    if (_messages.isEmpty) return;
    _chatId ??= _uuid.v4();
    final title = _messages.firstWhere(
      (m) => m['role'] == 'user',
      orElse: () => {'content': 'New Conversation'},
    )['content'];

    _chatsBox.put(_chatId, {
      'id': _chatId,
      'title': title,
      'messages': jsonEncode(_messages),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void _deleteChat(String id) {
    _chatsBox.delete(id);
    if (_chatId == id) {
      _createNewChat();
    } else {
      setState(() {});
    }
  }

  void _deleteAllChats() {
    _chatsBox.clear();
    _createNewChat();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? 'User';
      _selectedModelId = prefs.getString('selected_model') ?? 'openrouter/free';
    });
  }

  Future<void> _fetchModels() async {
    setState(() => _isLoadingModels = true);
    try {
      final models = await _apiService.getModels();
      if (mounted) {
        setState(() {
          _models = models;
          _filteredModels = models;
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingModels = false);
    }
  }

  Future<void> _selectModel(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', modelId);
    setState(() {
      _selectedModelId = modelId;
    });
  }

  Future<void> _resetApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('openrouter_key');
    await prefs.setBool('onboarding_complete', false);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _msgController.clear();
      _isChatActive = true;

      String contentToSend = text;
      if (_replyMessage != null) {
        String cleanQuote = _replyMessage!['content']!
            .replaceAll(RegExp(r'^>.*\n?', multiLine: true), '')
            .trim();

        final lines = cleanQuote.split('\n');
        if (lines.isNotEmpty) {
          cleanQuote = lines.first.trim();
          if (cleanQuote.length > 50) {
            cleanQuote = '${cleanQuote.substring(0, 50)}...';
          } else if (lines.length > 1) {
            cleanQuote = '$cleanQuote...';
          }
        }

        contentToSend = '> $cleanQuote\n\n$text';
        _replyMessage = null;
      }

      _messages.add({'role': 'user', 'content': contentToSend});
      _isLoading = true;
      _saveChat();
    });

    _scrollToBottom();

    try {
      final history = _messages
          .map((m) => {'role': m['role']!, 'content': m['content']!})
          .toList();
      history.removeLast();

      final response = await _apiService.sendMessage(
        text,
        history: history,
        modelId: _selectedModelId,
      );

      setState(() {
        _messages.add({'role': 'assistant', 'content': response});
        _isLoading = false;
        _saveChat();
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'system', 'content': 'Error: ${e.toString()}'});
        _isLoading = false;
      });
      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return GlassContainer(
              borderRadius: 32,
              margin: const EdgeInsets.only(top: 60),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.8,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Text(
                        'Select Model',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: GlassContainer(
                        opacity: 0.1,
                        enableBlur: false,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search models...',
                            icon: Icon(Icons.search, color: Colors.black54),
                          ),
                          onChanged: (val) {
                            setModalState(() {
                              _filteredModels = _models.where((m) {
                                final id = m['id'].toString().toLowerCase();
                                final name = (m['name'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final query = val.toLowerCase();
                                return id.contains(query) ||
                                    name.contains(query);
                              }).toList();
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoadingModels
                          ? const Center(child: LiquidOrb(size: 50))
                          : ListView.builder(
                              itemCount: _filteredModels.length,
                              itemBuilder: (context, index) {
                                final model = _filteredModels[index];
                                final isSelected =
                                    _selectedModelId == model['id'];
                                return ListTile(
                                  title: Text(
                                    model['name'] ?? model['id'],
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(model['id']),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.black87,
                                        )
                                      : null,
                                  onTap: () {
                                    _selectModel(model['id']);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        _filteredModels = _models;
      });
    });
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFE2E8F0),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Raiven',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.black87),
              title: const Text(
                'New Chat',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                _createNewChat();
              },
            ),
            const Divider(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: _chatsBox.length,
                      itemBuilder: (context, index) {
                        final key = _chatsBox.keys.elementAt(
                          _chatsBox.length - 1 - index,
                        );
                        final chat = _chatsBox.get(key);
                        final isCurrent = _chatId == key;

                        return ListTile(
                          title: Text(
                            chat['title'] ?? 'Chat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _loadChat(key);
                          },
                          leading: const Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            onPressed: () => _deleteChat(key),
                          ),
                          selected: isCurrent,
                          selectedTileColor: Colors.black.withValues(
                            alpha: 0.05,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_chatsBox.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          alignment: Alignment.centerLeft,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('Delete All Chats'),
                        onPressed: () {
                          _deleteAllChats();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.black54),
              title: const Text('Model Selector'),
              subtitle: Text(
                _selectedModelId.split('/').last,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _showModelSelector();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: Colors.black54,
              ),
              title: const Text('Reset API Key'),
              onTap: () {
                Navigator.pop(context);
                _resetApiKey();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient — const so no rebuilds
          const _BackgroundGradient(),

          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(
                        builder: (ctx) => IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Colors.black87,
                            size: 28,
                          ),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                          splashRadius: 24,
                        ),
                      ),
                      if (_isChatActive)
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: LiquidOrb(size: 32),
                        ),
                    ],
                  ),
                ),

                // Chat area
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _isChatActive
                        ? _buildChatList()
                        : _buildEmptyState(),
                  ),
                ),

                // Bottom input
                _buildBottomInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      key: const ValueKey('empty'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LiquidOrb(size: 200)
              .animate()
              .scale(duration: 800.ms, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: 40),
          Text(
            'Hey $_userName,',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.5,
              color: Colors.black87,
            ),
          ).animate().slideY(begin: 0.2, duration: 600.ms).fadeIn(),
          const SizedBox(height: 4),
          const Text(
            'What can I help with?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              color: Colors.black,
            ),
          ).animate().slideY(begin: 0.2, duration: 800.ms).fadeIn(),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      key: const ValueKey('chat'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      // Cull off-screen widgets for performance
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 10, bottom: 20),
              child: SizedBox(
                height: 30,
                width: 50,
                child: LiquidOrb(size: 30),
              ),
            ),
          );
        }

        final msg = _messages[index];
        final isUser = msg['role'] == 'user';
        final isSystem = msg['role'] == 'system';

        if (isSystem) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                msg['content']!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),
          );
        }

        return Dismissible(
          // Use a stable key so Flutter can diff properly
          key: ValueKey('msg_${_chatId}_$index'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            setState(() {
              _replyMessage = msg;
            });
            return false;
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.reply, color: Colors.black54),
          ),
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child:
                Container(
                      margin: const EdgeInsets.only(bottom: 16, top: 4),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      child: GlassContainer(
                        opacity: isUser ? 0.4 : 0.8,
                        color: isUser ? Colors.black87 : Colors.white,
                        enableBlur:
                            false, // Disable expensive blur on chat bubbles
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        borderRadius: 24,
                        child: _buildMessageContent(msg['content']!, isUser),
                      ),
                    )
                    .animate()
                    .slideY(
                      begin: 0.05,
                      duration: 250.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(duration: 200.ms),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    final quoteRegex = RegExp(r'^((?:>.*\n?)+)\n*([\s\S]*)$');
    final match = quoteRegex.firstMatch(content);

    if (match != null) {
      final quotedText = match
          .group(1)!
          .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
          .trim();
      final actualMessage = match.group(2)?.trim() ?? '';

      String displayQuote = quotedText.split('\n').first;
      if (displayQuote.length > 60) {
        displayQuote = '${displayQuote.substring(0, 60)}...';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.3),
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              displayQuote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isUser
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black54,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (actualMessage.isNotEmpty)
            MarkdownBody(
              data: actualMessage,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: 16,
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
        ],
      );
    }

    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 16,
          color: isUser ? Colors.white : Colors.black87,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildBottomInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reply bar
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: _replyMessage != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  child: GlassContainer(
                    enableBlur: false,
                    opacity: 0.15,
                    borderRadius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _replyMessage!['content']!
                                .replaceAll(
                                  RegExp(r'^>.*\n?', multiLine: true),
                                  '',
                                )
                                .trim()
                                .split('\n')
                                .first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _replyMessage = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Input field
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: GlassContainer(
            opacity: 0.5,
            borderRadius: 30,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Ask anything...',
                      hintStyle: TextStyle(
                        color: Colors.black.withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (!_isLoading) _sendMessage();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.05),
                    ),
                    child: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(
          begin: 1.0,
          duration: 800.ms,
          curve: Curves.easeOutQuart,
        ),
      ],
    );
  }
}

/// Extracted as const to avoid rebuilds
class _BackgroundGradient extends StatelessWidget {
  const _BackgroundGradient();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC7D2E6), Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
          ),
        ),
      ),
    );
  }
}

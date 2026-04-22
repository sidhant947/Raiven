import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../widgets/glass_container.dart';
import '../widgets/liquid_orb.dart';
import '../widgets/main_background.dart';
import '../services/api_service.dart';
import '../services/service_factory.dart';
import 'settings_screen.dart';
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
  ApiService? _apiService;
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
    _initApiService().then((_) => _fetchModels());
    _createNewChat();
  }

  Future<void> _initApiService() async {
    final service = await ServiceFactory.getService();
    if (mounted) {
      setState(() {
        _apiService = service;
      });
    }
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
              savedMsgs.map((e) => {
                'role': e['role'].toString(),
                'content': e['content'].toString(),
              }).toList(),
            );
          } else if (chatData['messages'] is List) {
            final List<dynamic> savedMsgs = chatData['messages'];
            _messages.addAll(
              savedMsgs.map((e) => {
                'role': e['role'].toString(),
                'content': e['content'].toString(),
              }).toList(),
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
    if (_apiService == null) return;
    setState(() => _isLoadingModels = true);
    try {
      final models = await _apiService!.getModels();
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

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _apiService == null) return;

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

      final response = await _apiService!.sendMessage(
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
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
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Text(
                        'Select Model',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                final name = (m['name'] ?? '').toString().toLowerCase();
                                final query = val.toLowerCase();
                                return id.contains(query) || name.contains(query);
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
                                final isSelected = _selectedModelId == model['id'];
                                return ListTile(
                                  title: Text(
                                    model['name'] ?? model['id'],
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(model['id']),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle, color: Colors.black87)
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
    return GlassContainer(
      borderRadius: 0,
      blur: 20,
      opacity: 0.8,
      color: const Color(0xFFE2E8F0).withValues(alpha: 0.8),
      child: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                          final key = _chatsBox.keys.elementAt(_chatsBox.length - 1 - index);
                          final chat = _chatsBox.get(key);
                          final isCurrent = _chatId == key;

                          return ListTile(
                            title: Text(
                              chat['title'] ?? 'Chat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _loadChat(key);
                            },
                            leading: const Icon(Icons.chat_bubble_outline, size: 20),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => _deleteChat(key),
                            ),
                            selected: isCurrent,
                            selectedTileColor: Colors.black.withValues(alpha: 0.05),
                          );
                        },
                      ),
                    ),
                    if (_chatsBox.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                subtitle: Text(_selectedModelId.split('/').last, style: const TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _showModelSelector();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined, color: Colors.black54),
                title: const Text('Settings'),
                onTap: () async {
                  Navigator.pop(context);
                  final refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsScreen()),
                  );
                  if (refresh == true) {
                    _loadUser();
                    await _initApiService();
                    await _fetchModels();
                    if (_models.isNotEmpty && !_models.any((m) => m['id'] == _selectedModelId)) {
                      _selectModel(_models.first['id']);
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: MainBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Const-optimized header
              const _ChatHeader(),

              // Chat area isolated
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isChatActive
                      ? _ChatListView(
                          scrollController: _scrollController,
                          messages: _messages,
                          isLoading: _isLoading,
                          chatId: _chatId,
                          onReply: (msg) => setState(() => _replyMessage = msg),
                        )
                      : _EmptyState(userName: _userName),
                ),
              ),

              // Bottom input isolated
              _BottomInputArea(
                controller: _msgController,
                isLoading: _isLoading,
                replyMessage: _replyMessage,
                onCancelReply: () => setState(() => _replyMessage = null),
                onSend: _sendMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87, size: 28),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              splashRadius: 24,
            ),
          ),
          const LiquidOrb(size: 32),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String userName;
  const _EmptyState({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LiquidOrb(size: 200)
              .animate()
              .scale(duration: 800.ms, curve: Curves.easeOutBack)
              .fadeIn(),
          const SizedBox(height: 40),
          Text(
            'Hey $userName,',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, letterSpacing: -0.5, color: Colors.black87),
          ).animate().slideY(begin: 0.2, duration: 600.ms).fadeIn(),
          const SizedBox(height: 4),
          const Text(
            'What can I help with?',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: Colors.black),
          ).animate().slideY(begin: 0.2, duration: 800.ms).fadeIn(),
        ],
      ),
    );
  }
}

class _ChatListView extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, String>> messages;
  final bool isLoading;
  final String? chatId;
  final Function(Map<String, String>) onReply;

  const _ChatListView({
    required this.scrollController,
    required this.messages,
    required this.isLoading,
    this.chatId,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemCount: messages.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length && isLoading) {
          return const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: 10, bottom: 20),
              child: SizedBox(height: 30, width: 50, child: LiquidOrb(size: 30)),
            ),
          );
        }

        final msg = messages[index];
        final isUser = msg['role'] == 'user';
        final isSystem = msg['role'] == 'system';

        if (isSystem) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(msg['content']!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),
          );
        }

        return _MessageBubble(
          key: ValueKey('msg_${chatId}_$index'),
          content: msg['content']!,
          isUser: isUser,
          onSwipe: () => onReply(msg),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final VoidCallback onSwipe;

  const _MessageBubble({
    Key? key,
    required this.content,
    required this.isUser,
    required this.onSwipe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: key!,
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onSwipe();
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply, color: Colors.black54),
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, top: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          child: RepaintBoundary(
            child: GlassContainer(
              opacity: isUser ? 0.4 : 0.8,
              color: isUser ? Colors.black87 : Colors.white,
              enableBlur: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              borderRadius: 24,
              child: _MessageContent(content: content, isUser: isUser),
            ),
          ),
        ).animate().slideY(begin: 0.05, duration: 250.ms, curve: Curves.easeOutCubic).fadeIn(duration: 200.ms),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final String content;
  final bool isUser;

  const _MessageContent({required this.content, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final quoteRegex = RegExp(r'^((?:>.*\n?)+)\n*([\s\S]*)$');
    final match = quoteRegex.firstMatch(content);

    if (match != null) {
      final quotedText = match.group(1)!.replaceAll(RegExp(r'^>\s?', multiLine: true), '').trim();
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
                  color: isUser ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              displayQuote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: isUser ? Colors.white.withValues(alpha: 0.6) : Colors.black54),
            ),
          ),
          const SizedBox(height: 8),
          if (actualMessage.isNotEmpty) _buildMarkdown(actualMessage),
        ],
      );
    }

    return _buildMarkdown(content);
  }

  Widget _buildMarkdown(String data) {
    return MarkdownBody(
      data: data,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(fontSize: 16, color: isUser ? Colors.white : Colors.black87, height: 1.4),
      ),
    );
  }
}

class _BottomInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final Map<String, String>? replyMessage;
  final VoidCallback onCancelReply;
  final VoidCallback onSend;

  const _BottomInputArea({
    required this.controller,
    required this.isLoading,
    this.replyMessage,
    required this.onCancelReply,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (replyMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: GlassContainer(
              enableBlur: false,
              opacity: 0.15,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      replyMessage!['content']!.replaceAll(RegExp(r'^>.*\n?', multiLine: true), '').trim().split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black54),
                    ),
                  ),
                  GestureDetector(
                    onTap: onCancelReply,
                    child: const Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.close, size: 16, color: Colors.black54)),
                  ),
                ],
              ),
            ),
          ),
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
                    controller: controller,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Ask anything...',
                      hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.5), fontSize: 16),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => onSend(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (!isLoading) onSend();
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.05)),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.black87, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: 1.0, duration: 800.ms, curve: Curves.easeOutQuart),
      ],
    );
  }
}

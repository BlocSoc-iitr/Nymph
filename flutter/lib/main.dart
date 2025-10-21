import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/signin_card.dart';
import 'screens/message_card.dart';
import 'screens/splash_screen.dart';
import 'screens/auth_check_screen.dart';
import 'screens/google_signin_screen.dart';
import 'services/fetch_messages.dart';
import 'services/jwt_prover.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/theme.dart';
import 'theme/app_colors.dart';

void main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase - make sure you've added the necessary configuration files
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(StealthNoteApp());
}

class StealthNoteApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nymph',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth-check': (context) => AuthCheckScreen(),
        '/signin': (context) => const GoogleSignInScreen(),
        '/home': (context) => StealthHomePage(),
      },
    );
  }
}

class StealthHomePage extends StatefulWidget {
  @override
  _StealthHomePageState createState() => _StealthHomePageState();
}

class _StealthHomePageState extends State<StealthHomePage> {
  final AuthService _authService = AuthService();
  List<Message> messages = [];
  final ScrollController _scrollController = ScrollController();
  bool isInternal = false;
  User? _user;
  int _messageKey = 0;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  DateTime? _oldestMessageTime;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
      });
    });
    // Add scroll listener
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && 
        !_isLoadingMore && 
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  String sliceEmail(dynamic email) {
    return email.substring(email.indexOf('@') + 1);
  }

  Future<void> _loadMessages() async {
    try {
      String? groupId = null;
      if (isInternal && _user != null) {
        groupId = sliceEmail(_user!.email);
      }
      final fetchedMessages = await fetchMessages(
          limit: 5, isInternal: isInternal, groupId: groupId);
      if (fetchedMessages != null && fetchedMessages.isNotEmpty) {
        List<Message> processedMessages = [];
        for (var message in fetchedMessages) {
          final msg = Message(
            id: message['id'],
            org: message['anonGroupId'],
            time: DateTime.parse(message['timestamp']),
            body: message['text'],
            likes: message['likes'],
            isLiked: 0,
            internal: message['internal'],
          );
          processedMessages.add(msg);
        }
        setState(() {
          messages = processedMessages;
          _messageKey++;
          _oldestMessageTime = processedMessages.last.time;
          _hasMoreMessages = fetchedMessages.length >= 5; // If we got less than limit, no more messages
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _oldestMessageTime == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      String? groupId = null;
      if (isInternal && _user != null) {
        groupId = sliceEmail(_user!.email);
      }
      
      final fetchedMessages = await fetchMessages(
        limit: 5,
        isInternal: isInternal,
        groupId: groupId,
        beforeTimestamp: _oldestMessageTime!.millisecondsSinceEpoch,
      );

      if (fetchedMessages != null && fetchedMessages.isNotEmpty) {
        List<Message> newMessages = [];
        for (var message in fetchedMessages) {
          final msg = Message(
            id: message['id'],
            org: message['anonGroupId'],
            time: DateTime.parse(message['timestamp']),
            body: message['text'],
            likes: message['likes'],
            isLiked: 0,
            internal: message['internal'],
          );
          newMessages.add(msg);
        }

        setState(() {
          messages.addAll(newMessages);
          _oldestMessageTime = newMessages.last.time;
          _hasMoreMessages = fetchedMessages.length >= 5; // If we got less than limit, no more messages
        });
      } else {
        setState(() {
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      print('Error loading more messages: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) {
        isInternal = false;
      } else if (index == 1) {
        isInternal = true;
      }
      messages = [];
      _oldestMessageTime = null;
      _hasMoreMessages = true;
    });
    _loadMessages();
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimaryColor,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondaryColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryColor,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/signin',
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Nymph', style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryColor,
        )),
        backgroundColor: AppColors.backgroundColor,
        foregroundColor: AppColors.textPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _showLogoutDialog,
          tooltip: 'Sign Out',
        ),
        actions: [
          IconButton(
            tooltip: 'Create Post',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppColors.backgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: SignInCard(
                          isInternal: isInternal,
                          onPostSuccess: () {
                            Navigator.of(context).maybePop();
                            setState(() {
                              messages = [];
                              _oldestMessageTime = null;
                              _hasMoreMessages = true;
                            });
                            _loadMessages();
                          },
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              messages = [];
              _oldestMessageTime = null;
              _hasMoreMessages = true;
            });
            await _loadMessages();
          },
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            children: [
              // Composer moved to a modal opened by the top-right + button
              ...messages.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: MessageCard(msg, key: ValueKey('${msg.id}_$_messageKey')),
              )).toList(),
              if (_isLoadingMore)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.accentColor,
                            backgroundColor: const Color(0xFF5CE5E5).withOpacity(0.1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading more messages...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_hasMoreMessages && messages.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5CE5E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF5CE5E5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'You\'re all caught up!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No more messages to show',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: AppColors.cardBackgroundColor,
        selectedItemColor: AppColors.accentColor,
        unselectedItemColor: AppColors.textSecondaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: [
          BottomNavigationBarItem(
            icon: Icon(_currentIndex == 0 ? Icons.home : Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(_currentIndex == 1 ? Icons.business : Icons.business_outlined),
            label: _user != null ? '${sliceEmail(_user!.email)} Internal' : 'Internal',
          ),
        ],
      ),
    );
  }
}

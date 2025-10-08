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
      title: 'StealthNote',
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      ),
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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      drawer: Drawer(
        backgroundColor: const Color(0xFF252525),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF5CE5E5).withOpacity(0.1),
                    const Color(0xFF252525),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5CE5E5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.security,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('StealthNote',
                      style: GoogleFonts.inter(
                        fontSize: 24, 
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
                  Text('Anonymous messaging',
                      style: GoogleFonts.inter(
                        fontSize: 14, 
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFFB8B8B8),
                      )),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: !isInternal ? const Color(0xFF5CE5E5).withOpacity(0.1) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.home_outlined,
                  color: !isInternal ? const Color(0xFF5CE5E5) : const Color(0xFFB8B8B8),
                ),
                title: Text('Home',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: !isInternal ? const Color(0xFF5CE5E5) : Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    isInternal = false;
                    messages = [];
                    _oldestMessageTime = null;
                    _hasMoreMessages = true;
                  });
                  _loadMessages();
                },
              ),
            ),
            if (_user != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isInternal ? const Color(0xFF5CE5E5).withOpacity(0.1) : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.business_outlined,
                    color: isInternal ? const Color(0xFF5CE5E5) : const Color(0xFFB8B8B8),
                  ),
                  title: Text('${sliceEmail(_user!.email)} Internal',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isInternal ? const Color(0xFF5CE5E5) : Colors.white,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      isInternal = true;
                      messages = [];
                      _oldestMessageTime = null;
                      _hasMoreMessages = true;
                    });
                    _loadMessages();
                  },
                ),
              ),
            ],
            const Divider(
              color: Color(0xFF808080),
              thickness: 0.5,
              height: 32,
              indent: 12,
              endIndent: 12,
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Color(0xFFFF5252),
                ),
                title: Text('Sign Out',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF5252),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  // Show confirmation dialog
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF252525),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        'Sign Out',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to sign out?',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFB8B8B8),
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
                              color: const Color(0xFFB8B8B8),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5252),
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
                },
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text('StealthNote', style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        )),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
              SignInCard(
                isInternal: isInternal,
                onPostSuccess: () {
                  setState(() {
                    messages = [];
                    _oldestMessageTime = null;
                    _hasMoreMessages = true;
                  });
                  _loadMessages();
                },
              ),
              const SizedBox(height: 24),
              ...messages.map((msg) => Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
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
                            color: const Color(0xFF5CE5E5),
                            backgroundColor: const Color(0xFF5CE5E5).withOpacity(0.1),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading more messages...',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFB8B8B8),
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
                            color: const Color(0xFFB8B8B8),
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
    );
  }
}

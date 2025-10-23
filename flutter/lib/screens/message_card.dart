import 'dart:typed_data';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mopro_flutter/mopro_flutter.dart';
import 'package:mopro_flutter/mopro_flutter_platform_interface.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/fetch_messages.dart';
import '../services/fetch_googleJWTPubkey.dart';
import '../services/toggle_like.dart';
import '../theme/theme.dart';

class Message {
  final String id;
  final String org;
  final DateTime time;
  final String body;
  int likes;
  int isLiked;
  final bool internal;

  Message({
    required this.id,
    required this.org,
    required this.time,
    required this.body,
    required this.likes,
    required this.isLiked,
    required this.internal,
  });
}

class MessageCard extends StatefulWidget {
  final Message msg;
  const MessageCard(this.msg, {Key? key}) : super(key: key);

  @override
  _MessageCardState createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  final _moproFlutterPlugin = MoproFlutter();

  VerifyJwtProofResult? _verificationResult;
  String? _srsPath;
  String? _status;
  String? _errorMessage;
  bool _isBusy = false;
  int? _verifyingTimeMillis;
  bool _isLoading = false;
  bool? _verified; // null = not verified yet

  // Generate a unique avatar seed for each message
  String _generateAvatarSeed() {
    // Use message ID + timestamp to create a unique seed
    final seed = '${widget.msg.id}_${widget.msg.time.millisecondsSinceEpoch}';
    return seed;
  }

  // Generate a random avatar URL using DiceBear API with unique seed
  String _generateAnonymousAvatar() {
    final seed = _generateAvatarSeed();
    final random = Random(seed.hashCode);
    
    // List of different avatar styles for variety
    final avatarStyles = [
      'avataaars',
      'bottts',
      'identicon',
      'personas',
      'micah',
      'adventurer',
      'big-smile',
      'croodles',
      'fun-emoji',
      'icons',
      'lorelei',
      'notionists',
      'open-peeps',
      'pixel-art',
      'rings',
      'shapes',
      'thumbs'
    ];
    
    // Select a random style based on the seed
    final style = avatarStyles[random.nextInt(avatarStyles.length)];
    
    // Generate random parameters for more variety
    final backgroundColor = random.nextInt(0xFFFFFF);
    final accessoriesProbability = random.nextInt(100);
    final facialHairProbability = random.nextInt(100);
    final clothingProbability = random.nextInt(100);
    
    return 'https://api.dicebear.com/7.x/$style/png?seed=${Uri.encodeComponent(seed)}&backgroundColor=${backgroundColor.toRadixString(16).padLeft(6, '0')}&accessoriesProbability=$accessoriesProbability&facialHairProbability=$facialHairProbability&clothingProbability=$clothingProbability&size=80';
  }

  // Generate a unique background color for internal cards
  Color _generateUniqueBackgroundColor() {
    if (!widget.msg.internal) {
      return AppColors.cardElevated; // Use default color for public cards
    }
    
    final seed = _generateAvatarSeed();
    final random = Random(seed.hashCode);
    
    // Generate RGB values (1-256, but we'll use 0-255 for Color)
    final r = random.nextInt(256);
    final g = random.nextInt(256);
    final b = random.nextInt(256);
    
    // Ensure the color is not too light (to maintain text readability)
    // If the color is too light, darken it
    final brightness = (r * 0.299 + g * 0.587 + b * 0.114);
    if (brightness > 180) {
      // Darken the color if it's too light
      return Color.fromRGBO(
        (r * 0.7).round().clamp(0, 255),
        (g * 0.7).round().clamp(0, 255),
        (b * 0.7).round().clamp(0, 255),
        0.9, // Slight transparency
      );
    }
    
    return Color.fromRGBO(r, g, b, 0.9); // Slight transparency for better text readability
  }

  @override
  void initState() {
    super.initState();
    // Copy assets needed for Jwt operations
    _copyAssets();
  }

  Future<void> _copyAssets() async {
    if (!mounted) return;
    
    setState(() {
      _status = 'Copying assets...';
      _errorMessage = null;
      _isBusy = true;
    });
    try {
      // Define asset paths relative to the 'assets' folder in pubspec.yaml
      const srsAssetPath = 'assets/jwt-srs.local';

      // Copy assets to the file system and store their paths
      final srsPath = await _moproFlutterPlugin.copyAssetToFileSystem(
        srsAssetPath,
      );

      if (!mounted) return;
      
      setState(() {
        _srsPath = srsPath;
        _status = 'Assets copied successfully. Ready.';
        _isBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _status = 'Error copying assets';
        _errorMessage = e.toString();
        _isBusy = false;
      });
      print("Error copying assets: $e");
    }
  }

  Uint8List toUint8List(List<dynamic> data) {
    return Uint8List.fromList(data.cast<int>());
  }

  // Function to call verifyJwtProof
  Future<void> _callVerifyJwtProof(String id, bool isInternal) async {
    setState(() {
      _isLoading = true;
      _verified = null;
    });
    if (_srsPath == null) {
      setState(() {
        _status = 'Proof not available or SRS path missing';
        _errorMessage = 'Generate a proof first or ensure SRS path is valid.';
      });
      return;
    }

    setState(() {
      _status = 'Verifying proof...';
      _verificationResult = null; // Clear previous verification result
      _errorMessage = null;
      _isBusy = true; // Start busy state
    });

    try {
      // Verify the proof
      final stopwatch = Stopwatch()..start();
      final message = await fetchMessage(id, isInternal);
      final googleJwtPubkeyModulus = await fetchGooglePublicKey(
        message['proofArgs']['keyId'],
      );
      final result = await _moproFlutterPlugin.verifyJwtProof(
        _srsPath!,
        Uint8List.fromList(message['proof'].cast<int>()),
        message['anonGroupId'],
        googleJwtPubkeyModulus?["n"],
        message['ephemeralPubkey'],
        message['ephemeralPubkeyExpiry'],
      );
      stopwatch.stop();

      setState(() {
        _verificationResult = result;
        _verifyingTimeMillis = stopwatch.elapsedMilliseconds;
        _status = result != null
            ? 'Verification finished.'
            : 'Verification failed (result is null)';
        _isBusy = false; // End busy state
        _isLoading = false;
        _verified = result?.isValid;
      });
    } catch (e) {
      setState(() {
        _status = 'Error verifying proof';
        _errorMessage = e.toString();
        _isBusy = false; // End busy state on error
        _isLoading = false;
        _verified = false;
      });
      print("Error verifying proof: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.base),
      decoration: BoxDecoration(
        color: _generateUniqueBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.msg.internal 
              ? Colors.white.withOpacity(0.2) 
              : Colors.white.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.msg.internal 
                ? Colors.black.withOpacity(0.25)
                : Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Compact
            Row(
              children: [
                // Anonymous User Avatar - Unique per message
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      _generateAnonymousAvatar(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accentColor,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Someone from ${widget.msg.org}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: widget.msg.internal 
                              ? Colors.white 
                              : AppColors.textPrimaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        timeago.format(widget.msg.time),
                        style: AppTextStyles.small.copyWith(
                          color: widget.msg.internal 
                              ? Colors.white.withOpacity(0.8) 
                              : AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Verification Status - Minimal
                if (_verified != null)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _verified!
                          ? AppColors.success.withOpacity(0.15)
                          : AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _verified! ? Icons.check_circle : Icons.check_circle_outline,
                      size: 16,
                      color: _verified! ? AppColors.success : AppColors.error,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            
            // Message Text - Flexible height
            MarkdownBody(
              data: widget.msg.body,
              styleSheet: MarkdownStyleSheet(
                p: AppTextStyles.body.copyWith(
                  fontSize: 15,
                  height: 1.4,
                  color: widget.msg.internal 
                      ? Colors.white.withOpacity(0.95) 
                      : AppColors.textPrimaryColor,
                ),
                a: AppTextStyles.body.copyWith(
                  color: widget.msg.internal 
                      ? AppColors.accentColor.withOpacity(0.9)
                      : AppColors.accentColor,
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                ),
                code: AppTextStyles.caption.copyWith(
                  color: widget.msg.internal 
                      ? Colors.white.withOpacity(0.9)
                      : AppColors.textSecondaryColor,
                  backgroundColor: widget.msg.internal 
                      ? Colors.black.withOpacity(0.2)
                      : AppColors.surfaceCard,
                  fontSize: 13,
                ),
                img: AppTextStyles.body,
              ),
              imageBuilder: (uri, title, alt) {
                print('Loading image: ${uri.toString()}'); // Debug log
                
                // Validate URL
                if (uri.toString().isEmpty || 
                    (!uri.toString().startsWith('http://') && 
                     !uri.toString().startsWith('https://'))) {
                  print('Invalid image URL: ${uri.toString()}');
                  return Container(
                    height: 80,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.accentColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textSecondaryColor,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Invalid URL',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryColor,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      uri.toString(),
                      fit: BoxFit.cover,
                      headers: {
                        'User-Agent': 'Mozilla/5.0 (compatible; StealthNote/1.0)',
                        'Accept': 'image/*',
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentColor,
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Loading image...',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Image load error: $error for URL: ${uri.toString()}'); // Debug log
                        print('Stack trace: $stackTrace'); // More detailed error info
                        return Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accentColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.textSecondaryColor,
                                  size: 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Failed to load',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              onTapLink: (text, href, title) {
                print('Link tapped: $href'); // Debug log
              },
            ),
            SizedBox(height: 12),
            
            // Bottom Actions - Compact
            Row(
              children: [
                // Like Button - Minimal
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () async {
                      if (widget.msg.isLiked == 0) {
                        await toggleLike(widget.msg.id, true);
                        setState(() {
                          widget.msg.likes++;
                          widget.msg.isLiked = 1;
                        });
                      } else {
                        await toggleLike(widget.msg.id, false);
                        setState(() {
                          widget.msg.likes--;
                          widget.msg.isLiked = 0;
                        });
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.msg.isLiked == 1
                            ? AppColors.accentColor.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.msg.isLiked == 1
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 16,
                            color: widget.msg.isLiked == 1
                                ? AppColors.accentColor
                                : widget.msg.internal 
                                    ? Colors.white.withOpacity(0.8)
                                    : AppColors.textSecondaryColor,
                          ),
                          if (widget.msg.likes > 0) ...[
                            SizedBox(width: 4),
                            Text(
                              widget.msg.likes.toString(),
                              style: AppTextStyles.caption.copyWith(
                                color: widget.msg.isLiked == 1
                                    ? AppColors.accentColor
                                    : widget.msg.internal 
                                        ? Colors.white.withOpacity(0.8)
                                        : AppColors.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                Spacer(),
                
                // Verify Button - Only show if not verified
                if (_verified == null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _isLoading
                          ? null
                          : () => _callVerifyJwtProof(
                                widget.msg.id,
                                widget.msg.internal,
                              ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                          decoration: BoxDecoration(
                            color: widget.msg.internal 
                                ? Colors.white.withOpacity(0.15)
                                : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: widget.msg.internal 
                                  ? Colors.white.withOpacity(0.4)
                                  : AppColors.accentColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                        child: _isLoading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accentColor,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 14,
                                      color: widget.msg.internal 
                                          ? Colors.white
                                          : AppColors.accentColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Verify',
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: widget.msg.internal 
                                            ? Colors.white
                                            : AppColors.accentColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

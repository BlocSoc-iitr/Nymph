import 'dart:typed_data';

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
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with org and time
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accentColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      // Deterministic anonymous avatar per org using DiceBear
                      "https://api.dicebear.com/7.x/bottts/png?seed=${Uri.encodeComponent(widget.msg.org)}&backgroundType=gradientLinear&size=80",
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Someone from ${widget.msg.org}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimaryColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        timeago.format(widget.msg.time),
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Verification badge
                if (_verified != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs / 2,
                    ),
                    decoration: BoxDecoration(
                      color: _verified!
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: _verified!
                            ? AppColors.success.withOpacity(0.3)
                            : AppColors.error.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _verified! ? Icons.verified : Icons.error_outline,
                          size: 12,
                          color: _verified! ? AppColors.success : AppColors.error,
                        ),
                        SizedBox(width: 4),
                        Text(
                          _verified! ? 'Verified' : 'Failed',
                          style: AppTextStyles.small.copyWith(
                            color: _verified! ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            
            // Message body
            MarkdownBody(
              data: widget.msg.body,
              styleSheet: MarkdownStyleSheet(
                p: AppTextStyles.body,
                a: AppTextStyles.body.copyWith(
                  color: AppColors.accentColor,
                  decoration: TextDecoration.underline,
                ),
                code: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryColor,
                  backgroundColor: AppColors.surfaceCard,
                ),
                img: AppTextStyles.body,
              ),
              imageBuilder: (uri, title, alt) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      uri.toString(),
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.accentColor,
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Loading image...',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
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
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  alt ?? 'Failed to load image',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (title != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    style: AppTextStyles.small.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: AppSpacing.md),
            
            // Divider
            Container(
              height: 1,
              color: Colors.white.withOpacity(0.05),
            ),
            SizedBox(height: AppSpacing.md),
            
            // Footer with actions
            Row(
              children: [
                // Like button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
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
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.msg.isLiked == 1
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 18,
                            color: widget.msg.isLiked == 1
                                ? AppColors.accentColor
                                : AppColors.textSecondaryColor,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            widget.msg.likes.toString(),
                            style: AppTextStyles.caption.copyWith(
                              color: widget.msg.isLiked == 1
                                  ? AppColors.accentColor
                                  : AppColors.textSecondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                
                // Verify button
                if (_verified == null)
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _callVerifyJwtProof(
                              widget.msg.id,
                              widget.msg.internal,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceCard,
                      foregroundColor: AppColors.accentColor,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.base,
                        vertical: AppSpacing.xs,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
                              Icon(Icons.shield_outlined, size: 16),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                'Verify',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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

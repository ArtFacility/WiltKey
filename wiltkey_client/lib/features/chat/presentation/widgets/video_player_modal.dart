import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';
import 'package:wiltkey_client/core/models.dart';
import 'package:wiltkey_client/core/theme/wk.dart';
import 'package:wiltkey_client/core/video/video_message_service.dart';
import 'package:wiltkey_client/l10n/app_localizations.dart';

/// Full-screen modal player for viewing encrypted short video messages.
class WkVideoPlayerModal extends StatefulWidget {
  final ChatMessage message;
  final VideoMessagePayload payload;
  final File? localFile;

  const WkVideoPlayerModal({
    super.key,
    required this.message,
    required this.payload,
    this.localFile,
  });

  static Future<void> show(
    BuildContext context, {
    required ChatMessage message,
    required VideoMessagePayload payload,
    File? localFile,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WkVideoPlayerModal(
          message: message,
          payload: payload,
          localFile: localFile,
        ),
      ),
    );
  }

  @override
  State<WkVideoPlayerModal> createState() => _WkVideoPlayerModalState();
}

class _WkVideoPlayerModalState extends State<WkVideoPlayerModal> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;
  File? _activeFile;
  bool _controlsVisible = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initVideo() async {
    try {
      File? f = widget.localFile;
      if (f == null || !(await f.exists())) {
        f = await VideoMessageService.getOrWriteVideoFile(
          messageId: widget.message.id,
          payload: widget.payload,
        );
      }

      if (f == null || !(await f.exists())) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Failed to load video file';
          });
        }
        return;
      }

      _activeFile = f;
      widget.message.cachedVideoPath = f.path;

      final controller = VideoPlayerController.file(f);
      await controller.initialize();
      // A broken/corrupt container can report a zero duration; looping then
      // spins on nothing and the scrubber's max==0 would assert.
      if (controller.value.duration.inMilliseconds > 0) {
        await controller.setLooping(true);
      }
      await controller.play();

      if (!mounted) {
        controller.dispose();
        return;
      }

      controller.addListener(_onControllerUpdate);

      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Error playing video: $e';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _saveToGallery() async {
    if (_activeFile == null || _saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.chatImageSaveFailed)),
            );
          }
          return;
        }
      }

      await Gal.putVideo(_activeFile!.path);
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatVideoSavedGallery ?? 'Video saved to gallery'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.wk;
    final l10n = AppLocalizations.of(context)!;
    final canSave = (widget.message.isSentByMe || widget.message.allowSave) &&
        !widget.message.ephemeral;
    // Slider needs max > 0 — a zero-duration (corrupt) container must not
    // assert the scrubber; 1000ms placeholder keeps it operable.
    final double rawMaxMs =
        _controller?.value.duration.inMilliseconds.toDouble() ?? 0;
    final double sliderMaxMs = rawMaxMs > 0 ? rawMaxMs : 1000.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Display
            if (_loading)
              Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(t.action),
                ),
              )
            else if (_error != null || _controller == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white60, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? l10n.chatVideoError,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _controlsVisible = !_controlsVisible);
                  },
                  child: AspectRatio(
                    aspectRatio: (_controller!.value.aspectRatio > 0 &&
                            _controller!.value.aspectRatio.isFinite)
                        ? _controller!.value.aspectRatio
                        : 16 / 9,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller!),
                        if (!_controller!.value.isPlaying)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // Top Header Overlay
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        l10n.chatAttachVideo ?? 'Video',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (canSave)
                        IconButton(
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.file_download_outlined, color: Colors.white),
                          tooltip: l10n.chatVideoSaveGallery ?? 'Save Video to Gallery',
                          onPressed: _saveToGallery,
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Controller Bar Overlay
            if (_controller != null && _controller!.value.isInitialized)
              AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scrubber Slider
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: t.action,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: t.action,
                          ),
                          child: Slider(
                            value: _controller!.value.position.inMilliseconds
                                .toDouble()
                                .clamp(0.0, sliderMaxMs),
                            min: 0.0,
                            max: sliderMaxMs,
                            onChanged: (val) {
                              _controller!.seekTo(Duration(milliseconds: val.round()));
                            },
                          ),
                        ),

                        // Controls & Timers
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                _controller!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_controller!.value.isPlaying) {
                                    _controller!.pause();
                                  } else {
                                    _controller!.play();
                                  }
                                });
                              },
                            ),
                            Text(
                              '${VideoMessageService.formatDurationMs(_controller!.value.position.inMilliseconds)} / ${VideoMessageService.formatDurationMs(_controller!.value.duration.inMilliseconds)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontFamily: 'Courier',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

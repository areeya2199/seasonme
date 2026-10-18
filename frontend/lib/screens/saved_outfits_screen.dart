import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/saved_outfit.dart';
import '../services/saved_outfits_service.dart';
import '../theme/app_theme.dart';

// Keep error presentation in English without changing shared service messages.
String _savedOutfitsErrorMessage(Object error) {
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' || 'unauthorized' =>
        'Access denied. Please sign in again or check Saved Outfits permissions.',
      'unauthenticated' => 'Please sign in again.',
      'unavailable' || 'network-request-failed' || 'retry-limit-exceeded' =>
        'Unable to connect. Check your internet connection and try again.',
      'object-not-found' =>
        'This photo is missing. You can still remove the saved outfit.',
      _ => 'Something went wrong. Please try again.',
    };
  }
  if (error is StateError ||
      error is ArgumentError ||
      error is FormatException) {
    final message = error.toString().replaceFirst(RegExp(r'^[^:]+: '), '');
    if (!RegExp(r'[\u0E00-\u0E7F]').hasMatch(message)) return message;
  }
  return 'Something went wrong. Please try again.';
}

class SavedOutfitsScreen extends StatefulWidget {
  final SavedOutfitsAccess? access;
  const SavedOutfitsScreen({super.key, this.access});

  @override
  State<SavedOutfitsScreen> createState() => _SavedOutfitsScreenState();
}

class _SavedOutfitsScreenState extends State<SavedOutfitsScreen> {
  late final SavedOutfitsAccess _access;
  StreamSubscription<String?>? _auth;
  List<SavedOutfit> _items = [];
  bool _loading = true;
  int _invalidCount = 0;
  int _request = 0;
  String? _error;
  String? _owner;
  final Set<String> _deleting = {};
  final Map<String, String> _deleteErrors = {};
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _access = widget.access ?? SavedOutfitsService.firebase();
    _owner = _access.currentUid;
    _auth = _access.accountChanges.listen((uid) {
      if (!mounted || uid == _owner) return;
      _owner = uid;
      ++_request;
      setState(() {
        _items = [];
        _deleting.clear();
        _deleteErrors.clear();
        _invalidCount = 0;
        _error = null;
        _loading = true;
      });
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    ++_request;
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final uid = _access.currentUid;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (uid == null) {
      setState(() {
        _loading = false;
        _items = [];
        _error = 'Please sign in to view Saved Outfits.';
      });
      return;
    }
    try {
      final result = await _access.list();
      if (!mounted || request != _request || uid != _access.currentUid) return;
      setState(() {
        _items = result.items;
        _invalidCount = result.invalidCount;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request || uid != _access.currentUid) return;
      setState(() {
        _items = [];
        _error = _savedOutfitsErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _remove(SavedOutfit item) async {
    if (_confirming || _deleting.contains(item.id)) return;
    final request = _request;
    _confirming = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Remove saved outfit?',
            style: TextStyle(fontFamily: 'Lora', fontSize: 21),
          ),
          // content: const Text(
          //   'This outfit and its saved photo will be removed from Saved Outfits.',
          // ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFA43E37),
                foregroundColor: AppColors.white,
                minimumSize: const Size(80, 48),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
    } finally {
      _confirming = false;
    }
    if (!mounted ||
        confirmed != true ||
        request != _request ||
        _access.currentUid != item.ownerUid) {
      return;
    }
    setState(() {
      _deleting.add(item.id);
      _deleteErrors.remove(item.id);
    });
    try {
      await _access.remove(item);
      if (!mounted ||
          request != _request ||
          _access.currentUid != item.ownerUid) {
        return;
      }
      setState(() {
        _items = _items.where((entry) => entry.id != item.id).toList();
        _deleting.remove(item.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved outfit removed.')));
    } catch (error) {
      if (!mounted ||
          request != _request ||
          _access.currentUid != item.ownerUid) {
        return;
      }
      setState(() {
        _deleting.remove(item.id);
        _deleteErrors[item.id] = _savedOutfitsErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) => GradientScaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 52) / 2;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GradientBackButton(
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Saved Outfits',
                            style: TextStyle(
                              fontFamily: 'Lora',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh outfits',
                          onPressed: _loading || _deleting.isNotEmpty
                              ? null
                              : _load,
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_invalidCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '$_invalidCount outfits could not be displayed because their data is incomplete. Please refresh to try again.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA43E37),
                          ),
                        ),
                      ),
                    if (!_loading && _error == null && _items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          '${_items.length} saved outfits',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF655A53),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _message(_error!, retry: true),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _message(
                  _invalidCount > 0
                      ? 'Unable to display your outfits.'
                      : 'Your outfits, kept close.',
                  empty: _invalidCount == 0,
                  retry: _invalidCount > 0,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid.builder(
                  itemCount: _items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    mainAxisExtent:
                        width * 1.14 + _metadataHeight(context, width - 24),
                  ),
                  itemBuilder: (context, index) => _tile(_items[index]),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _message(
    String text, {
    bool empty = false,
    bool retry = false,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 48, 28, 40),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0xFFF3E2DC),
            shape: BoxShape.circle,
          ),
          child: Icon(
            empty ? Icons.bookmark_outline : Icons.error_outline,
            size: 36,
            color: const Color(0xFF9B7770),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: empty ? 'Lora' : null,
            fontSize: empty ? 22 : 15,
          ),
        ),
        if (empty) ...[
          const SizedBox(height: 12),
          const Text(
            'No saved outfits yet.\nCheck an outfit and save the pieces that match your season.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF74645B)),
          ),
        ],
        if (retry) ...[
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ],
    ),
  );

  double _metadataHeight(BuildContext context, double width) {
    Size measure(String text, double size, {bool bold = false}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: DefaultTextStyle.of(context).style.merge(
            TextStyle(
              fontSize: size,
              fontWeight: bold ? FontWeight.w900 : null,
            ),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: width);
      final result = painter.size;
      painter.dispose();
      return result;
    }

    var tallest = 0.0;
    for (final item in _items) {
      final label = measure(_label(item), 12, bold: true),
          score = measure('${item.match.matchPercent}%', 17, bold: true);
      final matchHeight = label.width + 6 + score.width <= width
          ? math.max(label.height, score.height)
          : label.height + score.height;
      // Deletion errors use a compact retry action; full details appear in a dialog.
      final pending =
          _deleteErrors.containsKey(item.id) || item.status == 'deleting';
      final extra = pending
          ? math.max(48.0, measure('Retry delete', 12).height + 16)
          : 0.0;
      tallest = math.max(
        tallest,
        20 +
            matchHeight +
            3 +
            measure('Checked for ${item.match.season.name}', 12).height +
            extra,
      );
    }
    return tallest.ceilToDouble() + 2;
  }

  String _label(SavedOutfit item) => item.match.matchLevel.name == 'excellent'
      ? 'Excellent Match'
      : 'Good Match';

  Widget _tile(SavedOutfit item) {
    final deleting = _deleting.contains(item.id);
    final failed =
        _deleteErrors.containsKey(item.id) || item.status == 'deleting';
    final color = item.match.matchLevel.name == 'excellent'
        ? const Color(0xFF28714E)
        : const Color(0xFF88631C);
    return Container(
      key: ValueKey('${item.ownerUid}/${item.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1 / 1.14,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _OutfitPhoto(
                  key: ValueKey('photo/$_request/${item.ownerUid}/${item.id}'),
                  entry: item,
                  access: _access,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                        ),
                      ),
                      child: Text(
                        item.displayName,
                        key: ValueKey('outfit-name/${item.id}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: AppColors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: deleting
                          ? 'Removing outfit'
                          : 'Remove saved outfit',
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: deleting ? null : () => _remove(item),
                      icon: deleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Color(0xFF8B514A),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _label(item),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                    Text(
                      '${item.match.matchPercent}%',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Checked for ${item.match.season.name}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF665B54),
                  ),
                ),
                if (failed)
                  TextButton(
                    onPressed: deleting ? null : () => _retryDelete(item),
                    child: const Text(
                      'Retry delete',
                      style: TextStyle(fontSize: 12, color: Color(0xFFA43E37)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryDelete(SavedOutfit item) async {
    final detail =
        _deleteErrors[item.id] ?? 'Removal is incomplete. Please try again.';
    final request = _request;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not remove outfit'),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted && request == _request && _access.currentUid == item.ownerUid) {
      await _remove(item);
    }
  }
}

class _OutfitPhoto extends StatefulWidget {
  final SavedOutfit entry;
  final SavedOutfitsAccess access;
  const _OutfitPhoto({super.key, required this.entry, required this.access});
  @override
  State<_OutfitPhoto> createState() => _OutfitPhotoState();
}

class _OutfitPhotoState extends State<_OutfitPhoto> {
  Uint8List? _bytes;
  String? _error;
  int _request = 0;
  StreamSubscription<String?>? _auth;
  bool _accountChanged = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.access.accountChanges.listen((uid) {
      if (!mounted || uid == widget.entry.ownerUid) return;
      ++_request;
      setState(() {
        _accountChanged = true;
        _bytes = null;
        _error = 'Your account has changed.';
      });
    });
    _load();
  }

  @override
  void dispose() {
    ++_request;
    _bytes = null;
    _auth?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_accountChanged) return;
    final request = ++_request;
    setState(() {
      _error = null;
      _bytes = null;
    });
    try {
      final bytes = await widget.access.photo(widget.entry);
      if (!mounted ||
          request != _request ||
          widget.access.currentUid != widget.entry.ownerUid) {
        return;
      }
      setState(() => _bytes = bytes);
    } catch (error) {
      if (!mounted ||
          request != _request ||
          widget.access.currentUid != widget.entry.ownerUid) {
        return;
      }
      setState(() => _error = _savedOutfitsErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFE8DFD3),
    child: _bytes != null
        ? Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            cacheWidth: 600,
            gaplessPlayback: false,
            semanticLabel: 'Saved outfit',
            errorBuilder: (context, error, stack) =>
                _failure('Unable to read this photo.'),
          )
        : _error != null
        ? _failure(_error!)
        : const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold,
              ),
            ),
          ),
  );
  Widget _failure(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, color: Color(0xFF77645B)),
        TextButton(
          onPressed: _accountChanged
              ? null
              : () async {
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Could not load photo'),
                      content: Text(message),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  if (mounted) await _load();
                },
          child: const Text('Retry photo'),
        ),
      ],
    ),
  );
}

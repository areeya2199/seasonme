/// One task per analysis result. Retries reuse the same metadata/document ID.
/// Callbacks make failures at each persistence boundary testable without Firebase.
class HistorySaveTask {
  final String id;
  final void Function() checkOwner;
  final Future<void> Function() saveAnalysis;
  final Future<void> Function() uploadPhoto;
  final Future<void> Function() markReady;
  final Future<void> Function() markFailed;
  final void Function()? onStart;
  final void Function()? onFinish;
  bool _analysisSaved = false;
  bool _photoUploaded = false;
  bool _complete = false;
  Future<bool>? _running;

  HistorySaveTask({
    required this.id,
    required this.checkOwner,
    required this.saveAnalysis,
    required this.uploadPhoto,
    required this.markReady,
    required this.markFailed,
    this.onStart,
    this.onFinish,
  });

  Future<bool> save() {
    if (_running != null) return _running!;
    _running = _guardedSave().whenComplete(() => _running = null);
    return _running!;
  }

  Future<bool> _guardedSave() async {
    var started = false;
    try {
      onStart?.call();
      started = true;
      return await _save();
    } finally {
      if (started) onFinish?.call();
    }
  }

  Future<bool> _save() async {
    checkOwner();
    if (_complete) return true;
    if (!_analysisSaved) {
      await saveAnalysis();
      checkOwner();
      _analysisSaved = true;
    }
    try {
      if (!_photoUploaded) {
        await uploadPhoto();
        checkOwner();
        _photoUploaded = true;
      }
      await markReady();
      checkOwner();
      _complete = true;
      return true;
    } catch (_) {
      checkOwner();
      try {
        await markFailed();
      } catch (_) {
        // A pending record is recoverable even when the status update fails.
      }
      checkOwner();
      return false;
    }
  }
}

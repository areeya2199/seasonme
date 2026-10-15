class UndertoneUtils {
  UndertoneUtils._();

  /// Formats the saved analysis value without inferring it from a season.
  static String label(
    Map<String, dynamic>? analysis, {
    bool withSuffix = false,
  }) {
    final value = analysis?['undertone'];
    if (value is! String) return '—';

    final String undertone;
    switch (value.trim().toLowerCase()) {
      case 'warm':
      case 'warm undertone':
        undertone = 'Warm';
        break;
      case 'cool':
      case 'cool undertone':
        undertone = 'Cool';
        break;
      default:
        return '—';
    }
    return withSuffix ? '$undertone undertone' : undertone;
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Presentation states only. This widget does not persist or upload an outfit.
enum OutfitSaveState { idle, saving, saved, failed }

class OutfitSaveButton extends StatelessWidget {
  final OutfitSaveState state;
  final VoidCallback? onPressed;

  const OutfitSaveButton({super.key, required this.state, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final saved = state == OutfitSaveState.saved;
    final saving = state == OutfitSaveState.saving;
    final label = switch (state) {
      OutfitSaveState.idle => 'Save Outfit',
      OutfitSaveState.saving => 'Saving...',
      OutfitSaveState.saved => 'Saved',
      OutfitSaveState.failed => 'Retry',
    };
    final foreground = saved ? const Color(0xFF28714E) : AppColors.white;
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: saving || saved ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            backgroundColor: const Color(0xFF4C3935),
            foregroundColor: foreground,
            disabledBackgroundColor: saved
                ? const Color(0xFFE1EEE5)
                : const Color(0xFFE4D7CE),
            disabledForegroundColor: saved
                ? foreground
                : const Color(0xFF76665C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          icon: saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF76665C),
                  ),
                )
              : Icon(
                  saved
                      ? Icons.check
                      : state == OutfitSaveState.failed
                      ? Icons.refresh
                      : Icons.bookmark_outline,
                  size: 20,
                ),
          label: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

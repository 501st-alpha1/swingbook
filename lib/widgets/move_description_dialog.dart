import 'package:flutter/material.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../screens/skill_focus_page.dart';
import '../theme.dart';

/// Shows a popup for [move] with its description (if any), a Queue toggle
/// button, and a Focus button (when in a session).
///
///
/// [sessionExposureDeltas] and [onExposureAdjusted] are the in-memory
/// session exposure tracking state, threaded through to [SkillFocusPage].
/// [sessionRoles] — pass empty map outside a session to hide session buttons.
/// [queuedMoveIds] / [onToggleQueue] — the session's teach queue state.
void showMovePopup(
  BuildContext context,
  Move move,
  Map<String, Set<Role>> sessionRoles, {
  Map<String, Map<String, int>> sessionExposureDeltas = const {},
  void Function(String moveId, List<String> studentIds, int delta)? onExposureAdjusted,
  Set<String> queuedMoveIds = const {},
  ValueChanged<String>? onToggleQueue,
}) {
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final isQueued = queuedMoveIds.contains(move.id);
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final gold = isDark ? AppTheme.goldDark : AppTheme.gold;

        return AlertDialog(
          title: Text(move.name),
          content: move.hasDescription ? Text(move.description!) : null,
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                if (sessionRoles.isNotEmpty && onToggleQueue != null)
                  TextButton.icon(
                    icon: Icon(
                      isQueued ? Icons.playlist_remove : Icons.playlist_add,
                      size: 18,
                      color: isQueued ? gold : null,
                    ),
                    label: Text(
                      isQueued ? 'Dequeue' : 'Queue',
                      style: TextStyle(color: isQueued ? gold : null),
                    ),
                    onPressed: () {
                      onToggleQueue(move.id);
                      setState(() {});
                    },
                  ),
                if (sessionRoles.isNotEmpty)
                  FilledButton.icon(
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Focus'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SkillFocusPage(
                            move: move,
                            sessionRoles: sessionRoles,
                            sessionExposureDeltas: sessionExposureDeltas,
                            onExposureAdjusted: onExposureAdjusted,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

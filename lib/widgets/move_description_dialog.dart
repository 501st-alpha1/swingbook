import 'package:flutter/material.dart';

import '../models/move.dart';
import '../models/student.dart';
import '../screens/skill_focus_page.dart';

/// Shows a popup for [move] with its description (if any) and a button to
/// open the [SkillFocusPage] for drilling that skill with tonight's session.
///
/// [sessionRoles] is the current session's attendee map (studentId → role).
/// Pass an empty map when called outside a session context (e.g. catalog) —
/// the Focus button will be hidden when there are no session attendees.
void showMovePopup(
  BuildContext context,
  Move move,
  Map<String, Role> sessionRoles,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(move.name),
      content: move.hasDescription
          ? Text(move.description!)
          : null,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        if (sessionRoles.isNotEmpty)
          FilledButton.icon(
            icon: const Icon(Icons.center_focus_strong, size: 18),
            label: const Text('Focus'),
            onPressed: () {
              Navigator.pop(ctx); // close the dialog first
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SkillFocusPage(
                    move: move,
                    sessionRoles: sessionRoles,
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../models/move.dart';

/// Shows the full description of a move in a simple dialog. Used wherever
/// a move name appears, as the "more info" view for moves that don't have
/// one settled name and need a longer step-by-step reminder.
void showMoveDescription(BuildContext context, Move move) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(move.name),
      content: Text(move.description ?? ''),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

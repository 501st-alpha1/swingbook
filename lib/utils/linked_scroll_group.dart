import 'package:flutter/widgets.dart';

/// Links any number of [ScrollController]s so they always share the same
/// scroll offset, even when the controllers are created and disposed
/// dynamically (e.g. one per row of a lazily-built [SliverList]).
///
/// This solves a specific Flutter footgun: a single [ScrollController]
/// cannot be attached to more than one [Scrollable] at the same time (it
/// throws "ScrollController attached to multiple scroll views"). The
/// correct approach is one controller per scrollable, all kept in sync —
/// which is what this class does.
///
/// Usage: call [addAndGet] once per scrollable widget (e.g. inside a
/// `SliverChildBuilderDelegate`'s itemBuilder), and call [remove] when that
/// widget is disposed (typically in the controller's own dispose, or by
/// giving each scrollable a stable key so Flutter doesn't silently reuse
/// a disposed controller for a different row).
class LinkedScrollGroup {
  final List<_LinkedScrollController> _members = [];
  double _offset = 0;
  bool _isSyncing = false;

  /// Creates a new controller linked to this group's current offset.
  /// The caller owns the returned controller and must dispose it (which
  /// also removes it from this group).
  ScrollController addAndGet() {
    final controller = _LinkedScrollController(this, initialScrollOffset: _offset);
    _members.add(controller);
    return controller;
  }

  void _remove(_LinkedScrollController controller) {
    _members.remove(controller);
  }

  void _onOffsetChanged(_LinkedScrollController source, double newOffset) {
    if (_isSyncing) return;
    _offset = newOffset;
    _isSyncing = true;
    for (final member in List<_LinkedScrollController>.of(_members)) {
      if (member == source) continue;
      if (member.hasClients && member.offset != newOffset) {
        member.jumpTo(newOffset);
      }
    }
    _isSyncing = false;
  }
}

class _LinkedScrollController extends ScrollController {
  _LinkedScrollController(this._group, {required double initialScrollOffset})
      : super(initialScrollOffset: initialScrollOffset) {
    addListener(_handleSelfChanged);
  }

  final LinkedScrollGroup _group;

  void _handleSelfChanged() {
    if (!hasClients) return;
    _group._onOffsetChanged(this, offset);
  }

  @override
  void dispose() {
    removeListener(_handleSelfChanged);
    _group._remove(this);
    super.dispose();
  }
}

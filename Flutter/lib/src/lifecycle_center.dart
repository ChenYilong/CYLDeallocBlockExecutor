import 'lifecycle_event.dart';
import 'lifecycle_log.dart';

class _GlobalEntry {
  _GlobalEntry({
    required this.identifier,
    required this.callback,
    this.event,
    this.custom,
    this.timing = LifecycleTiming.afterSuper,
    this.ownerType,
    this.key,
  });

  final int identifier;
  final LifecycleCallback<Object> callback;
  final LifecycleEvent? event;
  final String? custom;
  final LifecycleTiming timing;
  final bool Function(Object owner)? ownerType;
  final String? key;
}

/// Global observers: one block that observes an event on every object, for
/// behavior that must not know its owners ("pause every animation while the
/// user scrolls"). Per-owner blocks run first, then the global ones, each group
/// in identifier order. Global observers never receive teardown events: the
/// owner is going away. A key replaces the observer added before under it.
///
/// [ownerFilter] is the Dart form of the owner type (Dart cannot pass a type
/// as a value for `is`): `(o) => o is MyState`.
class LifecycleCenter {
  LifecycleCenter._();

  static final List<_GlobalEntry> _entries = [];
  static int _nextIdentifier = 1;
  static final Set<WeakReference<Object>> _scrolling = {};

  /// True while any observed scroll source is dragging or decelerating.
  static bool get isUserScrolling {
    _scrolling.removeWhere((r) => r.target == null);
    return _scrolling.isNotEmpty;
  }

  static int addCallback<T extends Object>(
    LifecycleEvent event,
    LifecycleCallback<T> callback, {
    LifecycleTiming timing = LifecycleTiming.afterSuper,
    bool Function(Object owner)? ownerFilter,
    String? key,
  }) =>
      _add(_GlobalEntry(
        identifier: 0,
        event: event,
        timing: timing,
        ownerType: ownerFilter,
        key: key,
        callback: (o, i, info) => callback(o as T, i, info),
      ));

  static int addCustomCallback<T extends Object>(
    String name,
    LifecycleCallback<T> callback, {
    bool Function(Object owner)? ownerFilter,
    String? key,
  }) =>
      _add(_GlobalEntry(
        identifier: 0,
        custom: name,
        ownerType: ownerFilter,
        key: key,
        callback: (o, i, info) => callback(o as T, i, info),
      ));

  static int _add(_GlobalEntry prototype) {
    if (prototype.key != null) {
      _entries.removeWhere((e) => e.key == prototype.key);
    }
    final id = _nextIdentifier++;
    _entries.add(_GlobalEntry(
      identifier: id,
      callback: prototype.callback,
      event: prototype.event,
      custom: prototype.custom,
      timing: prototype.timing,
      ownerType: prototype.ownerType,
      key: prototype.key,
    ));
    return id;
  }

  /// Cancels one observer by [identifier] or by [key]; true when one was removed.
  static bool cancelCallback({int? identifier, String? key}) {
    assert((identifier == null) != (key == null),
        'pass exactly one of identifier or key');
    final before = _entries.length;
    _entries.removeWhere(
        (e) => identifier != null ? e.identifier == identifier : e.key == key);
    return _entries.length < before;
  }

  static final List<(int, String?, void Function(String description, LifecycleInfo info))> _deallocObservers = [];

  /// Observes the teardown of every owner that has a registry, to know when any
  /// object goes away. The callback gets a description (type and identity),
  /// never the owner: it is being destroyed. For logging and bookkeeping, not
  /// for cleanup.
  static int addDeallocObserver(
      void Function(String description, LifecycleInfo info) callback,
      {String? key}) {
    if (key != null) _deallocObservers.removeWhere((o) => o.$2 == key);
    final id = _nextIdentifier++;
    _deallocObservers.add((id, key, callback));
    return id;
  }

  static bool cancelDeallocObserver({int? identifier, String? key}) {
    assert((identifier == null) != (key == null),
        'pass exactly one of identifier or key');
    final before = _deallocObservers.length;
    _deallocObservers
        .removeWhere((o) => identifier != null ? o.$1 == identifier : o.$2 == key);
    return _deallocObservers.length < before;
  }

  /// Called by a registry when its owner's teardown blocks ran.
  static void dispatchDealloc(String description) {
    LifecycleLog.log(() => 'dealloc $description');
    const info = LifecycleInfo(
        event: null, timing: LifecycleTiming.end, isDealloc: true);
    for (final o in List.of(_deallocObservers)) {
      o.$3(description, info);
    }
  }

  /// For tests: removes every observer and forgets the scroll state.
  static void reset() {
    _deallocObservers.clear();
    _entries.clear();
    _scrolling.clear();
  }

  /// Called by a registry after the owner's own blocks of (event, timing) ran.
  static void dispatch(Object owner, LifecycleEvent? event, String? custom,
      LifecycleTiming timing, LifecycleInfo info) {
    if (event == LifecycleEvent.scrollWillBeginDragging) {
      _scrolling.add(WeakReference<Object>(owner));
    } else if (event == LifecycleEvent.scrollDidEndScrolling) {
      _scrolling.removeWhere((r) => r.target == null || identical(r.target, owner));
    }
    if (_entries.isEmpty) return;
    final snapshot = _entries
        .where((e) =>
            e.event == event &&
            e.custom == custom &&
            (custom != null || e.timing == timing))
        .toList()
      ..sort((a, b) => a.identifier.compareTo(b.identifier));
    for (final e in snapshot) {
      if (!_entries.contains(e)) continue;
      if (e.ownerType != null && !e.ownerType!(owner)) continue;
      e.callback(owner, e.identifier, info.copyWith(event: event, timing: timing, customEvent: custom));
    }
  }
}

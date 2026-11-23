import 'package:flutter/foundation.dart' show visibleForTesting;

import 'lifecycle_center.dart';
import 'lifecycle_event.dart';
import 'lifecycle_log.dart';

class _Entry {
  _Entry({
    required this.identifier,
    required this.callback,
    this.event,
    this.custom,
    this.timing = LifecycleTiming.afterSuper,
    this.invokeOnce = false,
    this.key,
  });

  final int identifier;
  final LifecycleCallback<Object> callback;
  final LifecycleEvent? event; // null: a teardown block or a custom event
  final String? custom; // set: a custom event block
  final LifecycleTiming timing;
  final bool invokeOnce;
  final String? key;
  bool fired = false;
  bool cancelled = false;

  bool get isDealloc => event == null && custom == null;
}

/// One registry per owner: the lifecycle blocks and the teardown blocks.
///
/// Rules (the iOS rules, see `docs/Lifecycle-Callbacks.md`):
/// - one identifier counter for every block;
/// - blocks run in identifier order, from a snapshot, so a block can add or
///   cancel blocks;
/// - adding with a key replaces the block added before under that key (the new
///   block starts unfired); keys are separate for lifecycle and teardown blocks;
/// - blocks with a key belong to their key holder: cancel-all and re-arm by
///   event skip them; cancel and re-arm by key reach them;
/// - no lock: Dart code runs on one isolate.
class LifecycleRegistry {
  LifecycleRegistry(Object owner) : _owner = WeakReference<Object>(owner);

  static final Expando<LifecycleRegistry> _registries = Expando();

  /// The registry of [owner], created on first use. For a `State` that mixes in
  /// `CYLLifecycleMixin` this is the same object as `lifecycle`.
  static LifecycleRegistry of(Object owner) =>
      _registries[owner] ??= LifecycleRegistry(owner);

  final WeakReference<Object> _owner;
  final List<_Entry> _entries = [];
  int _nextIdentifier = 1;

  final Set<(LifecycleEvent, LifecycleTiming)> _manual = {};
  final Map<LifecycleEvent, int> _performDepth = {};
  final List<(WeakReference<LifecycleRegistry>, Set<LifecycleEvent>?)> _forwards = [];

  /// Called when a block is added for [event] (the mixin uses it to attach its
  /// observers lazily).
  void Function(LifecycleEvent event)? onRegister;

  /// The mixin sets this once its automatic hooks bracket the framework call.
  bool hookInstalled = false;

  int get blockCount => _entries.where((e) => !e.cancelled).length;

  int _add(_Entry entry) {
    _entries.add(entry);
    return entry.identifier;
  }

  void _removeKey(String? key, {required bool dealloc, bool custom = false}) {
    if (key == null) return;
    for (final e in _entries) {
      if (e.key == key &&
          e.isDealloc == dealloc &&
          (e.custom != null) == custom &&
          !e.cancelled) {
        e.cancelled = true;
      }
    }
    _entries.removeWhere((e) => e.cancelled);
  }

  // MARK: lifecycle blocks

  /// Adds a block for [event]; returns its identifier.
  int addLifecycleCallback<T extends Object>(
    LifecycleEvent event,
    LifecycleCallback<T> callback, {
    LifecycleTiming timing = LifecycleTiming.afterSuper,
    bool invokeOnce = false,
    String? key,
  }) {
    _removeKey(key, dealloc: false);
    final id = _nextIdentifier++;
    _add(_Entry(
      identifier: id,
      event: event,
      timing: timing,
      invokeOnce: invokeOnce,
      key: key,
      callback: (owner, identifier, info) =>
          callback(owner as T, identifier, info),
    ));
    onRegister?.call(event);
    return id;
  }

  // MARK: custom events

  /// Adds a block for the custom event [name]; returns its identifier.
  int addCustomCallback<T extends Object>(
    String name,
    LifecycleCallback<T> callback, {
    bool invokeOnce = false,
    String? key,
  }) {
    _removeKey(key, dealloc: false, custom: true);
    final id = _nextIdentifier++;
    return _add(_Entry(
      identifier: id,
      custom: name,
      invokeOnce: invokeOnce,
      key: key,
      callback: (owner, identifier, info) =>
          callback(owner as T, identifier, info),
    ));
  }

  /// Runs the blocks of the custom event [name]: the owner's, the forwards',
  /// then the global observers', in identifier order.
  void postLifecycleEvent(String name, {Map<String, Object?>? userInfo}) {
    final owner = _owner.target;
    if (owner == null) return;
    final info = LifecycleInfo(
        event: null,
        timing: LifecycleTiming.afterSuper,
        customEvent: name,
        userInfo: userInfo);
    final snapshot = _entries
        .where((e) =>
            e.custom == name && !e.cancelled && !(e.invokeOnce && e.fired))
        .toList()
      ..sort((a, b) => a.identifier.compareTo(b.identifier));
    LifecycleLog.log(() =>
        '${LifecycleLog.describe(owner)} posts $name: ${snapshot.length} block(s)');
    for (final e in snapshot) {
      if (e.cancelled || (e.invokeOnce && e.fired)) continue;
      if (e.invokeOnce) e.fired = true;
      e.callback(owner, e.identifier, info);
    }
    for (final t in _liveForwards(null)) {
      t.postLifecycleEvent(name, userInfo: userInfo);
    }
    LifecycleCenter.dispatch(owner, null, name, LifecycleTiming.afterSuper, info);
  }

  // MARK: forwarding

  /// Forwards the events fired on this owner to [target]'s registry (all
  /// events, or [events]), as an object that is not a view gets the events of
  /// the view that shows it. The target is held weakly; forwarding to the same
  /// target again replaces the earlier forward. Posted custom events are
  /// forwarded too.
  void forwardLifecycleEvents(LifecycleRegistry target,
      {Set<LifecycleEvent>? events}) {
    _forwards.removeWhere((f) {
      final t = f.$1.target;
      return t == null || identical(t, target);
    });
    _forwards.add((WeakReference<LifecycleRegistry>(target), events));
  }

  List<LifecycleRegistry> _liveForwards(LifecycleEvent? event) {
    _forwards.removeWhere((f) => f.$1.target == null);
    return [
      for (final f in _forwards)
        if (f.$1.target != null &&
            (event == null || f.$2 == null || f.$2!.contains(event)))
          f.$1.target!,
    ];
  }

  /// Cancels one block by [identifier] or by [key]; true when one was removed.
  bool cancelLifecycleCallback({int? identifier, String? key}) =>
      _cancelOne(identifier: identifier, key: key, dealloc: false);

  /// Cancels the blocks of [event] (and [timing] when given) that have no key.
  void cancelAllLifecycleCallbacks(LifecycleEvent event,
      {LifecycleTiming? timing}) {
    for (final e in _entries) {
      if (!e.isDealloc &&
          e.key == null &&
          e.event == event &&
          (timing == null || e.timing == timing)) {
        e.cancelled = true;
      }
    }
    _entries.removeWhere((e) => e.cancelled);
  }

  /// Lets the invoke-once blocks of [event] without a key run once more. It
  /// never touches a view: the caller asks for its own layout or rebuild.
  void rearmLifecycleCallbacks(LifecycleEvent event,
      {LifecycleTiming? timing}) {
    for (final e in _entries) {
      if (!e.isDealloc &&
          e.key == null &&
          e.event == event &&
          (timing == null || e.timing == timing)) {
        e.fired = false;
      }
    }
  }

  /// Re-arms the one block added under [key].
  void rearmLifecycleCallback({required String key}) {
    for (final e in _entries) {
      if (!e.isDealloc && e.key == key) e.fired = false;
    }
  }

  // MARK: teardown blocks

  /// Adds a teardown block: it runs once, when the owner is disposed.
  int addDeallocCallback<T extends Object>(
    LifecycleCallback<T> callback, {
    String? key,
  }) {
    _removeKey(key, dealloc: true);
    final id = _nextIdentifier++;
    return _add(_Entry(
      identifier: id,
      key: key,
      callback: (owner, identifier, info) =>
          callback(owner as T, identifier, info),
    ));
  }

  bool cancelDeallocCallback({int? identifier, String? key}) =>
      _cancelOne(identifier: identifier, key: key, dealloc: true);

  /// Cancels the teardown blocks that have no key.
  void cancelAllDeallocCallbacks() {
    for (final e in _entries) {
      if (e.isDealloc && e.key == null) e.cancelled = true;
    }
    _entries.removeWhere((e) => e.cancelled);
  }

  bool _cancelOne({int? identifier, String? key, required bool dealloc}) {
    assert((identifier == null) != (key == null),
        'pass exactly one of identifier or key');
    for (final e in _entries) {
      if (e.isDealloc == dealloc &&
          !e.cancelled &&
          (identifier != null ? e.identifier == identifier : e.key == key)) {
        e.cancelled = true;
        _entries.remove(e);
        return true;
      }
    }
    return false;
  }

  /// Runs the teardown blocks in identifier order, once. The owner calls this
  /// from `dispose`.
  void runDealloc() {
    final owner = _owner.target;
    if (owner == null) return;
    final snapshot = _entries.where((e) => e.isDealloc && !e.cancelled).toList()
      ..sort((a, b) => a.identifier.compareTo(b.identifier));
    _entries.removeWhere((e) => e.isDealloc);
    LifecycleLog.log(() =>
        'teardown ${LifecycleLog.describe(owner)}: ${snapshot.length} block(s)');
    for (final e in snapshot) {
      if (e.cancelled) continue;
      e.callback(
          owner,
          e.identifier,
          const LifecycleInfo(
              event: null, timing: LifecycleTiming.end, isDealloc: true));
    }
    LifecycleCenter.dispatchDealloc(LifecycleLog.describe(owner));
  }

  // MARK: dispatch

  /// Declares that the owner dispatches [events] itself, for [timings] (all by
  /// default). Automatic hooks skip a declared (event, timing).
  void setManualLifecycleDispatch(bool manual, Set<LifecycleEvent> events,
      {Set<LifecycleTiming> timings = const {
        LifecycleTiming.beforeSuper,
        LifecycleTiming.afterSuper,
        LifecycleTiming.end,
      }}) {
    for (final e in events) {
      for (final t in timings) {
        manual ? _manual.add((e, t)) : _manual.remove((e, t));
      }
    }
  }

  bool isManual(LifecycleEvent event, LifecycleTiming timing) =>
      _manual.contains((event, timing));

  /// True when the automatic hook fires this (event, timing).
  @visibleForTesting
  bool isAutomatic(LifecycleEvent event, LifecycleTiming timing) =>
      hookInstalled && timing != LifecycleTiming.end && !isManual(event, timing);

  /// Fires the blocks of one (event, timing) for the automatic hooks. Skips a
  /// timing the owner declared manual.
  void fireAutomatic(LifecycleEvent event, LifecycleTiming timing,
      LifecycleInfo info) {
    if (isManual(event, timing)) return;
    _fire(event, timing, info);
  }

  /// Fires the blocks of one (event, timing) by hand. The event must be
  /// declared manual first.
  void invokeLifecycleCallbacks(
      LifecycleEvent event, LifecycleTiming timing, LifecycleInfo info) {
    assert(isManual(event, timing),
        'declare $event / $timing manual with setManualLifecycleDispatch first');
    _fire(event, timing, info);
  }

  /// Runs [callSuper], then [body], with the timings around them.
  ///
  /// With the mixin's hook the automatic timings come from the hook (they
  /// bracket the framework call inside [callSuper]); this method adds `end`
  /// after [body], at the outermost level only and not when `end` is declared
  /// manual. For an owner without a hook all three timings fire from the
  /// outermost call.
  void performLifecycle(
    LifecycleEvent event,
    LifecycleInfo info, {
    required void Function() callSuper,
    required void Function() body,
  }) {
    final depth = _performDepth[event] ?? 0;
    final outermost = depth == 0;
    _performDepth[event] = depth + 1;
    try {
      if (!hookInstalled && outermost) {
        fireAutomatic(event, LifecycleTiming.beforeSuper,
            info.copyWith(event: event, timing: LifecycleTiming.beforeSuper));
      }
      callSuper();
      if (!hookInstalled && outermost) {
        fireAutomatic(event, LifecycleTiming.afterSuper,
            info.copyWith(event: event, timing: LifecycleTiming.afterSuper));
      }
      body();
      if (outermost) {
        fireAutomatic(event, LifecycleTiming.end,
            info.copyWith(event: event, timing: LifecycleTiming.end));
      }
    } finally {
      _performDepth[event] = depth;
    }
  }

  void _fire(LifecycleEvent event, LifecycleTiming timing, LifecycleInfo info) {
    final owner = _owner.target;
    if (owner == null) return;
    final snapshot = _entries
        .where((e) =>
            !e.isDealloc &&
            !e.cancelled &&
            e.event == event &&
            e.timing == timing &&
            !(e.invokeOnce && e.fired))
        .toList()
      ..sort((a, b) => a.identifier.compareTo(b.identifier));
    LifecycleLog.log(() =>
        '${LifecycleLog.describe(owner)} ${event.name}/${timing.name}: ${snapshot.length} block(s)');
    for (final e in snapshot) {
      if (e.cancelled || (e.invokeOnce && e.fired)) continue;
      if (e.invokeOnce) e.fired = true;
      e.callback(owner, e.identifier,
          info.copyWith(event: event, timing: timing));
    }
    for (final t in _liveForwards(event)) {
      t._fire(event, timing, info);
    }
    LifecycleCenter.dispatch(
        owner, event, null, timing, info.copyWith(event: event, timing: timing));
  }
}

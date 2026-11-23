/// Debug log of the lifecycle moments (design v5). Off by default: turn it on
/// while developing, read what fires on which owner, in which order, and how
/// many blocks ran. Messages are built lazily, so the disabled path costs one
/// boolean check.
///
/// ```dart
/// LifecycleLog.enabled = true;                          // prints through `sink`
/// LifecycleLog.sink = (message) => debugPrint(message);
/// ```
class LifecycleLog {
  LifecycleLog._();

  static bool enabled = false;
  static void Function(String message) sink = print;

  /// A short name for an owner: its runtime type and identity (replace it to name your own owners).
  static String Function(Object? owner) describer = (owner) =>
      owner == null ? 'nil' : '${owner.runtimeType}@${identityHashCode(owner).toRadixString(16)}';

  static String describe(Object? owner) => describer(owner);

  static void log(String Function() message) {
    if (enabled) sink('[CYLLifecycle] ${message()}');
  }
}

/// Well-known custom event names posted by the components (the library never posts them itself).
abstract final class AnimationEvents {
  static const didStart = 'cyl.animation.didStart';
  static const didPause = 'cyl.animation.didPause';
  static const didResume = 'cyl.animation.didResume';
  static const didStop = 'cyl.animation.didStop';
}

abstract final class BadgeEvents {
  static const didShow = 'cyl.badge.didShow';
  static const didClear = 'cyl.badge.didClear';
  static const didBecomeReady = 'cyl.badge.didBecomeReady';
  static const animationDidStart = 'cyl.badge.animationDidStart';
  static const animationDidStop = 'cyl.badge.animationDidStop';
}

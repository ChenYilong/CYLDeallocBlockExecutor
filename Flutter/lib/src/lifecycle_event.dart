import 'dart:ui' show Size;

import 'package:flutter/painting.dart' show EdgeInsets;
import 'package:flutter/widgets.dart' show Brightness;

/// The events a block can be added to. Names match the iOS `CYLLifecycleEvent`.
/// There is no `dealloc` case: teardown blocks use `addDeallocCallback`.
enum LifecycleEvent {
  viewDidLoad,
  viewWillAppear,
  viewIsAppearing,
  viewDidAppear,
  viewWillLayoutSubviews,
  viewDidLayoutSubviews,
  viewWillDisappear,
  viewDidDisappear,
  viewSafeAreaInsetsDidChange,
  viewLayoutMarginsDidChange,
  traitCollectionDidChange,
  viewWillTransition,
  willMoveToParent,
  didMoveToParent,
  didReceiveMemoryWarning,
}

/// When a block runs relative to the framework's own implementation.
///
/// Dart has no way to find out whether a class overrides a method, so `end`
/// is never dispatched automatically: use `performLifecycle` or
/// `invokeLifecycleCallbacks`.
enum LifecycleTiming { beforeSuper, afterSuper, end }

/// What a block can read about the event (iOS `CYLLifecycleInfo`).
class LifecycleInfo {
  const LifecycleInfo({
    required this.event,
    required this.timing,
    this.animated = false,
    this.size,
    this.previousBrightness,
    this.previousTextScaleFactor,
    this.previousPadding,
    this.parentAttached,
    this.isDealloc = false,
  });

  final LifecycleEvent? event;
  final LifecycleTiming timing;

  /// Appearance events: the route transition has a non-zero duration.
  final bool animated;

  /// `viewWillTransition`: the new size of the view.
  final Size? size;

  /// `traitCollectionDidChange`: the values before the change.
  final Brightness? previousBrightness;
  final double? previousTextScaleFactor;

  /// `viewSafeAreaInsetsDidChange`: the padding before the change.
  final EdgeInsets? previousPadding;

  /// `willMoveToParent` / `didMoveToParent`: whether the state is being
  /// attached to (true) or detached from (false) the element tree.
  final bool? parentAttached;

  /// True for the block of a teardown.
  final bool isDealloc;

  LifecycleInfo copyWith({LifecycleEvent? event, LifecycleTiming? timing}) =>
      LifecycleInfo(
        event: event ?? this.event,
        timing: timing ?? this.timing,
        animated: animated,
        size: size,
        previousBrightness: previousBrightness,
        previousTextScaleFactor: previousTextScaleFactor,
        previousPadding: previousPadding,
        parentAttached: parentAttached,
        isDealloc: isDealloc,
      );
}

/// A block: the owner, its own identifier and the info.
typedef LifecycleCallback<T extends Object> = void Function(
    T owner, int identifier, LifecycleInfo info);

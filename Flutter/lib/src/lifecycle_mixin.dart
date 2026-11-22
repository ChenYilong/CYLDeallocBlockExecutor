import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'lifecycle_event.dart';
import 'lifecycle_registry.dart';

/// Fires the lifecycle events of a `State` without code in its overrides.
///
/// ```dart
/// class _PageState extends State<Page> with CYLLifecycleMixin<Page> {
///   @override
///   RouteObserver<ModalRoute<dynamic>>? get lifecycleRouteObserver => routeObserver;
///   ...
/// }
/// ```
///
/// Mapping (iOS event: Flutter source):
/// - `viewDidLoad`, `willMoveToParent` / `didMoveToParent`: `initState`,
///   `activate`, `deactivate`; the timings bracket `super`;
/// - `viewWillAppear` / `viewWillDisappear`: the `RouteAware` callbacks of
///   [lifecycleRouteObserver]; `viewIsAppearing`: the frame after
///   `viewWillAppear`; `viewDidAppear` / `viewDidDisappear`: the route
///   animation reaching its end. Foreground and background of the app are not
///   appear or disappear events (as on iOS);
/// - `viewWillLayoutSubviews` / `viewDidLayoutSubviews`: [layoutLifecycle]
///   wraps a child and fires around its layout;
/// - `viewSafeAreaInsetsDidChange`, `viewWillTransition`,
///   `traitCollectionDidChange`, `didReceiveMemoryWarning`: a
///   `WidgetsBindingObserver`, attached when the first block for one of them is
///   added and removed in `dispose`; no `super` exists there, so
///   `beforeSuper` and `afterSuper` fire back to back;
/// - `viewLayoutMarginsDidChange`: not available (Flutter has no per-view
///   layout margins).
///
/// Teardown blocks run in `dispose`, deterministically.
mixin CYLLifecycleMixin<W extends StatefulWidget> on State<W> {
  late final LifecycleRegistry lifecycle = LifecycleRegistry.of(this)
    ..onRegister = _onRegister;

  /// The app's route observer; null disables the appear / disappear events.
  RouteObserver<ModalRoute<dynamic>>? get lifecycleRouteObserver => null;

  _BindingObserver? _binding;
  _RouteListener? _routeListener;
  ModalRoute<dynamic>? _route;
  final List<VoidCallback> _animationDetach = [];
  bool _appearPending = false;
  bool _disappearPending = false;
  bool _disposed = false;

  Brightness? _lastBrightness;
  double? _lastTextScale;
  EdgeInsets? _lastPadding;
  Size? _lastSize;

  static const _bindingEvents = {
    LifecycleEvent.viewSafeAreaInsetsDidChange,
    LifecycleEvent.viewWillTransition,
    LifecycleEvent.traitCollectionDidChange,
    LifecycleEvent.didReceiveMemoryWarning,
  };

  /// Whether the `WidgetsBindingObserver` is attached (it is added when the first
  /// block for a binding event is registered).
  @visibleForTesting
  bool get observerAttached => _binding != null;

  void _onRegister(LifecycleEvent event) {
    if (_bindingEvents.contains(event) && _binding == null && !_disposed) {
      _attachBinding();
    }
  }

  void _attachBinding() {
    final view = _view;
    _lastBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _lastTextScale = WidgetsBinding.instance.platformDispatcher.textScaleFactor;
    if (view != null) {
      _lastPadding = _padding(view);
      _lastSize = view.physicalSize / view.devicePixelRatio;
    }
    _binding = _BindingObserver(this);
    WidgetsBinding.instance.addObserver(_binding!);
  }

  /// The view of the app (the implicit view, else the first one). Looked up
  /// without an inherited-widget dependency so it is usable in `initState`.
  FlutterView? get _view {
    final d = WidgetsBinding.instance.platformDispatcher;
    return d.implicitView ?? (d.views.isEmpty ? null : d.views.first);
  }

  static EdgeInsets _padding(FlutterView view) => EdgeInsets.fromViewPadding(
      view.padding, view.devicePixelRatio);

  // MARK: automatic hooks around super

  void _around(LifecycleEvent event, LifecycleInfo info, void Function() call) {
    lifecycle.fireAutomatic(event, LifecycleTiming.beforeSuper,
        info.copyWith(event: event, timing: LifecycleTiming.beforeSuper));
    call();
    lifecycle.fireAutomatic(event, LifecycleTiming.afterSuper,
        info.copyWith(event: event, timing: LifecycleTiming.afterSuper));
  }

  void _moveToParent(bool attached, void Function() call) {
    final info = LifecycleInfo(
        event: null, timing: LifecycleTiming.afterSuper, parentAttached: attached);
    _around(LifecycleEvent.willMoveToParent, info, call);
    _around(LifecycleEvent.didMoveToParent, info, () {});
  }

  @override
  void initState() {
    lifecycle.hookInstalled = true;
    _moveToParent(true, () {
      _around(
          LifecycleEvent.viewDidLoad,
          const LifecycleInfo(event: null, timing: LifecycleTiming.afterSuper),
          super.initState);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = lifecycleRouteObserver;
    final route = ModalRoute.of(context);
    if (observer != null && route != null && route != _route) {
      _detachRoute();
      _route = route;
      _routeListener = _RouteListener(this);
      observer.subscribe(_routeListener!, route);
    }
  }

  @override
  void activate() {
    _moveToParent(true, super.activate);
  }

  @override
  void deactivate() {
    _moveToParent(false, super.deactivate);
  }

  @override
  void dispose() {
    _disposed = true;
    _flushPending();
    _detachRoute();
    if (_binding != null) {
      WidgetsBinding.instance.removeObserver(_binding!);
      _binding = null;
    }
    lifecycle.runDealloc();
    super.dispose();
  }

  // MARK: appear and disappear

  bool get _animated =>
      (_route?.transitionDuration ?? Duration.zero) > Duration.zero;

  void _willAppear() {
    _appearPending = true;
    _fireEvent(LifecycleEvent.viewWillAppear);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_appearPending && !_disposed) _fireEvent(LifecycleEvent.viewIsAppearing);
    });
  }

  void _willDisappear() {
    _disappearPending = true;
    _fireEvent(LifecycleEvent.viewWillDisappear);
  }

  void _fireEvent(LifecycleEvent event, {LifecycleInfo? info}) {
    final base = info ?? LifecycleInfo(
        event: event, timing: LifecycleTiming.afterSuper, animated: _animated);
    lifecycle.fireAutomatic(event, LifecycleTiming.beforeSuper,
        base.copyWith(event: event, timing: LifecycleTiming.beforeSuper));
    lifecycle.fireAutomatic(event, LifecycleTiming.afterSuper,
        base.copyWith(event: event, timing: LifecycleTiming.afterSuper));
  }

  void _didAppear() {
    if (!_appearPending) return;
    _appearPending = false;
    _fireEvent(LifecycleEvent.viewDidAppear);
  }

  void _didDisappear() {
    if (!_disappearPending) return;
    _disappearPending = false;
    _fireEvent(LifecycleEvent.viewDidDisappear);
  }

  void _flushPending() {
    _didAppear();
    _didDisappear();
  }

  /// Fires [fire] once [animation] reaches [target] (at once, on the next
  /// frame, when it is already there).
  void _await(Animation<double>? animation, AnimationStatus target,
      VoidCallback fire) {
    if (animation == null || animation.status == target) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) fire();
      });
      return;
    }
    late AnimationStatusListener listener;
    listener = (status) {
      if (status == target) {
        animation.removeStatusListener(listener);
        if (!_disposed) fire();
      }
    };
    animation.addStatusListener(listener);
    _animationDetach.add(() => animation.removeStatusListener(listener));
  }

  void _detachRoute() {
    if (_routeListener != null) {
      lifecycleRouteObserver?.unsubscribe(_routeListener!);
      _routeListener = null;
    }
    for (final d in _animationDetach) {
      d();
    }
    _animationDetach.clear();
    _route = null;
  }

  // MARK: layout

  /// Wraps [child] so that the layout events fire around its layout.
  /// Blocks run during layout: do not call `setState` from them.
  Widget layoutLifecycle({required Widget child}) =>
      _LayoutLifecycle(registry: lifecycle, child: child);
}

class _RouteListener with RouteAware {
  _RouteListener(this._state);
  final CYLLifecycleMixin<StatefulWidget> _state;

  @override
  void didPush() {
    _state._willAppear();
    _state._await(_state._route?.animation, AnimationStatus.completed,
        _state._didAppear);
  }

  @override
  void didPopNext() {
    _state._willAppear();
    _state._await(_state._route?.secondaryAnimation, AnimationStatus.dismissed,
        _state._didAppear);
  }

  @override
  void didPushNext() {
    _state._willDisappear();
    _state._await(_state._route?.secondaryAnimation, AnimationStatus.completed,
        _state._didDisappear);
  }

  @override
  void didPop() {
    _state._willDisappear();
    _state._await(_state._route?.animation, AnimationStatus.dismissed,
        _state._didDisappear);
  }
}

class _BindingObserver with WidgetsBindingObserver {
  _BindingObserver(this._state);
  final CYLLifecycleMixin<StatefulWidget> _state;

  @override
  void didChangeMetrics() {
    final s = _state;
    final view = s._view;
    if (view == null) return;
    final padding = CYLLifecycleMixin._padding(view);
    if (padding != s._lastPadding) {
      final previous = s._lastPadding;
      s._lastPadding = padding;
      s._fireEvent(LifecycleEvent.viewSafeAreaInsetsDidChange,
          info: LifecycleInfo(
              event: null,
              timing: LifecycleTiming.afterSuper,
              previousPadding: previous));
    }
    final size = view.physicalSize / view.devicePixelRatio;
    if (size != s._lastSize) {
      s._lastSize = size;
      s._fireEvent(LifecycleEvent.viewWillTransition,
          info: LifecycleInfo(
              event: null, timing: LifecycleTiming.afterSuper, size: size));
    }
  }

  void _trait() {
    final s = _state;
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final info = LifecycleInfo(
        event: null,
        timing: LifecycleTiming.afterSuper,
        previousBrightness: s._lastBrightness,
        previousTextScaleFactor: s._lastTextScale);
    s._lastBrightness = dispatcher.platformBrightness;
    s._lastTextScale = dispatcher.textScaleFactor;
    s._fireEvent(LifecycleEvent.traitCollectionDidChange, info: info);
  }

  @override
  void didChangePlatformBrightness() => _trait();

  @override
  void didChangeTextScaleFactor() => _trait();

  @override
  void didHaveMemoryPressure() => _state._fireEvent(
      LifecycleEvent.didReceiveMemoryWarning);
}

class _LayoutLifecycle extends SingleChildRenderObjectWidget {
  const _LayoutLifecycle({required this.registry, required super.child});
  final LifecycleRegistry registry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutLifecycle(registry);

  @override
  void updateRenderObject(
      BuildContext context, _RenderLayoutLifecycle renderObject) {
    renderObject.registry = registry;
  }
}

class _RenderLayoutLifecycle extends RenderProxyBox {
  _RenderLayoutLifecycle(this.registry);
  LifecycleRegistry registry;

  void _fire(LifecycleEvent event) {
    for (final t in [LifecycleTiming.beforeSuper, LifecycleTiming.afterSuper]) {
      registry.fireAutomatic(
          event, t, LifecycleInfo(event: event, timing: t));
    }
  }

  @override
  void performLayout() {
    _fire(LifecycleEvent.viewWillLayoutSubviews);
    super.performLayout();
    _fire(LifecycleEvent.viewDidLayoutSubviews);
  }
}

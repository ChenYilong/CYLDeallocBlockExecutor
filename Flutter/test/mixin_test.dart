// ignore_for_file: library_private_types_in_public_api

import 'package:cyl_dealloc_block_executor/cyl_dealloc_block_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final routeObserver = RouteObserver<ModalRoute<dynamic>>();
final List<String> log = [];
void Function(_PageState)? onInit;

class Page extends StatefulWidget {
  const Page({super.key, this.name = 'page', this.registerAll = true});
  final String name;
  final bool registerAll;
  @override
  State<Page> createState() => _PageState();
}

class _PageState extends State<Page> with CYLLifecycleMixin<Page> {
  @override
  RouteObserver<ModalRoute<dynamic>>? get lifecycleRouteObserver => routeObserver;

  @override
  void initState() {
    log.add('app initState before super');
    // Blocks for the events fired inside super (viewDidLoad, move events) are
    // added before super, as an iOS owner adds them before the event.
    for (final ev in widget.registerAll ? LifecycleEvent.values : [LifecycleEvent.viewDidLoad]) {
      for (final t in [LifecycleTiming.beforeSuper, LifecycleTiming.afterSuper]) {
        lifecycle.addLifecycleCallback<_PageState>(ev, (o, id, i) {
          log.add('${ev.name}/${t.name}');
        }, timing: t);
      }
    }
    super.initState();
    log.add('app initState after super');
    onInit?.call(this);
  }

  @override
  Widget build(BuildContext context) => layoutLifecycle(
      child: Scaffold(
          body: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => const Text('next'))),
              child: Text(widget.name))));
}

Widget app(Widget home) =>
    MaterialApp(navigatorObservers: [routeObserver], home: home);

List<String> events(String suffix) =>
    log.where((l) => l.endsWith(suffix)).map((l) => l.split('/').first).toList();

void main() {
  setUp(() {
    log.clear();
    onInit = null;
  });

  testWidgets('initState: timings bracket super, load and move events fire',
      (tester) async {
    await tester.pumpWidget(app(const Page()));
    final i = log.indexOf('app initState before super');
    expect(i, 0);
    expect(log.indexOf('viewDidLoad/beforeSuper'), lessThan(log.indexOf('viewDidLoad/afterSuper')));
    expect(log.indexOf('app initState after super'),
        greaterThan(log.indexOf('viewDidLoad/afterSuper')),
        reason: 'the app code after super runs after .afterSuper');
    expect(log, contains('willMoveToParent/afterSuper'));
    expect(log, contains('didMoveToParent/afterSuper'));
  });

  testWidgets('appear events with a will / did split; no foreground confusion',
      (tester) async {
    await tester.pumpWidget(app(const Page()));
    expect(log, contains('viewWillAppear/afterSuper'));
    final will = log.indexOf('viewWillAppear/afterSuper');
    await tester.pumpAndSettle();
    expect(log, contains('viewIsAppearing/afterSuper'));
    expect(log, contains('viewDidAppear/afterSuper'));
    expect(log.indexOf('viewDidAppear/afterSuper'), greaterThan(will));
    log.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(events('/afterSuper').where((e) => e.contains('Appear') || e.contains('Disappear')),
        isEmpty);
  });

  testWidgets('push covers the page: will / did disappear, pop: appear again',
      (tester) async {
    await tester.pumpWidget(app(const Page()));
    await tester.pumpAndSettle();
    log.clear();
    await tester.tap(find.byType(TextButton));
    await tester.pump();
    expect(log, contains('viewWillDisappear/afterSuper'));
    expect(log, isNot(contains('viewDidDisappear/afterSuper')));
    await tester.pumpAndSettle();
    expect(log, contains('viewDidDisappear/afterSuper'));
    log.clear();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    expect(log, contains('viewWillAppear/afterSuper'));
    expect(log, isNot(contains('viewDidAppear/afterSuper')));
    await tester.pumpAndSettle();
    expect(log, contains('viewDidAppear/afterSuper'));
  });

  testWidgets('layout events fire around the child layout', (tester) async {
    await tester.pumpWidget(app(const Page()));
    expect(log, contains('viewWillLayoutSubviews/afterSuper'));
    expect(log.indexOf('viewWillLayoutSubviews/afterSuper'),
        lessThan(log.indexOf('viewDidLayoutSubviews/beforeSuper')));
  });

  testWidgets('trait change: brightness with the previous value', (tester) async {
    Brightness? previous;
    onInit = (s) => s.lifecycle.addLifecycleCallback<_PageState>(
        LifecycleEvent.traitCollectionDidChange, (o, id, i) => previous = i.previousBrightness);
    await tester.pumpWidget(app(const Page()));
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(previous, Brightness.light);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  });

  testWidgets('viewWillTransition with the new size, safe area insets change',
      (tester) async {
    Size? size;
    EdgeInsets? previousPadding;
    onInit = (s) {
      s.lifecycle.addLifecycleCallback<_PageState>(
          LifecycleEvent.viewWillTransition, (o, id, i) => size = i.size);
      s.lifecycle.addLifecycleCallback<_PageState>(
          LifecycleEvent.viewSafeAreaInsetsDidChange,
          (o, id, i) => previousPadding = i.previousPadding);
    };
    await tester.pumpWidget(app(const Page()));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);
    tester.view.padding = const FakeViewPadding(top: 47);
    await tester.pump();
    expect(size, const Size(500, 900));
    expect(previousPadding, EdgeInsets.zero);
    addTearDown(tester.view.reset);
  });

  testWidgets('memory pressure fires didReceiveMemoryWarning', (tester) async {
    await tester.pumpWidget(app(const Page()));
    log.clear();
    tester.binding.handleMemoryPressure();
    expect(log, contains('didReceiveMemoryWarning/afterSuper'));
  });

  testWidgets('dispose runs teardown blocks in order, once; observer removed',
      (tester) async {
    final order = <String>[];
    onInit = (s) {
      s.lifecycle.addDeallocCallback<_PageState>((o, id, i) => order.add('a'));
      s.lifecycle.addDeallocCallback<_PageState>((o, id, i) {
        expect(o.mounted, isTrue, reason: 'owner readable before super.dispose');
        order.add('b');
      });
    };
    await tester.pumpWidget(app(const Page()));
    await tester.pumpWidget(const SizedBox());
    expect(order, ['a', 'b']);
    log.clear();
    tester.binding.handleMemoryPressure(); // no observer left, nothing fires
    expect(log, isEmpty);
  });

  testWidgets('manual end after the body, automatic afterSuper stays automatic',
      (tester) async {
    onInit = (s) {
      s.lifecycle.setManualLifecycleDispatch(true, {LifecycleEvent.viewDidLayoutSubviews},
          timings: {LifecycleTiming.end});
      s.lifecycle.addLifecycleCallback<_PageState>(
          LifecycleEvent.viewDidLayoutSubviews, (o, id, i) => log.add('layout-block'),
          timing: LifecycleTiming.end, invokeOnce: true, key: 'cyl.core.layoutBlock');
    };
    await tester.pumpWidget(app(const Page()));
    expect(log, isNot(contains('layout-block')));
    final s = tester.state<State>(find.byType(Page)) as CYLLifecycleMixin;
    s.lifecycle.invokeLifecycleCallbacks(LifecycleEvent.viewDidLayoutSubviews,
        LifecycleTiming.end,
        const LifecycleInfo(event: LifecycleEvent.viewDidLayoutSubviews, timing: LifecycleTiming.end));
    s.lifecycle.invokeLifecycleCallbacks(LifecycleEvent.viewDidLayoutSubviews,
        LifecycleTiming.end,
        const LifecycleInfo(event: LifecycleEvent.viewDidLayoutSubviews, timing: LifecycleTiming.end));
    expect(log.where((l) => l == 'layout-block').length, 1);
    expect(log, contains('viewDidLayoutSubviews/afterSuper'));
  });

  testWidgets('detach: willMoveToParent reports parentAttached false', (tester) async {
    final attached = <bool?>[];
    onInit = (s) {
      for (final ev in [LifecycleEvent.willMoveToParent, LifecycleEvent.didMoveToParent]) {
        s.lifecycle.addLifecycleCallback<_PageState>(
            ev, (o, id, i) => attached.add(i.parentAttached));
      }
    };
    await tester.pumpWidget(app(const Page()));
    attached.clear();
    await tester.pumpWidget(const SizedBox());
    expect(attached, [false, false]);
  });

  testWidgets('trait change: text scale with the previous value', (tester) async {
    double? previous;
    onInit = (s) => s.lifecycle.addLifecycleCallback<_PageState>(
        LifecycleEvent.traitCollectionDidChange, (o, id, i) => previous = i.previousTextScaleFactor);
    await tester.pumpWidget(app(const Page()));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pump();
    expect(previous, 1.0);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  });

  testWidgets('the observer is attached lazily, on the first binding-event block',
      (tester) async {
    await tester.pumpWidget(app(const Page(registerAll: false)));
    final s = tester.state<State>(find.byType(Page)) as CYLLifecycleMixin;
    expect(s.observerAttached, isFalse, reason: 'only lifecycle blocks were added, no binding event');
    s.lifecycle.addLifecycleCallback<Object>(LifecycleEvent.didReceiveMemoryWarning, (o, id, i) {});
    expect(s.observerAttached, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(s.observerAttached, isFalse, reason: 'removed in dispose');
  });

  testWidgets('activate: reparenting with a GlobalKey fires detach then attach', (tester) async {
    final attached = <bool?>[];
    final key = GlobalKey();
    onInit = (s) {
      for (final ev in [LifecycleEvent.willMoveToParent, LifecycleEvent.didMoveToParent]) {
        s.lifecycle.addLifecycleCallback<_PageState>(ev, (o, id, i) => attached.add(i.parentAttached));
      }
    };
    Widget host(bool padded) => MaterialApp(
        home: padded
            ? Padding(padding: const EdgeInsets.all(1), child: Page(key: key))
            : Align(child: Page(key: key)));
    await tester.pumpWidget(host(true));
    attached.clear();
    await tester.pumpWidget(host(false));
    expect(attached, [false, false, true, true]);
  });

  testWidgets('pop: the popped page gets will and did disappear', (tester) async {
    await tester.pumpWidget(app(Builder(
        builder: (c) => TextButton(
            onPressed: () => Navigator.of(c)
                .push(MaterialPageRoute<void>(builder: (_) => const Page(name: 'second'))),
            child: const Text('go')))));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    log.clear();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    expect(log, contains('viewWillDisappear/afterSuper'));
    expect(log, isNot(contains('viewDidDisappear/afterSuper')));
    await tester.pumpAndSettle();
    expect(log, contains('viewDidDisappear/afterSuper'));
    expect(log.indexOf('viewWillDisappear/afterSuper'),
        lessThan(log.indexOf('viewDidDisappear/afterSuper')));
  });
}

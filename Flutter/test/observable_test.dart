import 'package:cyl_dealloc_block_executor/cyl_dealloc_block_executor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Owner {}

LifecycleInfo info(LifecycleEvent e) =>
    LifecycleInfo(event: e, timing: LifecycleTiming.afterSuper);

class _ScrollHost extends StatefulWidget {
  const _ScrollHost({required this.log});
  final List<String> log;
  @override
  State<_ScrollHost> createState() => _ScrollHostState();
}

class _ScrollHostState extends State<_ScrollHost> with CYLLifecycleMixin<_ScrollHost> {
  @override
  void initState() {
    super.initState();
    for (final e in [
      LifecycleEvent.scrollWillBeginDragging,
      LifecycleEvent.scrollDidEndDragging,
      LifecycleEvent.scrollDidEndScrolling,
    ]) {
      lifecycle.addLifecycleCallback<_ScrollHostState>(e, (o, id, i) {
        widget.log.add('${e.name}${i.willDecelerate == null ? '' : ' ${i.willDecelerate}'}');
      });
    }
    lifecycle.addLifecycleCallback<_ScrollHostState>(LifecycleEvent.didEnterScreen, (o, id, i) => widget.log.add('enter'));
    lifecycle.addLifecycleCallback<_ScrollHostState>(LifecycleEvent.didLeaveScreen, (o, id, i) => widget.log.add('leave'));
  }

  @override
  Widget build(BuildContext context) => scrollLifecycle(
        child: ListView(children: [for (var i = 0; i < 100; i++) SizedBox(height: 50, child: Text('$i'))]),
      );
}

void main() {
  debugLogTests();
  forwardAndScrollHelperTests();
  late Owner owner;
  late LifecycleRegistry r;
  late List<String> log;

  setUp(() {
    LifecycleCenter.reset();
    owner = Owner();
    r = LifecycleRegistry.of(owner)..hookInstalled = true;
    log = [];
  });

  test('custom events: order, owner, userInfo and the event name in info', () {
    final a = r.addCustomCallback<Owner>('cyl.badge.didShow', (o, id, i) {
      expect(o, same(owner));
      log.add('a$id ${i.customEvent} ${i.userInfo?['value']}');
    });
    final b = r.addCustomCallback<Owner>('cyl.badge.didShow', (o, id, i) => log.add('b$id'));
    r.postLifecycleEvent('cyl.badge.didShow', userInfo: {'value': '3'});
    expect(log, ['a$a cyl.badge.didShow 3', 'b$b']);
  });

  test('custom events: invoke once, replace by key, cancel by identifier and by key', () {
    r.addCustomCallback<Owner>('x', (o, id, i) => log.add('x'), invokeOnce: true);
    r.addCustomCallback<Owner>('y', (o, id, i) => log.add('y1'), key: 'k');
    r.addCustomCallback<Owner>('y', (o, id, i) => log.add('y2'), key: 'k');
    final id = r.addCustomCallback<Owner>('y', (o, i, x) => log.add('y3'));
    r.postLifecycleEvent('x');
    r.postLifecycleEvent('x');
    r.postLifecycleEvent('y');
    expect(log, ['x', 'y2', 'y3']);
    log.clear();
    expect(r.cancelLifecycleCallback(identifier: id), isTrue);
    expect(r.cancelLifecycleCallback(key: 'k'), isTrue);
    r.postLifecycleEvent('y');
    expect(log, isEmpty);
  });

  test('custom blocks share the identifier sequence and rearm by key', () {
    final a = r.addLifecycleCallback<Owner>(LifecycleEvent.viewDidLoad, (o, i, x) {});
    final b = r.addCustomCallback<Owner>('c', (o, i, x) => log.add('c'), invokeOnce: true, key: 'once');
    final c = r.addDeallocCallback<Owner>((o, i, x) {});
    expect(a < b && b < c, isTrue);
    r.postLifecycleEvent('c');
    r.postLifecycleEvent('c');
    r.rearmLifecycleCallback(key: 'once');
    r.postLifecycleEvent('c');
    expect(log, ['c', 'c']);
  });

  test('global observers run after the owner blocks, in identifier order', () {
    r.addLifecycleCallback<Owner>(LifecycleEvent.viewDidAppear, (o, i, x) => log.add('own'));
    LifecycleCenter.addCallback<Owner>(LifecycleEvent.viewDidAppear, (o, i, x) => log.add('g1 ${identical(o, owner)} ${x.event?.name}'));
    LifecycleCenter.addCallback<Owner>(LifecycleEvent.viewDidAppear, (o, i, x) => log.add('g2'));
    r.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper, info(LifecycleEvent.viewDidAppear));
    expect(log, ['own', 'g1 true viewDidAppear', 'g2']);
  });

  test('global observers: owner filter, key, cancel; never on teardown', () {
    final other = Owner();
    final ro = LifecycleRegistry.of(other)..hookInstalled = true;
    LifecycleCenter.addCallback<Object>(LifecycleEvent.viewDidLoad, (o, i, x) => log.add('only owner'), ownerFilter: (o) => identical(o, owner));
    LifecycleCenter.addCallback<Object>(LifecycleEvent.viewDidLoad, (o, i, x) => log.add('before'), timing: LifecycleTiming.beforeSuper, key: 'k');
    LifecycleCenter.addCallback<Object>(LifecycleEvent.viewDidLoad, (o, i, x) => log.add('replaced'), timing: LifecycleTiming.beforeSuper, key: 'k');
    r.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.beforeSuper, info(LifecycleEvent.viewDidLoad));
    r.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.afterSuper, info(LifecycleEvent.viewDidLoad));
    ro.fireAutomatic(LifecycleEvent.viewDidLoad, LifecycleTiming.afterSuper, info(LifecycleEvent.viewDidLoad));
    expect(log, ['replaced', 'only owner']);
    expect(LifecycleCenter.cancelCallback(key: 'k'), isTrue);
    expect(LifecycleCenter.cancelCallback(key: 'k'), isFalse);
    log.clear();
    r.addDeallocCallback<Owner>((o, i, x) => log.add('own dealloc'));
    LifecycleCenter.addCallback<Object>(LifecycleEvent.viewDidLoad, (o, i, x) => log.add('global at dealloc'));
    r.runDealloc();
    expect(log, ['own dealloc']);
  });

  test('isUserScrolling follows the scroll events and a global observer pauses and resumes', () {
    final paused = <String>{};
    LifecycleCenter.addCallback<Object>(LifecycleEvent.scrollWillBeginDragging, (o, i, x) => paused.add('all'));
    LifecycleCenter.addCallback<Object>(LifecycleEvent.scrollDidEndScrolling, (o, i, x) => paused.clear());
    expect(LifecycleCenter.isUserScrolling, isFalse);
    r.fireAutomatic(LifecycleEvent.scrollWillBeginDragging, LifecycleTiming.afterSuper, info(LifecycleEvent.scrollWillBeginDragging));
    expect(LifecycleCenter.isUserScrolling, isTrue);
    expect(paused, {'all'});
    r.fireAutomatic(LifecycleEvent.scrollDidEndScrolling, LifecycleTiming.afterSuper, info(LifecycleEvent.scrollDidEndScrolling));
    expect(LifecycleCenter.isUserScrolling, isFalse);
    expect(paused, isEmpty);
  });

  test('forwarding: the target receives the chosen events, a second forward replaces the first', () {
    final item = Owner();
    final ri = LifecycleRegistry.of(item)..hookInstalled = true;
    ri.addLifecycleCallback<Owner>(LifecycleEvent.didEnterScreen, (o, i, x) => log.add('item enter'));
    ri.addLifecycleCallback<Owner>(LifecycleEvent.didLeaveScreen, (o, i, x) => log.add('item leave'));
    ri.addCustomCallback<Owner>('cyl.badge.didShow', (o, i, x) => log.add('item badge'));
    r.forwardLifecycleEvents(ri, events: {LifecycleEvent.didEnterScreen});
    r.fireAutomatic(LifecycleEvent.didEnterScreen, LifecycleTiming.afterSuper, info(LifecycleEvent.didEnterScreen));
    r.fireAutomatic(LifecycleEvent.didLeaveScreen, LifecycleTiming.afterSuper, info(LifecycleEvent.didLeaveScreen));
    expect(log, ['item enter']);
    log.clear();
    r.forwardLifecycleEvents(ri);
    r.fireAutomatic(LifecycleEvent.didLeaveScreen, LifecycleTiming.afterSuper, info(LifecycleEvent.didLeaveScreen));
    r.postLifecycleEvent('cyl.badge.didShow');
    r.fireAutomatic(LifecycleEvent.didEnterScreen, LifecycleTiming.afterSuper, info(LifecycleEvent.didEnterScreen));
    expect(log, ['item leave', 'item badge', 'item enter']);
  });

  testWidgets('scrollLifecycle: a drag begins, a fling decelerates and ends, in order', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(MaterialApp(home: _ScrollHost(log: log)));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(log.first, 'scrollWillBeginDragging');
    expect(log.last, 'scrollDidEndScrolling');
    expect(log.where((l) => l.startsWith('scrollDidEndDragging')).length, 1);
  });
}

void debugLogTests() {
  group('debug log, dealloc observers and event names', () {
    tearDown(() {
      LifecycleLog.enabled = false;
      LifecycleLog.sink = print;
      LifecycleCenter.reset();
    });

    test('off by default and lazy; on, it names the owner, event, timing and the block count', () {
      final lines = <String>[];
      LifecycleLog.sink = lines.add;
      LifecycleLog.describer = (o) => 'Tab(tab-1)';
      final r = LifecycleRegistry.of(Owner())..hookInstalled = true;
      r.addLifecycleCallback<Owner>(LifecycleEvent.viewDidAppear, (o, i, x) {});
      r.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper, info(LifecycleEvent.viewDidAppear));
      expect(lines, isEmpty);
      LifecycleLog.enabled = true;
      r.fireAutomatic(LifecycleEvent.viewDidAppear, LifecycleTiming.afterSuper, info(LifecycleEvent.viewDidAppear));
      r.addCustomCallback<Owner>(AnimationEvents.didPause, (o, i, x) {});
      r.postLifecycleEvent(AnimationEvents.didPause);
      r.addDeallocCallback<Owner>((o, i, x) {});
      r.runDealloc();
      expect(lines, [
        '[CYLLifecycle] Tab(tab-1) viewDidAppear/afterSuper: 1 block(s)',
        '[CYLLifecycle] Tab(tab-1) posts cyl.animation.didPause: 1 block(s)',
        '[CYLLifecycle] teardown Tab(tab-1): 1 block(s)',
        '[CYLLifecycle] dealloc Tab(tab-1)',
      ]);
    });

    test('a dealloc observer learns when any owner is torn down, with a description and never the owner', () {
      final seen = <String>[];
      LifecycleLog.describer = (o) => 'Owner(7)';
      final id = LifecycleCenter.addDeallocObserver((d, i) => seen.add('$d ${i.isDealloc}'), key: 'debug');
      final r = LifecycleRegistry.of(Owner());
      r.runDealloc();
      expect(seen, ['Owner(7) true']);
      expect(LifecycleCenter.cancelDeallocObserver(identifier: id), isTrue);
      r.runDealloc();
      expect(seen.length, 1);
      expect(AnimationEvents.didResume, 'cyl.animation.didResume');
      expect(BadgeEvents.animationDidStop, 'cyl.badge.animationDidStop');
    });
  });
}

void forwardAndScrollHelperTests() {
  group('forwarding and the scroll helper', () {
    setUp(LifecycleCenter.reset);
    tearDown(LifecycleCenter.reset);

    test('a forward does not make a global observer hear the same moment twice', () {
      final owner = Owner();
      final item = Owner();
      final r = LifecycleRegistry.of(owner)..hookInstalled = true;
      final ri = LifecycleRegistry.of(item)..hookInstalled = true;
      final heard = <String>[];
      LifecycleCenter.addCallback<Object>(LifecycleEvent.didEnterScreen, (o, i, x) => heard.add(identical(o, owner) ? 'source' : 'target'));
      LifecycleCenter.addCustomCallback<Object>('cyl.badge.didShow', (o, i, x) => heard.add(identical(o, owner) ? 'source' : 'target'));
      r.forwardLifecycleEvents(ri);
      r.fireAutomatic(LifecycleEvent.didEnterScreen, LifecycleTiming.afterSuper, info(LifecycleEvent.didEnterScreen));
      r.postLifecycleEvent('cyl.badge.didShow');
      expect(heard, ['source', 'source']);
    });

    test('whileUserScrolls pauses on the first drag, resumes when scrolling ended, and cancels', () {
      final r = LifecycleRegistry.of(Owner())..hookInstalled = true;
      final calls = <String>[];
      final cancel = LifecycleCenter.whileUserScrolls(pause: () => calls.add('pause'), resume: () => calls.add('resume'));
      r.fireAutomatic(LifecycleEvent.scrollWillBeginDragging, LifecycleTiming.afterSuper, info(LifecycleEvent.scrollWillBeginDragging));
      r.fireAutomatic(LifecycleEvent.scrollDidEndScrolling, LifecycleTiming.afterSuper, info(LifecycleEvent.scrollDidEndScrolling));
      expect(calls, ['pause', 'resume']);
      cancel();
      calls.clear();
      r.fireAutomatic(LifecycleEvent.scrollWillBeginDragging, LifecycleTiming.afterSuper, info(LifecycleEvent.scrollWillBeginDragging));
      expect(calls, isEmpty);
    });
  });
}

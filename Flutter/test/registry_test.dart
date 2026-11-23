import 'package:cyl_dealloc_block_executor/cyl_dealloc_block_executor.dart';
import 'package:flutter_test/flutter_test.dart';

class Owner {}

LifecycleInfo info(LifecycleEvent e, LifecycleTiming t) =>
    LifecycleInfo(event: e, timing: t);

void main() {
  const e = LifecycleEvent.viewDidLayoutSubviews;
  const end = LifecycleTiming.end;
  late Owner owner;
  late LifecycleRegistry r;
  late List<String> log;

  setUp(() {
    owner = Owner();
    r = LifecycleRegistry.of(owner);
    log = [];
  });

  void fire([LifecycleTiming t = LifecycleTiming.end]) {
    r.setManualLifecycleDispatch(true, {e});
    r.invokeLifecycleCallbacks(e, t, info(e, t));
  }

  test('one registry per owner', () {
    expect(LifecycleRegistry.of(owner), same(r));
  });

  test('order by identifier, owner and identifier in every block', () {
    final a = r.addLifecycleCallback<Owner>(e, (o, id, i) {
      expect(o, same(owner));
      log.add('a$id');
    }, timing: end);
    final b = r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('b$id'),
        timing: end);
    expect(b, greaterThan(a));
    fire();
    expect(log, ['a$a', 'b$b']);
  });

  test('typed owner', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add(o.runtimeType.toString()),
        timing: end);
    fire();
    expect(log, ['Owner']);
  });

  test('cancel one by identifier and by key; unknown identifier is false', () {
    final a = r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('a'), timing: end);
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('b'), timing: end, key: 'k');
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('c'), timing: end);
    expect(r.cancelLifecycleCallback(identifier: a), isTrue);
    expect(r.cancelLifecycleCallback(identifier: a), isFalse);
    expect(r.cancelLifecycleCallback(key: 'k'), isTrue);
    fire();
    expect(log, ['c']);
  });

  test('cancel all by event and timing', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('end'), timing: end);
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('after'));
    r.cancelAllLifecycleCallbacks(e, timing: end);
    fire();
    fire(LifecycleTiming.afterSuper);
    expect(log, ['after']);
  });

  test('invoke once, re-arm runs it again', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('once'),
        timing: end, invokeOnce: true);
    fire();
    fire();
    expect(log, ['once']);
    r.rearmLifecycleCallbacks(e);
    fire();
    expect(log, ['once', 'once']);
  });

  test('replace by key starts unfired and keeps one block', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('old'),
        timing: end, invokeOnce: true, key: 'cyl.core.layoutBlock');
    fire();
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('new'),
        timing: end, invokeOnce: true, key: 'cyl.core.layoutBlock');
    fire();
    fire();
    expect(log, ['old', 'new']);
    expect(r.blockCount, 1);
  });

  test('isolation: cancel-all and re-arm by event skip keyed blocks', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('core'),
        timing: end, invokeOnce: true, key: 'cyl.core.x');
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('app'),
        timing: end, invokeOnce: true);
    fire();
    r.rearmLifecycleCallbacks(e); // re-arms only the app block
    fire();
    expect(log, ['core', 'app', 'app']);
    r.cancelAllLifecycleCallbacks(e); // keeps the core block
    expect(r.blockCount, 1);
    r.rearmLifecycleCallback(key: 'cyl.core.x');
    fire();
    expect(log.last, 'core');
  });

  test('add and cancel from inside a block', () {
    late int second;
    r.addLifecycleCallback<Owner>(e, (o, id, i) {
      log.add('first');
      r.cancelLifecycleCallback(identifier: second);
      r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('added'), timing: end);
    }, timing: end);
    second = r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('second'),
        timing: end);
    fire();
    expect(log, ['first']);
    fire();
    expect(log, ['first', 'first', 'added']);
  });

  test('timing carried in info', () {
    r.addLifecycleCallback<Owner>(e, (o, id, i) {
      log.add('${i.event!.name}/${i.timing.name}');
    }, timing: end);
    fire();
    expect(log, ['viewDidLayoutSubviews/end']);
  });

  test('performLifecycle without a hook: all timings, once at the outermost', () {
    for (final t in LifecycleTiming.values) {
      r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add(t.name), timing: t);
    }
    r.performLifecycle(e, info(e, end), callSuper: () {
      log.add('super');
      r.performLifecycle(e, info(e, end),
          callSuper: () => log.add('inner super'), body: () => log.add('inner body'));
    }, body: () => log.add('body'));
    expect(log, [
      'beforeSuper', 'super', 'inner super', 'inner body', 'afterSuper', 'body', 'end'
    ]);
  });

  test('performLifecycle with a hook adds only end', () {
    r.hookInstalled = true;
    for (final t in LifecycleTiming.values) {
      r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add(t.name), timing: t);
    }
    r.performLifecycle(e, info(e, end),
        callSuper: () => log.add('super'), body: () => log.add('body'));
    expect(log, ['super', 'body', 'end']);
  });

  test('manual per timing: the hook skips only the declared timing', () {
    r.hookInstalled = true;
    r.setManualLifecycleDispatch(true, {e}, timings: {end});
    expect(r.isAutomatic(e, LifecycleTiming.afterSuper), isTrue);
    expect(r.isAutomatic(e, end), isFalse);
    r.addLifecycleCallback<Owner>(e, (o, id, i) => log.add('end'), timing: end);
    r.performLifecycle(e, info(e, end), callSuper: () {}, body: () {});
    expect(log, isEmpty, reason: 'declared manual: perform does not fire it');
    r.invokeLifecycleCallbacks(e, end, info(e, end));
    expect(log, ['end']);
  });

  test('raw invoke needs the event declared manual', () {
    expect(() => r.invokeLifecycleCallbacks(e, end, info(e, end)),
        throwsAssertionError);
  });

  test('dealloc: order, once, shared identifiers, keyed replacement', () {
    final a = r.addDeallocCallback<Owner>((o, id, i) {
      expect(i.isDealloc, isTrue);
      log.add('a$id');
    });
    final l = r.addLifecycleCallback<Owner>(e, (o, id, i) {}, timing: end);
    r.addDeallocCallback<Owner>((o, id, i) => log.add('old'), key: 'k');
    final c = r.addDeallocCallback<Owner>((o, id, i) => log.add('new'), key: 'k');
    expect(l, a + 1, reason: 'one counter');
    r.runDealloc();
    r.runDealloc();
    expect(log, ['a$a', 'new']);
    expect(c, greaterThan(l));
  });

  test('dealloc isolation: cancel-all keeps keyed, cancel by key removes it', () {
    r.addDeallocCallback<Owner>((o, id, i) => log.add('app'));
    r.addDeallocCallback<Owner>((o, id, i) => log.add('core'), key: 'cyl.core.kvo');
    r.cancelAllDeallocCallbacks();
    r.runDealloc();
    expect(log, ['core']);
    log.clear();
    r.addDeallocCallback<Owner>((o, id, i) => log.add('core2'), key: 'cyl.core.kvo');
    expect(r.cancelDeallocCallback(key: 'cyl.core.kvo'), isTrue);
    r.runDealloc();
    expect(log, isEmpty);
  });
}

// ignore_for_file: deprecated_member_use
// The newest stable Flutter (CI) deprecates package:flutter/material.dart in favor of material_ui; this device-check app keeps
// material.dart so it also builds on the Flutter 3.47 line used for the device run.
import 'package:cyl_dealloc_block_executor/cyl_dealloc_block_executor.dart';
import 'package:flutter/material.dart';

/// Device check app: a block per `LifecycleEvent` on a page with a 400-row list, every firing printed with the prefix `CYL`
/// (read with `adb logcat -s flutter`), and the global pause / resume counted by `LifecycleCenter.whileUserScrolls`.
final routeObserver = RouteObserver<ModalRoute<dynamic>>();
int pauses = 0;
int resumes = 0;

void main() {
  LifecycleCenter.whileUserScrolls(
    pause: () => debugPrint('CYL SCROLLCOUNT pauses=${++pauses} resumes=$resumes'),
    resume: () => debugPrint('CYL SCROLLCOUNT pauses=$pauses resumes=${++resumes}'),
  );
  runApp(MaterialApp(
    navigatorObservers: [routeObserver],
    home: const ListPage(),
  ));
}

class ListPage extends StatefulWidget {
  const ListPage({super.key});
  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> with CYLLifecycleMixin<ListPage> {
  int count = 0;

  @override
  RouteObserver<ModalRoute<dynamic>>? get lifecycleRouteObserver => routeObserver;

  @override
  void initState() {
    // Blocks for events fired inside super (viewDidLoad, move events) go in before super.
    for (final e in LifecycleEvent.values) {
      // Layout events fire during layout: only log them, never rebuild from there.
      lifecycle.addLifecycleCallback<_ListPageState>(e, (o, id, i) {
        count += 1;
        debugPrint('CYL EVENT $count ${e.name}${i.willDecelerate == null ? '' : ' willDecelerate=${i.willDecelerate}'}');
      });
    }
    lifecycle.addDeallocCallback<_ListPageState>((o, id, i) => debugPrint('CYL EVENT teardown'));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CYL lifecycle'),
        actions: [
          // Replacing the page disposes this State, which runs the teardown block.
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('replaced page'))))),
            child: const Text('replace'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('second page'))))),
            child: const Text('push'),
          ),
        ],
      ),
      body: layoutLifecycle(
        child: scrollLifecycle(
          child: ListView.builder(
            itemCount: 400,
            itemBuilder: (context, i) => ListTile(title: Text('row $i')),
          ),
        ),
      ),
    );
  }
}

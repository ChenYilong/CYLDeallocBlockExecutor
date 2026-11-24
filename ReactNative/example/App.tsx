import React, { useRef, useState } from 'react';
import { Button, FlatList, StyleSheet, Text, View } from 'react-native';
// The library sources, not a published package (the file imports react-native, so it is not in the package index).
import { useLifecycle } from '../src/native.ts';
import { LifecycleCenter, LifecycleEvent, LifecycleLog } from '../src/index.ts';

// One block per event, printed as `CYL EVENT n name` (read with `adb logcat -s ReactNativeJS`), and the global pause / resume counted.
let pauses = 0;
let resumes = 0;
LifecycleCenter.whileUserScrolls(
  () => console.log(`CYL SCROLLCOUNT pauses=${++pauses} resumes=${resumes}`),
  () => console.log(`CYL SCROLLCOUNT pauses=${pauses} resumes=${++resumes}`),
);
LifecycleLog.enabled = false;

const rows = Array.from({ length: 400 }, (_, i) => `row ${i}`);

function ListScreen({ onReplace }: { onReplace: () => void }) {
  const owner = useRef({ name: 'ListScreen' }).current;
  const count = useRef(0);
  const { registry, onLayout, scrollHandlers } = useLifecycle(owner);
  const registered = useRef(false);
  if (!registered.current) {
    registered.current = true;
    for (const name of Object.values(LifecycleEvent)) {
      registry.addLifecycleCallback(name, (_o, _id, info) => {
        count.current += 1;
        const decel = info?.willDecelerate == null ? '' : ` willDecelerate=${info.willDecelerate}`;
        console.log(`CYL EVENT ${count.current} ${name}${decel}`);
      });
    }
    registry.addDeallocCallback(() => console.log('CYL EVENT teardown'));
  }
  return (
    <View style={styles.flex} onLayout={onLayout}>
      <Button title="replace" onPress={onReplace} />
      <FlatList
        data={rows}
        keyExtractor={(r) => r}
        renderItem={({ item }) => <Text style={styles.row}>{item}</Text>}
        {...scrollHandlers}
      />
    </View>
  );
}

export default function App() {
  const [replaced, setReplaced] = useState(false);
  return replaced ? (
    <View style={styles.center}><Text>replaced screen</Text></View>
  ) : (
    <ListScreen onReplace={() => setReplaced(true)} />
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, paddingTop: 48 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  row: { padding: 16, fontSize: 18 },
});

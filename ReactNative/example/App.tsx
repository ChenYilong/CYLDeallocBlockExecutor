import React, { useRef, useState } from 'react';
import { Button, FlatList, StyleSheet, Text, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import type { NativeStackScreenProps } from '@react-navigation/native-stack';
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

type RootParams = { Home: undefined; Detail: undefined };
const Stack = createNativeStackNavigator<RootParams>();

const rows = Array.from({ length: 400 }, (_, i) => `row ${i}`);

/**
 * Lifecycle blocks for one screen. The React Navigation `navigation` object is the navigation source: its focus, blur,
 * transitionStart and transitionEnd events feed viewWillAppear ... viewDidDisappear, and didEnterScreen / didLeaveScreen
 * follow the did events. Every event logs `CYL EVENT n name screen=<screen>`.
 */
// The library only needs addListener, so any React Navigation navigation object fits.
type NavigationSource = NonNullable<NonNullable<Parameters<typeof useLifecycle>[1]>['navigation']>;

function useScreenLifecycle(screen: string, navigation: NavigationSource) {
  const owner = useRef({ name: screen }).current;
  const count = useRef(0);
  const lifecycle = useLifecycle(owner, { navigation, navigationMode: 'stack' });
  const registered = useRef(false);
  if (!registered.current) {
    registered.current = true;
    for (const name of Object.values(LifecycleEvent)) {
      lifecycle.registry.addLifecycleCallback(name, (_o, _id, info) => {
        count.current += 1;
        const decel = info?.willDecelerate == null ? '' : ` willDecelerate=${info.willDecelerate}`;
        console.log(`CYL EVENT ${count.current} ${name}${decel} screen=${screen}`);
      });
    }
    lifecycle.registry.addDeallocCallback(() => console.log(`CYL EVENT teardown screen=${screen}`));
  }
  return lifecycle;
}

function HomeScreen({ navigation, onReplace }: NativeStackScreenProps<RootParams, 'Home'> & { onReplace: () => void }) {
  const { onLayout, scrollHandlers } = useScreenLifecycle('Home', navigation);
  return (
    <View style={styles.flex} onLayout={onLayout}>
      <Button title="replace" onPress={onReplace} />
      <Button title="push Detail" onPress={() => navigation.navigate('Detail')} />
      <FlatList
        data={rows}
        keyExtractor={(r) => r}
        renderItem={({ item }) => <Text style={styles.row}>{item}</Text>}
        {...scrollHandlers}
      />
    </View>
  );
}

function DetailScreen({ navigation }: NativeStackScreenProps<RootParams, 'Detail'>) {
  const { onLayout } = useScreenLifecycle('Detail', navigation);
  return (
    <View style={styles.center} onLayout={onLayout}>
      <Text>Detail screen</Text>
      <Button title="Back" onPress={() => navigation.goBack()} />
    </View>
  );
}

export default function App() {
  const [replaced, setReplaced] = useState(false);
  return replaced ? (
    <View style={styles.center}><Text>replaced screen</Text></View>
  ) : (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Home">
        <Stack.Screen name="Home">{(props) => <HomeScreen {...props} onReplace={() => setReplaced(true)} />}</Stack.Screen>
        <Stack.Screen name="Detail" component={DetailScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  row: { padding: 16, fontSize: 18 },
});

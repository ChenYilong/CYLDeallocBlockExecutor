// Written without a HarmonyOS toolchain: untested.
// The sources live in ../src (plain TypeScript, imported with `.ts` extensions so Node can test them).
// If hvigor cannot resolve these paths or the `.ts` extensions, move the files into
// src/main/ets and drop the extensions; see docs/Cross-Platform-API.md (HarmonyOS).
export { LifecycleController } from '../src/controller';
export { LifecycleRegistry } from '../src/registry';
export { LifecycleEvent, LifecycleTiming } from '../src/types';

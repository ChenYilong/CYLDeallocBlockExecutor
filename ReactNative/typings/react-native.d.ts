// Stub so `npm run typecheck` does not need the real react-native package
// (hundreds of megabytes). `native.ts` only uses these four names.
declare module 'react-native' {
  export const Appearance: object;
  export const AppState: object;
  export const Dimensions: object;
  export const Platform: { OS: string };
}

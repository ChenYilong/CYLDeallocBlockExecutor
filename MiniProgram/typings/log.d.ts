export type LogSink = (message: string) => void;
/**
 * Debug log of the lifecycle moments (design v5). Off by default: turn it on while developing, read what fires on which owner,
 * in which order, and how many blocks ran. Every message is built lazily, so the disabled path costs one boolean check.
 *
 *   LifecycleLog.enabled = true;                       // prints through `sink`
 *   LifecycleLog.sink = (message) => myLogger(message); // your own destination
 */
export declare class LifecycleLog {
    static enabled: boolean;
    static sink: LogSink;
    static log(message: () => string): void;
    /** A short name for an owner: its class name, plus `name` or `id` when it has one. */
    static describe(owner: unknown): string;
}
/** Well-known custom event names posted by the components (the library never posts them itself). */
export declare const AnimationEvents: {
    readonly didStart: 'cyl.animation.didStart';
    readonly didPause: 'cyl.animation.didPause';
    readonly didResume: 'cyl.animation.didResume';
    readonly didStop: 'cyl.animation.didStop';
};
export declare const BadgeEvents: {
    readonly didShow: 'cyl.badge.didShow';
    readonly didClear: 'cyl.badge.didClear';
    readonly didBecomeReady: 'cyl.badge.didBecomeReady';
    readonly animationDidStart: 'cyl.badge.animationDidStart';
    readonly animationDidStop: 'cyl.badge.animationDidStop';
};

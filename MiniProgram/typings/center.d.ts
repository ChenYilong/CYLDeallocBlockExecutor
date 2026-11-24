import type { LifecycleCallback, LifecycleEvent, LifecycleInfo, LifecycleTiming } from './types';
/** Options of `whileUserScrolls` and `addDeallocObserver`. */
export interface KeyOptions {
    key?: string;
}
export interface CenterOptions {
    timing?: LifecycleTiming;
    /** Only owners that are instances of this class are observed. */
    ownerType?: abstract new (...args: any[]) => object;
    key?: string;
}
/**
 * Global observers: one block that observes an event on every object, for
 * behavior that must not know its owners ("pause every animation while the user
 * scrolls"). Per-owner blocks run first, then the global ones, each group in
 * identifier order. Global observers never receive teardown events: the owner is
 * going away. A key replaces the observer added before under it.
 */
export declare class LifecycleCenter {
    private static entries;
    private static nextIdentifier;
    private static readonly scrolling;
    /** True while any observed scroll source is dragging or decelerating. */
    static get isUserScrolling(): boolean;
    static addCallback<T = any>(event: LifecycleEvent, callback: LifecycleCallback<T>, options?: CenterOptions): number;
    static addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options?: CenterOptions): number;
    private static add;
    /**
     * The ready-made version of "pause every animation while the user scrolls, resume afterwards": `pause` runs when any observed scroll
     * source starts to be dragged, `resume` when it stopped for good. Returns a function that removes both observers. The two
     * observers use the keys `<key>.pause` and `<key>.resume` (default key `cyl.scroll`), so calling it again replaces the earlier pair.
     */
    static whileUserScrolls(pause: () => void, resume: () => void, options?: KeyOptions): () => void;
    /** Cancels one observer by `identifier` or by `key`; true when one was removed. */
    static cancelCallback(target: {
        identifier: number;
    } | {
        key: string;
    }): boolean;
    private static deallocObservers;
    /**
     * Observes the teardown of every owner that has a registry, to know when any object goes away. The callback gets a description
     * (class name and `name` / `id`), never the owner: it is being destroyed. For logging and bookkeeping, not for cleanup.
     */
    static addDeallocObserver(callback: (description: string, info: LifecycleInfo) => void, options?: KeyOptions): number;
    static cancelDeallocObserver(target: {
        identifier: number;
    } | {
        key: string;
    }): boolean;
    /** Called by a registry when its owner's teardown blocks ran. */
    static dispatchDealloc(description: string): void;
    /** For tests: removes every observer and forgets the scroll state. */
    static reset(): void;
    /** Called by a registry after the owner's own blocks of (event, timing) ran. */
    static dispatch(owner: object, event: LifecycleEvent | null, custom: string | undefined, timing: LifecycleTiming, info: LifecycleInfo): void;
}

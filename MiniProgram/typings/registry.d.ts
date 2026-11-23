import type { LifecycleCallback, LifecycleEvent, LifecycleInfo, LifecycleTiming } from './types';
/** Options of `addCustomCallback`. A named interface (not an inline type), so ArkTS accepts an object literal for it. */
export interface CustomOptions {
    invokeOnce?: boolean;
    key?: string;
}
/** Options of `addDeallocCallback`. */
export interface DeallocOptions {
    key?: string;
}
export interface AddOptions {
    timing?: LifecycleTiming;
    invokeOnce?: boolean;
    key?: string;
}
/**
 * One registry per owner: the lifecycle blocks and the teardown blocks.
 *
 * The iOS rules (see `docs/Lifecycle-Callbacks.md`): one identifier counter for
 * every block; blocks run in identifier order from a snapshot, so a block can
 * add or cancel blocks; adding with a key replaces the block added before under
 * that key (the new block starts unfired; keys are separate for lifecycle and
 * teardown blocks); keyed blocks belong to their key holder: cancel-all and
 * re-arm by event skip them. No lock: JavaScript runs one thread.
 */
export declare class LifecycleRegistry {
    /** The registry of `owner`, created on first use. */
    static of(owner: object): LifecycleRegistry;
    private readonly owner;
    private entries;
    private nextIdentifier;
    private readonly manual;
    private readonly performDepth;
    private forwards;
    /** Called when a block is added for `event` (the controller attaches its sources lazily). */
    onRegister: ((event: LifecycleEvent) => void) | undefined;
    /** The controller sets this once its automatic hooks fire `beforeSuper` / `afterSuper`. */
    hookInstalled: boolean;
    constructor(owner: object);
    hasBlocksFor(event: LifecycleEvent): boolean;
    get blockCount(): number;
    /** Removes the entries that match and marks them cancelled, so a running snapshot skips them. */
    private drop;
    private removeKey;
    /** Adds a block for `event`; returns its identifier. */
    addLifecycleCallback<T = any>(event: LifecycleEvent, callback: LifecycleCallback<T>, options?: AddOptions): number;
    /** Cancels one block by `identifier` or by `key`; true when one was removed. */
    cancelLifecycleCallback(target: {
        identifier: number;
    } | {
        key: string;
    }): boolean;
    /** Adds a block for the custom event `name` (a name the app or the core posts); returns its identifier. */
    addCustomCallback<T = any>(name: string, callback: LifecycleCallback<T>, options?: CustomOptions): number;
    /** Runs the blocks of the custom event `name` (the owner's, then the global observers'), in identifier order. */
    postLifecycleEvent(name: string, userInfo?: Record<string, unknown>): void;
    /**
     * A forwarded post runs the target's own blocks only: the source already told the global observers once, so an observer
     * never hears the same moment twice (once from the source, once from each target).
     */
    private post;
    /**
     * Forwards the events fired on this owner to `target`'s registry (all events, or the given set), as an object that is
     * not a view gets the events of the view that shows it. The target is held weakly; forwarding to the same target again
     * replaces the earlier forward. Posted custom events are forwarded too.
     */
    forwardLifecycleEvents(target: LifecycleRegistry, events?: readonly LifecycleEvent[]): void;
    private liveForwards;
    /** Cancels the blocks of `event` (and `timing` when given) that have no key. */
    cancelAllLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void;
    /** Lets the invoke-once blocks of `event` without a key run once more. */
    rearmLifecycleCallbacks(event: LifecycleEvent, timing?: LifecycleTiming): void;
    /** Re-arms the one block added under `key`. */
    rearmLifecycleCallback(key: string): void;
    /** Adds a teardown block: it runs once, when the owner is torn down. */
    addDeallocCallback<T = any>(callback: LifecycleCallback<T>, options?: DeallocOptions): number;
    cancelDeallocCallback(target: {
        identifier: number;
    } | {
        key: string;
    }): boolean;
    /** Cancels the teardown blocks that have no key. */
    cancelAllDeallocCallbacks(): void;
    private cancelOne;
    /** Runs the teardown blocks in identifier order, once. The owner calls this when it is torn down. */
    runDealloc(): void;
    /** Declares that the owner dispatches `events` itself, for `timings` (all by default). */
    setManualLifecycleDispatch(manual: boolean, events: readonly LifecycleEvent[], timings?: readonly LifecycleTiming[]): void;
    isManual(event: LifecycleEvent, timing: LifecycleTiming): boolean;
    /** True when the controller's automatic hook fires this (event, timing). */
    isAutomatic(event: LifecycleEvent, timing: LifecycleTiming): boolean;
    /** Fires the blocks of one (event, timing) for the automatic hooks; skips a timing declared manual. */
    fireAutomatic(event: LifecycleEvent, timing: LifecycleTiming, info?: Partial<LifecycleInfo>): void;
    /** Fires the blocks of one (event, timing) by hand. The event must be declared manual first. */
    invokeLifecycleCallbacks(event: LifecycleEvent, timing: LifecycleTiming, info?: Partial<LifecycleInfo>): void;
    /**
     * Runs `callSuper`, then `body`, with the timings around them. With the
     * controller's hook the automatic timings come from the hook; this method
     * adds `end` after `body`, at the outermost level only and not when `end` is
     * declared manual. For an owner without a hook all three timings fire from
     * the outermost call.
     */
    performLifecycle(event: LifecycleEvent, parts: {
        callSuper: () => void;
        body: () => void;
        info?: Partial<LifecycleInfo>;
    }): void;
    private fire;
}

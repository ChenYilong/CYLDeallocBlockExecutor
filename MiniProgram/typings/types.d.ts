/** The events a block can be added to. Names match the iOS `CYLLifecycleEvent`. */
export declare const LifecycleEvent: {
    readonly viewDidLoad: 'viewDidLoad';
    readonly viewWillAppear: 'viewWillAppear';
    readonly viewIsAppearing: 'viewIsAppearing';
    readonly viewDidAppear: 'viewDidAppear';
    readonly viewWillLayoutSubviews: 'viewWillLayoutSubviews';
    readonly viewDidLayoutSubviews: 'viewDidLayoutSubviews';
    readonly viewWillDisappear: 'viewWillDisappear';
    readonly viewDidDisappear: 'viewDidDisappear';
    readonly viewSafeAreaInsetsDidChange: 'viewSafeAreaInsetsDidChange';
    readonly viewLayoutMarginsDidChange: 'viewLayoutMarginsDidChange';
    readonly traitCollectionDidChange: 'traitCollectionDidChange';
    readonly viewWillTransition: 'viewWillTransition';
    readonly willMoveToParent: 'willMoveToParent';
    readonly didMoveToParent: 'didMoveToParent';
    readonly didReceiveMemoryWarning: 'didReceiveMemoryWarning';
    readonly willMoveToWindow: 'willMoveToWindow';
    readonly didMoveToWindow: 'didMoveToWindow';
    readonly didEnterScreen: 'didEnterScreen';
    readonly didLeaveScreen: 'didLeaveScreen';
    readonly scrollWillBeginDragging: 'scrollWillBeginDragging';
    readonly scrollDidEndDragging: 'scrollDidEndDragging';
    readonly scrollDidEndScrolling: 'scrollDidEndScrolling';
};
export type LifecycleEvent = (typeof LifecycleEvent)[keyof typeof LifecycleEvent];
/**
 * When a block runs relative to the platform's own handling. React has no
 * `super` call: the controller fires `beforeSuper` then `afterSuper` back to
 * back at the single moment the platform reports, and `end` only through
 * `performLifecycle` / `invokeLifecycleCallbacks`.
 */
export declare const LifecycleTiming: {
    readonly beforeSuper: 'beforeSuper';
    readonly afterSuper: 'afterSuper';
    readonly end: 'end';
};
export type LifecycleTiming = (typeof LifecycleTiming)[keyof typeof LifecycleTiming];
export declare const allTimings: readonly LifecycleTiming[];
export interface Insets {
    top: number;
    left: number;
    bottom: number;
    right: number;
}
/** What a block can read about the event (iOS `CYLLifecycleInfo`). */
export interface LifecycleInfo {
    event: LifecycleEvent | null;
    timing: LifecycleTiming;
    /** Appearance events: the navigation transition is animated. */
    animated?: boolean;
    /** `viewWillTransition`: the new window size. */
    size?: {
        width: number;
        height: number;
    };
    /** `traitCollectionDidChange`: the values before the change. */
    previousColorScheme?: string | null;
    previousFontScale?: number;
    /** `viewSafeAreaInsetsDidChange`: the insets before the change. */
    previousInsets?: Insets;
    /** `willMoveToParent` / `didMoveToParent`: attached to (true) or detached from (false) the tree. */
    parentAttached?: boolean;
    /** True for the block of a teardown. */
    isDealloc?: boolean;
    /** Scroll events: the scrolling source (a scroll view, a list, a page), as the platform names it. */
    scrollView?: unknown;
    /** `scrollDidEndDragging`: the scroll view keeps moving after the finger lifts. */
    willDecelerate?: boolean;
    /** `willMoveToWindow` / `didMoveToWindow`: the window, or null when the view leaves it. */
    window?: unknown;
    /** Custom events: the name the event was posted under. */
    customEvent?: string;
    /** Custom events: what the poster passed along. */
    userInfo?: Record<string, unknown>;
}
/** A block: the owner, its own identifier and the info. */
export type LifecycleCallback<T> = (owner: T, identifier: number, info: LifecycleInfo) => void;

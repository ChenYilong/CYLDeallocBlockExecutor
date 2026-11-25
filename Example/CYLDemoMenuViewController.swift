//
//  CYLDemoMenuViewController.swift
//  The Home tab of the Example: a sectioned menu built with CollectionViewClassifyMenu's tag list, as the
//  "Example demo" rule of instructions.md asks (sections with titled headers, a More / Less fold at 3 rows, tap, a
//  long-press subtitle popover with an arrow, wrapping titles, adaptive tag width).
//

import UIKit
import CollectionViewClassifyMenu
import CYLDeallocBlockExecutor

/// One row of the demo menu: the main title and icon become the tag, the subtitle is shown by a long press.
struct CYLDemoMenuItem {
    let title: String
    let subtitle: String
    let symbol: String
}

/// One titled section of the demo menu.
struct CYLDemoMenuSection {
    let title: String
    let symbol: String
    let items: [CYLDemoMenuItem]
}

final class CYLDemoMenuViewController: UIViewController {

    /// The most rows a section shows before its More / Less control appears (the Example's maximum).
    static let maximumRows = 3

    static let sections: [CYLDemoMenuSection] = [
        CYLDemoMenuSection(title: "Lifecycle events", symbol: "arrow.triangle.2.circlepath", items: [
            CYLDemoMenuItem(title: "viewWillAppear log", subtitle: "A block added with cylAddLifecycleCallback(for: .viewWillAppear) logs each appearance.", symbol: "eye"),
            CYLDemoMenuItem(title: "One-time layout block, run once at the end of the first layout pass", subtitle: "invokeOnce: true with timing .end, like CYLTabBarController's one-time layout block.", symbol: "rectangle.split.3x1"),
            CYLDemoMenuItem(title: "Re-skin on appearance change", subtitle: "traitCollectionDidChange re-applies the theme when light or dark mode changes.", symbol: "circle.lefthalf.filled"),
            CYLDemoMenuItem(title: "Scroll begin and end", subtitle: "scrollWillBeginDragging, scrollDidEndDragging and scrollDidEndScrolling, also after a flick.", symbol: "hand.draw"),
            CYLDemoMenuItem(title: "Global observers", subtitle: "One block that observes an event on every object, for example pause animations while scrolling.", symbol: "dot.radiowaves.left.and.right"),
            CYLDemoMenuItem(title: "Event forwarding", subtitle: "An object that is not a view receives the events of the view that shows it.", symbol: "arrowshape.turn.up.right")
        ]),
        CYLDemoMenuSection(title: "Dealloc blocks", symbol: "trash", items: [
            CYLDemoMenuItem(title: "Several blocks per object", subtitle: "Each object holds any number of dealloc blocks; they run in the order they were added.", symbol: "square.stack.3d.up"),
            CYLDemoMenuItem(title: "Owner and identifier in every block", subtitle: "Every block receives the owner and its own identifier.", symbol: "number"),
            CYLDemoMenuItem(title: "Cancel one or all", subtitle: "cylCancelDeallocCallback(identifier:) and cylCancelAllDeallocCallbacks().", symbol: "xmark.circle")
        ]),
        CYLDemoMenuSection(title: "Theme", symbol: "paintpalette", items: [
            CYLDemoMenuItem(title: "Random background", subtitle: "Tapping toggles between the setter and the notification that apply a random background color.", symbol: "dice"),
            CYLDemoMenuItem(title: "Observer removed on dealloc", subtitle: "The theme observer is removed by a keyed dealloc block, so it never leaks.", symbol: "link.badge.plus")
        ])
    ]

    private let tagList = CYLTagListView(frame: .zero)
    private var bySetter = false
    private var popover: CYLDemoSubtitleViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Home"
        view.backgroundColor = .systemBackground
        view.themeMap = ["BackgroundColor": "randomColor"]

        tagList.translatesAutoresizingMaskIntoConstraints = false
        tagList.menuDataSource = self
        tagList.menuDelegate = self
        tagList.showsSectionHeaders = true
        // At most three rows per section; the fold control (More / Less with its built-in icon) shows past that.
        tagList.defaultVisibleRows = CYLDemoMenuViewController.maximumRows
        let fold = CYLMenuFoldControl(position: .headerTrailing, content: .iconAndTitle)
        fold.title = "More"
        fold.collapseTitle = "Less"
        tagList.foldControl = fold
        // Titles wrap to as many lines as they need; the tag width follows the title, so a row holds as many tags as fit.
        let style = CYLMenuStyle()
        style.titleWraps = true
        tagList.style = style
        view.addSubview(tagList)
        NSLayoutConstraint.activate([
            tagList.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tagList.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tagList.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tagList.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        tagList.reloadMenuData()
    }

    /// Tapping a tag does what tapping the old log cell did: toggle the theme, then show the log (the Log tab).
    private func tapItem(at indexPath: IndexPath) {
        bySetter.toggle()
        if bySetter {
            view.themeMap = ["BackgroundColor": "randomColor"]
        } else {
            NotificationCenter.default.post(name: kThemeDidChangeNotification, object: nil,
                                            userInfo: ["BackgroundColor": "randomColor"])
        }
        tabBarController?.selectedIndex = CYLDemoTabs.logIndex
    }

    /// A long press shows the subtitle in a small popover with an arrow pointing at the tag.
    private func showSubtitle(at indexPath: IndexPath) {
        guard popover == nil, presentedViewController == nil,
              let button = tagList.tagButton(at: indexPath) else { return }
        let item = CYLDemoMenuViewController.sections[indexPath.section].items[indexPath.item]
        let content = CYLDemoSubtitleViewController(text: item.subtitle)
        content.modalPresentationStyle = .popover
        if let controller = content.popoverPresentationController {
            controller.sourceView = button
            controller.sourceRect = button.bounds
            controller.permittedArrowDirections = [.up, .down]
            controller.delegate = content
        }
        popover = content
        present(content, animated: true)
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        popover = nil
        super.dismiss(animated: flag, completion: completion)
    }
}

extension CYLDemoMenuViewController: CYLMenuDataSource {

    func numberOfSectionsInMenu() -> Int {
        CYLDemoMenuViewController.sections.count
    }

    func menuNumberOfItems(inSection section: Int) -> Int {
        CYLDemoMenuViewController.sections[section].items.count
    }

    func menuTitle(forSection section: Int) -> String {
        CYLDemoMenuViewController.sections[section].title
    }

    func menuImage(forSection section: Int) -> UIImage? {
        UIImage(systemName: CYLDemoMenuViewController.sections[section].symbol)
    }

    func menuTitleForItem(at indexPath: IndexPath) -> String {
        CYLDemoMenuViewController.sections[indexPath.section].items[indexPath.item].title
    }

    func menuImageForItem(at indexPath: IndexPath) -> UIImage? {
        UIImage(systemName: CYLDemoMenuViewController.sections[indexPath.section].items[indexPath.item].symbol)
    }

    func menuItemIsSelectable(at indexPath: IndexPath) -> Bool {
        false
    }

    func menuAccessibilityHintForItem(at indexPath: IndexPath) -> String? {
        CYLDemoMenuViewController.sections[indexPath.section].items[indexPath.item].subtitle
    }
}

extension CYLDemoMenuViewController: CYLMenuDelegate {

    func menu(_ menu: Any, didSelectItemAt indexPath: IndexPath) {
        tapItem(at: indexPath)
    }

    func menu(_ menu: Any, didLongPressItemAt indexPath: IndexPath) {
        showSubtitle(at: indexPath)
    }
}

/// The small floating box: a label with the subtitle. `.none` keeps it a popover with an arrow on iPhone.
final class CYLDemoSubtitleViewController: UIViewController, UIPopoverPresentationControllerDelegate {

    private let text: String

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14)
        ])
        let width: CGFloat = 240
        let height = label.sizeThatFits(CGSize(width: width - 28, height: .greatestFiniteMagnitude)).height + 24
        preferredContentSize = CGSize(width: width, height: height)
    }

    func adaptivePresentationStyle(for controller: UIPresentationController,
                                   traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }
}

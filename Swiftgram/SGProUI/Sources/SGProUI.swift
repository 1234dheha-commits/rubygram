// MARK: Rubygram — Developer pane (was Swiftgram Pro)
import Foundation
import UIKit
import UniformTypeIdentifiers
import SGItemListUI
import UndoUI
import AccountContext
import Display
import TelegramCore
import Postbox
import ItemListUI
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import TelegramUIPreferences
import SettingsUI

// Optional
import SGSimpleSettings
import SGLogging
#if DEBUG
import FLEX
#endif


private enum SGProControllerSection: Int32, SGItemListSection {
    case codemagic
    case appearance
    case debugging
    case about
}

private enum SGProDisclosureLink: String {
    case appIcons
    case codeMagicWeb
    case codeMagicLatestBuild
}

private enum SGProToggles: String {
    case flexOverlay
}

private enum SGProOneFromManySetting: String {
    case noop
}

private enum SGProAction {
    case triggerDevBuild
    case triggerAppStoreBuild
    case openAccentColor
}

private typealias SGProControllerEntry = SGItemListUIEntry<SGProControllerSection, SGProToggles, AnyHashable, SGProOneFromManySetting, SGProDisclosureLink, SGProAction>

// User-defaults backed prefs for Developer pane
private struct RubygramDevPrefs {
    static let flexOverlayKey = "rubygram.dev.flexOverlay"
    static var flexOverlayEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: flexOverlayKey) }
        set { UserDefaults.standard.set(newValue, forKey: flexOverlayKey) }
    }
}

private func SGProControllerEntries(presentationData: PresentationData) -> [SGProControllerEntry] {
    var entries: [SGProControllerEntry] = []

    let id = SGItemListCounter()

    // Section: Code Magic
    entries.append(.header(id: id.count, section: .codemagic, text: "CODE MAGIC", badge: nil))
    entries.append(.action(id: id.count, section: .codemagic, actionType: .triggerDevBuild, text: "Trigger Dev IPA Build", kind: .generic))
    entries.append(.action(id: id.count, section: .codemagic, actionType: .triggerAppStoreBuild, text: "Trigger TestFlight Build", kind: .generic))
    entries.append(.disclosure(id: id.count, section: .codemagic, link: .codeMagicLatestBuild, text: "Latest Build Status"))
    entries.append(.disclosure(id: id.count, section: .codemagic, link: .codeMagicWeb, text: "Open Codemagic Dashboard"))
    entries.append(.notice(id: id.count, section: .codemagic, text: "Triggers Codemagic builds for this app. Build status appears in the Codemagic dashboard."))

    // Section: Appearance
    entries.append(.header(id: id.count, section: .appearance, text: presentationData.strings.Appearance_Title.uppercased(), badge: nil))
    entries.append(.disclosure(id: id.count, section: .appearance, link: .appIcons, text: presentationData.strings.Appearance_AppIcon))
    entries.append(.action(id: id.count, section: .appearance, actionType: .openAccentColor, text: "Accent Color", kind: .generic))

    // Section: Debugging
    entries.append(.header(id: id.count, section: .debugging, text: "DEBUGGING", badge: nil))
    entries.append(.toggle(id: id.count, section: .debugging, settingName: .flexOverlay, value: RubygramDevPrefs.flexOverlayEnabled, text: "FLEX Debug Overlay", enabled: true))
    #if DEBUG
    entries.append(.notice(id: id.count, section: .debugging, text: "Tap the toggle to show / hide the FLEX explorer overlay. Inspect views, network calls and live state."))
    #else
    entries.append(.notice(id: id.count, section: .debugging, text: "FLEX overlay is only active in development builds."))
    #endif

    // Section: About
    entries.append(.header(id: id.count, section: .about, text: "ABOUT", badge: nil))
    entries.append(.notice(id: id.count, section: .about, text: "Rubygram Developer pane. Based on Swiftgram, branded for personal use. Not affiliated with Telegram."))

    return entries
}

public func okUndoController(_ text: String, _ presentationData: PresentationData) -> UndoOverlayController {
    return UndoOverlayController(presentationData: presentationData, content: .succeed(text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false })
}

private func openExternalURL(_ urlString: String, context: AccountContext) {
    guard let url = URL(string: urlString) else { return }
    context.sharedContext.applicationBindings.openUrl(url.absoluteString)
}

private func triggerCodemagicBuild(workflow: String, context: AccountContext, presentationData: PresentationData, present: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void) {
    // Token + app id can be overridden via UserDefaults; default values are placeholders.
    // To configure: set `rubygram.dev.codemagic.token` and `rubygram.dev.codemagic.appId` via the app's standard UserDefaults.
    let token = UserDefaults.standard.string(forKey: "rubygram.dev.codemagic.token") ?? ""
    let appId = UserDefaults.standard.string(forKey: "rubygram.dev.codemagic.appId") ?? ""

    guard !token.isEmpty, !appId.isEmpty else {
        let alert = textAlertController(context: context, title: "Codemagic not configured", text: "Set `rubygram.dev.codemagic.token` and `rubygram.dev.codemagic.appId` in this app's UserDefaults (e.g. via a debugger or a future config screen), then try again.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
        present(alert, nil)
        return
    }

    guard let url = URL(string: "https://api.codemagic.io/builds") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(token, forHTTPHeaderField: "x-auth-token")
    let body: [String: Any] = [
        "appId": appId,
        "workflowId": workflow,
        "branch": "main"
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

    URLSession.shared.dataTask(with: request) { data, response, error in
        DispatchQueue.main.async {
            if let error = error {
                let alert = textAlertController(context: context, title: "Codemagic", text: "Network error: \(error.localizedDescription)", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                present(alert, nil)
                return
            }
            var msg = "Build queued."
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let buildId = json["buildId"] as? String {
                msg = "Build queued.\nID: \(buildId)"
                UserDefaults.standard.set(buildId, forKey: "rubygram.dev.codemagic.lastBuildId")
            }
            let alert = textAlertController(context: context, title: "Codemagic", text: msg, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
            present(alert, nil)
        }
    }.resume()
}

public func sgProController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<SGProToggles, AnyHashable, SGProOneFromManySetting, SGProDisclosureLink, SGProAction>(context: context, setBoolValue: { toggleName, value in
        switch toggleName {
        case .flexOverlay:
            RubygramDevPrefs.flexOverlayEnabled = value
            #if DEBUG
            if value {
                FLEXManager.shared.showExplorer()
            } else {
                FLEXManager.shared.hideExplorer()
            }
            #endif
            simplePromise.set(true)
        }
    }, setOneFromManyValue: { _ in
        // no-op
    }, openDisclosureLink: { link in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch link {
        case .appIcons:
            pushControllerImpl?(themeSettingsController(context: context, focusOnItemTag: .icon))
        case .codeMagicWeb:
            let appId = UserDefaults.standard.string(forKey: "rubygram.dev.codemagic.appId") ?? ""
            let dashUrl = appId.isEmpty ? "https://codemagic.io/apps" : "https://codemagic.io/app/\(appId)"
            openExternalURL(dashUrl, context: context)
        case .codeMagicLatestBuild:
            if let lastId = UserDefaults.standard.string(forKey: "rubygram.dev.codemagic.lastBuildId"), !lastId.isEmpty {
                openExternalURL("https://codemagic.io/build/\(lastId)", context: context)
            } else {
                let alert = textAlertController(context: context, title: "Codemagic", text: "No build has been triggered yet from this device.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                presentControllerImpl?(alert, nil)
            }
        }
    }, action: { action in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch action {
        case .triggerDevBuild:
            triggerCodemagicBuild(workflow: "ios-release", context: context, presentationData: presentationData, present: { c, a in
                presentControllerImpl?(c, a)
            })
        case .triggerAppStoreBuild:
            triggerCodemagicBuild(workflow: "ios-appstore", context: context, presentationData: presentationData, present: { c, a in
                presentControllerImpl?(c, a)
            })
        case .openAccentColor:
            pushControllerImpl?(themeSettingsController(context: context))
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, simplePromise.get())
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in

        let entries = SGProControllerEntries(presentationData: presentationData)

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Developer"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))

        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    let _ = pushControllerImpl

    return controller
}

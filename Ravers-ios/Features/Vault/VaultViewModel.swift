
import SwiftUI

@Observable
final class VaultViewModel {
    enum Tab: String, CaseIterable { case holding, passes, orders }

    var selectedTab: Tab = .holding
    var holding: [Product] = []
//    var savedItems: [Product] = []

    func load() async { }
}

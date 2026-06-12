import Foundation

final class PanelState: ObservableObject {
    @Published var isExpanded = false
    @Published var isPinned = false
}

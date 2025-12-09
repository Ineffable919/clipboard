import Foundation

@Observable
final class HistoryViewModel {
    var selectedId: PasteboardModel.ID?
    var lastTapId: PasteboardModel.ID?
    var lastTapTime: TimeInterval = 0
    var pendingDeleteId: PasteboardModel.ID?

    var showPreviewId: PasteboardModel.ID?
    var isDel: Bool = false
    var isQuickPastePressed: Bool = false
    var lastLoadTriggerIndex: Int = -1
}

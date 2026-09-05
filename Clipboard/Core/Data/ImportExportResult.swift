import Foundation

extension PasteSQLManager {
    struct ImportExportResult {
        let success: Bool
        let message: String
        var importedAppInfo: [(name: String, path: String)] = []
        var importedChipsData: Data?
    }

}

import Foundation

extension PasteSQLManager {
    struct ImportExportResult {
        let success: Bool
        let message: String
        var importedChipsData: Data?
    }

}

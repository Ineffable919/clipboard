import AppKit
import Foundation

class FileAccessHelper {
    static let shared = FileAccessHelper()
    private let bookmarkDictKey = "AuthorizedFolderBookmarkDict"
}

extension FileAccessHelper {
    private func loadAllBookmarks() -> [String: Data] {
        return UserDefaults.standard.dictionary(forKey: bookmarkDictKey)
            as? [String: Data] ?? [:]
    }

    private func saveAllBookmarks(_ bookmarks: [String: Data]) {
        UserDefaults.standard.set(bookmarks, forKey: bookmarkDictKey)
    }

    func saveSecurityBookmarks(for filePaths: [String]) {
        var allBookmarks = loadAllBookmarks()

        for path in filePaths {
            let fileURL = URL(fileURLWithPath: path)

            if let existingBookmark = allBookmarks[path] {
                do {
                    var isStale = false
                    _ = try URL(
                        resolvingBookmarkData: existingBookmark,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )

                    if !isStale {
                        continue
                    }

                } catch {
                    log.debug("⚠️检查现有 bookmark 失败，将重新创建：\(path)")
                }
            }

            do {
                let bookmark = try fileURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                allBookmarks[path] = bookmark
            } catch {
                log.debug("⚠️无法创建 bookmark：\(path) - \(error)")
            }
        }

        saveAllBookmarks(allBookmarks)
    }

    func restoreAllAccesses() {
        let allBookmarks = loadAllBookmarks()
        var updatedBookmarks = allBookmarks
        var hasStaleBookmarks = false

        for (path, bookmarkData) in allBookmarks {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    do {
                        let newBookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        updatedBookmarks[path] = newBookmark
                        hasStaleBookmarks = true
                    } catch {
                        updatedBookmarks.removeValue(forKey: path)
                        hasStaleBookmarks = true
                        continue
                    }
                }

                _ = url.startAccessingSecurityScopedResource()

            } catch {
                updatedBookmarks.removeValue(forKey: path)
                hasStaleBookmarks = true
            }
        }

        if hasStaleBookmarks {
            saveAllBookmarks(updatedBookmarks)
        }
    }

    func refreshBookmark(for path: String) -> Bool {
        var allBookmarks = loadAllBookmarks()

        guard allBookmarks[path] != nil else {
            return false
        }

        let fileURL = URL(fileURLWithPath: path)
        do {
            let newBookmark = try fileURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            allBookmarks[path] = newBookmark
            saveAllBookmarks(allBookmarks)
            return true
        } catch {
            return false
        }
    }

    func refreshStaleBookmarks() {
        let allBookmarks = loadAllBookmarks()
        var updatedBookmarks = allBookmarks
        var hasUpdates = false

        for (path, bookmarkData) in allBookmarks {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    do {
                        let newBookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        updatedBookmarks[path] = newBookmark
                        hasUpdates = true
                    } catch {
                        updatedBookmarks.removeValue(forKey: path)
                        hasUpdates = true
                    }
                }

            } catch {
                updatedBookmarks.removeValue(forKey: path)
                hasUpdates = true
            }
        }

        if hasUpdates {
            saveAllBookmarks(updatedBookmarks)
        }
    }

    func stopAccessingSecurityScopedResources() {
        let allBookmarks = loadAllBookmarks()

        for (path, bookmarkData) in allBookmarks {
            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if !isStale {
                    url.stopAccessingSecurityScopedResource()
                }

            } catch {
                log.debug("⚠️停止访问文件：\(path) - \(error)")
            }
        }
    }
}

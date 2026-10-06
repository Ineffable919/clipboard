import AppKit
import Combine

extension TopBarViewModel {
    // MARK: - Filter Methods

    func toggleType(_ type: PasteModelType) {
        if selectedTypes.contains(type) {
            selectedTypes.remove(type)
            removeTagForType(type)
        } else {
            selectedTypes.insert(type)
            addTagForType(type)
        }
        filterDidChange.send()
    }

    func toggleApp(_ id: Int64) {
        if selectedAppIDs.remove(id) != nil {
            tags.removeAll { $0.type == .filterApp && $0.associatedValue == String(id) }
        } else if let app = SourceAppCache.shared.apps[id] {
            selectedAppIDs.insert(id)
            let tag = InputTag(
                icon: AppIconCache.shared.getCachedIcon(forAppID: id)
                    ?? NSImage(systemSymbolName: "questionmark.app.dashed", accessibilityDescription: nil),
                label: app.name, type: .filterApp, associatedValue: String(id), appPath: app.path
            )
            tags.append(tag)
            if AppIconCache.shared.getCachedIcon(forAppID: id) == nil {
                Task { [weak self] in
                    let icon = await AppIconCache.shared.loadIcon(forAppID: id, path: app.path)
                    guard let self, let index = tags.firstIndex(where: { $0.id == tag.id }) else { return }
                    tags[index].icon = icon
                    filterDidChange.send()
                }
            }
        }
        filterDidChange.send()
    }

    func setDateFilter(_ option: DateFilterOption?) {
        tags.removeAll { $0.type == .filterDate }
        selectedDateFilter = option
        if let dateFilter = option {
            let tag = InputTag(
                icon: NSImage(
                    systemSymbolName: "calendar",
                    accessibilityDescription: nil
                ),
                label: dateFilter.displayName,
                type: .filterDate,
                associatedValue: dateFilter.rawValue
            )
            tags.append(tag)
        }
        filterDidChange.send()
    }

    func refreshGroupTags() {
        let validGroupIds = Set(
            chipStore.chips.lazy.filter { !$0.isSystem }.map(\.id)
        )
        selectedGroupIds.formIntersection(validGroupIds)
        tags.removeAll { $0.type == .filterGroup }
        for chip in chipStore.chips where selectedGroupIds.contains(chip.id) {
            addTagForGroup(chip)
        }
        syncSelectedChip()
        filterDidChange.send()
    }

    func toggleGroupFilter(_ groupId: Int) {
        if selectedGroupIds.remove(groupId) != nil {
            tags.removeAll {
                $0.type == .filterGroup
                    && $0.associatedValue == String(groupId)
            }
        } else if let chip = chipStore.chips.first(where: { $0.id == groupId }) {
            selectedGroupIds.insert(groupId)
            addTagForGroup(chip)
        }
        syncSelectedChip(preferredGroupId: groupId)
        filterDidChange.send()
    }

    func addTagForGroup(_ chip: CategoryChip) {
        let tag = InputTag(
            icon: makeColorDotImage(colorIndex: chip.colorIndex),
            label: chip.name,
            type: .filterGroup,
            associatedValue: String(chip.id)
        )
        tags.append(tag)
    }

    func syncSelectedChip(preferredGroupId: Int? = nil) {
        let preferredId = preferredGroupId.flatMap {
            selectedGroupIds.contains($0) ? $0 : nil
        }
        let currentId = selectedGroupIds.contains(chipStore.selectedChipId)
            ? chipStore.selectedChipId
            : nil
        let selectedId = preferredId
            ?? currentId
            ?? chipStore.chips.first { selectedGroupIds.contains($0.id) }?.id
            ?? -1
        if chipStore.selectedChipId != selectedId {
            chipStore.selectedChipId = selectedId
        }
    }

    func makeColorDotImage(colorIndex: Int) -> NSImage {
        CategoryDotRenderer.image(colorIndex: colorIndex)
    }

    func clearAllFilters() {
        selectedTypes.removeAll()
        selectedAppIDs.removeAll()
        selectedDateFilter = nil
        selectedGroupIds.removeAll()
        tags.removeAll()
        if chipStore.selectedChipId != -1 {
            chipStore.selectedChipId = -1
        }
        filterDidChange.send()
    }

    func addTagForType(_ type: PasteModelType) {
        if type == .string || type == .rich {
            let hasTextTag = tags.contains {
                $0.type == .filterType
                    && $0.associatedValue == textTagAssociatedValue
            }
            if !hasTextTag {
                let tag = InputTag(
                    icon: NSImage(
                        systemSymbolName: "doc.text",
                        accessibilityDescription: nil
                    ),
                    label: String(localized: .text),
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        } else {
            let (icon, label) = type.iconAndLabel
            let tag = InputTag(
                icon: NSImage(
                    systemSymbolName: icon,
                    accessibilityDescription: nil
                ),
                label: label,
                type: .filterType,
                associatedValue: type.rawValue
            )
            tags.append(tag)
        }
    }

    func removeTagForType(_ type: PasteModelType) {
        if type == .string || type == .rich {
            let hasString = selectedTypes.contains(.string)
            let hasRich = selectedTypes.contains(.rich)
            if !hasString, !hasRich {
                tags.removeAll {
                    $0.type == .filterType
                        && $0.associatedValue == textTagAssociatedValue
                }
            }
        } else {
            tags.removeAll {
                $0.type == .filterType && $0.associatedValue == type.rawValue
            }
        }
    }

    func removeTag(_ tag: InputTag) {
        tags.removeAll { $0 == tag }

        switch tag.type {
        case .filterType:
            if tag.associatedValue == textTagAssociatedValue {
                selectedTypes.remove(.string)
                selectedTypes.remove(.rich)
            } else if let type = PasteModelType(rawValue: tag.associatedValue) {
                selectedTypes.remove(type)
            }
        case .filterApp:
            if let id = Int64(tag.associatedValue) { selectedAppIDs.remove(id) }
        case .filterDate:
            selectedDateFilter = nil
        case .filterGroup:
            if let groupId = Int(tag.associatedValue) {
                selectedGroupIds.remove(groupId)
            }
            syncSelectedChip()
        }
        filterDidChange.send()
    }

    func removeLastFilter() {
        guard let lastTag = tags.last else { return }
        removeTag(lastTag)
    }

    func toggleTextType() {
        let hasString = selectedTypes.contains(.string)
        let hasRich = selectedTypes.contains(.rich)

        if hasString, hasRich {
            selectedTypes.remove(.string)
            selectedTypes.remove(.rich)
            tags.removeAll {
                $0.type == .filterType
                    && $0.associatedValue == textTagAssociatedValue
            }
        } else {
            let needAddTag = !hasString && !hasRich
            selectedTypes.insert(.string)
            selectedTypes.insert(.rich)
            if needAddTag {
                let tag = InputTag(
                    icon: NSImage(
                        systemSymbolName: "doc.text",
                        accessibilityDescription: nil
                    ),
                    label: String(localized: .text),
                    type: .filterType,
                    associatedValue: textTagAssociatedValue
                )
                tags.append(tag)
            }
        }
        filterDidChange.send()
    }

    func isTextTypeSelected() -> Bool {
        selectedTypes.contains(.string) || selectedTypes.contains(.rich)
    }

}

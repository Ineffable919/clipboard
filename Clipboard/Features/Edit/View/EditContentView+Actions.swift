import AppKit

extension EditContentView {
    // MARK: - JSON Actions

    func setLoading(_ loading: Bool) {
        loadingView.isHidden = !loading
        if loading {
            loadingIndicator.startAnimation(nil)
        } else {
            loadingIndicator.stopAnimation(nil)
        }
    }

    func performJSONAction(_ action: JSONToolAction) {
        guard isLoaded, !jsonEditor.isBusy else { return }
        let target = jsonEditor.transformTarget()
        let replacesDocument = target.range.location == 0
            && target.range.length == (jsonEditor.currentText as NSString).length
        let width = jsonEditor.preparationWidth
        let knownValidity = replacesDocument ? jsonEditor.knownValidity : nil
        transformTask?.cancel()
        jsonAnalysisTask?.cancel()
        jsonEditor.isBusy = true

        transformTask = Task { @MainActor [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                do {
                    return try Result<(JSONDocument, Bool), JSONTransformError>.success(
                        JSONDocument.transform(
                            target.text, action: action, entireDocument: replacesDocument,
                            knownValidity: knownValidity, width: width
                        )
                    )
                } catch let error as JSONTransformError {
                    return .failure(error)
                } catch {
                    return .failure(.invalidJSON)
                }
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            guard let self, !Task.isCancelled else { return }
            defer { jsonEditor.isBusy = false }

            switch result {
            case let .success((document, hasChanges)):
                let changed = hasChanges && jsonEditor.replaceText(
                    document.text, in: target.range, document: document.index,
                    previousText: target.text, preparedText: document.preparedText,
                    knownValidity: document.isValid
                )
                if !changed, statistics == nil {
                    scheduleJSONAnalysis(
                        immediately: true, knownValidity: replacesDocument ? document.isValid : jsonEditor.knownValidity
                    )
                }
                if !changed, let validity = jsonEditor.knownValidity {
                    statisticsBar.setJSONValid(validity)
                }
                jsonEditor.scrollToTop()
            case let .failure(error): showJSONError(error)
            }
        }
    }

    func showJSONError(_ error: JSONTransformError) {
        switch error {
        case let .duplicateKey(key):
            statisticsBar.setError(String(localized: .jsonDuplicateKey(key)))
        case .invalidJSON:
            statisticsBar.setError(String(localized: .jsonTransformFailed))
        case .cancelled:
            scheduleJSONAnalysis(immediately: true, knownValidity: jsonEditor.knownValidity)
        }
    }
}

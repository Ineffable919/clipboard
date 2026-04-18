//
//  SettingViewModel.swift
//  Clipboard
//
//  Created by crown on 2026/4/18.
//

import Foundation
import SwiftUI

@MainActor
@Observable final class SettingViewModel {
    var selectedPage: SettingPage = .general
    
    func navigateTo(_ page: SettingPage) {
        selectedPage = page
    }
}

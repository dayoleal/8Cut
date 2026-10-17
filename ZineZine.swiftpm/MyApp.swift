//
//  MyApp.swift
//  8Cut
//
//  Created by Dayô Araújo on 17/10/26.
//

import SwiftUI

@main
struct MyApp: App {
    @State private var viewModel = AppViewModel(repository: FileZineRepository())

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
        }
    }
}

//
//  TutorApp.swift
//  Tutor
//
//  Created by Martha Heredia Andrade on 16/05/26.
//

import SwiftUI

@main
struct TutorApp: App {
    private let modoTaller: ModoTaller = .demo

    var body: some Scene {
        WindowGroup {
            switch modoTaller {
            case .enVivo:
                VistaEnVivo()
            case .demo:
                VistaDemo()
            }
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}

enum ModoTaller {
    case enVivo
    case demo
}

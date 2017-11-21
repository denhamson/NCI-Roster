// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "NCI-Roster",
    dependencies: [
        .Package(url: "https://github.com/IBM-Swift/Kitura.git", majorVersion: 1, minor: 4),
        .Package(url: "https://github.com/IBM-Swift/Kitura-MustacheTemplateEngine.git", majorVersion: 1, minor: 4),
        .Package(url: "https://github.com/IBM-Swift/Kitura-StencilTemplateEngine.git", majorVersion: 1, minor: 4),
        .Package(url: "https://github.com/IBM-Swift/Kitura-Session.git", majorVersion: 1, minor: 4)
        ])

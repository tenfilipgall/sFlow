import AppKit

if CommandLine.arguments.contains("--analyze") {
    Analyzer.run()
    exit(0)
}

if CommandLine.arguments.contains("--seed") {
    let args = CommandLine.arguments.filter { $0 != "--seed" }
    let bundleId = args.last
    SeedMode.run(bundleIdArg: bundleId)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

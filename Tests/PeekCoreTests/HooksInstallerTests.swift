import Foundation
import Testing

@Suite struct HooksInstallerTests {
    let dir = TestSupport.tempDirectory()
    var settings: URL { dir.appendingPathComponent("settings.json") }

    func run(_ action: String) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-I", TestSupport.repoRoot.appendingPathComponent("scripts/hooks.py").path,
                             action, "--settings", settings.path]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    func read() throws -> NSDictionary {
        try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? NSDictionary)
    }

    func write(_ object: [String: Any]) throws {
        try JSONSerialization.data(withJSONObject: object).write(to: settings)
    }

    @Test func installOnAMissingFileAddsBothHooksAndTheEccSwitch() throws {
        #expect(try run("install") == 0)
        let s = try read()
        #expect((s["env"] as? [String: String])?["ECC_DISABLED_HOOKS"] == "stop:desktop-notify")
        let hooks = try #require(s["hooks"] as? [String: [[String: Any]]])
        #expect(hooks["Stop"]?.count == 1)
        #expect(hooks["Notification"]?.first?["matcher"] as? String == "permission_prompt|elicitation_dialog")
        let command = (hooks["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String
        #expect(command?.contains("$HOME/Applications/Peek.app/Contents/Resources/peek-hook") == true)
    }

    @Test func installTwiceChangesNothing() throws {
        _ = try run("install")
        let first = try read()
        _ = try run("install")
        #expect(try read() == first)
    }

    @Test func installKeepsExistingEccIds() throws {
        try write(["env": ["ECC_DISABLED_HOOKS": "pre:something"]])
        _ = try run("install")
        #expect((try read()["env"] as? [String: String])?["ECC_DISABLED_HOOKS"] == "pre:something,stop:desktop-notify")
    }

    @Test func uninstallRestoresTheOriginal() throws {
        let original: [String: Any] = [
            "model": "opus",
            "env": ["ECC_DISABLED_HOOKS": "pre:something", "OTHER": "1"],
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "echo mine"]]]]],
        ]
        try write(original)
        _ = try run("install")
        _ = try run("uninstall")
        #expect(try read() == original as NSDictionary)
    }

    @Test func existingNonAsciiTextIsWrittenBackLiterally() throws {
        try Data(#"{"note": "local only — no remote database touched"}"#.utf8).write(to: settings)
        _ = try run("install")
        let text = try String(contentsOf: settings, encoding: .utf8)
        #expect(text.contains("local only — no remote database touched"))
        #expect(!text.contains(#"\u2014"#))   // the JSON escape Python writes by default
    }

    @Test func theFileKeepsItsPermissions() throws {
        try write(["model": "opus"])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settings.path)
        _ = try run("install")
        let mode = try FileManager.default.attributesOfItem(atPath: settings.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
    }

    @Test func aBackupIsWrittenBeforeChanging() throws {
        try write(["model": "opus"])
        _ = try run("install")
        let backups = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix("settings.json.peek-backup-") }
        #expect(backups.count == 1)
        let backup = try JSONSerialization.jsonObject(with: Data(contentsOf: dir.appendingPathComponent(backups[0]))) as? NSDictionary
        #expect(backup == ["model": "opus"] as NSDictionary)
    }

    @Test func theGuardedCommandIsHarmlessWithoutTheApp() throws {
        _ = try run("install")
        let hooks = try #require(try read()["hooks"] as? [String: [[String: Any]]])
        let command = try #require((hooks["Stop"]?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.environment = ["HOME": dir.path, "PATH": "/usr/bin:/bin"]   // no Peek.app under this HOME
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func installPathsAgree() throws {
        func text(_ path: String) throws -> String {
            try String(contentsOf: TestSupport.repoRoot.appendingPathComponent(path), encoding: .utf8)
        }
        #expect(try text("scripts/hooks.py").contains("$HOME/Applications/Peek.app/Contents/Resources/peek-hook"))
        #expect(try text("scripts/install.sh").contains("$HOME/Applications/Peek.app"))
        #expect(try text("scripts/build.sh").contains("Contents/Resources/peek-hook"))
    }
}

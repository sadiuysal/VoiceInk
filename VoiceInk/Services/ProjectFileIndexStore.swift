import Foundation
import SwiftData
import os

final class ProjectFileIndexStore: ObservableObject {
	static let shared = ProjectFileIndexStore()

	private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "ProjectFileIndexStore")
	private let fileManager = FileManager.default

	private var modelContainer: ModelContainer?
	@MainActor
	private var modelContext: ModelContext? { modelContainer?.mainContext }

	private init() {
		setupModelContainer()
	}

	private func setupModelContainer() {
		do {
			let schema = Schema([
				IndexedFile.self
			])
			let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, allowsSave: true)
			modelContainer = try ModelContainer(for: schema, configurations: [configuration])
			logger.info("ProjectFileIndexStore initialized")
		} catch {
			logger.error("Failed to init ProjectFileIndexStore: \(error.localizedDescription)")
		}
	}

	// MARK: - Public API

	@MainActor
	func indexProject(at rootURL: URL) async {
		guard let context = modelContext else { return }
		let rootPath = rootURL.path
		let start = Date()

		do {
			let files = try enumerateFilesRecursively(at: rootURL)
			// Clear existing entries for root before re-inserting for a clean slate
			try deleteAll(for: rootPath)
			for file in files { context.insert(file) }
			try context.save()
			logger.info("Indexed \(files.count) files for \(rootURL.lastPathComponent)")
		} catch {
			logger.error("Indexing failed: \(error.localizedDescription)")
		}

		let ms = Int(Date().timeIntervalSince(start) * 1000)
		logger.log("Project file index complete in \(ms)ms")
	}

	@MainActor
	func upsertFile(_ fileURL: URL, rootURL: URL) async {
		guard let context = modelContext else { return }
		let rootPath = rootURL.path + "/"
		guard fileURL.path.hasPrefix(rootPath) else { return }
		let rel = String(fileURL.path.dropFirst(rootPath.count))
		let filename = fileURL.lastPathComponent
		let ext = fileURL.pathExtension.lowercased()
		let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
		if values?.isDirectory == true { return }
		let size = values?.fileSize ?? 0
		let mtime = values?.contentModificationDate ?? Date()
		let tag = inferTag(relPath: rel, filename: filename, ext: ext)

		// Remove any existing matching entry
		let existing = try? context.fetch(FetchDescriptor<IndexedFile>(predicate: #Predicate { $0.rootPath == rootURL.path && $0.relPath == rel }))
		existing?.forEach { context.delete($0) }

		let item = IndexedFile(rootPath: rootURL.path, relPath: rel, filename: filename, ext: ext, byteSize: size, modifiedAt: mtime, tag: tag)
		context.insert(item)
		do { try context.save() } catch {
			logger.error("Failed upsert: \(rel): \(error.localizedDescription)")
		}
	}

	@MainActor
	func deletePath(_ relPath: String, rootPath: String) throws {
		guard let context = modelContext else { return }
		let rows = try context.fetch(FetchDescriptor<IndexedFile>(predicate: #Predicate { $0.rootPath == rootPath && $0.relPath == relPath }))
		rows.forEach { context.delete($0) }
		try context.save()
	}

	@MainActor
	func files(for rootPath: String) -> [IndexedFile] {
		guard let context = modelContext else { return [] }
		let descriptor = FetchDescriptor<IndexedFile>(predicate: #Predicate { $0.rootPath == rootPath }, sortBy: [SortDescriptor(\.relPath)])
		return (try? context.fetch(descriptor)) ?? []
	}

	@MainActor
	func exportFileStructure(rootPath: String) -> String {
		let items = files(for: rootPath)
		var out = ""
		for f in items {
			out += "\(f.relPath) — \(f.tag)\n"
		}
		return out
	}

	// MARK: - Private

	private func enumerateFilesRecursively(at root: URL) throws -> [IndexedFile] {
		let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
		guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: Array(resourceKeys), options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
			throw NSError(domain: "ProjectFileIndexStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enumerator failed"])
		}
		var results: [IndexedFile] = []
		let rootPath = root.path + "/"
		let excludes = defaultExcludes()
		for case let url as URL in enumerator {
			let path = url.path
			if excludes.contains(where: { path.contains($0) }) { enumerator.skipDescendants(); continue }
			let values = try url.resourceValues(forKeys: resourceKeys)
			guard values.isRegularFile == true else { continue }
			let rel = String(path.dropFirst(rootPath.count))
			let filename = url.lastPathComponent
			let ext = url.pathExtension.lowercased()
			let size = values.fileSize ?? 0
			let mtime = values.contentModificationDate ?? Date()
			let tag = inferTag(relPath: rel, filename: filename, ext: ext)
			results.append(IndexedFile(rootPath: root.path, relPath: rel, filename: filename, ext: ext, byteSize: size, modifiedAt: mtime, tag: tag))
		}
		return results.sorted { $0.relPath < $1.relPath }
	}

	private func defaultExcludes() -> [String] {
		return ["/.git/", "/DerivedData/", "/Pods/", "/node_modules/", "/.build/", "/.swiftpm/"]
	}

	private func inferTag(relPath: String, filename: String, ext: String) -> String {
		let lower = relPath.lowercased()
		if lower.contains("/views/") && ext == "swift" { return "SwiftUI view" }
		if lower.contains("/services/") && ext == "swift" { return "Service" }
		if lower.contains("/models/") && ext == "swift" { return "Model" }
		if lower.contains("/whisper/") && ext == "swift" { return "Whisper engine" }
		if lower.contains("/powermode/") && ext == "swift" { return "Power Mode UI/logic" }
		if lower.contains("/resources/") { return "Resource/asset" }
		if filename == "project.pbxproj" { return "Xcode project" }
		if ext == "swift" { return "Swift source" }
		if ext == "md" { return "Markdown doc" }
		if ["json","yml","yaml","toml","plist"].contains(ext) { return "Config" }
		if ["png","jpg","jpeg","gif","wav","mp3"].contains(ext) { return "Asset" }
		return "File"
	}

	@MainActor
	private func deleteAll(for rootPath: String) throws {
		guard let context = modelContext else { return }
		let rows = try context.fetch(FetchDescriptor<IndexedFile>(predicate: #Predicate { $0.rootPath == rootPath }))
		rows.forEach { context.delete($0) }
		try context.save()
	}
}



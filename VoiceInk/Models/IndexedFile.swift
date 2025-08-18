import Foundation
import SwiftData

@Model
final class IndexedFile {
	@Attribute(.unique) var id: UUID
	var rootPath: String
	var relPath: String
	var filename: String
	var ext: String
	var byteSize: Int
	var modifiedAt: Date
	var tag: String

	init(id: UUID = UUID(), rootPath: String, relPath: String, filename: String, ext: String, byteSize: Int, modifiedAt: Date, tag: String) {
		self.id = id
		self.rootPath = rootPath
		self.relPath = relPath
		self.filename = filename
		self.ext = ext
		self.byteSize = byteSize
		self.modifiedAt = modifiedAt
		self.tag = tag
	}
}



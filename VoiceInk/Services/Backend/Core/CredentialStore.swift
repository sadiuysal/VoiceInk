import Foundation
import Security
import os

/// Secure credential storage with project-scoped isolation
@MainActor
public final class CredentialStore: ObservableObject {
    static let shared = CredentialStore()
    
    private let logger = Logger(subsystem: "com.sadiuysal.VoiceInk", category: "CredentialStore")
    private let keychainService = "com.sadiuysal.VoiceInk.credentials"
    
    private init() {}
    
    // MARK: - Credential Management
    
    func storeCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType,
        value: String
    ) throws {
        let key = makeKey(projectId: project.id, sourceType: sourceType, credentialType: credentialType)
        try storeInKeychain(key: key, value: value)
        logger.info("Stored credential for project \(project.name), source \(sourceType)")
    }
    
    func retrieveCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType
    ) throws -> String? {
        let key = makeKey(projectId: project.id, sourceType: sourceType, credentialType: credentialType)
        return try retrieveFromKeychain(key: key)
    }
    
    func removeCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType
    ) throws {
        let key = makeKey(projectId: project.id, sourceType: sourceType, credentialType: credentialType)
        try removeFromKeychain(key: key)
        logger.info("Removed credential for project \(project.name), source \(sourceType)")
    }
    
    func removeAllCredentials(for project: Project) throws {
        let projectPrefix = "project:\(project.id.uuidString)"
        try removeAllKeychainItems(withPrefix: projectPrefix)
        logger.info("Removed all credentials for project \(project.name)")
    }
    
    func hasCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType
    ) -> Bool {
        do {
            let credential = try retrieveCredential(
                for: project,
                sourceType: sourceType,
                credentialType: credentialType
            )
            return credential != nil
        } catch {
            return false
        }
    }
    
    // MARK: - Batch Operations
    
    func storeCredentials(
        for project: Project,
        sourceType: String,
        credentials: [CredentialType: String]
    ) throws {
        for (type, value) in credentials {
            try storeCredential(
                for: project,
                sourceType: sourceType,
                credentialType: type,
                value: value
            )
        }
    }
    
    func retrieveCredentials(
        for project: Project,
        sourceType: String,
        types: [CredentialType]
    ) throws -> [CredentialType: String] {
        var credentials: [CredentialType: String] = [:]
        
        for type in types {
            if let credential = try retrieveCredential(
                for: project,
                sourceType: sourceType,
                credentialType: type
            ) {
                credentials[type] = credential
            }
        }
        
        return credentials
    }
    
    // MARK: - Project Migration
    
    func migrateCredentials(from oldProject: Project, to newProject: Project) throws {
        let sourceTypes = getStoredSourceTypes(for: oldProject)
        
        for sourceType in sourceTypes {
            let credentialTypes = getStoredCredentialTypes(for: oldProject, sourceType: sourceType)
            
            for credentialType in credentialTypes {
                if let credential = try retrieveCredential(
                    for: oldProject,
                    sourceType: sourceType,
                    credentialType: credentialType
                ) {
                    try storeCredential(
                        for: newProject,
                        sourceType: sourceType,
                        credentialType: credentialType,
                        value: credential
                    )
                }
            }
        }
        
        logger.info("Migrated credentials from \(oldProject.name) to \(newProject.name)")
    }
    
    // MARK: - Validation
    
    func validateCredential(
        for project: Project,
        sourceType: String,
        credentialType: CredentialType,
        validator: CredentialValidator
    ) async throws -> CredentialValidationResult {
        guard let credential = try retrieveCredential(
            for: project,
            sourceType: sourceType,
            credentialType: credentialType
        ) else {
            return CredentialValidationResult(
                isValid: false,
                message: "Credential not found"
            )
        }
        
        return try await validator.validate(credential)
    }
    
    // MARK: - Private Methods
    
    private func makeKey(
        projectId: UUID,
        sourceType: String,
        credentialType: CredentialType
    ) -> String {
        return "project:\(projectId.uuidString):source:\(sourceType):credential:\(credentialType.rawValue)"
    }
    
    private func storeInKeychain(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainError(status)
        }
    }
    
    private func retrieveFromKeychain(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw CredentialStoreError.keychainError(status)
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw CredentialStoreError.dataCorruption
        }
        
        return string
    }
    
    private func removeFromKeychain(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychainError(status)
        }
    }
    
    private func removeAllKeychainItems(withPrefix prefix: String) throws {
        let allKeys = try getAllKeychainKeys()
        let keysToRemove = allKeys.filter { $0.hasPrefix(prefix) }
        
        for key in keysToRemove {
            try removeFromKeychain(key: key)
        }
    }
    
    private func getAllKeychainKeys() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw CredentialStoreError.keychainError(status)
        }
        
        guard let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { item in
            item[kSecAttrAccount as String] as? String
        }
    }
    
    private func getStoredSourceTypes(for project: Project) -> [String] {
        let projectPrefix = "project:\(project.id.uuidString):source:"
        
        do {
            let allKeys = try getAllKeychainKeys()
            let projectKeys = allKeys.filter { $0.hasPrefix(projectPrefix) }
            
            let sourceTypes = Set(projectKeys.compactMap { key in
                let components = key.components(separatedBy: ":")
                return components.count > 3 ? components[3] : nil
            })
            
            return Array(sourceTypes)
        } catch {
            logger.error("Failed to get stored source types: \(error.localizedDescription)")
            return []
        }
    }
    
    private func getStoredCredentialTypes(for project: Project, sourceType: String) -> [CredentialType] {
        let sourcePrefix = "project:\(project.id.uuidString):source:\(sourceType):credential:"
        
        do {
            let allKeys = try getAllKeychainKeys()
            let sourceKeys = allKeys.filter { $0.hasPrefix(sourcePrefix) }
            
            let credentialTypes = sourceKeys.compactMap { key in
                let credentialTypeString = String(key.dropFirst(sourcePrefix.count))
                return CredentialType(rawValue: credentialTypeString)
            }
            
            return credentialTypes
        } catch {
            logger.error("Failed to get stored credential types: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Supporting Types

public enum CredentialType: String, CaseIterable, Codable {
    case apiKey = "api_key"
    case accessToken = "access_token"
    case refreshToken = "refresh_token"
    case username = "username"
    case password = "password"
    case githubToken = "github_token"
    case clientId = "client_id"
    case clientSecret = "client_secret"
    case certificate = "certificate"
    case privateKey = "private_key"
    
    var displayName: String {
        switch self {
        case .apiKey: return "API Key"
        case .accessToken: return "Access Token"
        case .refreshToken: return "Refresh Token"
        case .username: return "Username"
        case .password: return "Password"
        case .githubToken: return "GitHub Token"
        case .clientId: return "Client ID"
        case .clientSecret: return "Client Secret"
        case .certificate: return "Certificate"
        case .privateKey: return "Private Key"
        }
    }
    
    var isSecret: Bool {
        switch self {
        case .username, .clientId:
            return false
        default:
            return true
        }
    }
}

public protocol CredentialValidator {
    func validate(_ credential: String) async throws -> CredentialValidationResult
}

public struct CredentialValidationResult {
    public let isValid: Bool
    public let message: String
    public let metadata: [String: String]
    
    public init(isValid: Bool, message: String, metadata: [String: String] = [:]) {
        self.isValid = isValid
        self.message = message
        self.metadata = metadata
    }
}

public enum CredentialStoreError: LocalizedError {
    case keychainError(OSStatus)
    case dataCorruption
    case credentialNotFound
    case invalidCredentialType
    
    public var errorDescription: String? {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .dataCorruption:
            return "Credential data is corrupted"
        case .credentialNotFound:
            return "Credential not found"
        case .invalidCredentialType:
            return "Invalid credential type"
        }
    }
}

// MARK: - Credential Validators

public struct GitHubTokenValidator: CredentialValidator {
    public func validate(_ credential: String) async throws -> CredentialValidationResult {
        guard !credential.isEmpty else {
            return CredentialValidationResult(
                isValid: false,
                message: "Token cannot be empty"
            )
        }
        
        // Basic format validation
        if !credential.hasPrefix("ghp_") && !credential.hasPrefix("github_pat_") {
            return CredentialValidationResult(
                isValid: false,
                message: "Token format appears invalid"
            )
        }
        
        // Test API call
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("token \(credential)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    return CredentialValidationResult(
                        isValid: true,
                        message: "Token is valid",
                        metadata: ["status_code": "200"]
                    )
                } else {
                    return CredentialValidationResult(
                        isValid: false,
                        message: "Token validation failed: HTTP \(httpResponse.statusCode)"
                    )
                }
            }
        } catch {
            return CredentialValidationResult(
                isValid: false,
                message: "Network error during validation: \(error.localizedDescription)"
            )
        }
        
        return CredentialValidationResult(
            isValid: false,
            message: "Unexpected response during validation"
        )
    }
}

public struct BasicAuthValidator: CredentialValidator {
    public func validate(_ credential: String) async throws -> CredentialValidationResult {
        let components = credential.components(separatedBy: ":")
        
        guard components.count == 2 else {
            return CredentialValidationResult(
                isValid: false,
                message: "Basic auth must be in format 'username:password'"
            )
        }
        
        let username = components[0]
        let password = components[1]
        
        guard !username.isEmpty, !password.isEmpty else {
            return CredentialValidationResult(
                isValid: false,
                message: "Username and password cannot be empty"
            )
        }
        
        return CredentialValidationResult(
            isValid: true,
            message: "Credential format is valid"
        )
    }
}
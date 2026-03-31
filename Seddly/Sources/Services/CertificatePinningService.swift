import Foundation
import Security
import CryptoKit
import os

/// Provides a URLSession with public key pinning for supabase.co domains.
/// Uses SPKI (Subject Public Key Info) hash pinning for rotation resilience.
final class CertificatePinningService: NSObject, URLSessionDelegate, Sendable {

    /// Shared pinned URLSession for all Supabase API calls.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: CertificatePinningService(), delegateQueue: nil)
    }()

    /// SHA-256 hashes of the Subject Public Key Info (SPKI) for pinned certificates.
    /// Pins intermediate CAs only — root CA pins are too broad and defeat pinning.
    ///
    /// PIN ROTATION: When Supabase rotates certificates, add the new intermediate
    /// CA SPKI hash here BEFORE the old one expires, then remove the old hash in
    /// a subsequent release. Always maintain at least 2 pins for rotation safety.
    private static let pinnedSPKIHashes: Set<String> = [
        // Primary: Cloudflare Inc ECC CA-3 (intermediate CA used by supabase.co)
        "Lgav0MmkCnG0hpEjGFCnSPq3RE45GdVUqz2dQJfUKOk=",
        // Backup: Google Trust Services GTS CA 1P5 (intermediate CA, rotation resilience)
        "hxqRlPTu1bMS/0DITB1SSu0vd4u/8l8TjPgfaAp63Gc=",
        // Backup: Cloudflare Inc ECC CA-2 (previous intermediate, rotation safety)
        "h6801m+z8v3zbgkRHpq6L29Esgfzhj89C1SyUCOQmqU=",
    ]

    /// The domain to apply pinning to.
    private static let pinnedDomain = "supabase.co"

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              challenge.protectionSpace.host.hasSuffix(Self.pinnedDomain) else {
            return (.performDefaultHandling, nil)
        }

        // Evaluate the server trust against system root certificates
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            AppLogger.network.error("Certificate trust evaluation failed: \(error?.localizedDescription ?? "unknown")")
            return (.cancelAuthenticationChallenge, nil)
        }

        // Check each certificate in the chain for a matching public key pin
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        for index in 0..<certificateCount {
            guard let certificate = SecTrustCopyCertificateChain(serverTrust)?[index] as? SecCertificate else {
                continue
            }

            if let publicKeyHash = spkiHash(for: certificate),
               Self.pinnedSPKIHashes.contains(publicKeyHash) {
                return (.useCredential, URLCredential(trust: serverTrust))
            }
        }

        AppLogger.network.error("Certificate pinning failed for \(challenge.protectionSpace.host): no matching public key pin found")
        return (.cancelAuthenticationChallenge, nil)
    }

    /// Computes the base64-encoded SHA-256 hash of the certificate's Subject Public Key Info.
    private func spkiHash(for certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else { return nil }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        let hash = SHA256.hash(data: publicKeyData)
        return Data(hash).base64EncodedString()
    }
}

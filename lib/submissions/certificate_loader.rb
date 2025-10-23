# frozen_string_literal: true

require 'openssl'
require 'base64'

module Submissions
  # Certificate Loader Module
  #
  # Loads signing certificates from encrypted_configs and converts them to PEM format
  # for use with DSS service multipart API.
  #
  # Usage:
  #   cert_data = CertificateLoader.load_certificate_pem(account)
  #   cert_data[:certificate_pem]  # => PEM-encoded certificate
  #   cert_data[:private_key_pem]  # => PEM-encoded private key
  #   cert_data[:tsa_url]          # => Timestamp Authority URL
  module CertificateLoader
    class << self
      # Loads certificate from database and converts to PEM format
      #
      # @param account [Account] The account to load certificate for
      # @return [Hash, nil] Hash with :certificate_pem, :private_key_pem, :tsa_url or nil if not available
      def load_certificate_pem(account)
        pkcs12 = load_pkcs12(account)
        return nil unless pkcs12

        tsa_url = load_tsa_url(account)
        return nil unless tsa_url

        {
          certificate_pem: extract_certificate_pem(pkcs12),
          private_key_pem: extract_private_key_pem(pkcs12),
          tsa_url: tsa_url
        }
      rescue StandardError => e
        log_error("Failed to load certificate PEM: #{e.message}", e)
        nil
      end

      private

      def load_pkcs12(account)
        # Use the existing Accounts module method to load PKCS12
        return nil unless defined?(Accounts)

        Accounts.load_signing_pkcs(account)
      rescue StandardError => e
        log_error("Failed to load PKCS12: #{e.message}", e)
        nil
      end

      def load_tsa_url(account)
        # Use the existing Accounts module method to load TSA URL
        return nil unless defined?(Accounts)

        url = Accounts.load_timeserver_url(account)
        url.presence || default_tsa_url
      rescue StandardError => e
        log_error("Failed to load TSA URL: #{e.message}", e)
        default_tsa_url
      end

      def default_tsa_url
        # Default to DigiCert timestamp server
        'http://timestamp.digicert.com'
      end

      def extract_certificate_pem(pkcs12)
        # Extract the certificate from PKCS12 and convert to PEM
        certificate = pkcs12.certificate
        certificate.to_pem
      end

      def extract_private_key_pem(pkcs12)
        # Extract the private key from PKCS12 and convert to PEM (unencrypted PKCS#8 format)
        # Note: The PEM private key is NOT password protected - it's sent over
        # HTTPS to the DSS service which is trusted within the same network
        private_key = pkcs12.key

        # Convert RSA private key to PKCS#8 format
        # Build PKCS#8 PrivateKeyInfo structure manually
        require 'base64'

        # Get RSA key in DER format (PKCS#1)
        rsa_der = private_key.to_der

        # Create PKCS#8 structure
        # SEQUENCE {
        #   version INTEGER,
        #   privateKeyAlgorithm AlgorithmIdentifier,
        #   privateKey OCTET STRING
        # }
        asn1_seq = OpenSSL::ASN1::Sequence.new([
          OpenSSL::ASN1::Integer.new(0), # version
          OpenSSL::ASN1::Sequence.new([  # AlgorithmIdentifier
            OpenSSL::ASN1::ObjectId.new('1.2.840.113549.1.1.1'), # RSA OID
            OpenSSL::ASN1::Null.new(nil)
          ]),
          OpenSSL::ASN1::OctetString.new(rsa_der) # privateKey
        ])

        # Convert to DER and then to PEM
        pkcs8_der = asn1_seq.to_der
        pkcs8_pem = "-----BEGIN PRIVATE KEY-----\n"
        pkcs8_pem += Base64.strict_encode64(pkcs8_der).scan(/.{1,64}/).join("\n")
        pkcs8_pem += "\n-----END PRIVATE KEY-----\n"

        pkcs8_pem
      end

      def log_error(message, exception = nil)
        if defined?(Rails)
          Rails.logger.error("[Certificate Loader] #{message}")
          Rails.logger.error(exception.backtrace.join("\n")) if exception
        end

        # Also report to Rollbar if available
        Rollbar.error(exception, message:) if defined?(Rollbar) && exception
      end
    end
  end
end

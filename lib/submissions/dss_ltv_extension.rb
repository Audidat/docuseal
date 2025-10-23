# frozen_string_literal: true

require 'net/http'
require 'uri'
require_relative 'certificate_loader'

module Submissions
  # DSS LTV Extension Module
  #
  # This module integrates with the external DSS (Digital Signature Service) to extend
  # PAdES signatures to LTA (Long Term Archive) level.
  #
  # Configuration:
  #   DSS_SERVICE_URL - URL of the DSS service (default: http://localhost:4000)
  #
  # Usage:
  #   DssLtvExtension.extend_to_lta(pdf_io, account) # => StringIO with LTA-extended PDF or nil on failure
  module DssLtvExtension
    class << self
      # Extends a signed PDF to PAdES-BASELINE-LTA using the DSS service
      #
      # @param io [StringIO] PDF content as StringIO
      # @param account [Account] Account for certificate loading
      # @return [StringIO, nil] Extended PDF as StringIO, or nil if extension fails/disabled
      def extend_to_lta(io, account = nil)
        return nil unless enabled?
        return nil unless io.respond_to?(:string)

        pdf_bytes = io.string
        return nil if pdf_bytes.empty?

        # Load certificate PEM data if account is provided
        cert_data = account ? CertificateLoader.load_certificate_pem(account) : nil

        extended_pdf = if cert_data
                         call_dss_extend_with_cert(pdf_bytes, cert_data)
                       else
                         call_dss_extend_service(pdf_bytes)
                       end

        return nil unless extended_pdf

        StringIO.new(extended_pdf)
      rescue StandardError => e
        log_error("DSS LTV extension failed: #{e.message}", e)
        nil
      end

      private

      def enabled?
        dss_service_url.present?
      end

      def dss_service_url
        @dss_service_url ||= ENV.fetch('DSS_SERVICE_URL', 'http://localhost:4000')
      end

      def call_dss_extend_service(pdf_bytes)
        uri = URI("#{dss_service_url}/api/extend")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 10
        http.read_timeout = 60 # LTA extension can take time (TSA, OCSP, CRL calls)

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/pdf'
        request.body = pdf_bytes

        log_info("Calling DSS extend service at #{uri}")

        response = http.request(request)

        if response.code == '200'
          log_info("DSS extend service succeeded (#{response.body.bytesize} bytes)")
          response.body
        else
          log_error("DSS extend service failed with status #{response.code}: #{response.body}")
          nil
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        log_error("DSS service timeout: #{e.message}", e)
        nil
      rescue StandardError => e
        log_error("DSS service error: #{e.message}", e)
        nil
      end

      def call_dss_extend_with_cert(pdf_bytes, cert_data)
        uri = URI("#{dss_service_url}/api/extend-with-cert")

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = 10
        http.read_timeout = 60 # LTA extension can take time (TSA, OCSP, CRL calls)

        # Create multipart form data
        boundary = "----RubyMultipartBoundary#{SecureRandom.hex(16)}"
        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

        # Build multipart body
        body_parts = []

        # Add PDF file
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"pdf\"; filename=\"document.pdf\"\r\n"
        body_parts << "Content-Type: application/pdf\r\n\r\n"
        body_parts << pdf_bytes
        body_parts << "\r\n"

        # Add certificate PEM
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"certificate_pem\"\r\n\r\n"
        body_parts << cert_data[:certificate_pem]
        body_parts << "\r\n"

        # Add private key PEM
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"private_key_pem\"\r\n\r\n"
        body_parts << cert_data[:private_key_pem]
        body_parts << "\r\n"

        # Add TSA URL
        body_parts << "--#{boundary}\r\n"
        body_parts << "Content-Disposition: form-data; name=\"tsa_url\"\r\n\r\n"
        body_parts << cert_data[:tsa_url]
        body_parts << "\r\n"

        # End boundary
        body_parts << "--#{boundary}--\r\n"

        request.body = body_parts.join

        log_info("Calling DSS extend-with-cert service at #{uri} with database certificate")

        response = http.request(request)

        if response.code == '200'
          log_info("DSS extend-with-cert service succeeded (#{response.body.bytesize} bytes)")
          response.body
        else
          log_error("DSS extend-with-cert service failed with status #{response.code}: #{response.body}")
          nil
        end
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        log_error("DSS service timeout: #{e.message}", e)
        nil
      rescue StandardError => e
        log_error("DSS service error: #{e.message}", e)
        nil
      end

      def log_info(message)
        Rails.logger.info("[DSS LTV Extension] #{message}") if defined?(Rails)
      end

      def log_error(message, exception = nil)
        if defined?(Rails)
          Rails.logger.error("[DSS LTV Extension] #{message}")
          Rails.logger.error(exception.backtrace.join("\n")) if exception
        end

        # Also report to Rollbar if available
        Rollbar.error(exception, message:) if defined?(Rollbar) && exception
      end
    end
  end
end

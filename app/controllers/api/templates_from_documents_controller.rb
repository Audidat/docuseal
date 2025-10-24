# frozen_string_literal: true

module Api
  class TemplatesFromDocumentsController < ApiBaseController
    load_and_authorize_resource :template, parent: false

    def create_from_pdf
      create_template_from_document('pdf')
    end

    def create_from_docx
      create_template_from_document('docx')
    end

    def create_from_html
      create_template_from_html
    end

    private

    def create_template_from_document(format)
      @template.account = current_account
      @template.author = current_user
      @template.name = params[:name] || "API Template #{Time.current.to_i}"

      if params[:folder_name].present?
        @template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      end

      @template.external_id = params[:external_id] if params[:external_id].present?

      Templates.maybe_assign_access(@template)
      @template.save!

      # Handle documents array (for multi-document support)
      documents_params = params[:documents] || [{ file: params[:file], name: params[:name] }]

      files = documents_params.map do |doc|
        file_data = decode_file(doc[:file] || doc['file'])
        filename = (doc[:name] || doc['name'] || "document.#{format}")

        create_uploaded_file(file_data, filename, format)
      end

      # Create attachments
      documents = Templates::CreateAttachments.call(@template, { files: files }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      # Extract fields from documents
      if @template.fields.blank?
        @template.fields = Templates::ProcessDocument.normalize_attachment_fields(@template, documents)
        schema.each { |item| item['pending_fields'] = true } if @template.fields.present?
      end

      @template.update!(schema: schema)

      WebhookUrls.enqueue_events(@template, 'template.created')
      SearchEntries.enqueue_reindex(@template)

      render json: Templates::SerializeForApi.call(@template), status: :created

    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF is encrypted. Please provide an unencrypted PDF.' }, status: :unprocessable_entity
    rescue StandardError => e
      Rollbar.error(e) if defined?(Rollbar)
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def create_template_from_html
      @template.account = current_account
      @template.author = current_user
      @template.name = params[:name] || "HTML Template #{Time.current.to_i}"

      if params[:folder_name].present?
        @template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      end

      @template.external_id = params[:external_id] if params[:external_id].present?

      Templates.maybe_assign_access(@template)
      @template.save!

      html_content = params[:html]

      # Create PDF from HTML
      tempfile = Tempfile.new(['template', '.html'])
      tempfile.write(html_content)
      tempfile.rewind

      file = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: "#{@template.name}.html",
        type: 'text/html'
      )

      documents = Templates::CreateAttachments.call(@template, { files: [file] }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      if @template.fields.blank?
        @template.fields = Templates::ProcessDocument.normalize_attachment_fields(@template, documents)
        schema.each { |item| item['pending_fields'] = true } if @template.fields.present?
      end

      @template.update!(schema: schema)

      WebhookUrls.enqueue_events(@template, 'template.created')
      SearchEntries.enqueue_reindex(@template)

      render json: Templates::SerializeForApi.call(@template), status: :created

    rescue StandardError => e
      Rollbar.error(e) if defined?(Rollbar)
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def decode_file(file_data)
      # Handle base64 or URL
      if file_data.start_with?('http://', 'https://')
        # Download from URL
        DownloadUtils.call(file_data).body
      elsif file_data.include?('base64,')
        # Data URI format: data:application/pdf;base64,JVBERi0xLjQK...
        Base64.decode64(file_data.split(',', 2).last)
      else
        # Raw base64
        Base64.decode64(file_data)
      end
    rescue => e
      raise "Invalid file data: #{e.message}"
    end

    def create_uploaded_file(file_data, filename, format)
      tempfile = Tempfile.new(['upload', ".#{format}"])
      tempfile.binmode
      tempfile.write(file_data)
      tempfile.rewind

      ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: filename,
        type: content_type_for(format)
      )
    end

    def content_type_for(format)
      case format.to_s
      when 'pdf'
        'application/pdf'
      when 'docx'
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      when 'doc'
        'application/msword'
      else
        'application/octet-stream'
      end
    end
  end
end

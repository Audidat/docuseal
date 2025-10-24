# frozen_string_literal: true

module Api
  class SubmissionsFromDocumentsController < ApiBaseController
    before_action only: [:create_from_pdf, :create_from_docx, :create_from_html] do
      authorize!(:create, Submission)
    end

    def create_from_pdf
      create_submission_from_document('pdf')
    end

    def create_from_docx
      create_submission_from_document('docx')
    end

    def create_from_html
      create_submission_from_html_content
    end

    private

    def create_submission_from_document(format)
      # Create temporary template
      template = Template.new(
        account: current_account,
        author: current_user,
        name: params[:name] || "API Submission #{Time.current.to_i}",
        external_id: params[:external_id]
      )

      if params[:folder_name].present?
        template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      end

      Templates.maybe_assign_access(template)
      template.save!

      # Process submitters first to create role→UUID mapping
      submitters_params = params[:submitters]
      role_to_uuid = {}

      if submitters_params.present?
        submitters_params.each do |submitter|
          role = submitter[:role] || submitter['role'] || 'Signer'
          uuid = submitter[:uuid] || submitter['uuid'] || SecureRandom.uuid
          role_to_uuid[role] = uuid
        end
      end

      # Handle documents array (for multi-document support)
      documents_params = params[:documents] || [{ file: params[:file], name: params[:name], fields: params[:fields] }]

      files = []
      doc_fields_map = {}

      documents_params.each_with_index do |doc, index|
        file_data = decode_file(doc[:file] || doc['file'])
        filename = (doc[:name] || doc['name'] || "document#{index + 1}.#{format}")

        uploaded_file = create_uploaded_file(file_data, filename, format)
        files << uploaded_file

        # Store fields for this document to be processed after attachments are created
        if (doc_fields = doc[:fields] || doc['fields'])
          doc_fields_map[index] = doc_fields
        end
      end

      # Create attachments
      documents = Templates::CreateAttachments.call(template, { files: files }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      # Now process fields with attachment UUIDs
      all_fields = []
      doc_fields_map.each do |doc_index, doc_fields|
        attachment_uuid = documents[doc_index]&.uuid
        all_fields += process_fields(doc_fields, doc_index, role_to_uuid, attachment_uuid)
      end

      # Set fields - either provided or extracted from document
      if all_fields.any?
        template.fields = all_fields
      elsif template.fields.blank?
        template.fields = Templates::ProcessDocument.normalize_attachment_fields(template, documents)
      end

      # Set submitters from fields if not provided
      submitters_params = params[:submitters] || extract_submitters_from_fields(template.fields)
      template.submitters = process_submitters(submitters_params, role_to_uuid)

      # Save template with all attributes: schema, fields, and submitters
      template.update!(schema: schema, fields: template.fields, submitters: template.submitters)

      # Create submission from template
      submissions = create_submissions_from_template(template)

      WebhookUrls.enqueue_events(submissions, 'submission.created')
      Submissions.send_signature_requests(submissions)

      submissions.each do |submission|
        submission.submitters.each do |submitter|
          next unless submitter.completed_at?

          ProcessSubmitterCompletionJob.perform_async('submitter_id' => submitter.id, 'send_invitation_email' => false)
        end
      end

      SearchEntries.enqueue_reindex(submissions)

      render json: build_create_json(submissions), status: :created

    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF is encrypted. Please provide an unencrypted PDF.' }, status: :unprocessable_entity
    rescue StandardError => e
      Rollbar.error(e) if defined?(Rollbar)
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def create_submission_from_html_content
      # Create temporary template
      template = Template.new(
        account: current_account,
        author: current_user,
        name: params[:name] || "HTML Submission #{Time.current.to_i}",
        external_id: params[:external_id]
      )

      if params[:folder_name].present?
        template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])
      end

      Templates.maybe_assign_access(template)
      template.save!

      html_content = params[:html]

      # Create file from HTML
      tempfile = Tempfile.new(['submission', '.html'])
      tempfile.write(html_content)
      tempfile.rewind

      file = ActionDispatch::Http::UploadedFile.new(
        tempfile: tempfile,
        filename: "#{template.name}.html",
        type: 'text/html'
      )

      documents = Templates::CreateAttachments.call(template, { files: [file] }, extract_fields: true)
      schema = documents.map { |doc| { attachment_uuid: doc.uuid, name: doc.filename.base } }

      # Extract fields and submitters from HTML
      if template.fields.blank?
        template.fields = Templates::ProcessDocument.normalize_attachment_fields(template, documents)
      end

      submitters_params = params[:submitters] || extract_submitters_from_fields(template.fields)
      template.submitters = process_submitters(submitters_params)

      template.update!(schema: schema)

      # Create submission from template
      submissions = create_submissions_from_template(template)

      WebhookUrls.enqueue_events(submissions, 'submission.created')
      Submissions.send_signature_requests(submissions)

      SearchEntries.enqueue_reindex(submissions)

      render json: build_create_json(submissions), status: :created

    rescue StandardError => e
      Rollbar.error(e) if defined?(Rollbar)
      render json: { error: e.message }, status: :unprocessable_entity
    ensure
      tempfile&.close
      tempfile&.unlink
    end

    def create_submissions_from_template(template)
      submission_params = {
        send_email: params.fetch(:send_email, true),
        send_sms: params.fetch(:send_sms, false),
        order: params[:order] || 'preserved',
        completed_redirect_url: params[:completed_redirect_url],
        bcc_completed: params[:bcc_completed],
        reply_to: params[:reply_to],
        expire_at: params[:expire_at],
        message: params[:message],
        metadata: params[:metadata]
      }.compact

      submitters_data = params[:submitters] || extract_submitters_from_fields(template.fields)

      submissions_attrs, attachments = Submissions::NormalizeParamUtils.normalize_submissions_params!(
        { submitters: submitters_data }.merge(submission_params),
        template
      )

      submissions = Submissions.create_from_submitters(
        template: template,
        user: current_user,
        source: :api,
        submitters_order: submission_params[:order] || 'preserved',
        submissions_attrs: submissions_attrs,
        params: submission_params
      )

      # Force copy template fields and schema to submission for API-created submissions
      submissions.each do |submission|
        if submission.template_fields.blank?
          submission.update!(
            template_fields: submission.template.fields,
            template_schema: submission.template.schema
          )
        end
      end

      submitters = submissions.flat_map(&:submitters)
      Submissions::NormalizeParamUtils.save_default_value_attachments!(attachments, submitters)

      submitters.each do |submitter|
        SubmissionEvents.create_with_tracking_data(submitter, 'api_complete_form', request) if submitter.completed_at?
      end

      submissions
    end

    def build_create_json(submissions)
      json = submissions.flat_map do |submission|
        submission.submitters.map do |s|
          Submitters::SerializeForApi.call(s, with_documents: false, with_urls: true, params: params)
        end
      end

      if submissions.size == 1
        submission = submissions.first.reload
        {
          id: submission.id,
          name: submission.template.name,
          submitters: json,
          created_at: submission.created_at
        }
      else
        { submitters: json }
      end
    end

    def process_fields(fields_array, page_offset = 0, role_to_uuid = {}, attachment_uuid = nil)
      fields_array.map do |field|
        # Get role from field and map it to submitter_uuid
        role = field[:role] || field['role'] || 'Signer'
        submitter_uuid = field[:submitter_uuid] || field['submitter_uuid'] || role_to_uuid[role]

        # If no UUID found for this role, create one and store it
        if submitter_uuid.nil?
          submitter_uuid = SecureRandom.uuid
          role_to_uuid[role] = submitter_uuid
        end

        {
          uuid: field[:uuid] || SecureRandom.uuid,
          submitter_uuid: submitter_uuid,
          name: field[:name] || field['name'],
          type: field[:type] || field['type'],
          required: field.fetch(:required, field.fetch('required', true)),
          readonly: field[:readonly] || field['readonly'],
          default_value: field[:default_value] || field['default_value'],
          title: field[:title] || field['title'],
          description: field[:description] || field['description'],
          attachment_uuid: attachment_uuid,
          areas: [
            {
              attachment_uuid: attachment_uuid,
              page: (field[:page] || field['page'] || 0) + page_offset,
              x: field[:x] || field['x'],
              y: field[:y] || field['y'],
              w: field[:w] || field['w'],
              h: field[:h] || field['h']
            }
          ]
        }
      end
    end

    def process_submitters(submitters_array, role_to_uuid = {})
      submitters_array.map do |submitter|
        role = submitter[:role] || submitter['role'] || 'Signer'

        # Use existing UUID from role_to_uuid map, or create new one
        uuid = submitter[:uuid] || submitter['uuid'] || role_to_uuid[role] || SecureRandom.uuid

        # Store UUID in map for consistency
        role_to_uuid[role] ||= uuid

        {
          uuid: uuid,
          name: role,
          email: submitter[:email] || submitter['email']
        }
      end
    end

    def extract_submitters_from_fields(fields)
      roles = fields.flat_map { |f| f['submitter_uuid'] || [] }.uniq

      if roles.empty?
        [{ role: 'Signer' }]
      else
        roles.map { |role| { role: role } }
      end
    end

    def decode_file(file_data)
      if file_data.start_with?('http://', 'https://')
        DownloadUtils.call(file_data).body
      elsif file_data.include?('base64,')
        Base64.decode64(file_data.split(',', 2).last)
      else
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

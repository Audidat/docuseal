# frozen_string_literal: true

# == Schema Information
#
# Table name: submissions
#
#  id                  :bigint           not null, primary key
#  archived_at         :datetime
#  expire_at           :datetime
#  name                :text
#  preferences         :text             not null
#  slug                :string           not null
#  source              :string           not null
#  submitters_order    :string           not null
#  template_fields     :text
#  template_schema     :text
#  template_submitters :text
#  variables           :text
#  variables_schema    :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  account_id          :bigint           not null
#  created_by_user_id  :bigint
#  template_id         :bigint
#
# Indexes
#
#  index_submissions_on_account_id_and_id                           (account_id,id)
#  index_submissions_on_account_id_and_template_id_and_id           (account_id,template_id,id) WHERE (archived_at IS NULL)
#  index_submissions_on_account_id_and_template_id_and_id_archived  (account_id,template_id,id) WHERE (archived_at IS NOT NULL)
#  index_submissions_on_created_by_user_id                          (created_by_user_id)
#  index_submissions_on_slug                                        (slug) UNIQUE
#  index_submissions_on_template_id                                 (template_id)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_user_id => users.id)
#  fk_rails_...  (template_id => templates.id)
#
FactoryBot.define do
  factory :submission do
    template
    created_by_user factory: %i[user]

    before(:create) do |submission, _|
      submission.account_id = submission.template.account_id
      submission.template_fields = submission.template.fields
      submission.template_schema = submission.template.schema
      submission.template_submitters = submission.template.submitters
    end

    trait :with_submitters do
      after(:create) do |submission, _|
        submission.template_submitters.each do |template_submitter|
          create(:submitter, submission:,
                             account_id: submission.account_id,
                             uuid: template_submitter['uuid'],
                             created_at: submission.created_at)
        end
      end
    end

    trait :with_events do
      after(:create) do |submission, _|
        submission.submitters.each do |submitter|
          create(:submission_event, submission:, submitter:)
        end
      end
    end
  end
end

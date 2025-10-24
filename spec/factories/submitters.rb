# frozen_string_literal: true

# == Schema Information
#
# Table name: submitters
#
#  id            :bigint           not null, primary key
#  completed_at  :datetime
#  declined_at   :datetime
#  email         :string
#  ip            :string
#  metadata      :text             not null
#  name          :string
#  opened_at     :datetime
#  phone         :string
#  preferences   :text             not null
#  sent_at       :datetime
#  slug          :string           not null
#  timezone      :string
#  ua            :string
#  uuid          :string           not null
#  values        :text             not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#  external_id   :string
#  submission_id :bigint           not null
#
# Indexes
#
#  index_submitters_on_account_id_and_id            (account_id,id)
#  index_submitters_on_completed_at_and_account_id  (completed_at,account_id)
#  index_submitters_on_email                        (email)
#  index_submitters_on_external_id                  (external_id)
#  index_submitters_on_slug                         (slug) UNIQUE
#  index_submitters_on_submission_id                (submission_id)
#
# Foreign Keys
#
#  fk_rails_...  (submission_id => submissions.id)
#
FactoryBot.define do
  factory :submitter do
    submission
    email { Faker::Internet.email }
    name { Faker::Name.name }

    before(:create) do |submitter, _|
      submitter.account_id = submitter.submission.account_id
    end
  end
end

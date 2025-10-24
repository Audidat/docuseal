# frozen_string_literal: true

# == Schema Information
#
# Table name: submission_events
#
#  id              :bigint           not null, primary key
#  data            :text             not null
#  event_timestamp :datetime         not null
#  event_type      :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  submission_id   :bigint           not null
#  submitter_id    :bigint
#
# Indexes
#
#  index_submission_events_on_created_at     (created_at)
#  index_submission_events_on_submission_id  (submission_id)
#  index_submission_events_on_submitter_id   (submitter_id)
#
# Foreign Keys
#
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (submitter_id => submitters.id)
#
FactoryBot.define do
  factory :submission_event do
    submission
    submitter
    event_type { 'view_form' }
    event_timestamp { Time.zone.now }
    data do
      {
        ip: Faker::Internet.ip_v4_address,
        ua: Faker::Internet.user_agent,
        sid: SecureRandom.base58(10),
        uid: Faker::Number.number(digits: 4)
      }
    end
  end
end

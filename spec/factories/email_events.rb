# frozen_string_literal: true

# == Schema Information
#
# Table name: email_events
#
#  id             :bigint           not null, primary key
#  data           :text             not null
#  email          :string           not null
#  emailable_type :string           not null
#  event_datetime :datetime         not null
#  event_type     :string           not null
#  tag            :string           not null
#  created_at     :datetime         not null
#  account_id     :bigint           not null
#  emailable_id   :bigint           not null
#  message_id     :string           not null
#
# Indexes
#
#  index_email_events_on_account_id_and_event_datetime  (account_id,event_datetime)
#  index_email_events_on_email                          (email)
#  index_email_events_on_email_event_types              (email) WHERE ((event_type)::text = ANY (ARRAY[('bounce'::character varying)::text, ('soft_bounce'::character varying)::text, ('permanent_bounce'::character varying)::text, ('complaint'::character varying)::text, ('soft_complaint'::character varying)::text]))
#  index_email_events_on_emailable                      (emailable_type,emailable_id)
#  index_email_events_on_message_id                     (message_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :email_event do
    account
    event_type { 'bounce' }
    message_id { SecureRandom.uuid }
    tag { 'submitter_invitation' }
    email { Faker::Internet.email }
    event_datetime { 1.hour.ago }
  end
end

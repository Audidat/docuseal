# frozen_string_literal: true

# == Schema Information
#
# Table name: webhook_urls
#
#  id         :bigint           not null, primary key
#  events     :text             not null
#  secret     :text             not null
#  sha1       :string           not null
#  url        :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_webhook_urls_on_account_id  (account_id)
#  index_webhook_urls_on_sha1        (sha1)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :webhook_url do
    account
    url { Faker::Internet.url }
  end
end

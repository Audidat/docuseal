# frozen_string_literal: true

# == Schema Information
#
# Table name: account_configs
#
#  id         :bigint           not null, primary key
#  key        :string           not null
#  value      :text             not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_account_configs_on_account_id          (account_id)
#  index_account_configs_on_account_id_and_key  (account_id,key) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
FactoryBot.define do
  factory :account_config do
    account
  end
end

# frozen_string_literal: true

# == Schema Information
#
# Table name: template_folders
#
#  id               :bigint           not null, primary key
#  archived_at      :datetime
#  name             :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  author_id        :bigint           not null
#  parent_folder_id :bigint
#
# Indexes
#
#  index_template_folders_on_account_id        (account_id)
#  index_template_folders_on_author_id         (author_id)
#  index_template_folders_on_parent_folder_id  (parent_folder_id)
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (author_id => users.id)
#  fk_rails_...  (parent_folder_id => template_folders.id)
#
FactoryBot.define do
  factory :template_folder do
    account

    author factory: %i[user]
    name { Faker::Book.title }

    trait :with_templates do
      after(:create) do |template_folder|
        create_list(:template, 2, folder: template_folder, account: template_folder.account)
      end
    end
  end
end

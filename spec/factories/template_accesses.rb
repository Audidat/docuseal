# frozen_string_literal: true

# == Schema Information
#
# Table name: template_accesses
#
#  id          :bigint           not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  template_id :bigint           not null
#  user_id     :bigint           not null
#
# Indexes
#
#  index_template_accesses_on_template_id_and_user_id  (template_id,user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (template_id => templates.id)
#
FactoryBot.define do
  factory :template_access do
    template
    user
  end
end

class Campaign < ApplicationRecord
  belongs_to :list

  # This line connects the Campaign to the ActionText table
  has_rich_text :body

  # Basic validations (must be added manually)
  validates :name, :subject, presence: true
end

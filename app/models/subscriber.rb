class Subscriber < ApplicationRecord
  belongs_to :list

  # Validation (must be added manually after scaffold)
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # Critical business rule: scoped uniqueness
  validates :email, uniqueness: { scope: :list_id, message: "is already subscribed to this list" }
end

class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  has_many :lists,     dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :subscribers, through: :lists
end

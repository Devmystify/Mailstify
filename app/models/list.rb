class List < ApplicationRecord
  belongs_to :user

  has_many :subscribers, dependent: :destroy
  has_many :campaigns, dependent: :destroy

  validates :user, presence: true
  validates :name, presence: true
end

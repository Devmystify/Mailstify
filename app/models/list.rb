class List < ApplicationRecord
  has_many :subscribers, dependent: :destroy
  has_many :campaigns, dependent: :destroy
end

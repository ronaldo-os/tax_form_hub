class Recommendation < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :text, presence: true, length: { maximum: 1000 }
end

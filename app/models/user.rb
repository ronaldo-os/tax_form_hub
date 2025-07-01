class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  has_many :tax_submissions
  has_many :companies
  has_many :locations, dependent: :destroy
  has_one_attached :profile_image

  # Enums
  enum role: {
    user: "user",
    superadmin: "superadmin"
  }, _suffix: true

  # Callbacks
  after_initialize :set_default_role, if: :new_record?

  # Methods
  def superadmin?
    role == "superadmin"
  end

  private

  def set_default_role
    self.role ||= "user"
  end
end

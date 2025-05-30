class User < ApplicationRecord
  after_initialize :set_default_role, if: :new_record?
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :tax_submissions


  def set_default_role
    self.role ||= 'user'
  end

  enum role: {
    user: "user",
    superadmin: "superadmin"
  }, _suffix: true

  def superadmin?
    role == "superadmin"
  end
end

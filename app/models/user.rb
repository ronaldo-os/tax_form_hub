class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: {
    user: "user",
    superadmin: "superadmin"
  }, _suffix: true

  def superadmin?
    role == "superadmin"
  end
end

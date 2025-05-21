class User < ApplicationRecord
  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: {
    user: "user",
    superadmin: "superadmin"
  }, _suffix: true
end

class User < ApplicationRecord
  # Virtual attribute for sign-up (not stored in DB)
  attr_accessor :company_name

  # Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  validates :email, format: { 
    with: /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/,
    message: "format is invalid or contains unsupported characters" 
  }


  # Associations
  belongs_to :company, optional: true
  has_many :companies
  has_many :networks, dependent: :destroy
  has_many :connected_companies, through: :networks, source: :company
  has_many :recommendations, dependent: :destroy
  has_many :tax_submissions
  has_many :invoices
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

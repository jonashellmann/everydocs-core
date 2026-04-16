class User < ActiveRecord::Base
  has_secure_password

  has_many :documents
  has_many :folders
  has_many :tags
  has_many :people
  has_many :states

  validates_presence_of :name, :email, :password_digest
  validates :encryption_actived_flag, inclusion: { in: [true, false] }
  validates :secret_key, presence: true, if: :encryption_actived_flag?
  validates :secret_key, format: { with: /\A[0-9a-f]{64}\z/, message: "must be a 64-character hex string" }, allow_nil: true
end

class Group < ActiveRecord::Base
  belongs_to :group

  has_many :users, through: :usergroups
  has_many :documents, through: :documentgroups

  validates_presence_of :name
end

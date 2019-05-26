class Folder < ActiveRecord::Base
  belongs_to :folder

  has_many :documents
end

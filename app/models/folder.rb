class Folder < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user

  has_many :documents
  has_many :folders

	def as_json(_options = {})
  	super include: {
      folders: {
        include: {
          folders: {
            include: {
              folders: {
                include: {
                  folders: {}
                }
              }
            }
          }
        }
      },
		}
	end
end

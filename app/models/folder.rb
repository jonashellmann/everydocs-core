class Folder < ActiveRecord::Base
  belongs_to :folder
  belongs_to :user

  has_many :documents, dependent: :destroy
  has_many :folders, dependent: :destroy

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

class ChangeIndexOnFoldersAgain < ActiveRecord::Migration[7.0]
  def change
    remove_index :folders, name: "index_folders_on_name_and_user_id"
    add_index :folders, [:name, :user_id, :folder_id], unique: true
  end
end

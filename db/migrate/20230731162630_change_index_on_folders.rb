class ChangeIndexOnFolders < ActiveRecord::Migration[7.0]
  def change
    remove_index :folders, name: "index_folders_on_name"
    add_index :folders, [:name, :user_id], unique: true
  end
end

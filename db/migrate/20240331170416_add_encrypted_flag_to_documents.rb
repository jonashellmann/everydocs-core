class AddEncryptedFlagToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :encrypted_flag, :boolean, default: false
  end
end

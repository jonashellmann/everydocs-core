class AddSecretKeyToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :secret_key, :string, default: nil
    add_column :users, :encryption_actived_flag, :boolean, default: false
  end
end

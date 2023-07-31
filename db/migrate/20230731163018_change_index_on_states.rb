class ChangeIndexOnStates < ActiveRecord::Migration[7.0]
  def change
    remove_index :states, name: "index_states_on_name"
    add_index :states, [:name, :user_id], unique: true
  end
end

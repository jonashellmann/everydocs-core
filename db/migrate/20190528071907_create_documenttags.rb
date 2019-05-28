class CreateDocumenttags < ActiveRecord::Migration
  def change
    create_table :documenttags do |t|
      t.references :document, index: true, foreign_key: true
      t.references :tag, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end

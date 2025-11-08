class CreateCallLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :call_logs do |t|
      t.references :phone_number, null: false, foreign_key: true
      t.string :status
      t.text :message
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end

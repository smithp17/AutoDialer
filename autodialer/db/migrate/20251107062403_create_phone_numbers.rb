class CreatePhoneNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :phone_numbers do |t|
      t.string :number
      t.string :status
      t.string :call_sid
      t.integer :duration
      t.datetime :called_at

      t.timestamps
    end
  end
end

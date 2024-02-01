class MakeSetupNameCaseSensitiveAndAddIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :setups, [:name, :user_id], unique: true
  end
end

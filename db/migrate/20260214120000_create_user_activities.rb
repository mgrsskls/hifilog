# frozen_string_literal: true

class CreateUserActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :verb, null: false
      t.datetime :occurred_at, null: false
      t.references :subject, polymorphic: true, null: false
      t.jsonb :metadata, null: false, default: {}
      t.datetime :hidden_at

      t.timestamps
    end

    add_index :user_activities, [:user_id, :occurred_at], order: { occurred_at: :desc }
    add_index :user_activities, [:user_id, :subject_type, :subject_id, :verb], name: 'index_user_activities_on_user_subject_verb'
    add_index :user_activities, :hidden_at
  end
end

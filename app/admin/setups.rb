ActiveAdmin.register Setup do
  permit_params :name, :user_id, :private

  remove_filter :setup_possessions
  remove_filter :possessions
  remove_filter :name
  remove_filter :private
end

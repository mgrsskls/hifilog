ActiveAdmin.register AppNews do
  permit_params :text

  remove_filter :text
  remove_filter :users
end

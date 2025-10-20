ActiveAdmin.register Event do
  permit_params :name, :url, :address, :country_code, :start_date, :end_date
end

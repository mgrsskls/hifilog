ActiveAdmin.register Event do
  permit_params :name, :url, :address, :country_code, :start_date, :end_date


  controller do
    def find_resource
      scoped_collection.friendly.find(params[:id])
    end

    def show
      @event = Event.friendly.find(params[:id])
      show! #it seems to need this
    end
  end
end

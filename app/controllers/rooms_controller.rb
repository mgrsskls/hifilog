class RoomsController < ApplicationController
  before_action :authenticate_user!

  add_breadcrumb "Hifi Gear", :root_path
  add_breadcrumb I18n.t("dashboard")
  add_breadcrumb I18n.t("headings.rooms"), :dashboard_rooms_path

  def index
    @active_menu = :dashboard
    @active_dashboard_menu = :rooms
    @rooms = current_user.rooms.sort_by{|c| c[:name].downcase}
  end

  def show
    @active_menu = :dashboard
    @active_dashboard_menu = :rooms
    @room = Room.find(params[:id])
    add_breadcrumb @room.name, dashboard_room_path(@room)
  end

  def create
    @room = Room.new(room_params)

    if @room.save
      current_user.rooms << @room
      flash[:notice] = "The room <a href=" + dashboard_room_path(@room) + ">" + @room.name + "</a> has been created."
      redirect_to dashboard_rooms_path
    else
      @active_menu = :dashboard
      @active_dashboard_menu = :rooms
      @rooms = current_user.rooms.sort_by{|c| c[:name].downcase}
      flash[:alert] = "An error occured. Please try again."
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @room = Room.find(params[:id])
    @room.destroy!
    flash[:notice] = "The room <b>" + @room.name + "</b> has been deleted."
    redirect_to dashboard_rooms_path
  end

  private

  def room_params
    params.require(:room).permit(:name)
  end
end

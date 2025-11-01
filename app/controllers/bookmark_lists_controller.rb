class BookmarkListsController < InheritedResources::Base
  include Bookmarks

  before_action :authenticate_user!
  before_action :set_menu

  def new
    @bookmark_list = BookmarkList.new

    @page_title = I18n.t('bookmark_list.new.heading')
  end

  def edit
    @bookmark_list = current_user.bookmark_lists.find(params[:id])

    @page_title = "#{t('edit')} #{@bookmark_list.name}"
  end

  def create
    @bookmark_list = BookmarkList.new(bookmark_list_params)
    @bookmark_list.user = current_user

    if @bookmark_list.save
      flash[:notice] = I18n.t(
        'bookmark_list.messages.created',
        link: ActionController::Base.helpers.link_to(@bookmark_list.name, dashboard_bookmark_list_path(@bookmark_list))
      )
      redirect_to dashboard_bookmark_list_path(@bookmark_list)
    else
      @active_dashboard_menu = :bookmarks
      render :new, status: :unprocessable_content
    end
  end

  def update
    @bookmark_list = current_user.bookmark_lists.find(params[:id])
    @active_dashboard_menu = :bookmarks

    if @bookmark_list.update(bookmark_list_params)
      flash[:notice] = I18n.t(
        'bookmark_list.messages.updated',
        name: @bookmark_list.name
      )
      redirect_to dashboard_bookmark_list_path(@bookmark_list)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @bookmark_list = current_user.bookmark_lists.find(params[:id])
    @bookmark_list.destroy
    flash[:notice] = I18n.t('bookmark_list.messages.deleted', name: @bookmark_list.name)
    redirect_to dashboard_bookmarks_path
  end

  private

  def set_menu
    @active_dashboard_menu = :bookmarks
    @active_menu = :dashboard
  end

  def bookmark_list_params
    params.expect(bookmark_list: [:name, { bookmark_ids: [] }])
  end
end

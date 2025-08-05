class BookmarkListsController < InheritedResources::Base
  include Bookmarks

  before_action :authenticate_user!
  before_action :set_menu

  def show
    @bookmark_list = current_user.bookmark_lists.find(params[:id])

    @page_title = Bookmark.model_name.human(count: 2)
    @active_dashboard_menu = :bookmarks

    @all_bookmarks = current_user.bookmarks
                                 .includes([product: [:brand]])
                                 .includes([:product_variant])
                                 .includes([:bookmark_list])
                                 .order(['brand.name', 'LOWER(products.name)'])
                                 .map { |bookmark| BookmarkPresenter.new(bookmark) }

    all_bookmarks_in_list = current_user.bookmarks
                                        .where(bookmark_list_id: @bookmark_list.id)
                                        .includes([product: [{ sub_categories: :category }, :brand]])
                                        .includes([:product_variant])

    bookmarks = all_bookmarks_in_list

    if params[:category].present?
      sub_cat = SubCategory.friendly.find(params[:category])

      if sub_cat
        bookmarks = bookmarks.where({ product: { products_sub_categories: { sub_category_id: sub_cat.id } } })
                             .order(['brand.name', 'LOWER(product.name)'])
        @sub_category = sub_cat
      else
        bookmarks = bookmarks.order(['brand.name', 'LOWER(products.name)'])
      end
    else
      bookmarks = bookmarks.order(['brand.name', 'LOWER(products.name)'])
    end

    @bookmarks = bookmarks.map { |bookmark| BookmarkPresenter.new(bookmark) }

    @categories = get_grouped_sub_categories(bookmarks: all_bookmarks_in_list)
  end

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
      @bookmark_lists = current_user.bookmark_lists.order('LOWER(name)')
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

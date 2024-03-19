class NotesController < ApplicationController
  before_action :authenticate_user!

  def index
    @active_menu = :dashboard
    @active_dashboard_menu = :notes
    @notes = current_user.notes.order('updated_at DESC, created_at DESC')
    @page_title = I18n.t('headings.notes')
  end

  def show
    @active_menu = :dashboard
    @active_dashboard_menu = :notes

    @note = current_user.notes.find(params[:id])
    markdown = Redcarpet::Markdown.new(
      Redcarpet::Render::HTML.new,
      tables: true,
      strikethrough: true,
      superscript: true
    )
    @html = markdown.render(@note.text)
    @product = Product.find(@note.product_id)
    @product_variant = ProductVariant.find(@note.product_variant_id) if @note.product_variant_id.present?

    display_name = @product_variant.present? ? @product_variant.display_name : @product.display_name
    add_breadcrumb I18n.t('dashboard'), dashboard_root_path
    add_breadcrumb I18n.t('headings.notes'), dashboard_notes_path
    add_breadcrumb display_name
    @page_title = "#{I18n.t('headings.notes')} — #{display_name}"
  end

  def new
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:variant]) if params[:variant].present?

    @note = current_user.notes.find_by(
      product_id: @product.id,
      product_variant_id: (@product_variant.id if @product_variant.present?)
    )

    display_name = @product_variant.present? ? @product_variant.display_name : @product.display_name
    add_breadcrumb I18n.t('headings.products'), products_path
    add_breadcrumb display_name, @product_variant.present? ? product_variant_path(
      product_id: @product.friendly_id,
      variant: @product_variant.friendly_id
    ) : product_path(id: @product.friendly_id)
    add_breadcrumb 'Notes'
    @page_title = "Notes — #{display_name}"
  end

  def create
    note = Note.new(note_params)
    note.user = current_user

    if note.save
      flash[:notice] = 'Success'
      redirect_back fallback_location: root_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @note = current_user.notes.find(params[:id])
    @note.update(note_params)

    if @note.save
      flash[:notice] = 'Success'
      redirect_back fallback_location: root_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @note = current_user.notes.find(params[:id])

    flash[:alert] = 'The note could not be deleted.' unless @note.destroy

    redirect_to dashboard_notes_path
  end

  private

  def note_params
    params.require(:note).permit(:text, :product_id, :product_variant_id)
  end
end

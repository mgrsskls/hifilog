class NotesController < ApplicationController
  include ActionView::Helpers::SanitizeHelper

  before_action :authenticate_user!

  def index
    @active_menu = :dashboard
    @active_dashboard_menu = :notes
    @notes = current_user.notes.order('updated_at DESC, created_at DESC')
    @page_title = Note.model_name.human(count: 2)
  end

  def show
    @active_menu = :dashboard
    @active_dashboard_menu = :notes

    @note = current_user.notes.find(params[:id])
    @html = sanitize(
      Commonmarker.to_html(
        @note.text,
        options: {
          extension: {
            strikethrough: false,
            tagfilter: false,
            table: false,
            autolink: false,
            tasklist: false,
          }
        }
      ),
      tags: %w[p b i strong em br ul ol li del blockquote]
    )
    @product = Product.find(@note.product_id)
    @product_variant = ProductVariant.find(@note.product_variant_id) if @note.product_variant_id.present?

    display_name = @product_variant.present? ? @product_variant.display_name : @product.display_name
    @page_title = "#{Note.model_name.human(count: 2)} — #{display_name}"
  end

  def new
    @product = Product.friendly.find(params[:product_id])
    @product_variant = @product.product_variants.friendly.find(params[:id]) if params[:id].present?

    @note = current_user.notes.find_by(
      product_id: @product.id,
      product_variant_id: (@product_variant.id if @product_variant.present?)
    )

    display_name = @product_variant.present? ? @product_variant.display_name : @product.display_name
    @page_title = "Notes — #{display_name}"
  end

  def create
    @note = Note.new(note_params)
    @note.user = current_user

    save_note
  end

  def update
    @note = current_user.notes.find(params[:id])
    @note.update(note_params)

    save_note
  end

  def destroy
    @note = current_user.notes.find(params[:id])

    flash[:alert] = I18n.t('note.messages.delete_failed') unless @note.destroy

    redirect_to dashboard_notes_path
  end

  private

  def save_note
    @product = @note.product
    @product_variant = @note.product_variant

    if @note.save
      flash[:notice] = I18n.t('note.messages.saved')

      if @product_variant.present?
        redirect_back fallback_location: product_new_variant_notes_url(
          product_id: @product.friendly_id,
          id: @product_variant.friendly_id
        )
      else
        redirect_back fallback_location: product_new_notes_url(product_id: @product.friendly_id)
      end
    else
      @note.errors.each do |error|
        flash.now[:alert] = error.full_message
      end
      render :new, status: :unprocessable_entity
    end
  end

  def note_params
    params.expect(note: [:text, :product_id, :product_variant_id])
  end
end

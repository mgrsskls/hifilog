module FilterableService
  extend ActiveSupport::Concern
  include FilterConstants

  def apply_letter_filter(scope, params, column)
    return scope if params[:letter].blank?

    downcase = params[:letter].downcase

    return scope unless ABC.include?(downcase)

    scope.where("left(lower(#{column}),1) = ?", downcase)
  end
end

module HistoryHelper
  def get_history_possessions(possessions)
    all = possessions.where.not(period_from: nil)
                     .or(possessions.where.not(period_to: nil))
                     .includes([{ product: [:brand] }])
                     .includes(
                       [
                         { product_variant: [
                           { product: [
                             :brand
                           ] }
                         ] }
                       ]
                     )
                     .includes(
                       [
                         { custom_product:
                           [
                             { images_attachments: :blob }
                           ] }
                       ]
                     )
                     .includes([{ images_attachments: :blob }])
                     .includes([:product_option])

    from = all.reject { |possession| possession.period_from.nil? }.map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_from,
        type: :from,
        presenter:
      }
    end

    to = all.reject { |possession| possession.period_to.nil? }.map do |possession|
      presenter = if possession.custom_product_id
                    CustomProductPossessionPresenter.new(possession)
                  else
                    PossessionPresenter.new(possession)
                  end

      {
        date: presenter.period_to,
        type: :to,
        presenter:
      }
    end

    (from + to).sort_by { |possession| possession[:date] }
               .group_by { |possession| possession[:date].year }
  end
end

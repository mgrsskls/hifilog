# frozen_string_literal: true

module Contributions
  extend ActiveSupport::Concern

  private

  def version_group_count(data, model, event)
    data[[model, event]] || 0
  end
end

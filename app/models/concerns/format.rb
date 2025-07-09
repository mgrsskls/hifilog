module Format
  include FormatHelper
  extend ActiveSupport::Concern

  def formatted_release_date
    format_partial_date(release_year, release_month, release_day)
  end

  def formatted_founded_date
    format_partial_date(founded_year, founded_month, founded_day)
  end

  def formatted_discontinued_date
    format_partial_date(discontinued_year, discontinued_month, discontinued_day)
  end
end

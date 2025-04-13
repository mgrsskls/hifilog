module Format
  include FormatHelper
  extend ActiveSupport::Concern

  def formatted_release_date
    format_partial_date(release_day, release_month, release_year)
  end

  def formatted_founded_date
    format_partial_date(founded_day, founded_month, founded_year)
  end

  def formatted_discontinued_date
    format_partial_date(discontinued_day, discontinued_month, discontinued_year)
  end
end

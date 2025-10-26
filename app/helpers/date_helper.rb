module DateHelper
  def humanize_date_range(start_date, end_date = nil)
    return start_date.strftime('%B %-d, %Y') unless end_date

    if start_date.year != end_date.year
      # different years
      "#{start_date.strftime('%B %-d, %Y')} – #{end_date.strftime('%B %-d, %Y')}"
    elsif start_date.month != end_date.month
      # same year, different months
      "#{start_date.strftime('%B %-d')} – #{end_date.strftime('%B %-d, %Y')}"
    elsif start_date.day != end_date.day
      # same month, same year, different days
      "#{start_date.strftime('%B %-d')}–#{end_date.strftime('%-d, %Y')}"
    else
      start_date.strftime('%B %-d, %Y')
    end
  end
end

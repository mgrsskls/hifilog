# frozen_string_literal: true

# Shared building blocks for the <meta name="description"> copy of catalog entities.
#
# A description written by a contributor always wins. When an entry has none — which is the
# common case, most catalog entries carry no description at all — we assemble a sentence from
# whatever structured data the entry does have (dates, price, categories, country), so that a
# thin entry still produces something specific instead of a near-identical stub shared by
# every product in its category.
module MetaDescription
  extend ActiveSupport::Concern

  # Search engines typically render 150-160 characters; 200 leaves room without producing
  # copy that is mostly cut off. Matches the length the catalog used before.
  META_DESC_LENGTH = 200

  private

  def truncate_meta(text)
    ActionController::Base.helpers.truncate(
      text.to_s.squish,
      length: META_DESC_LENGTH,
      separator: ' ',
      escape: false
    )
  end

  # Joins the sentences that are present, in priority order, then truncates once.
  def meta_sentences(*sentences)
    truncate_meta(sentences.compact_blank.join(' '))
  end

  def meta_lifecycle_sentence
    if release_year.present? && discontinued_year.present?
      "Released in #{release_year}, discontinued in #{discontinued_year}."
    elsif release_year.present?
      "Released in #{release_year}."
    elsif discontinued_year.present?
      "Discontinued in #{discontinued_year}."
    end
  end

  def meta_maker
    return brand.name if brand.country_code.blank?

    "#{brand.name} from #{brand.country_name}"
  end

  def meta_subject(*parts)
    parts.compact_blank.join(' ')
  end
end

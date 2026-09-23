# frozen_string_literal: true

# Links from the entry forms into the contribution guidelines page (/contribute/guidelines).
#
# Each key is one section of the page. The page uses the dasherized key as the id of the section
# (:brand_abbreviation -> #brand-abbreviation). The ids stay the same when the sections get new
# numbers, so old links in comments and forms stay correct. Do not rename a key.
#
# GuidelinesHelperTest checks that the page has an element for each key. An unknown key raises,
# so a form that links to a removed section fails in its test.
module GuidelinesHelper
  GUIDELINE_SECTIONS = [
    :scope, :sources, :duplicates, :partial, :comments, :language, :objectivity, :conduct,
    :brand_name, :brand_abbreviation, :brand_legal_name, :brand_details, :brand_categories,
    :brand_ownership, :product_or_version, :product_name, :product_categories, :product_series,
    :initial_release, :dates, :price, :diy_kit, :versions, :options, :series, :specifications,
    :descriptions, :changelog
  ].freeze

  # The link to info@hifilog.com. All characters are HTML entities, so that simple spam bots
  # do not find the address in the page source. Use this link for each link to the address.
  # rubocop:disable Layout/LineLength
  CONTACT_EMAIL_LINK = '<a href="&#77;&#97;&#105;&#76;&#84;&#79;&#58;&#105;&#110;&#102;&#111;&#64;&#104;&#105;&#102;&#105;&#108;&#111;&#103;&#46;&#99;&#111;&#109;">&#105;&#110;&#102;&#111;&#64;&#104;&#105;&#102;&#105;&#108;&#111;&#103;&#46;&#99;&#111;&#109;</a>'
  # rubocop:enable Layout/LineLength

  def contact_email_link
    CONTACT_EMAIL_LINK.html_safe # rubocop:disable Rails/OutputSafety -- constant, no user input
  end

  def guideline_anchor(section)
    raise ArgumentError, "Unknown guideline section: #{section}" unless GUIDELINE_SECTIONS.include?(section)

    section.to_s.dasherize
  end

  def guideline_path(section)
    contribute_guidelines_path(anchor: guideline_anchor(section))
  end

  # Small "?" link next to a form field. The accessible name tells what the link is about,
  # because "?" alone has no meaning for a screen reader.
  def guideline_link(section, label)
    link_to '?', guideline_path(section),
            class: 'GuidelineLink',
            target: '_blank',
            title: t('guidelines.link_title', label:),
            'aria-label': t('guidelines.link_title', label:), rel: 'noopener'
  end
end

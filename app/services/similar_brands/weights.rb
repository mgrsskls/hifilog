# frozen_string_literal: true

# Tuning values for the "Similar Brands" block. See README, section "Similar Brands".
#
# When you change a value, also increase SimilarBrands::CACHE_VERSION. If you do not, cached lists
# keep the old order until they expire.
#
# The score of a candidate brand is the sum of these parts:
#
#   1. Sub category profile: SUB_CATEGORY_WEIGHT * sum of min(share of the brand, share of the
#      candidate) over the sub categories of the brand. A share is the part of the products of a
#      brand in one sub category.
#   2. Active period:        PERIOD_WEIGHT * shared years / all years of both brands
#   3. Country:              COUNTRY_WEIGHT when both brands are from the same country
#   4. Price level:          PRICE_WEIGHT for the same band of the median product price, half of
#                            it for the next band. Same currency only.
#   5. Attributes:           for each attribute in ATTRIBUTES: weight * the part of the products
#                            of the candidate that have the most frequent value of the brand
#
# A missing value on one side gives 0 points. It does not give a penalty.
module SimilarBrands::Weights
  SUB_CATEGORY_WEIGHT = 100
  PERIOD_WEIGHT = 20
  COUNTRY_WEIGHT = 15
  PRICE_WEIGHT = 10
  # The same bands as for products: approximately x3 wide.
  PRICE_BAND_WIDTH = SimilarProducts::Weights::PRICE_BAND_WIDTH

  # The same weights as for products. Numeric classes are not used for brands.
  ATTRIBUTES = SimilarProducts::Weights::ATTRIBUTES

  # Candidates with a lower score are not shown. The value is low on purpose.
  MIN_SCORE = 10
end

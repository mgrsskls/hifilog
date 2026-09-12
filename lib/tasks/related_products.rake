# frozen_string_literal: true

# Verifies the authored pairing graph against a real catalogue. See
# RelatedProducts::GraphCheck for why this cannot be caught by the test suite alone.
#
#   bin/rails related_products:check
#
# Exits non-zero on any problem, so it can sit in a deploy step.
namespace :related_products do
  desc 'Check the Related Products graph against this database'
  task check: :environment do
    result = RelatedProducts::GraphCheck.call

    result.notes.each { |note| puts "note: #{note}" }

    if result.problems.any?
      warn "\nRelated Products graph problems:"
      result.problems.each { |problem| warn "  - #{problem}" }
      abort "\n#{result.problems.size} problem(s) found."
    end

    graph = RelatedProducts::Graph
    puts "Related Products graph OK: #{graph::ROLES.size} roles, #{graph.every_edge.size} edges, " \
         "#{SubCategory.count} sub categories all assigned."
  end
end

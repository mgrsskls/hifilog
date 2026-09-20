"""Tests for the parts of the importer that must not change silently.

The network and the language model are not tested here. What is tested is what
happens to their answers: the checks that keep a wrong or invented value out of
the catalogue. Those checks are the reason this pipeline can be trusted, so
each has a test that fails if it is removed.
"""

import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from hifilog_import.candidates import Candidate, Provenance
from hifilog_import.discover import (
    locale_prefix,
    normalise_url,
    prefer_canonical,
    score_url,
    urls_from_sitemap,
)
from hifilog_import import classify as classifier
from hifilog_import import platform as platform_module
from hifilog_import.extract_markup import (
    availability_says_current,
    apply_markup,
    apply_shopify_product,
    apply_woocommerce_product,
    apply_squarespace_item,
    page_text,
)
from hifilog_import.extract_text import Schema, apply_text_extraction, parse_answer
from hifilog_import import validations as validations_module
from hifilog_import.scope import OtherBrands, condition, out_of_scope
from hifilog_import.normalize import (
    dedupe_key,
    strip_site_suffix,
    parse_price,
    parse_year,
    reduce_model,
    shop_state,
    sku_is_the_model,
)

FIXTURES = Path(__file__).resolve().parent / "fixtures"
# A small schema of its own, not the exported one: the export is generated and
# gitignored, and a test must not depend on a file that a clone does not have.
SCHEMA = Schema.load(Path(__file__).resolve().parent / "fixtures" / "product_schema.json")


def fixture(name):
    return (FIXTURES / name).read_text(encoding="utf-8")


class MarkupTest(unittest.TestCase):
    def test_reads_a_schema_org_product(self):
        candidate = Candidate("acme-audio", "https://acme.test/products/aria-5")
        found = apply_markup(candidate, fixture("shopify_product.html"), candidate.source_url)
        self.assertTrue(found)
        self.assertEqual(candidate.name, "Aria 5")
        self.assertEqual(candidate.price, 2499.0)
        self.assertEqual(candidate.price_currency, "EUR")
        self.assertEqual(candidate.model_no, "ACM-ARIA5")
        self.assertEqual(candidate.provenance["price"].source, "jsonld")

    def test_in_stock_means_the_product_is_not_discontinued(self):
        """A product the brand's own shop sells today is still made.

        The opposite is not read: see DiscontinuedTest, where out of stock
        leaves the field empty because nothing in the data separates "sold out
        until Thursday" from "gone for ever".
        """
        candidate = Candidate("acme-audio", "https://acme.test/products/aria-5")
        apply_markup(candidate, fixture("shopify_product.html"), candidate.source_url)
        self.assertFalse(candidate.discontinued)

    def test_a_page_without_markup_gives_only_a_title(self):
        candidate = Candidate("acme-audio", "https://acme.test/model-88")
        found = apply_markup(candidate, fixture("plain_product.html"), candidate.source_url)
        self.assertFalse(found)
        self.assertEqual(candidate.name, "Model 88 Integrated Amplifier")
        self.assertIsNone(candidate.price)

    def test_page_text_drops_scripts(self):
        text = page_text(fixture("shopify_product.html"))
        self.assertIn("Sensitivity 90 dB", text)
        self.assertNotIn("schema.org", text)


class RealMarkupTest(unittest.TestCase):
    """What a real manufacturer page does, which a clean example does not."""

    def setUp(self):
        self.candidate = Candidate("cambridge-audio", "https://example.test/cxa81-mkii")
        apply_markup(self.candidate, fixture("real_cambridge_shape.html"), self.candidate.source_url)

    def test_version_words_do_not_become_part_of_the_name(self):
        self.assertEqual(self.candidate.name, "CXA81 MKII")
        self.assertEqual(self.candidate.variant_name, "Black UK/EU")

    def test_a_price_of_zero_is_not_a_price(self):
        self.assertIsNone(self.candidate.price)
        self.assertIsNone(self.candidate.price_currency)

    def test_an_article_number_per_version_is_not_the_model_number(self):
        self.assertIsNone(self.candidate.model_no)

    def test_discontinued_is_read_from_availability(self):
        self.assertTrue(self.candidate.discontinued)

    def test_an_image_url_may_be_a_list(self):
        self.assertEqual(len(self.candidate.image_urls), 2)


class HandBuiltSiteTest(unittest.TestCase):
    """A page that states nothing in machine readable form.

    The markup step can only guess the name from the page title, and on this
    page the title holds the company name as well. The guess is therefore
    written with a low confidence, so that the text extractor replaces it. If
    the confidence order is ever turned round, this test fails.
    """

    def setUp(self):
        self.html = fixture("real_plain_shape.html")
        self.page = page_text(self.html)
        self.candidate = Candidate("accuphase", "https://example.test/model/e-4000")
        self.found = apply_markup(self.candidate, self.html, self.candidate.source_url)

    def test_no_product_object_is_found(self):
        self.assertFalse(self.found)
        self.assertEqual(self.candidate.provenance["name"].source, "heuristic")

    def test_the_text_extractor_replaces_the_guessed_name(self):
        answer = {
            "is_product": True,
            "name": "E-4000",
            "sub_category_slug": "integrated-amplifiers",
            "attributes": {"amplifier_output_power": {"ohm_8": 180, "ohm_4": 260}},
            "evidence": {
                "name": "E-4000",
                "sub_category_slug": "INTEGRATED STEREO AMPLIFIER",
                "amplifier_output_power": "180 watts into 8 ohms / 260 watts into 4 ohms",
            },
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertEqual(self.candidate.name, "E-4000")
        self.assertEqual(self.candidate.sub_category_slug, "integrated-amplifiers")
        self.assertEqual(
            self.candidate.custom_attributes["amplifier_output_power"],
            {"value": {"ohm_8": 180.0, "ohm_4": 260.0}, "unit": "w"},
        )

    def test_a_price_is_not_invented_for_a_page_that_has_none(self):
        answer = {
            "is_product": True,
            "name": "E-4000",
            "price": 9500,
            "evidence": {"name": "E-4000", "price": "9,500 EUR"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertIsNone(self.candidate.price)


class BetterSourceWinsTest(unittest.TestCase):
    def test_markup_is_not_overwritten_by_text(self):
        candidate = Candidate("acme-audio", "u")
        candidate.set("name", "Aria 5", Provenance("jsonld", "u"))
        candidate.set("name", "Aria 5 Loudspeaker", Provenance("llm", "u"))
        self.assertEqual(candidate.name, "Aria 5")

    def test_text_fills_what_markup_left_empty(self):
        candidate = Candidate("acme-audio", "u")
        candidate.set("price", 2499.0, Provenance("llm", "u"))
        self.assertEqual(candidate.price, 2499.0)


class EvidenceTest(unittest.TestCase):
    """A value must be quoted from the page, or it is dropped."""

    def setUp(self):
        self.page = page_text(fixture("plain_product.html"))
        self.candidate = Candidate("acme-audio", "https://acme.test/model-88")

    def test_accepts_a_value_that_the_page_states(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "release_year": 1994,
            "sub_category_slug": "integrated-amplifiers",
            "evidence": {
                "name": "Model 88",
                "release_year": "was introduced in 1994",
                "sub_category_slug": "Model 88 integrated amplifier",
            },
        }
        self.assertTrue(
            apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        )
        self.assertEqual(self.candidate.release_year, 1994)

    def test_drops_a_value_that_is_not_on_the_page(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "release_year": 1988,
            "evidence": {"name": "Model 88", "release_year": "released in 1988"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertIsNone(self.candidate.release_year)
        self.assertTrue(self.candidate.warnings)

    def test_evidence_may_be_broken_over_lines(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "price": "3450",
            "evidence": {"name": "Model 88", "price": "Price\n €3.450,00"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertEqual(self.candidate.price, 3450.0)

    def test_a_list_page_is_refused(self):
        candidate = Candidate("acme-audio", "https://acme.test/loudspeakers")
        answer = {"is_product": False}
        self.assertFalse(
            apply_text_extraction(candidate, answer, fixture("category_page.html"), "u", SCHEMA)
        )


class SchemaLimitsTest(unittest.TestCase):
    def setUp(self):
        self.page = page_text(fixture("plain_product.html"))
        self.candidate = Candidate("acme-audio", "https://acme.test/model-88")

    def test_an_unknown_sub_category_is_refused(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "sub_category_slug": "valve-amplifiers",
            "evidence": {"name": "Model 88"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertIsNone(self.candidate.sub_category_slug)

    def test_an_option_is_stored_as_its_id(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "attributes": {"input_connectors": ["rca", "xlr", "bluetooth"]},
            "evidence": {"name": "Model 88", "input_connectors": "4 x RCA, 1 x XLR"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertEqual(self.candidate.custom_attributes["input_connectors"], ["1", "2"])

    def test_a_number_keeps_its_unit_and_inputs(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "attributes": {"amplifier_output_power": {"ohm_8": 88}},
            "evidence": {"name": "Model 88", "amplifier_output_power": "88 watts per channel into 8 ohms"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertEqual(
            self.candidate.custom_attributes["amplifier_output_power"],
            {"value": {"ohm_8": 88.0}, "unit": "w"},
        )

    def test_an_unknown_attribute_is_refused(self):
        answer = {
            "is_product": True,
            "name": "Model 88",
            "attributes": {"thd": 0.01},
            "evidence": {"name": "Model 88", "thd": "0.01"},
        }
        apply_text_extraction(self.candidate, answer, self.page, "u", SCHEMA)
        self.assertEqual(self.candidate.custom_attributes, {})


class PlatformTest(unittest.TestCase):
    """Which builder a site uses, and whether that means product data."""

    def test_each_builder_is_recognised(self):
        cases = {
            "shopify": '<script>var Shopify={};Shopify.theme=1</script>',
            "squarespace": '<link href="https://static1.squarespace.com/a.css">',
            "wix": '<script src="https://static.parastorage.com/x.js"></script>',
            "woocommerce": '<link href="/wp-content/plugins/woocommerce/a.css">',
            "wordpress": '<link href="/wp-content/themes/a/style.css">',
            "webflow": '<script src="https://assets.website-files.com/a.js"></script>',
        }
        for expected, html in cases.items():
            self.assertEqual(platform_module.detect(html), expected, expected)

    def test_a_shop_on_wordpress_reads_as_the_shop(self):
        html = '<link href="/wp-content/plugins/woocommerce/a.css"><link href="/wp-includes/b.css">'
        self.assertEqual(platform_module.detect(html), "woocommerce")

    def test_a_hand_built_site_is_unknown(self):
        self.assertEqual(platform_module.detect("<html><body>Hi</body></html>"), "unknown")

    def test_the_builder_alone_does_not_mean_product_data(self):
        """A brochure site on a shop builder carries no product object."""
        brochure = '<link href="https://static1.squarespace.com/a.css"><h1>Our speakers</h1>'
        self.assertEqual(platform_module.detect(brochure), "squarespace")
        self.assertFalse(platform_module.has_shop(brochure))
        self.assertFalse(platform_module.has_product_markup(brochure))

    def test_product_markup_is_found_only_for_a_product(self):
        self.assertTrue(platform_module.has_product_markup(fixture("shopify_product.html")))
        self.assertFalse(platform_module.has_product_markup(fixture("plain_product.html")))

    def test_a_wix_product_url_is_a_product_url(self):
        home = "https://acme.test"
        self.assertGreaterEqual(score_url(home + "/product-page/aria-5", home), 2)


class ShopifyCatalogTest(unittest.TestCase):
    """A Shopify shop is read as a catalogue rather than crawled."""

    PRODUCT = {
        "title": "Aria 5 Walnut",
        "handle": "aria-5",
        "body_html": "<p>A <b>three way</b> speaker.</p>",
        "product_type": "Loudspeakers",
        "variants": [
            {"title": "Walnut", "sku": "ARIA5-WAL", "price": "2499.00"},
            {"title": "Black", "sku": "ARIA5-BLK", "price": "2399.00"},
        ],
        "images": [{"src": "https://images.test/1.jpg"}],
    }

    def setUp(self):
        self.candidate = Candidate("acme-audio", "https://acme.test/products/aria-5")
        apply_shopify_product(
            self.candidate, self.PRODUCT, "https://acme.test/products.json", "EUR"
        )

    def test_the_catalogue_gives_name_and_price(self):
        self.assertEqual(self.candidate.name, "Aria 5")
        self.assertEqual(self.candidate.variant_name, "Walnut")
        self.assertEqual(self.candidate.price, 2399.0)

    def test_the_shop_text_is_not_taken_as_the_description(self):
        """The description of a catalogue product is written by people."""
        data = json.loads(self.candidate.to_json())
        self.assertNotIn("description", data)
        self.assertNotIn("description", data["provenance"])

    def test_no_extractor_can_set_a_description(self):
        self.candidate.set("description", "Marketing copy.", Provenance("jsonld", "u", "x"))
        self.assertNotIn("description", json.loads(self.candidate.to_json()))

    def test_the_currency_comes_from_the_shop_not_from_the_catalogue(self):
        """products.json carries a price and no currency."""
        self.assertEqual(self.candidate.price_currency, "EUR")
        bare = Candidate("acme-audio", "u")
        apply_shopify_product(bare, self.PRODUCT, "u", None)
        self.assertIsNone(bare.price_currency)

    def test_the_shops_own_category_is_kept_apart(self):
        self.assertEqual(self.candidate.source_category, "Loudspeakers")
        self.assertIsNone(self.candidate.sub_category_slug)

    def test_every_version_is_carried_for_the_review(self):
        self.assertEqual(len(self.candidate.variants), 2)
        self.assertIsNone(self.candidate.model_no)

    def test_one_version_means_the_article_number_is_the_products(self):
        product = dict(self.PRODUCT)
        product["variants"] = [{"title": "Default", "sku": "ARIA5", "price": "2499.00"}]
        candidate = Candidate("acme-audio", "u")
        apply_shopify_product(candidate, product, "u", "EUR")
        self.assertEqual(candidate.model_no, "ARIA5")

    def test_the_shops_currency_is_read_from_a_page(self):
        html = '<script>var Shopify = {}; Shopify.currency = {"active":"GBP","rate":"1.0"};</script>'
        self.assertEqual(platform_module.shopify_currency(html), "GBP")
        self.assertIsNone(platform_module.shopify_currency("<html>nothing</html>"))


class SquarespaceTest(unittest.TestCase):
    """The data behind a Squarespace page, which its markup leaves out."""

    ITEM = {
        "title": "Reference Two Walnut",
        "body": "<p>A two way monitor.</p>",
        "assetUrl": "https://images.test/1.jpg",
        "structuredContent": {
            "productType": 2,
            "variants": [{"sku": "REF2-WAL", "priceMoney": {"value": "4200.00", "currency": "EUR"}}],
        },
    }

    def test_only_products_are_taken_from_a_collection(self):
        text = json.dumps({"items": [self.ITEM, {"title": "A blog post"}]})
        self.assertEqual(len(platform_module.parse_squarespace(text)), 1)

    def test_a_single_page_answers_with_one_item(self):
        text = json.dumps({"item": self.ITEM})
        self.assertEqual(len(platform_module.parse_squarespace(text)), 1)

    def test_the_item_gives_the_name_and_the_price(self):
        candidate = Candidate("acme-audio", "https://acme.test/shop/reference-two")
        apply_squarespace_item(candidate, self.ITEM, candidate.source_url)
        self.assertEqual(candidate.name, "Reference Two")
        self.assertEqual(candidate.variant_name, "Walnut")
        self.assertEqual(candidate.price, 4200.0)
        self.assertEqual(candidate.price_currency, "EUR")

    def test_an_article_number_that_carries_the_finish_is_not_the_model(self):
        """REF2-WAL is the shop's number for the walnut one, not the model."""
        candidate = Candidate("acme-audio", "u")
        apply_squarespace_item(candidate, self.ITEM, "u")

        self.assertIsNone(candidate.model_no)

    def test_an_article_number_that_is_the_model_is_kept(self):
        item = dict(self.ITEM)
        item["title"] = "REF-2 Walnut"
        item["structuredContent"] = {
            "productType": 2,
            "variants": [{"sku": "REF2", "priceMoney": {"value": "4200.00", "currency": "EUR"}}],
        }
        candidate = Candidate("acme-audio", "u")
        apply_squarespace_item(candidate, item, "u")

        self.assertEqual(candidate.model_no, "REF2")

    def test_an_article_number_per_variant_is_not_the_model_number(self):
        item = dict(self.ITEM)
        item["structuredContent"] = {
            "productType": 2,
            "variants": [
                {"sku": "REF2-WAL", "priceMoney": {"value": "4200.00", "currency": "EUR"}},
                {"sku": "REF2-OAK", "priceMoney": {"value": "4200.00", "currency": "EUR"}},
            ],
        }
        candidate = Candidate("acme-audio", "u")
        apply_squarespace_item(candidate, item, "u")
        self.assertIsNone(candidate.model_no)
        self.assertEqual(candidate.price, 4200.0)

    def test_markup_is_not_overwritten_by_the_twin(self):
        candidate = Candidate("acme-audio", "u")
        candidate.set("name", "Reference Two", Provenance("jsonld", "u"))
        apply_squarespace_item(candidate, self.ITEM, "u")
        self.assertEqual(candidate.name, "Reference Two")


class SiteNameInProductNameTest(unittest.TestCase):
    """Squarespace writes the site title into the name of every product.

    All 277 products of the first Squarespace sample came back as
    "<product> em-dash <brand>".
    """

    def test_the_brand_is_taken_off_the_end(self):
        self.assertEqual(
            strip_site_suffix("Acoustical Systems HELOX record clamp \u2014 Artisan Fidelity",
                              "Artisan Fidelity"),
            "Acoustical Systems HELOX record clamp",
        )
        self.assertEqual(strip_site_suffix("Aeolus | ZMF Headphones", "ZMF Headphones"), "Aeolus")

    def test_only_the_brand_is_taken_off(self):
        self.assertEqual(strip_site_suffix("Planar 3 - Walnut", "Rega"), "Planar 3 - Walnut")

    def test_a_name_that_begins_with_the_brand_is_untouched(self):
        self.assertEqual(strip_site_suffix("Rega Planar 3", "Rega"), "Rega Planar 3")

    def test_no_brand_name_means_no_change(self):
        self.assertEqual(strip_site_suffix("Aeolus \u2014 ZMF", None), "Aeolus \u2014 ZMF")


class DiscoveryTest(unittest.TestCase):
    def test_a_product_url_scores_above_a_blog_url(self):
        home = "https://acme.test"
        self.assertGreaterEqual(score_url(home + "/products/aria-5", home), 2)
        self.assertEqual(score_url(home + "/blog/how-we-build", home), -1)
        self.assertEqual(score_url("https://other.test/products/x", home), -1)

    def test_a_list_page_is_not_a_product_page(self):
        """Learnt from a real crawl: a Shopify collection page carries a Product
        object for the first product on it, so nothing later would catch it."""
        home = "https://acme.test"
        self.assertEqual(score_url(home + "/collections/floorstanders", home), -1)
        self.assertGreaterEqual(score_url(home + "/collections/x/products/aria-5", home), 2)
        self.assertEqual(score_url(home + "/pages/about-us", home), -1)

    def test_a_page_of_an_older_site_keeps_its_extension_out_of_the_comparison(self):
        home = "https://acme.test"
        self.assertEqual(score_url(home + "/support.html", home), -1)
        self.assertLess(score_url(home + "/power_amp.html", home), 2)
        self.assertGreaterEqual(score_url(home + "/model/e-4000", home), 2)

    def test_only_one_language_of_one_product_is_crawled(self):
        kept = prefer_canonical([
            "https://acme.test/products/aria-5",
            "https://acme.test/en-mx/products/aria-5",
            "https://acme.test/fr/products/aria-5",
            "https://acme.test/es-mx/products/model-88",
            "https://acme.test/fr/products/model-88",
        ])
        self.assertIn("https://acme.test/products/aria-5", kept)
        self.assertNotIn("https://acme.test/en-mx/products/aria-5", kept)
        self.assertEqual(len(kept), 2)

    def test_a_product_name_is_not_read_as_a_language(self):
        self.assertIsNone(locale_prefix("/model/e-4000"))
        self.assertIsNone(locale_prefix("/products/x"))
        self.assertEqual(locale_prefix("/en-mx/products/x"), "en-mx")

    def test_a_forum_on_the_brands_own_site_is_refused(self):
        """One Wix site listed 1298 forum archive pages in its sitemap."""
        home = "https://acme.test"
        self.assertEqual(score_url(home + "/group/forum-archive/discussion", home), -1)
        self.assertEqual(score_url(home + "/post/2016-1-11-todays-tunes", home), -1)

    def test_a_builders_own_content_path_is_refused(self):
        """One sample sitemap held 434 /content/ URLs out of 461."""
        home = "https://acme.test"
        self.assertEqual(score_url(home + "/content/v1/abc123/image.jpg", home), -1)

    def test_a_sitemap_index_is_not_read_as_pages(self):
        pages, sitemaps = urls_from_sitemap(
            '<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            "<sitemap><loc>https://acme.test/s1.xml</loc></sitemap></sitemapindex>"
        )
        self.assertEqual(pages, [])
        self.assertEqual(sitemaps, ["https://acme.test/s1.xml"])

    def test_tracking_parameters_do_not_make_a_second_page(self):
        self.assertEqual(
            normalise_url("https://ACME.test/products/aria-5/?utm_source=x#specs"),
            "https://acme.test/products/aria-5",
        )


class NormalizeTest(unittest.TestCase):
    def test_revisions_reduce_to_one_form(self):
        self.assertEqual(reduce_model("CXA81 MkII"), reduce_model("cxa81mkii"))
        self.assertEqual(reduce_model("Mark 2"), reduce_model("MkII"))

    def test_the_brand_name_in_a_product_name_is_ignored(self):
        self.assertEqual(dedupe_key("rega", None, "Rega Planar 3"), dedupe_key("rega", None, "Planar 3"))

    def test_both_decimal_separators(self):
        self.assertEqual(parse_price("€1.299,00"), 1299.0)
        self.assertEqual(parse_price("$1,299.00"), 1299.0)
        self.assertEqual(parse_price("1299"), 1299.0)

    def test_a_year_outside_the_possible_range_is_refused(self):
        self.assertIsNone(parse_year("3000"))
        self.assertEqual(parse_year("introduced in 1977"), 1977)


class DiscontinuedTest(unittest.TestCase):
    """What a shop's availability does and does not say.

    One direction is safe: a product the brand's own shop sells today is not
    discontinued. The other is not: out of stock can mean sold out until
    Thursday, or gone for ever, and nothing in the data separates those.
    """

    def test_on_sale_means_not_discontinued(self):
        self.assertFalse(availability_says_current("https://schema.org/InStock"))
        self.assertFalse(availability_says_current("https://schema.org/BackOrder"))

    def test_only_an_explicit_statement_means_discontinued(self):
        self.assertTrue(availability_says_current("https://schema.org/Discontinued"))

    def test_out_of_stock_says_nothing(self):
        self.assertIsNone(availability_says_current("https://schema.org/OutOfStock"))
        self.assertIsNone(availability_says_current("https://schema.org/SoldOut"))
        self.assertIsNone(availability_says_current(None))

    def test_a_shopify_variant_that_can_be_bought(self):
        product = {
            "title": "Aria 5", "handle": "aria-5",
            "variants": [{"title": "Default", "price": "2499.00", "available": True}],
        }
        candidate = Candidate("acme-audio", "u")
        apply_shopify_product(candidate, product, "u", "EUR")

        self.assertFalse(candidate.discontinued)

    def test_a_shopify_product_with_nothing_in_stock_says_nothing(self):
        product = {
            "title": "Aria 5", "handle": "aria-5",
            "variants": [{"title": "Default", "price": "2499.00", "available": False}],
        }
        candidate = Candidate("acme-audio", "u")
        apply_shopify_product(candidate, product, "u", "EUR")

        self.assertIsNone(candidate.discontinued)

    def test_a_woocommerce_product_that_can_be_bought(self):
        product = {
            "name": "CS-55A", "sku": "CS55A", "is_purchasable": True, "is_in_stock": True,
            "prices": {"price": "345000", "currency_code": "EUR", "currency_minor_unit": 2},
        }
        candidate = Candidate("cayin", "u")
        apply_woocommerce_product(candidate, product, "u", "Cayin")

        self.assertFalse(candidate.discontinued)

    def test_a_woocommerce_product_that_cannot_says_nothing(self):
        product = {"name": "CS-55A", "is_purchasable": False, "is_in_stock": False}
        candidate = Candidate("cayin", "u")
        apply_woocommerce_product(candidate, product, "u", "Cayin")

        self.assertIsNone(candidate.discontinued)

    def test_a_squarespace_variant_with_stock(self):
        item = {
            "title": "Reference Two",
            "structuredContent": {
                "productType": 2,
                "variants": [{"sku": "REF2", "qtyInStock": 3,
                              "priceMoney": {"value": "4200.00", "currency": "EUR"}}],
            },
        }
        candidate = Candidate("acme-audio", "u")
        apply_squarespace_item(candidate, item, "u")

        self.assertFalse(candidate.discontinued)

    def test_the_cambridge_page_still_reads_as_discontinued(self):
        """The real page states schema.org/Discontinued on every offer."""
        candidate = Candidate("cambridge-audio", "u")
        apply_markup(candidate, fixture("real_cambridge_shape.html"), "u", "Cambridge Audio")

        self.assertTrue(candidate.discontinued)


class ClassifierTest(unittest.TestCase):
    """What comes back from the classifier, before any of it is believed."""

    ITEMS = [
        {"brand": "KEF", "brand_slug": "kef", "source_category": "Passive HiFi Speakers",
         "name": "LS50 Meta"},
        {"brand": "Koss", "brand_slug": "koss", "source_category": "Cushions",
         "name": "Porta Pro Cushions"},
    ]
    KNOWN = {"bookshelf-standmount-loudspeakers", "subwoofers", "in-wall-loudspeakers"}

    def clean(self, payload):
        return classifier.clean_results(classifier.parse_answer(payload), self.ITEMS, self.KNOWN)

    def test_a_slug_this_catalogue_defines_is_kept(self):
        results = self.clean('{"results": [{"id": 0, "slugs": ["bookshelf-standmount-loudspeakers"]}]}')

        self.assertEqual(results[0]["slugs"], ["bookshelf-standmount-loudspeakers"])

    def test_a_slug_it_does_not_define_is_dropped(self):
        results = self.clean('{"results": [{"id": 0, "slugs": ["standmounts", "loudspeakers"]}]}')

        self.assertEqual(results[0]["slugs"], [])

    def test_a_product_may_be_two_things(self):
        results = self.clean(
            '{"results": [{"id": 0, "slugs": ["subwoofers", "in-wall-loudspeakers"]}]}'
        )

        self.assertEqual(len(results[0]["slugs"]), 2)

    def test_an_id_that_names_no_product_of_the_batch_is_dropped(self):
        results = self.clean('{"results": [{"id": 9, "slugs": ["subwoofers"]}]}')

        self.assertEqual(results, {})

    def test_out_of_scope_is_carried(self):
        results = self.clean('{"results": [{"id": 1, "slugs": [], "out_of_scope": true}]}')

        self.assertTrue(results[1]["out_of_scope"])

    def test_an_answer_wrapped_in_a_code_fence(self):
        results = self.clean('```json\n{"results": [{"id": 0, "slugs": ["subwoofers"]}]}\n```')

        self.assertEqual(results[0]["slugs"], ["subwoofers"])

    def test_an_unreadable_answer_is_empty_rather_than_an_error(self):
        self.assertEqual(self.clean("I could not classify these."), {})

    def test_the_same_product_has_the_same_key_and_a_changed_one_does_not(self):
        first = classifier.cache_key(self.ITEMS[0])

        self.assertEqual(first, classifier.cache_key(dict(self.ITEMS[0])))
        self.assertNotEqual(first, classifier.cache_key({**self.ITEMS[0], "name": "LS60"}))

    def test_the_prompt_carries_the_products_and_the_slugs(self):
        prompt = classifier.build_prompt(
            self.ITEMS,
            [{"slug": "subwoofers", "name": "Subwoofers", "category": "Loudspeakers"}],
        )

        self.assertIn("LS50 Meta", prompt)
        self.assertIn("subwoofers", prompt)
        self.assertIn("Passive HiFi Speakers", prompt)


class ScopeTest(unittest.TestCase):
    """What a shop sells that this catalogue does not hold.

    Every example here is a real item from the first run over 128 shops.
    """

    def test_a_service_is_refused(self):
        self.assertEqual(
            out_of_scope("Tier 5 Care Plan Service Items", "Repair Service"),
            "a service, not a product",
        )

    def test_a_gift_card_is_refused(self):
        self.assertEqual(out_of_scope("Gift Card"), "a payment, not a product")

    def test_a_record_is_refused_but_a_record_player_is_not(self):
        self.assertEqual(out_of_scope("Kind of Blue", "Vinyl LP"), "a recording, not equipment")
        self.assertIsNone(out_of_scope("Planar 3", "Turntables"))

    def test_a_product_is_not_refused(self):
        self.assertIsNone(out_of_scope("MACARIA Birch", "Loudspeakers"))
        self.assertIsNone(out_of_scope("Model 88 Integrated Amplifier"))

    def test_a_whole_word_is_needed(self):
        """"used" must not match "unused", and "cap" must not match "capacitor"."""
        self.assertIsNone(condition("Unused Demo Stock Cable"), )
        self.assertIsNone(out_of_scope("Capacitor upgrade board"))

    def test_the_address_is_read_when_the_name_says_nothing(self):
        """A real case: a deposit listed under the product's own name."""
        self.assertIsNone(out_of_scope("ZMC2"))
        self.assertEqual(
            out_of_scope("ZMC2", None, "https://decware.test/product-page/10-deposit-zmc2"),
            "a payment, not a product",
        )

    def test_the_host_cannot_refuse_a_product(self):
        self.assertIsNone(out_of_scope("Aria 5", None, "https://gift-card-audio.test/products/aria-5"))

    def test_a_car_range_of_a_hi_fi_brand_is_refused(self):
        """These two brands made 15 of the 59 errors in 430 hand checks."""
        self.assertIsNone(out_of_scope('15" Subwoofer', "Subwoofer"))
        self.assertIn(
            "car", out_of_scope("SWS-8X Under-the-Seat", "Subwoofer", None, "earthquake")
        )

    def test_the_home_ranges_of_the_same_brand_are_kept(self):
        self.assertIsNone(out_of_scope("MiniMe DSP P8", "Subwoofer", None, "earthquake"))

    def test_a_brand_set_aside_is_left_out_whole(self):
        self.assertEqual(
            out_of_scope("SL Series 15 inch Floor Speaker", "Speaker", None, "cerwin-vega"),
            "brand set aside for now",
        )

    def test_earthquake_tnt_is_car_audio(self):
        self.assertIn("car", out_of_scope("TNT-12DVC Subwoofer", "Subwoofer", None, "earthquake"))
        self.assertIn("car", out_of_scope("Tremor-X12D4 Subwoofer", "Subwoofer", None, "earthquake"))

    def test_dj_cartridges_are_refused(self):
        self.assertIn("DJ", out_of_scope("Concorde MKII Scratch", "Phono Cartridges", None, "ortofon"))
        self.assertIn("DJ", out_of_scope("OM Q.bert", "Phono Cartridges", None, "ortofon"))
        self.assertIsNone(out_of_scope("Concorde Music", "Phono Cartridges", None, "ortofon"))
        self.assertIn("DJ", out_of_scope("OM PRO S premounted", "Phono Cartridges", None, "ortofon"))
        self.assertIn("DJ", out_of_scope("VNL TRIX", "Phono Cartridges", None, "ortofon"))
        self.assertIn("DJ", out_of_scope("DJ200i", "Cartridges", None, "grado-labs"))
        self.assertIsNone(out_of_scope("Debut PRO S", "Plattenspieler", None, "pro-ject"))
        self.assertIsNone(out_of_scope("2M Black", "Phono Cartridges", None, "ortofon"))

    def test_a_range_name_means_nothing_outside_its_brand(self):
        self.assertIsNone(out_of_scope("Stroker Reference", "Speakers", None, "some-other-brand"))

    def test_a_condition_is_reported_apart_from_a_refusal(self):
        self.assertIsNone(out_of_scope("B-stock - Duo", "B-Stock"))
        self.assertEqual(condition("B-stock - Duo", "B-Stock"), "b-stock")
        self.assertEqual(condition("SB-2000 Pro", "Subwoofer Outlet"), "outlet")
        self.assertEqual(condition("A6000 (アウトレット品)", "有線イヤホン"), "アウトレット")
        self.assertEqual(condition("T4 4-Drivers IEM 50$Off StockSales (4PCS Limited)"), "stocksales")
        self.assertEqual(condition("Factory Renewed DRD-1 Differential Reference DAC"), "factory renewed")
        self.assertEqual(condition("VTF-TN1 Subwoofer (C Stock)"), "c stock")



class OtherBrandsTest(unittest.TestCase):
    """A shop that sells the products of other brands."""

    def setUp(self):
        self.brands = OtherBrands([
            ("summit-hi-fi", "Summit Hi-Fi"), ("nad", "NAD"),
            ("michell", "Michell Engineering"), ("ojas", "Ojas"), ("denon", "Denon"),
            ("wireworld", "Wireworld Cable Technology"), ("eclipse", "Eclipse"),
            ("o-audio", "Ø Audio"), ("moon", "Moon"), ("simaudio", "Moon by Simaudio"),
            ("tonewinner", "ToneWinner"), ("psb-speakers", "PSB Speakers"),
        ])

    def test_a_product_named_after_another_brand_is_found(self):
        self.assertEqual(self.brands.of("NAD C 558", "summit-hi-fi"), "nad")
        self.assertEqual(
            self.brands.of("Michell Engineering Revolv Turntable", "summit-hi-fi"), "michell"
        )

    def test_spacing_and_a_trailing_speakers_do_not_matter(self):
        self.assertEqual(self.brands.of("TONE WINNER SW-1000", "summit-hi-fi"), "tonewinner")
        self.assertEqual(self.brands.of("PSB B600 Premium Bookshelf", "summit-hi-fi"), "psb-speakers")

    def test_the_own_brand_is_not_another_brand(self):
        self.assertIsNone(self.brands.of("NAD C 558", "nad"))
        self.assertIsNone(self.brands.of("MOON 888", "simaudio"))

    def test_the_whole_brand_name_must_match(self):
        self.assertIsNone(self.brands.of("Michell Gyro", "summit-hi-fi"))
        self.assertIsNone(self.brands.of("NADIA 5", "summit-hi-fi"))

    def test_a_product_of_two_brands_stays(self):
        self.assertIsNone(self.brands.of("Denon x Ojas DL-103O", "ojas"))

    def test_a_brand_name_that_is_an_ordinary_word_is_not_matched(self):
        self.assertIsNone(self.brands.of("Eclipse 10 Speaker Cable", "wireworld"))
        self.assertIsNone(self.brands.of("Audio Splitter", "summit-hi-fi"))


class ValidationsTest(unittest.TestCase):
    def test_a_first_reading_classifies_an_unmapped_row(self):
        row = {"source_url": "https://x.test/p/1"}
        verdict = validations_module.apply_to(
            row, {"verdict": "classified", "slugs": ["dacs"], "by": "a", "at": "t"}
        )
        self.assertEqual(verdict, "classified")
        self.assertEqual(row["sub_category_slugs"], ["dacs"])
        self.assertEqual(row["validated_by"], "a")
        self.assertEqual(row["validation_verdict"], "classified")

    def test_a_check_corrects_the_name_and_keeps_the_shop_title(self):
        row = {"brand_slug": "fyne-audio", "name": "F1-8 Standmount Speaker | Hi-Fi",
               "source_url": "u", "match_keys": ["fyne-audio:F18STANDMOUNTSPEAKERHIFI"]}
        check = {"verdict": "agreed", "name": "F1-8 Standmount Speaker | Hi-Fi",
                 "corrected_name": "F1-8"}
        validations_module.apply_to(row, check)
        self.assertEqual(row["name"], "F1-8")
        self.assertEqual(row["source_name"], "F1-8 Standmount Speaker | Hi-Fi")
        self.assertEqual(validations_module.source_name(row), "F1-8 Standmount Speaker | Hi-Fi")
        self.assertIn("fyne-audio:F18", row["match_keys"])
        self.assertNotIn("fyne-audio:F18STANDMOUNTSPEAKERHIFI", row["match_keys"])
        # A second run finds the same check again, and changes nothing.
        validations_module.apply_to(row, check)
        self.assertEqual(row["source_name"], "F1-8 Standmount Speaker | Hi-Fi")

    def test_a_model_number_equal_to_the_name_is_cleared(self):
        row = {"name": "F1-8", "model_no": "f1 8", "provenance": {"model_no": {"source": "jsonld"}}}
        self.assertTrue(validations_module.drop_model_equal_to_name(row))
        self.assertIsNone(row["model_no"])
        self.assertNotIn("model_no", row["provenance"])

    def test_a_model_number_that_says_more_than_the_name_stays(self):
        row = {"name": "Model One", "model_no": "MO-SG-01"}
        self.assertFalse(validations_module.drop_model_equal_to_name(row))
        self.assertEqual(row["model_no"], "MO-SG-01")

    def test_a_shop_category_or_title_marks_a_product_discontinued(self):
        for row in (
            {"name": "DAC1", "source_category": "Archived Digital Cables"},
            {"name": "Reference 4", "source_category": "Legacy Products"},
            {"name": "DAC1", "source_name": "Benchmark DAC1 - Digital to Analog Audio Converter - Discontinued"},
            {"name": "HX310 PEQ", "source_name": "HX310 PEQ (DISCONTINUED)"},
            {"name": "OYSTER", "source_name": "OYSTER – OUT OF PRODUCTION"},
        ):
            self.assertTrue(validations_module.mark_discontinued(row), row)
            self.assertIs(row["discontinued"], True)

    def test_a_series_name_is_not_read_as_discontinued(self):
        for row in (
            {"name": "Concert Legacy 11", "source_category": "Speakers"},
            {"name": "Signature 10", "source_category": "Legacy Audio Series"},
            {"name": "Archiver", "source_name": "Archiver - JFET Variable Equalization Phonostage"},
        ):
            self.assertFalse(validations_module.mark_discontinued(row), row)

    def test_an_out_of_scope_row_keeps_its_verdict(self):
        row = {"source_url": "https://x.test/p/2", "sub_category_slugs": ["dacs"]}
        validations_module.apply_to(row, {"verdict": "out_of_scope", "note": "a toaster"})
        self.assertEqual(row["validation_verdict"], "out_of_scope")
        self.assertEqual(row["sub_category_slugs"], [])

class WooCommerceTest(unittest.TestCase):
    """WooCommerce shops in the sample wrote no product markup at all.

    382 product pages of one shop gave nothing: the SEO plugin had replaced the
    markup with BreadcrumbList, ItemPage, Organization and WebSite. The Store
    API is therefore not an improvement for these shops but the only source.
    """

    PRODUCT = {
        "name": "Cayin CS-55A",
        "permalink": "https://cayin.test/produkt/cs-55a",
        "sku": "CS55A",
        "description": "<p>An <b>integrated</b> amplifier.</p>",
        "prices": {"price": "345000", "currency_code": "EUR", "currency_minor_unit": 2},
        "images": [{"src": "https://cayin.test/i/1.jpg"}],
        "categories": [{"name": "Verstärker"}],
    }

    def test_the_price_is_read_with_its_exponent(self):
        self.assertEqual(
            platform_module.woocommerce_price(self.PRODUCT["prices"]), (3450.0, "EUR")
        )

    def test_a_price_of_zero_is_not_a_price(self):
        amount, currency = platform_module.woocommerce_price(
            {"price": "0", "currency_code": "EUR", "currency_minor_unit": 2}
        )
        self.assertIsNone(amount)
        self.assertEqual(currency, "EUR")

    def test_the_store_api_answer_is_a_plain_array(self):
        self.assertEqual(len(platform_module.parse_woocommerce_catalog('[{"name": "a"}]')), 1)
        self.assertEqual(platform_module.parse_woocommerce_catalog('{"code": "not_found"}'), [])

    def test_a_product_is_read_from_the_store_api(self):
        candidate = Candidate("cayin", self.PRODUCT["permalink"])
        apply_woocommerce_product(candidate, self.PRODUCT, "https://cayin.test/wp-json", "Cayin")

        self.assertEqual(candidate.name, "Cayin CS-55A")
        self.assertEqual(candidate.model_no, "CS55A")
        self.assertEqual(candidate.price, 3450.0)
        self.assertEqual(candidate.price_currency, "EUR")
        self.assertEqual(candidate.source_category, "Verstärker")
        self.assertNotIn("description", json.loads(candidate.to_json()))


class ArticleNumberTest(unittest.TestCase):
    """A shop's article number is not the manufacturer's model number.

    Every example is real, from the first import of 245 shops.
    """

    def test_a_number_that_is_in_the_name_is_the_model(self):
        self.assertTrue(sku_is_the_model("CS55A", "Cayin CS-55A"))
        self.assertTrue(sku_is_the_model("ARIA5", "Aria 5"))

    def test_a_house_number_is_refused(self):
        self.assertFalse(sku_is_the_model("WAUD-WA11-BK", "Woo Audio WA11 Topaz Headphone Amplifier"))
        self.assertFalse(sku_is_the_model("ADVXLR3F35M-BLK", "XLR Adapter Cable"))

    def test_a_name_inside_the_number_is_refused(self):
        """The decoration around the model is exactly what must not be stored."""
        self.assertFalse(sku_is_the_model("ADVR34-NVY", "R34"))

    def test_nothing_to_compare_means_no(self):
        self.assertFalse(sku_is_the_model(None, "Aria 5"))
        self.assertFalse(sku_is_the_model("ARIA5", None))

    def test_the_shopify_catalogue_refuses_a_house_number(self):
        product = {
            "title": "Woo Audio WA11 Topaz Headphone Amplifier",
            "variants": [{"title": "Default", "sku": "WAUD-WA11-BK", "price": "1399.00"}],
        }
        candidate = Candidate("woo-audio", "u")
        apply_shopify_product(candidate, product, "u", "USD")

        self.assertIsNone(candidate.model_no)
        self.assertEqual(candidate.price, 1399.0)


class ShopStateTest(unittest.TestCase):
    """A shop sells states of a product that a catalogue does not have."""

    def test_a_condition_in_the_name_is_recognised(self):
        self.assertEqual(shop_state('B-Stock: MACARIA Walnut'), "b-stock")
        self.assertEqual(shop_state("Show Model: MACARIA White Quartz"), "show model")

    def test_an_ordinary_name_is_not(self):
        self.assertIsNone(shop_state("MACARIA Birch - Natural Finish"))
        self.assertIsNone(shop_state("Planar 3"))


class AnswerParsingTest(unittest.TestCase):
    def test_json_inside_a_code_fence(self):
        self.assertEqual(parse_answer('```json\n{"is_product": true}\n```'), {"is_product": True})

    def test_a_broken_answer_is_empty_rather_than_an_error(self):
        self.assertEqual(parse_answer("I could not read this page."), {})


class CandidateTest(unittest.TestCase):
    def test_a_candidate_is_offered_under_both_keys(self):
        candidate = Candidate("acme-audio", "u", name="Aria 5", model_no="ACM-ARIA5")
        self.assertEqual(candidate.match_keys, ["acme-audio:ACMARIA5", "acme-audio:ARIA5"])

    def test_json_round_trip(self):
        candidate = Candidate("acme-audio", "u", name="Aria 5")
        candidate.set("price", 2499.0, Provenance("jsonld", "u"))
        data = json.loads(candidate.to_json())
        self.assertEqual(data["price"], 2499.0)
        self.assertEqual(data["provenance"]["price"]["source"], "jsonld")


if __name__ == "__main__":
    unittest.main(verbosity=2)


class SpecsTest(unittest.TestCase):
    """The specification list of a product page, read into custom attributes."""

    ZETH = (
        "ZETH\nfrom €11,900.00\nTechnical Data\nFrequency Response:\n40 - 20.000 Hz\n"
        "Driver:\nVOXATIV AC-1.9\nEfficiency:\n95 dB / 1W / 1 m\n"
        "Dimensions (W x H x D):\n33 x 108 x 25 cm / 13 x 42,5 x 10 \"\n"
        "Weight:\n32 kg / 62 lbs each\n"
    )

    def read(self, text, sub_categories=("floorstanding-loudspeakers",)):
        from hifilog_import import specs
        return {label: value for label, (value, _) in
                specs.read_specs(text, list(sub_categories), lambda label: True).items()}

    def test_the_voxativ_zeth(self):
        values = self.read(self.ZETH)
        self.assertEqual(values["frequency_response_range"],
                         {"value": {"min": 40, "max": 20000}, "unit": "hz"})
        self.assertEqual(values["loudspeaker_sensitivity"], {"value": 95, "unit": "db_1w_1m"})
        self.assertEqual(values["dimensions"], {"value": {"w": 33, "h": 108, "l": 25}, "unit": "cm"})
        self.assertEqual(values["weight"], {"value": 32, "unit": "kg"})

    def test_millimetres_become_centimetres_in_the_stated_order(self):
        values = self.read("Dimensions (H x W x D): 942 x 180 x 300 mm")
        self.assertEqual(values["dimensions"], {"value": {"h": 94.2, "w": 18, "l": 30}, "unit": "cm"})

    def test_dimensions_without_an_order_are_left_out(self):
        self.assertNotIn("dimensions", self.read("Dimensions: 33 x 108 x 25 cm"))

    def test_a_voltage_sensitivity_keeps_its_unit(self):
        values = self.read("Sensitivity: 93 dB (2,8 V / 1 m)")
        self.assertEqual(values["loudspeaker_sensitivity"], {"value": 93, "unit": "db_283v_1m"})

    def test_two_values_for_one_attribute_are_left_out(self):
        values = self.read(
            "Efficiency: 94 dB / 97 dB 1W / 1 m\nImpedance: 4 or 8 Ohm\n"
            "Weight: 14 lbs – Full Metal Version: 50 lbs\nImpedance: > 4 ohm\n"
            "Sensitivity: 98/102 dB / 1W / 1 m\nEfficiency: Up to 101 dB | 2.83V / 1m"
        )
        self.assertEqual(values, {})

    def test_a_weight_for_a_pair_or_for_shipping_is_left_out(self):
        self.assertEqual(self.read("Weight: 32 kg per pair\nShipping weight: 40 kg"), {})

    def test_grams_become_kilograms(self):
        self.assertEqual(self.read("Net weight: 320g/0.71lb")["weight"], {"value": 0.32, "unit": "kg"})

    def test_amplifier_power_is_read_per_load(self):
        values = self.read("Power Output: 100W @ 8Ω / 200W @ 4Ω", ("integrated-amplifiers",))
        self.assertEqual(values["amplifier_output_power"],
                         {"value": {"ohm_8": 100, "ohm_4": 200}, "unit": "w"})
        self.assertNotIn("amplifier_output_power",
                         self.read("Power Output: 120 watts into 4Ω or 8Ω", ("integrated-amplifiers",)))

    def test_headphone_sensitivity_needs_milliwatts(self):
        values = self.read("Sensitivity: 93 dB/mW", ("over-ear-headphones",))
        self.assertEqual(values["headphone_sensitivity"], {"value": 93, "unit": "db_mw"})
        self.assertEqual(self.read("Sensitivity: 110 dB/V", ("over-ear-headphones",)), {})

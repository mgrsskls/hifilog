const form = document.querySelector(".EntityForm");
const input = document.querySelector("#brand-filter");
const addBrand = document.querySelector(".ProductFormAddBrand");
const searchResultsWrapper = document.querySelector(".Options--brands");
const template = document.querySelector("#brand-template");

if (form) {
	const subCategories = form.querySelector(".EntityForm-subCategories");
	const discontinuedInput = form.querySelector(".Entity-discontinued");

	if (discontinuedInput) {
		const discontinuedInputs = discontinuedInput.querySelectorAll("input");

		discontinuedInputs.forEach((el) => {
			el.addEventListener("change", () => {
				renderDiscontinuedDate(form, discontinuedInputs);
			});
		});
	}

	if (subCategories) {
		const subCategoryInputs = form.querySelectorAll(
			'[name="product[sub_category_ids][]"]',
		);
		const customAttributes = form.querySelectorAll(
			".EntityForm-attributes [data-sub-category-ids]",
		);

		renderCustomAttributes(customAttributes, subCategoryInputs);

		subCategoryInputs.forEach((checkbox) => {
			checkbox.addEventListener("change", () => {
				renderCustomAttributes(customAttributes, subCategoryInputs);
			});
		});
	}

	setupCustomAttributeNumbers(form.querySelector(".EntityFormAttributes"));

	setupProductTitlePreview(form);

	setupProductSeriesField(form);

	// The brand payload feeds two things now: the product form's brand picker, and the
	// duplicate warning on the brand forms. Gate the fetch on data-url rather than on the
	// picker markup, so the brand forms get it too, and only fetch when something needs it.
	const needsBrands = Boolean(
		searchResultsWrapper || form.querySelector("[data-brand-duplicate]"),
	);

	if (form.dataset.url && needsBrands) {
		const headers = new Headers();
		headers.append("Accept", "application/json");

		fetch(form.dataset.url, {
			headers,
		})
			.then((res) => res.json())
			.then(({ brands }) => {
				if (searchResultsWrapper && template) {
					const elements = appendBrands(brands);

					renderBrands(input, elements, addBrand);

					if (input) {
						input.addEventListener("input", ({ target }) => {
							renderBrands(target, elements, addBrand);
							renderProductTitlePreview(form);
						});
					}
				}

				setupDuplicateWarning(form, brands);
			})
			.catch(() => {
				alert(
					"An error happened when loading the brands. Please reload the page. If this problem continues to exist, please contact us at info@hifilog.com.",
				);
			});
	}
}

function renderDiscontinuedDate(form, inputs) {
	const checkedInput = Array.from(inputs).find(
		(input) => input.checked === true,
	);
	const date = form.querySelector(".Entity-discontinuedDate");

	if (date && checkedInput) {
		const hide = checkedInput.value === "0";

		date.hidden = hide;

		date.querySelectorAll("input, select").forEach((el) => {
			el.disabled = hide;
		});
	}
}

function renderCustomAttributes(attributes, inputs) {
	const checked = Array.from(inputs)
		.filter((input) => input.checked)
		.map((input) => parseInt(input.value, 10));

	attributes.forEach((attribute) => {
		const applicable = JSON.parse(attribute.dataset.subCategoryIds);

		if (attribute.dataset.unitVariant) {
			renderUnitVariant(attribute, attributes, checked);
			return;
		}

		attribute.hidden = !checked.some((id) => applicable.includes(id));

		if (!attribute.hidden) renderAttributeOptions(attribute, checked);
	});
}

/**
 * A number attribute whose sub categories offer different units has one block of fields for each
 * group of units, with the same field names. The block of the first ticked sub category that the
 * attribute applies to is shown: a cartridge asks for its weight in grams, a loudspeaker in
 * kilograms. The sub categories are listed in menu order, so "first" means first in the menu.
 *
 * The fields of the other blocks are disabled, so the browser does not submit them.
 */
function renderUnitVariant(attribute, attributes, checked) {
	const variants = Array.from(attributes).filter(
		(other) => other.dataset.unitVariant === attribute.dataset.unitVariant,
	);
	const first = checked.find((id) =>
		variants.some((variant) =>
			JSON.parse(variant.dataset.subCategoryIds).includes(id),
		),
	);
	const applicable = JSON.parse(attribute.dataset.subCategoryIds);

	attribute.hidden = first === undefined || !applicable.includes(first);

	// When no ticked sub category applies, the block with the stored unit stays enabled, although
	// hidden. The controller replaces all custom attributes, so a figure that is not submitted is
	// deleted. The hidden fields of every other attribute are submitted in the same way.
	const keepsValue =
		first === undefined && "unitVariantKeepsValue" in attribute.dataset;

	attribute.querySelectorAll("input, select").forEach((field) => {
		field.disabled = attribute.hidden && !keepsValue;
	});
}

/**
 * Hides the options the ticked categories do not offer, so a phono stage is not asked about
 * I2S. The visible set is the union across ticked categories rather than the intersection: a
 * product in two categories genuinely is both, so an option either one offers is a real answer.
 *
 * An option that is already ticked is never hidden, whatever the categories say. The value is
 * recorded data -- a phono stage really can have an unusual socket, and a category edited by
 * mistake must not quietly drop an answer the contributor cannot see to restore.
 *
 * Options carry no data attribute at all unless some category narrows the list, in which case
 * there is nothing to do here.
 */
function renderAttributeOptions(attribute, checked) {
	attribute
		.querySelectorAll("[data-option-sub-category-ids]")
		.forEach((option) => {
			const offeredIn = JSON.parse(option.dataset.optionSubCategoryIds);
			const offered = checked.some((id) => offeredIn.includes(id));
			const ticked = Array.from(option.querySelectorAll("input")).some(
				(input) => input.checked,
			);

			option.hidden = !offered && !ticked;
		});
}

/**
 * Normalises the figures a contributor types, and warns when the two rows of a unit pair
 * disagree.
 *
 * An attribute whose units are a pair (weight: kg and lb) has one row for each unit. Nothing is
 * converted: each row holds the figure the source states in that unit, and the server stores
 * what it receives. See docs/custom-attributes.md, "Two units".
 */
function setupCustomAttributeNumbers(container) {
	if (!container) return;

	let equivalents;

	try {
		equivalents = JSON.parse(container.dataset.unitEquivalents || "{}");
	} catch {
		equivalents = {};
	}

	const decimalSeparator = localeDecimalSeparator();

	// Rewrites what was typed into a form the server can read, before it is submitted.
	container.querySelectorAll('input[name*="[value]"]').forEach((input) =>
		input.addEventListener("change", () => {
			const value = parseTypedNumber(input.value, decimalSeparator);

			// Left as typed when it is not a number at all: the contributor should see
			// their own input rather than have it silently rewritten or cleared. The
			// controller drops an unreadable figure the way it drops a blank one.
			if (!Number.isNaN(value)) input.value = String(value);
		}),
	);

	container
		.querySelectorAll("[data-unit-pair]")
		.forEach((pair) =>
			setupUnitPairWarning(pair, equivalents, decimalSeparator),
		);
}

/**
 * Shows the warning of a unit pair when both rows hold a figure for the same input and the two
 * cannot describe the same measurement.
 *
 * The rule of CustomAttribute.figures_agree?: a figure stands for half of its last decimal
 * place in each direction ("0.7 lb" is 0.65 to 0.75 lb), and the two ranges must overlap after
 * conversion. The contributor can still save: a brand's own figures sometimes disagree.
 */
function setupUnitPairWarning(pair, equivalents, decimalSeparator) {
	const [first, second] = pair.querySelectorAll("[data-unit-pair-row]");
	const warning = pair.querySelector("[data-unit-pair-warning]");
	const [unit, factor] = equivalents[second?.dataset.unitPairRow] || [];

	if (!first || !warning || unit !== first.dataset.unitPairRow) return;

	const update = () => {
		const firstRanges = figureRanges(first, decimalSeparator);
		const secondRanges = figureRanges(second, decimalSeparator);

		warning.hidden = Object.keys(firstRanges).every(
			(input) =>
				!(input in secondRanges) ||
				rangesOverlap(firstRanges[input], secondRanges[input], factor),
		);
	};

	pair.addEventListener("change", update);
	update();
}

/**
 * The range each filled field of a row stands for, keyed by input ("w", "h", "l"), or by
 * "value" for an attribute without inputs.
 */
function figureRanges(row, decimalSeparator) {
	const ranges = {};

	row.querySelectorAll('input[name*="[value]"]').forEach((input) => {
		const number = parseTypedNumber(input.value, decimalSeparator);

		if (Number.isNaN(number)) return;

		const decimals = (String(number).split(".")[1] || "").length;
		const half = 0.5 * 10 ** -decimals;

		ranges[input.dataset.input || "value"] = [number - half, number + half];
	});

	return ranges;
}

// `factor` converts the second range into the unit of the first.
function rangesOverlap([low, high], [otherLow, otherHigh], factor) {
	return low <= otherHigh * factor && otherLow * factor <= high;
}

/**
 * The decimal separator of the page's locale. Intl has no parse API, so this is the standard
 * way to get at it: format a number and read the decimal part back.
 */
function localeDecimalSeparator() {
	const locale = document.documentElement.lang || navigator.language || "en";
	const parts = new Intl.NumberFormat(locale).formatToParts(1.2);

	return parts.find((part) => part.type === "decimal")?.value || ".";
}

/**
 * Reads a number a contributor typed, whichever separator convention they used.
 *
 * `Number.parseFloat("0,5")` returns 0 rather than NaN, so nothing catches it and 0 is written
 * to the catalogue as though it were a measurement. It also accepts "12abc" as 12. Someone
 * typing a decimal comma has no way to tell either happened.
 *
 * Most of this is decided from the string alone, and only the genuinely ambiguous case falls
 * back to the locale:
 *
 *   both separators present            the last one is the decimal, the other groups
 *   one separator, appearing twice+    grouping
 *   one separator, not followed by     decimal -- "0,5", "12,45", "1.2345"
 *     exactly three digits
 *   one separator, followed by         ambiguous: "1,234" is 1234 to an English reader and
 *     exactly three digits             1.234 to a German one. The locale breaks the tie,
 *                                      because guessing from the digits would just be the
 *                                      same silent-wrong-number bug in a new costume.
 *
 * Returns NaN for anything that is not wholly a number, so a typo is rejected rather than
 * truncated. That includes a repeated separator whose groups are not a real grouping --
 * "12.3.4" is a mistyped decimal, not twelve-thousand-three-hundred-and-four, and reading it
 * as the latter would be the same silent-wrong-number bug this function exists to prevent.
 */
function parseTypedNumber(text, decimalSeparator) {
	const raw = String(text).replace(/[\s  ]/g, "");

	if (raw === "") return Number.NaN;

	const decimal = decimalSeparatorIn(raw, decimalSeparator);

	if (decimal === INVALID_GROUPING) return Number.NaN;

	const normalised = decimal
		? raw.replaceAll(decimal === "," ? "." : ",", "").replace(decimal, ".")
		: raw.replaceAll(",", "").replaceAll(".", "");

	return /^-?\d+(\.\d+)?$/.test(normalised) ? Number(normalised) : Number.NaN;
}

const INVALID_GROUPING = "invalid-grouping";

function decimalSeparatorIn(raw, decimalSeparator) {
	const hasComma = raw.includes(",");
	const hasDot = raw.includes(".");

	if (hasComma && hasDot) {
		return raw.lastIndexOf(",") > raw.lastIndexOf(".") ? "," : ".";
	}

	if (!hasComma && !hasDot) return null;

	const separator = hasComma ? "," : ".";

	// Repeated, so it can only be grouping: "1.234.567". Every group after the first must be
	// exactly three digits, or this is a mistyped separator rather than a real grouping.
	if (raw.indexOf(separator) !== raw.lastIndexOf(separator)) {
		return isValidGrouping(raw, separator) ? null : INVALID_GROUPING;
	}

	const trailing = raw.slice(raw.lastIndexOf(separator) + 1);

	if (trailing.length !== 3) return separator;

	return decimalSeparator === separator ? separator : null;
}

function isValidGrouping(raw, separator) {
	const groups = (raw.startsWith("-") ? raw.slice(1) : raw).split(separator);

	return (
		groups[0].length >= 1 &&
		groups[0].length <= 3 &&
		groups.slice(1).every((group) => group.length === 3)
	);
}

function renderBrands(input, brands, addBrandForm) {
	const value = input.value.trim().toLowerCase();

	if (value.length > 0) {
		brands.forEach((brand) => {
			// Match the abbreviation as well as the name, so "B&O" finds "Bang & Olufsen".
			// A miss here opens the "we could not find the brand" panel, which is how
			// duplicate brands get created.
			const { brand: name, brandAbbreviation: abbreviation } = brand.dataset;

			brand.hidden = !(
				name.startsWith(value) ||
				(abbreviation && abbreviation.startsWith(value))
			);
		});

		if (addBrandForm) {
			addBrandForm.hidden = !brands
				.map((brand) => brand.hidden)
				.every((v) => v === true);
		}
	} else {
		brands.forEach((brand) => {
			brand.hidden = true;
			brand.querySelector("input").checked = false;
		});

		addBrandForm.hidden = true;
	}
}

function appendBrands(brands) {
	const fragment = document.createDocumentFragment();

	brands.forEach((brand) => {
		const clone = template.content.cloneNode(true);
		const input = clone.querySelector("input");
		const label = clone.querySelector("label");
		const abbreviation = brand.abbreviation || "";

		clone.firstElementChild.dataset.brand = brand.name.toLowerCase();
		clone.firstElementChild.dataset.brandAbbreviation =
			abbreviation.toLowerCase();
		input.value = brand.id;
		input.id = `brands-${brand.id}`;
		label.setAttribute("for", `brands-${brand.id}`);
		label.textContent = brand.name;

		// Shown because it is never part of the name -- it is the reason this row matched
		// when someone typed "B&O".
		if (abbreviation) {
			const hint = document.createElement("small");
			hint.textContent = abbreviation;
			label.appendChild(document.createTextNode(" "));
			label.appendChild(hint);
		}

		fragment.appendChild(clone);
	});

	searchResultsWrapper.appendChild(fragment);

	return Array.from(searchResultsWrapper.children);
}

/**
 * Warns when the brand being typed already exists -- including under a different form of
 * its name. Duplicate brands are the real cost of an ambiguous name field, and nothing in
 * the form told anyone about them before.
 */
function setupDuplicateWarning(form, brands) {
	const target = form.querySelector("[data-brand-duplicate]");
	const nameInput = form.querySelector("[data-brand-name-input]");

	if (!target || !nameInput) return;

	const currentId = form.dataset.brandId;

	const render = () => {
		const value = nameInput.value.trim().toLowerCase();

		if (value.length < 2) {
			target.hidden = true;
			return;
		}

		const match = brands.find((brand) => {
			if (currentId && String(brand.id) === currentId) return false;

			return (
				brand.name.toLowerCase() === value ||
				(brand.abbreviation || "").toLowerCase() === value
			);
		});

		if (!match) {
			target.hidden = true;
			return;
		}

		target.replaceChildren();
		target.appendChild(document.createTextNode("A brand called "));

		const strong = document.createElement("b");
		strong.textContent = match.name;
		target.appendChild(strong);

		target.appendChild(document.createTextNode(" already exists. "));

		const link = document.createElement("a");
		link.href = `/brands/${match.slug}`;
		link.textContent = "Open it";
		target.appendChild(link);

		target.hidden = false;
	};

	nameInput.addEventListener("input", render);
	render();
}

/**
 * Shows the title a product will actually get, e.g. "B&O Beolab 90" once the brand has an
 * abbreviation. Demonstrates the "product name only, no brand name" convention that the
 * guidelines state in a collapsed block nobody opens, and warns when the brand name --
 * abbreviation or full name -- has been typed in twice.
 */
function setupProductTitlePreview(form) {
	const nameInput = form.querySelector("[data-product-name-input]");

	if (!nameInput) return;

	nameInput.addEventListener("input", () => renderProductTitlePreview(form));

	["[data-brand-name-input]", "[data-brand-abbreviation-input]"].forEach(
		(selector) => {
			form
				.querySelector(selector)
				?.addEventListener("input", () => renderProductTitlePreview(form));
		},
	);

	// Delegated: the brand radios are built from the fetched payload, long after this runs.
	form.addEventListener("change", ({ target }) => {
		if (target.name === "product[brand_id]") renderProductTitlePreview(form);
	});

	renderProductTitlePreview(form);
}

function renderProductTitlePreview(form) {
	const nameInput = form.querySelector("[data-product-name-input]");
	const target = form.querySelector("[data-product-title-preview]");

	if (!nameInput || !target) return;

	const productName = nameInput.value.trim();
	const brand = selectedBrandNameForms(form);
	const brandName = brand && (brand.abbreviation || brand.name);

	if (!productName || !brandName) {
		target.hidden = true;
		return;
	}

	// Checks both forms: the title is built from whichever one is displayed (the
	// abbreviation when there is one), but a contributor can type either the
	// abbreviation or the full name into the product name field.
	const productNameLower = productName.toLowerCase();
	const repeats = [brand.name, brand.abbreviation].some(
		(value) => value && productNameLower.startsWith(`${value.toLowerCase()} `),
	);
	const seriesName = selectedSeriesName(form);
	const repeatsSeries = Boolean(
		seriesName &&
		productNameLower !== seriesName.toLowerCase() &&
		(productNameLower.startsWith(`${seriesName.toLowerCase()} `) ||
			productNameLower.endsWith(` ${seriesName.toLowerCase()}`)),
	);

	target.replaceChildren();
	target.appendChild(
		document.createTextNode(
			repeats
				? "Looks like the brand name is in there twice \u2014 "
				: "Will appear as ",
		),
	);

	const strong = document.createElement("b");
	strong.textContent = `${brandName} ${productName}`;
	target.appendChild(strong);

	// The series is not part of the title (docs/product-series.md). It is shown on its own line
	// under the title, so it must not be typed into the product name as well.
	if (seriesName) {
		target.appendChild(
			document.createTextNode(
				repeatsSeries
					? ` \u2014 please remove \u201c${seriesName}\u201d from the name: the series is shown separately.`
					: `, in the ${seriesName} series`,
			),
		);
	}

	target.hidden = false;
}

function selectedSeriesName(form) {
	return form.querySelector("[data-product-series-input]")?.value.trim() || "";
}

/**
 * The series field of the product form: a text input with a <datalist> of the series of the
 * selected brand. The user selects a series or types a new name; the server creates a new
 * series for a new name (Product#product_series_name=). When the brand changes, the list is
 * loaded for the new brand and the field is cleared, because a series belongs to one brand.
 */
function setupProductSeriesField(form) {
	const field = form.querySelector("[data-product-series-field]");
	const seriesInput = field?.querySelector("[data-product-series-input]");
	const list = field?.querySelector("datalist");

	if (!field || !seriesInput || !list) return;

	seriesInput.addEventListener("input", () => renderProductTitlePreview(form));

	// Delegated: the brand radios are built from the fetched payload, long after this runs.
	form.addEventListener("change", ({ target }) => {
		if (target.name !== "product[brand_id]") return;

		seriesInput.value = "";
		renderProductTitlePreview(form);
		loadSeriesOptions(field, list, target.value);
	});

	// A new brand (typed into the "Add new brand" fields) has no series yet.
	form
		.querySelector("[data-brand-name-input]")
		?.addEventListener("input", () => {
			if (!form.querySelector('[name="product[brand_id]"]:checked')) {
				list.replaceChildren();
			}
		});
}

function loadSeriesOptions(field, list, brandId) {
	list.replaceChildren();

	if (!brandId || !field.dataset.seriesUrl) return;

	const headers = new Headers();
	headers.append("Accept", "application/json");

	fetch(
		field.dataset.seriesUrl.replace("__BRAND__", encodeURIComponent(brandId)),
		{
			headers,
		},
	)
		.then((res) => (res.ok ? res.json() : { series: [] }))
		.then(({ series }) => {
			(series || []).forEach(({ name }) => {
				const option = document.createElement("option");
				option.value = name;
				list.appendChild(option);
			});
		})
		.catch(() => {
			// The field still works without suggestions: a typed name selects or creates a series.
		});
}

// Returns { name, abbreviation } for whichever brand is currently selected, so callers can
// check both forms rather than only the one the title preview happens to display.
function selectedBrandNameForms(form) {
	const filter = form.querySelector("#brand-filter");

	if (filter?.disabled) {
		return {
			name: filter.value,
			abbreviation: filter.dataset.brandAbbreviation,
		};
	}

	const checked = form.querySelector('[name="product[brand_id]"]:checked');

	if (checked) {
		const label = checked.closest("[data-brand]")?.querySelector("label");

		return {
			name: label?.firstChild?.textContent.trim(),
			abbreviation: label?.querySelector("small")?.textContent.trim(),
		};
	}

	const addBrandWrapper = form.querySelector(".ProductFormAddBrand");

	if (addBrandWrapper && !addBrandWrapper.hidden) {
		return {
			name: form.querySelector("[data-brand-name-input]")?.value.trim(),
			abbreviation: form
				.querySelector("[data-brand-abbreviation-input]")
				?.value.trim(),
		};
	}

	return null;
}

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

	setupProductTitlePreview(form);

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
	attributes.forEach((attribute) => {
		const filteredInputs = Array.from(inputs).filter((checkbox) =>
			JSON.parse(attribute.dataset.subCategoryIds).includes(
				parseInt(checkbox.value, 10),
			),
		);

		attribute.hidden =
			filteredInputs.filter((input) => input.checked).length === 0;
	});
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

	target.hidden = false;
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

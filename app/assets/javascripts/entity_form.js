const form = document.querySelector(".EntityForm");
const input = document.querySelector("#brand-filter");
const addBrand = document.querySelector(".ProductFormAddBrand");
const searchResultsWrapper = document.querySelector(".Options--brands");
const template = document.querySelector("#brand-template");

if (form) {
	const subCategories = form.querySelector(".EntityForm-subCategories");

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

	if (searchResultsWrapper) {
		const headers = new Headers();
		headers.append("Accept", "application/json");

		fetch(form.dataset.url, {
			headers,
		})
			.then((res) => res.json())
			.then(({ brands }) => {
				const elements = appendBrands(brands);

				renderBrands(input, elements, addBrand);

				if (input) {
					input.addEventListener("input", ({ target }) => {
						renderBrands(target, elements, addBrand);
					});
				}
			})
			.catch((e) => {
				alert(
					"An error happened when loading the brands. Please reload the page. If this problem continues to exist, please contact us at info@hifilog.com.",
				);
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
			if (brand.dataset.brand.startsWith(value)) {
				brand.hidden = false;
			} else {
				brand.hidden = true;
			}
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
	const wrapper = searchResultsWrapper.cloneNode();

	brands.forEach((brand) => {
		const clone = template.content.cloneNode(true);
		const input = clone.querySelector("input");
		const label = clone.querySelector("label");

		clone.firstElementChild.dataset.brand = brand.name.toLowerCase();
		input.value = brand.id;
		input.id = `brands-${brand.id}`;
		label.setAttribute("for", `brands-${brand.id}`);
		label.textContent = brand.name;

		wrapper.appendChild(clone);
	});

	searchResultsWrapper.replaceWith(wrapper);

	return Array.from(wrapper.children);
}

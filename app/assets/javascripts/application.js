import "./theme_toggle.js";

{
	let scrollY = 0;

	const headerToggle = document.querySelector(".Header-toggle");
	const menuButtons = document.querySelectorAll("button.MenuMain-link");
	const filterOpen = document.querySelector(".Filter-open");
	const filterClose = document.querySelector(".Filter-close");
	const filterCategories = document.querySelectorAll('[name="category"]');
	const filterSubCategories = document.querySelectorAll("[data-category]");
	const buttonsWithLoadingState = document.querySelectorAll(
		".Button--loadingIcon, .CheckboxButton",
	);

	if (headerToggle) {
		headerToggle.addEventListener("click", onMenuToggle);
	}

	if (filterOpen) {
		filterOpen.addEventListener("click", onOpenFilter);
	}

	if (filterClose) {
		filterClose.addEventListener("click", onCloseFilter);
	}

	menuButtons.forEach((category) =>
		category.addEventListener("click", onSubMenuToggle),
	);

	filterCategories.forEach((category) =>
		category.addEventListener("change", onCategoryChange),
	);

	buttonsWithLoadingState.forEach((el) => {
		const button = el.closest("button");
		const form = el.closest("form");

		button.addEventListener("click", () => {
			if (form.checkValidity()) {
				button.disabled = true;
				button.classList.add("is-loading");
				form.submit();
			}
		});
	});

	document.querySelectorAll("button[data-dialog]").forEach((button) => {
		button.addEventListener("click", () => {
			const dialog = document.querySelector(`#${button.dataset.dialog}`);

			if (dialog) {
				dialog.showModal();
			}
		});
	});

	document.querySelectorAll(".OpenImageDialog").forEach((button) => {
		if (!button.classList.contains("OpenImageDialog--upload")) {
			button.addEventListener("mouseover", ({ currentTarget }) => {
				const dialog = currentTarget.parentNode.querySelector("dialog");

				if (dialog) {
					const image = new Image();

					image.src = dialog.querySelector("img").src;
				}
			});
		}
	});

	document.querySelectorAll(".ImageDialog").forEach((dialog) => {
		dialog.addEventListener("click", () => {
			dialog.close();
		});
	});

	function onSubMenuToggle({ currentTarget: button }) {
		const shouldOpen = button.getAttribute("aria-expanded") === "false";
		const onEscape = (e) => {
			if (e.key === "Escape") {
				button.setAttribute("aria-expanded", "false");
				window.removeEventListener("keydown", onEscape);
				window.removeEventListener("click", onOutSideClick);
			}
		};
		const onOutSideClick = (e) => {
			if (!e.target.closest(".MenuList")) {
				button.setAttribute("aria-expanded", "false");
				window.removeEventListener("click", onOutSideClick);
				window.removeEventListener("keydown", onEscape);
			}
		};

		menuButtons.forEach((menuButton) => {
			if (menuButton === button) {
				if (shouldOpen) {
					menuButton.setAttribute("aria-expanded", "true");

					if (window.matchMedia("(max-width: 54rem)")) {
						if (
							menuButton.getBoundingClientRect().bottom > window.innerHeight
						) {
							menuButton.scrollIntoView(false);
						}

						if (menuButton.getBoundingClientRect().top < 0) {
							menuButton.scrollIntoView();
						}
					}
				} else {
					menuButton.setAttribute("aria-expanded", "false");
				}
			} else {
				menuButton.setAttribute("aria-expanded", "false");
			}
		});

		if (shouldOpen) {
			window.addEventListener("keydown", onEscape);
			window.addEventListener("click", onOutSideClick);
		} else {
			window.removeEventListener("keydown", onEscape);
			window.removeEventListener("click", onOutSideClick);
		}

		if (button.classList.contains("MainMenu-link--mega")) {
			document
				.querySelectorAll("body > nav, body > main, body > footer")
				.forEach((element) => {
					element.inert = shouldOpen;
				});
		}
	}

	function onMenuToggle({ currentTarget: button }) {
		const shouldOpen = button.getAttribute("aria-expanded") === "false";

		if (shouldOpen) {
			scrollY = window.scrollY;
			button.setAttribute("aria-expanded", "true");
		} else {
			button.setAttribute("aria-expanded", "false");
			window.requestAnimationFrame(() => window.scrollTo(0, scrollY));
		}
	}

	function onOpenFilter({ currentTarget: button }) {
		button.setAttribute("aria-expanded", "true");
	}

	function onCloseFilter({ currentTarget: button }) {
		const filter = button.closest(".Filter");

		if (filter) {
			const filterButton = document.querySelector(".Filter-open");

			if (filterButton) {
				filterButton.setAttribute("aria-expanded", "false");
			}
		}
	}

	function onCategoryChange({ currentTarget: input }) {
		filterSubCategories.forEach((subCategory) => {
			const hide = subCategory.dataset.category !== input.value;

			subCategory.hidden = hide;
			subCategory.querySelectorAll("input").forEach((input, i) => {
				input.disabled = hide;

				if (!hide && i === 0) {
					input.checked = true;
				}
			});
		});
	}

	/**
	 * Fetch if user has a product, product variant or brand.
	 * Used for product and brand tables.
	 */

	const productIds = [];
	const productVariantIds = [];
	const brandIds = [];

	document.querySelectorAll(".Symbols").forEach((symbol) => {
		if (symbol.dataset.productVariant) {
			productVariantIds.push(parseInt(symbol.dataset.productVariant, 10));
		} else if (symbol.dataset.product) {
			productIds.push(parseInt(symbol.dataset.product, 10));
		} else if (symbol.dataset.brand) {
			brandIds.push(parseInt(symbol.dataset.brand, 10));
		}
	});

	if (productIds.length || productVariantIds.length || brandIds.length) {
		let params = new URLSearchParams();

		for (const productId of productIds) {
			params.append("products[]", productId);
		}

		for (const productVariantId of productVariantIds) {
			params.append("product_variants[]", productVariantId);
		}

		for (const brandId of brandIds) {
			params.append("brands[]", brandId);
		}

		let url = new URL(
			`/user/has?${params.toString()}`,
			document.location.origin,
		);

		fetch(url, {
			headers: {
				"Content-Type": "application/json",
			},
		})
			.then((res) => res.json())
			.then(({ brands, products, product_variants }) => {
				for (const [array, alias] of [
					[brands, "brand"],
					[products, "product"],
					[product_variants, "product-variant"],
				]) {
					if (!array) continue;

					for (const item of array) {
						const el = document.querySelector(
							`.Symbols[data-${alias}="${item.id}"]`,
						);

						if (el) {
							el.querySelector('[data-symbol="in_collection"]').hidden =
								!item.in_collection;
							el.querySelector('[data-symbol="previously_owned"]').hidden =
								!item.previously_owned;
						}
					}
				}
			});
	}
}

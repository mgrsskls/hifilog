document.addEventListener("DOMContentLoaded", () => {
	const selectBookmarkList = document.querySelector("#select-bookmark-list");

	if (selectBookmarkList) {
		selectBookmarkList.addEventListener("change", onSelectBookmarkList);
	}

	function onSelectBookmarkList({ target }) {
		target.closest("form").submit();
	}

	/**
	 * Fetch if user has a product, product variant or brand.
	 * Used for product and brand tables.
	 */

	const productIds = [];
	const productVariantIds = [];
	const brandIds = [];
	const eventIds = [];

	document.querySelectorAll(".Symbols").forEach((symbol) => {
		if (symbol.dataset.productVariant) {
			const id = parseInt(symbol.dataset.productVariant, 10);

			if (!productVariantIds.includes(id)) {
				productVariantIds.push(id);
			}
		} else if (symbol.dataset.product) {
			const id = parseInt(symbol.dataset.product, 10);

			if (!productIds.includes(id)) {
				productIds.push(id);
			}
		} else if (symbol.dataset.brand) {
			const id = parseInt(symbol.dataset.brand, 10);

			if (!brandIds.includes(id)) {
				brandIds.push(id);
			}
		} else if (symbol.dataset.event) {
			const id = parseInt(symbol.dataset.event, 10);

			if (!eventIds.includes(id)) {
				eventIds.push(id);
			}
		}
	});

	if (
		productIds.length ||
		productVariantIds.length ||
		brandIds.length ||
		eventIds.length
	) {
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

		for (const eventId of eventIds) {
			params.append("events[]", eventId);
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
			.then(({ brands, products, product_variants, events }) => {
				for (const [array, alias] of [
					[brands, "brand"],
					[products, "product"],
					[product_variants, "product-variant"],
					[events, "event"],
				]) {
					if (!array) continue;

					for (const item of array) {
						const elements = document.querySelectorAll(
							`.Symbols[data-${alias}="${item.id}"]`,
						);

						elements.forEach((el) => {
							el.querySelector('[data-symbol="in_collection"]').hidden =
								!item.in_collection;
							el.querySelector('[data-symbol="previously_owned"]').hidden =
								!item.previously_owned;
							el.querySelector('[data-symbol="bookmarked"]').hidden =
								!item.bookmarked;
						});
					}
				}
			});
	}
});

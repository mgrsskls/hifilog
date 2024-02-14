import "./theme_toggle.js";

{
	let scrollY = 0;

	const headerToggle = document.querySelector(".Header-toggle");
	const menuButtons = document.querySelectorAll("button.MenuMain-link");
	const filterOpen = document.querySelector(".Filter-open");
	const filterClose = document.querySelector(".Filter-close");
	const filterCategories = document.querySelectorAll('[name="category"]');
	const filterSubCategories = document.querySelectorAll("[data-category]");
	const sort = document.querySelector("#sort");

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

	if (sort) {
		sort.addEventListener("change", onSortChange);
	}

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

					if (window.matchMedia("(max-width: 50rem)")) {
						menuButton.scrollIntoView();
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

	function onSortChange({ target }) {
		target.closest("form").submit();
	}
}

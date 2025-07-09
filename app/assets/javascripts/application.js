import "./theme_toggle.js";
import "./_search.js";

{
	let scrollY = 0;

	const headerToggle = document.querySelector(".Header-toggle");
	const sidebarToggle = document.querySelector(".Sidebar-toggle");
	const menuButtons = document.querySelectorAll("button.MenuMain-link");
	const filterOpen = document.querySelector(".Filter-open");
	const filterClose = document.querySelector(".Filter-close");
	const filterCategories = document.querySelectorAll('[name="category"]');
	const filterSubCategories = document.querySelectorAll("[data-category]");
	const buttonsWithLoadingState = document.querySelectorAll(
		".Button--loadingIcon, .CheckboxButton",
	);
	const filterCheckboxes = document.querySelectorAll(".Filter .Pagination");
	const signUpCall = document.querySelector(".SignUpCall");

	if (signUpCall) {
		const button = signUpCall.querySelector("button");

		if (button) {
			button.addEventListener("click", () => {
				document.cookie =
					"hide_sign_up_call=1; path=/; SameSite=Strict; Secure";
				signUpCall.remove();
			});
		}
	}

	filterCheckboxes.forEach((el) => {
		if (el.querySelectorAll('[type="checkbox"]').length == 2) {
			el.querySelectorAll('[type="checkbox"]').forEach((checkbox) => {
				checkbox.addEventListener("change", ({ target }) => {
					if (target.checked) {
						Array.from(
							target
								.closest(".Pagination")
								.querySelectorAll('[type="checkbox"]'),
						).filter((checkbox) => checkbox !== target)[0].checked = false;
					}
				});
			});
		}
	});

	if (headerToggle) {
		headerToggle.addEventListener("click", onMenuToggle);
	}

	if (sidebarToggle) {
		sidebarToggle.addEventListener("click", onSidebarToggle);
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

					if (window.matchMedia("(width < 54rem)")) {
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

	function onSidebarToggle({ currentTarget: button }) {
		const shouldOpen = button.getAttribute("aria-expanded") === "false";

		if (shouldOpen) {
			button.parentNode.classList.add("is-dark");
			button.setAttribute("aria-expanded", "true");
		} else {
			button.parentNode.classList.remove("is-dark");
			button.setAttribute("aria-expanded", "false");
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
}

let value;
let timeout;
let results = {};
let eventListener = false;

const container = document.querySelector(".Search-xhrResults");
const search = container.closest("search");
const searchInput = search.querySelector("input");

if (searchInput) {
	searchInput.addEventListener("input", onSearchInput);
}

const onKeyDown = (e) => {
	if (e.key === "Escape") {
		closeSearch();
	}
};

const onClick = ({ target }) => {
	if (!search.contains(target)) {
		closeSearch();
	}
};

const onFocus = ({ target }) => {
	if (!search.contains(target)) {
		closeSearch();
	}
};

function onSearchInput({ target: input }) {
	if (!eventListener) {
		document.addEventListener("keydown", onKeyDown);
		document.addEventListener("click", onClick);
		document.body.addEventListener("focus", onFocus, true);

		eventListener = true;
	}

	clearTimeout(timeout);

	timeout = setTimeout(() => {
		value = input.value.trim();

		if (value.length >= 2) {
			fetch(`/search?query=${value}`, {
				headers: new Headers({
					"X-Requested-With": "XMLHttpRequest",
				}),
			})
				.then((res) => res.json())
				.then((json) => {
					results[value] = json.html;

					if (json.query === value) {
						if (json.html) {
							container.dataset.focus = true;
							container.innerHTML = json.html;
						} else {
							container.dataset.focus = false;
							container.textContent = "";
						}
					}
				});
		} else {
			container.dataset.focus = false;
			container.textContent = "";
		}
	}, 300);
}

function closeSearch() {
	container.dataset.focus = false;
	eventListener = false;

	document.removeEventListener("keydown", onKeyDown);
	document.removeEventListener("click", onClick);
	document.body.removeEventListener("focus", onFocus, true);
}

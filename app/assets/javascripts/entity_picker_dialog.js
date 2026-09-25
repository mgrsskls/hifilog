// Dialogs that pick entities with one checkbox each (shared/_entity_picker_dialog):
//
// * The rows load the first time the dialog opens, when the dialog has data-picker-src. The page
//   itself then carries no rows.
// * The filter field hides the rows that do not match. A hidden row keeps its checkbox, so the
//   filter never changes the selection.
// * The counter shows how many rows are checked.
// * The dialog opens by itself when the URL has "#<id of the dialog>", for example after sign-in.
//
// application.js opens the dialog (button[data-dialog]). This file only adds the behavior above.
document.querySelectorAll("dialog[data-picker]").forEach((dialog) => {
	const list = dialog.querySelector("[data-picker-list]");

	if (!list) return;

	const filter = dialog.querySelector("[data-picker-filter]");
	const counter = dialog.querySelector("[data-picker-count]");
	const noMatch = dialog.querySelector("[data-picker-no-match]");
	const closeButton = dialog.querySelector("[data-picker-close]");
	const submitButton = dialog.querySelector("button[type=submit]");
	const src = dialog.dataset.pickerSrc;
	let loaded = !src;

	function options() {
		return list.querySelectorAll("[data-picker-option]");
	}

	function applyFilter() {
		const query = filter ? filter.value.trim().toLowerCase() : "";
		let visible = 0;

		options().forEach((option) => {
			const match = query === "" || option.dataset.pickerText.includes(query);

			option.hidden = !match;

			if (match) visible += 1;
		});

		// Not "no match" when there is no row at all: then the list is empty or not yet loaded.
		if (noMatch) noMatch.hidden = visible > 0 || options().length === 0;
	}

	function updateCounter() {
		if (!counter) return;

		const checked = list.querySelectorAll(
			"input[type=checkbox]:checked",
		).length;

		counter.textContent = counter.dataset.pickerCountTemplate.replace(
			"{count}",
			checked,
		);
	}

	function showMessage(text) {
		list.textContent = "";
		const paragraph = document.createElement("p");
		paragraph.textContent = text;
		list.append(paragraph);
	}

	async function load() {
		if (loaded) return;

		loaded = true;
		showMessage(list.dataset.pickerLoading);

		try {
			const response = await fetch(src, {
				headers: { "X-Requested-With": "XMLHttpRequest" },
			});

			if (!response.ok) throw new Error(response.status);

			list.innerHTML = await response.text();
			applyFilter();
			updateCounter();
		} catch {
			loaded = false;
			showMessage(list.dataset.pickerError);
		}
	}

	document
		.querySelectorAll(`button[data-dialog="${dialog.id}"]`)
		.forEach((button) => button.addEventListener("click", load));

	if (filter) {
		filter.addEventListener("input", applyFilter);
		// Enter in the filter field would send the form around the dialog.
		filter.addEventListener("keydown", (event) => {
			if (event.key === "Enter") event.preventDefault();
		});
	}

	list.addEventListener("change", updateCounter);

	if (closeButton) {
		closeButton.addEventListener("click", () => dialog.close());
	}

	// A field of the form outside the dialog can be invalid. The browser can not show its message
	// above the modal dialog, so the dialog closes first.
	if (submitButton) {
		submitButton.addEventListener("click", (event) => {
			const form = submitButton.form;

			if (form && !form.checkValidity()) {
				event.preventDefault();
				dialog.close();
				form.reportValidity();
			}
		});
	}

	updateCounter();
	applyFilter();

	if (window.location.hash === `#${dialog.id}`) {
		// Without the hash, a reload does not open the dialog again.
		history.replaceState(
			null,
			"",
			window.location.pathname + window.location.search,
		);
		dialog.showModal();
		load();
	}
});

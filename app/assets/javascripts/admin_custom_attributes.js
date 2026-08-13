const editor = document.querySelector("[data-options-editor]");

if (editor) {
	const list = editor.querySelector("[data-options-list]");
	const template = editor.querySelector("[data-option-template]");
	const empty = editor.querySelector("[data-options-empty]");
	const addButton = editor.querySelector("[data-option-add]");

	// The datalist is already the full key -> label map the server rendered, so the
	// preview reads from it rather than shipping the same data a second time.
	const labels = new Map(
		Array.from(
			editor.querySelectorAll("#custom-attribute-option-keys option"),
			(option) => [option.value, option.textContent.trim()],
		),
	);

	function renderPreview(row) {
		const input = row.querySelector("[data-option-value]");
		const preview = row.querySelector("[data-option-preview]");
		if (!input || !preview) return;

		const key = input.value.trim();

		if (key === "") {
			preview.textContent = "";
		} else if (labels.has(key)) {
			preview.textContent = labels.get(key);
		} else {
			preview.textContent = "⚠ no translation yet";
		}
	}

	function renderEmptyState() {
		if (!empty) return;
		empty.hidden = list.querySelector("[data-option-row]") === null;
	}

	function removeRow(button) {
		const row = button.closest("[data-option-row]");
		if (!row) return;

		const usage = Number(button.dataset.usage || 0);

		if (usage > 0) {
			const label =
				row.querySelector("[data-option-value]")?.value || "this option";
			const products = usage === 1 ? "1 product" : `${usage} products`;
			const confirmed = window.confirm(
				`${products} currently use “${label}”. Removing it leaves those products ` +
					`pointing at an option that no longer exists. Remove it anyway?`,
			);

			if (!confirmed) return;
		}

		row.remove();
		renderEmptyState();
	}

	editor.addEventListener("input", (event) => {
		const row = event.target.closest("[data-option-row]");
		if (row) renderPreview(row);
	});

	editor.addEventListener("click", (event) => {
		const remove = event.target.closest("[data-option-remove]");
		if (remove) removeRow(remove);
	});

	if (addButton && template) {
		addButton.addEventListener("click", () => {
			list.append(template.content.cloneNode(true));
			renderEmptyState();
			list
				.querySelector("[data-option-row]:last-child [data-option-value]")
				?.focus();
		});
	}

	list.querySelectorAll("[data-option-row]").forEach(renderPreview);
	renderEmptyState();
}

// Only one of the two field groups ever applies: `option`/`options` attributes are
// picked from a list, `number` attributes are measured in units. Hiding the group that
// does not apply removes the main source of confusion in this form. Saving also clears
// whatever no longer applies, so switching away from a populated group says so out loud
// rather than dropping the data quietly.
const inputTypeInputs = document.querySelectorAll(
	'input[name="custom_attribute[input_type]"]',
);

if (inputTypeInputs.length > 0) {
	const groups = {
		options: document.querySelector('[data-field-group="options"]'),
		measurement: document.querySelector('[data-field-group="measurement"]'),
	};
	const warning = document.querySelector("[data-input-type-warning]");

	function renderFieldGroups() {
		const selected = Array.from(inputTypeInputs).find((input) => input.checked);
		const inputType = selected ? selected.value : null;
		const wantsOptions = inputType === "option" || inputType === "options";

		if (groups.options) groups.options.hidden = !wantsOptions;
		if (groups.measurement) groups.measurement.hidden = inputType !== "number";

		if (warning) {
			const count = groups.options
				? groups.options.querySelectorAll("[data-option-row]").length
				: 0;
			const dropping = !wantsOptions && count > 0;

			warning.hidden = !dropping;

			if (dropping) {
				warning.textContent =
					`Saving with this input type removes the ${count} ` +
					`option${count === 1 ? "" : "s"} defined for this attribute.`;
			}
		}
	}

	inputTypeInputs.forEach((input) => {
		input.addEventListener("change", renderFieldGroups);
	});

	renderFieldGroups();
}

// Saves one field of one record from an index table, without a form submit.
//
// An input opts in with `data-inline-edit-url` (where to send it) and
// `data-inline-edit-field` (the parameter name). The value is sent on "change",
// that is, when the input loses focus or Enter is pressed after an edit. The
// input shows the result in `data-inline-edit-state`: "saving", "saved" or
// "error". The page styles these states; this script sets only the attribute.
//
// One listener on the document serves every input on the page, so a table of
// any length costs one handler.

function csrfToken() {
	const meta = document.querySelector('meta[name="csrf-token"]');
	if (meta) return meta.content;
	const field = document.querySelector('input[name="authenticity_token"]');
	return field ? field.value : "";
}

async function save(input) {
	const body = new FormData();
	body.append(input.dataset.inlineEditField, input.value);

	input.dataset.inlineEditState = "saving";
	input.title = "";

	try {
		const response = await fetch(input.dataset.inlineEditUrl, {
			method: "PATCH",
			headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
			body,
			credentials: "same-origin",
		});
		const answer = await response.json().catch(() => ({}));

		if (!response.ok) {
			input.dataset.inlineEditState = "error";
			input.title = answer.error || `Not saved (${response.status})`;
			return;
		}

		// The server may have normalised the value, for example removed spaces.
		if (typeof answer.value === "string") input.value = answer.value;
		input.defaultValue = input.value;
		input.dataset.inlineEditState = "saved";
	} catch (_error) {
		input.dataset.inlineEditState = "error";
		input.title = "Not saved: no connection";
	}
}

document.addEventListener("change", (event) => {
	const input = event.target;
	if (!(input instanceof HTMLInputElement)) return;
	if (!input.dataset.inlineEditUrl) return;
	save(input);
});

// Enter would otherwise submit the batch action form around the table.
document.addEventListener("keydown", (event) => {
	const input = event.target;
	if (event.key !== "Enter") return;
	if (!(input instanceof HTMLInputElement) || !input.dataset.inlineEditUrl)
		return;
	event.preventDefault();
	input.blur();
});

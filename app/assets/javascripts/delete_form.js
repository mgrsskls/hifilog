Array.from(document.querySelectorAll(".DeleteButton")).forEach((button) => {
	button.closest("form").addEventListener("submit", (event) => {
		if (!window.confirm(button.dataset.msg)) {
			event.preventDefault();
		}
	});
});

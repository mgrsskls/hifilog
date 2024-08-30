customElements.define(
	"theme-toggle",
	class ThemeToggle extends HTMLElement {
		#name;
		#currentTheme;
		#defaultTheme;
		#inputs;

		constructor() {
			super();
		}

		connectedCallback() {
			this.#inputs = Array.from(this.querySelectorAll('[type="radio"]'));
			this.#name = this.#inputs[0].name;
			this.#currentTheme = this.#getStoredTheme() || this.#getCurrentTheme();
			this.#defaultTheme = this.#inputs[0].value;

			this.#render();

			this.#inputs.forEach((input) => {
				input.addEventListener("change", ({ target }) => {
					const { value } = target;

					this.#saveTheme(value);
					this.#render();
				});
			});
		}

		#saveTheme(theme) {
			this.#currentTheme = theme;

			if (theme === this.#defaultTheme) {
				localStorage.removeItem(this.#name);
			} else {
				localStorage.setItem(this.#name, theme);
			}
		}

		#getStoredTheme() {
			return localStorage[this.#name];
		}

		#getCurrentTheme() {
			const checkedInput = this.#inputs.find((input) => input.checked);

			if (checkedInput) return checkedInput.value;

			return null;
		}

		#render() {
			document.documentElement.dataset.theme = this.#currentTheme;

			const input = this.#inputs.find(
				(input) => input.value === this.#currentTheme,
			);

			if (input) {
				input.checked = true;
			}
		}
	},
);

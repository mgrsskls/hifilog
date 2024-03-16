let avifSupported = false;

const avif = new Image();

avif.onload = function () {
	avifSupported = true;
};

avif.src =
	"data:image/avif;base64,AAAAIGZ0eXBhdmlmAAAAAGF2aWZtaWYxbWlhZk1BMUIAAADybWV0YQAAAAAAAAAoaGRscgAAAAAAAAAAcGljdAAAAAAAAAAAAAAAAGxpYmF2aWYAAAAADnBpdG0AAAAAAAEAAAAeaWxvYwAAAABEAAABAAEAAAABAAABGgAAAB0AAAAoaWluZgAAAAAAAQAAABppbmZlAgAAAAABAABhdjAxQ29sb3IAAAAAamlwcnAAAABLaXBjbwAAABRpc3BlAAAAAAAAAAIAAAACAAAAEHBpeGkAAAAAAwgICAAAAAxhdjFDgQ0MAAAAABNjb2xybmNseAACAAIAAYAAAAAXaXBtYQAAAAAAAAABAAEEAQKDBAAAACVtZGF0EgAKCBgANogQEAwgMg8f8D///8WfhwB8+ErK42A=";

document.querySelectorAll(".ImageLightbox").forEach((gallery) => {
	const items = Array.from(gallery.querySelectorAll(".ImageLightbox-item"));
	const preloadedImages = [];

	let currentIndex;
	let keyDownListenerAdded = false;

	gallery.querySelectorAll(".ImageLightbox-thumb").forEach((button, i) => {
		button.addEventListener("click", () => {
			if (typeof currentIndex === "number") {
				hideImage(currentIndex);
			}

			showImage(i);
		});

		button.addEventListener("mouseover", () => {
			preloadImage(i);
		});
	});

	gallery.querySelectorAll(".ImageLightbox-dialog").forEach((dialog) => {
		dialog.addEventListener("click", ({ target }) => {
			if (target.tagName === "A") return;

			if (target.closest("button")) {
				const button = target.closest("button");

				if (button.getAttribute("rel") === "prev") {
					hideImage(currentIndex);
					showImage(currentIndex - 1);
				} else if (button.getAttribute("rel") === "next") {
					hideImage(currentIndex);
					showImage(currentIndex + 1);
				}
				return;
			}

			dialog.close();
		});
	});

	function hideImage(i) {
		items[i].querySelector("dialog").close();
	}

	function showImage(i) {
		const dialog = items[i].querySelector("dialog");
		if (!keyDownListenerAdded) {
			document.addEventListener("keydown", onKeyDown);
		}

		if (preloadedImages.includes(i)) {
			preloadImage(i + 1);
		} else {
			if (!preloadedImages.includes(currentIndex + 1)) {
				dialog.querySelector("img").addEventListener("load", () => {
					preloadImage(i + 1);
				});
			}
		}

		dialog.showModal();
		currentIndex = i;
		keyDownListenerAdded = true;
	}

	function onKeyDown({ key }) {
		if (!items[currentIndex].querySelector("dialog").open) return;

		switch (key) {
			case "ArrowLeft": {
				if (currentIndex > 0) {
					hideImage(currentIndex);
					showImage(currentIndex - 1);
				}
				break;
			}
			case "ArrowRight": {
				if (currentIndex < items.length - 1) {
					hideImage(currentIndex);
					showImage(currentIndex + 1);
				}
				break;
			}
		}
	}

	function preloadImage(index) {
		if (items[index] && !preloadedImages.includes(index)) {
			const image = new Image();
			const dialog = items[index].querySelector("dialog");

			if (dialog) {
				if (avifSupported) {
					image.src = dialog.querySelector("source").srcset;
				} else {
					image.src = dialog.querySelector("img").src;
				}

				preloadedImages.push(index);
			}
		}
	}
});

import "./theme_toggle.js";

{
  let scrollY = 0;

  document.querySelector(".Header-toggle").addEventListener("click", onMenuToggle);
  document.querySelector(".Filter-open").addEventListener("click", onOpenFilter);
  document.querySelector(".Filter-close").addEventListener("click", onCloseFilter);
  document.querySelectorAll(".Pagination input").forEach(input => {
    input.addEventListener("click", onFilterInput);
  });

  function onFilterInput2() {
    console.log(2)
  }

  function onFilterInput(e) {
    e.preventDefault();

    const input = e.target;

    if (input.hasAttribute("checked")) {
      input.checked = false;
    }

    input.closest("form").submit();
  }

  function onMenuToggle({ currentTarget: button }) {
    const shouldOpen = button.getAttribute('aria-expanded') === 'false';

    if (shouldOpen) {
      scrollY = window.scrollY;
      button.setAttribute('aria-expanded', 'true');
    } else {
      button.setAttribute('aria-expanded', 'false');
      window.requestAnimationFrame(() => window.scrollTo(0, scrollY));
    }
  }

  function onOpenFilter({ currentTarget: button }) {
    button.setAttribute('aria-expanded', 'true');
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
}

import "./theme_toggle.js";

{
  let scrollY = 0;

  function onMenuToggle({ currentTarget }) {
    const button = currentTarget;
    const shouldOpen = button.getAttribute('aria-expanded') === 'false';

    if (shouldOpen) {
      scrollY = window.scrollY;
      button.setAttribute('aria-expanded', 'true');
    } else {
      button.setAttribute('aria-expanded', 'false');
      window.requestAnimationFrame(() => window.scrollTo(0, scrollY));
    }
  }

  document.querySelector(".Header-toggle").addEventListener("click", onMenuToggle);
}

const form = document.querySelector(".NewProduct");
const input = document.querySelector("#brand-filter");
const addBrand = document.querySelector(".ProductFormAddBrand");
const searchResultsWrapper = document.querySelector(".Options--brands");
const template = document.querySelector("#brand-template");

if (form && searchResultsWrapper) {
  const headers = new Headers();
  headers.append("Accept", "application/json");

  fetch(form.dataset.url, {
    headers,
  })
  .then(res => res.json())
  .then(({ brands }) => {
    const elements = appendBrands(brands);

    render(input, elements, addBrand);

    if (input) {
      input.addEventListener("input", ({ target }) => {
        render(target, elements, addBrand);
      });
    }
  })
  .catch((e) => {
    alert("An error happened when loading the brands. Please reload the page. If this problem continues to exist, please contact us at info@hifilog.com.");
  });
}

function render(input, brands, addBrandForm) {
  const value = input.value.trim().toLowerCase();

  if (value.length > 0) {
    brands.forEach(brand => {
      if (brand.dataset.brand.startsWith(value)) {
        brand.hidden = false;
      } else {
        brand.hidden = true;
      }
    });

    if (addBrandForm) {
      addBrandForm.hidden = !brands.map(brand => brand.hidden).every((v) => v === true);
    }
  } else {
    brands.forEach(brand => {
      brand.hidden = true;
      brand.querySelector("input").checked = false;
    });

    addBrandForm.hidden = true;
  }
}

function appendBrands(brands) {
  const wrapper = searchResultsWrapper.cloneNode();

  brands.forEach(brand => {
    const clone = template.content.cloneNode(true);
    const input = clone.querySelector("input");
    const label = clone.querySelector("label");

    clone.firstElementChild.dataset.brand = brand.name.toLowerCase();
    input.value = brand.id;
    input.id = `brands-${brand.id}`;
    label.setAttribute("for", `brands-${brand.id}`);
    label.textContent = brand.name;

    wrapper.appendChild(clone);
  });

  searchResultsWrapper.replaceWith(wrapper);

  return Array.from(wrapper.children);
}

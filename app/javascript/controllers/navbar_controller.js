import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "dropdown", "rootDropdown" ]

  connect() {
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.boundHandleClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.closeAllDropdowns()
    }
  }

  closeAllDropdowns() {
    this.element.querySelectorAll('.dropdown-container').forEach(dropdown => {
      dropdown.classList.add("hidden")
    })
    this.element.querySelectorAll('svg.rotate-180, svg.rotate-90').forEach(svg => {
      svg.classList.remove("rotate-180", "rotate-90")
    })
  }

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  toggleMobileRoot(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const button = event.currentTarget;
    const rootLi = button.closest('li');
    const dropdown = rootLi.querySelector('.dropdown-container');
    
    // Hide other root dropdowns
    this.element.querySelectorAll('li > .dropdown-container').forEach(d => {
      if (d !== dropdown) {
        d.classList.add("hidden");
        const otherButton = d.closest('li').querySelector('button svg');
        if (otherButton) otherButton.classList.remove("rotate-180", "rotate-90");
      }
    });

    if (dropdown) {
      dropdown.classList.toggle("hidden");
      const svg = button.querySelector('svg');
      if (svg) svg.classList.toggle("rotate-180");
    }
  }

  toggleDropdown(event) {
    event.preventDefault();
    event.stopPropagation();
    
    const button = event.currentTarget;
    const container = button.closest('.relative');
    const dropdown = container.querySelector(':scope > .dropdown-container');
    
    // Hide sibling dropdowns
    const parentContainer = container.parentElement;
    if (parentContainer) {
      parentContainer.querySelectorAll(':scope > .relative > .dropdown-container').forEach(d => {
        if (d !== dropdown) {
          d.classList.add("hidden");
          const siblingButton = d.previousElementSibling?.querySelector('button svg');
          if (siblingButton) siblingButton.classList.remove("rotate-180", "rotate-90");
        }
      });
    }

    if (dropdown) {
      const isHidden = dropdown.classList.toggle("hidden");
      const svg = button.querySelector('svg');
      if (svg) {
        if (window.innerWidth >= 768) {
          isHidden ? svg.classList.remove("rotate-90") : svg.classList.add("rotate-90");
        } else {
          isHidden ? svg.classList.remove("rotate-180") : svg.classList.add("rotate-180");
        }
      }
    }
  }
}

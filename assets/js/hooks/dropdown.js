export const hooks = {
  Dropdown: {
    mounted() {
        const button = this.el.querySelector('.item-dropdown-button');
        if (!button) return;

        const updatePosition = () => {
            const rect = button.getBoundingClientRect();
            const windowWidth = window.innerWidth;

            const distanceToLeft = rect.left;
            const distanceToRight = windowWidth - rect.right;

            this.el.classList.remove('dropdown-left', 'dropdown-right');

            if (distanceToLeft > distanceToRight) {
                this.el.classList.add('dropdown-left');
            } else {
                this.el.classList.add('dropdown-right');
            }
        };
        
        button.addEventListener('mousedown', updatePosition);
        button.addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ') {
            updatePosition();
        }
        });
    }
  }
}
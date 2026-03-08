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

            // Удаляем оба класса направления
            this.el.classList.remove('dropdown-left', 'dropdown-right');

            if (distanceToLeft > distanceToRight) {
                // Кнопка ближе к правому краю → меню слева
                this.el.classList.add('dropdown-left');
            } else {
                // Кнопка ближе к левому краю или равноудалена → меню справа
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
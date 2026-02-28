export const hooks = {
  Tooltip: {
    mounted() {
      this.el.addEventListener('mouseenter', e => {
        // Создаём элемент тултипа, но пока скрываем
        const tooltip = document.createElement('div');
        tooltip.className = 'fixed bg-neutral text-white p-2 rounded shadow-lg text-xs z-1000';
        tooltip.innerHTML = this.el.dataset.tooltip;   // здесь уже готовый HTML
        tooltip.style.left = e.clientX + 40 + 'px';   // смещение вправо от курсора
        tooltip.style.top = '0px';                     // временно
        tooltip.style.opacity = '0';                    // невидим
        tooltip.style.pointerEvents = 'none';           // не перехватывает мышь
        tooltip.id = 'tooltip-' + this.el.id;
        document.body.appendChild(tooltip);

        // Получаем реальную высоту тултипа
        const tooltipHeight = tooltip.offsetHeight;

        // Расстояние от курсора до нижнего края окна
        const viewportHeight = window.innerHeight;
        const distanceToBottom = viewportHeight - e.clientY;
        const BOTTOM_THRESHOLD = 200; // порог в пикселях

        let top;
        if (distanceToBottom <= BOTTOM_THRESHOLD) {
          // Показываем сверху
          top = e.clientY - tooltipHeight - 5;
          // Если слишком высоко – прижимаем к верхнему краю
          if (top < 0) top = 5;
        } else {
          // Показываем снизу
          top = e.clientY + 5;
        }

        // Устанавливаем финальную позицию и показываем
        tooltip.style.top = top + 'px';
        tooltip.style.opacity = '1';
        tooltip.style.pointerEvents = 'auto';

        this.tooltip = tooltip; // сохраняем для удаления
      });

      this.onDocumentKeydown = (event) => {
        if (event.key === 'Escape' && this.tooltip) {
          this.tooltip.remove();
          this.tooltip = null;
        }
      };
      document.addEventListener('keydown', this.onDocumentKeydown);

      events = ['mouseleave', 'click'];

      events.forEach(event => {
        this.el.addEventListener(event, () => {
          if (this.tooltip) {
            this.tooltip.remove();
            this.tooltip = null;
          }
        });
      });
    }
  }
}
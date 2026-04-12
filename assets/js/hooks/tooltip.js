export const hooks = {
  Tooltip: {
    mounted() {
      this.el.addEventListener('mouseenter', e => {
        const tooltip = document.createElement('div');
        
        tooltip.className = 'fixed bg-neutral text-white p-2 rounded shadow-lg text-xs z-1000 phx-tooltip';
        tooltip.innerHTML = this.el.dataset.tooltip;
        tooltip.style.left = e.clientX + 40 + 'px';
        tooltip.style.top = '0px';
        tooltip.style.opacity = '0';
        tooltip.style.pointerEvents = 'none';
        tooltip.id = 'tooltip-' + this.el.id;
        document.body.appendChild(tooltip);

        const tooltipHeight = tooltip.offsetHeight;
        const viewportHeight = window.innerHeight;
        const distanceToBottom = viewportHeight - e.clientY;
        const BOTTOM_THRESHOLD = 200;
        let top;
        if (distanceToBottom <= BOTTOM_THRESHOLD) {
          top = e.clientY - tooltipHeight - 5;
          if (top < 0) top = 5;
        } else {
          top = e.clientY + 5;
        }
        tooltip.style.top = top + 'px';
        tooltip.style.opacity = '1';
        tooltip.style.pointerEvents = 'auto';

        this.tooltip = tooltip;
      });

      this.onDocumentKeydown = (event) => {
        if (event.key === 'Escape') {
          document.querySelectorAll('.phx-tooltip').forEach(t => t.remove());
          if (this.tooltip) this.tooltip = null;
        }
      };
      document.addEventListener('keydown', this.onDocumentKeydown);

      ['mouseleave', 'click'].forEach(event => {
        this.el.addEventListener(event, () => {
          if (this.tooltip) {
            this.tooltip.remove();
            this.tooltip = null;
          }
        });
      });
    },

    destroyed() {
      document.removeEventListener('keydown', this.onDocumentKeydown);
      if (this.tooltip) {
        this.tooltip.remove();
        this.tooltip = null;
      }
    }
  }
};
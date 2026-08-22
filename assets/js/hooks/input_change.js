export const hooks = {
  InputChange: {
    mounted() {
      const el = this.el;

      const applyMinIfEmpty = () => {
        if (el.type === 'number' && el.dataset.min !== undefined) {
          if (el.value === '') {
            const min = parseFloat(el.dataset.min);
            if (!isNaN(min)) {
              el.value = String(min);
              return String(min);
            }
          }
        }
        return el.value;
      };

      applyMinIfEmpty();

      el.addEventListener('input', (e) => {
        const eventName = el.dataset.event;
        if (!eventName) return;

        let value = e.target.value;

        if (el.type === 'number' && el.dataset.max !== undefined) {
          const max = parseFloat(el.dataset.max);
          if (!isNaN(max)) {
            const numValue = parseFloat(value);
            if (!isNaN(numValue) && numValue > max) {
              e.target.value = String(max);
              value = String(max);
            }
          }
        }

        if (el.type === 'number' && el.dataset.min !== undefined) {
          if (value === '' || value < el.dataset.min) {
            const min = parseFloat(el.dataset.min);
            if (!isNaN(min)) {
              e.target.value = String(min);
              value = String(min);
            }
          }
        }

        this.pushEvent(eventName, { value });
      });

      this.handleEvent("apply_max", (payload) => {
        if (payload.id && payload.id !== el.id) return;

        if (el.type === 'number' && el.dataset.max !== undefined) {
          const max = parseFloat(el.dataset.max);
          if (!isNaN(max)) {
            el.value = String(max);
            const eventName = el.dataset.event;
            if (eventName) {
              this.pushEvent(eventName, { value: String(max) });
            }
          }
        }
      });
    }
  }
};
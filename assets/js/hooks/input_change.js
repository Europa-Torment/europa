export const hooks = {
  InputChange: {
    mounted() {
      this.el.addEventListener('input', (e) => {
        const eventName = this.el.dataset.event;
        if (!eventName) {
          return;
        }

        this.pushEvent(eventName, { value: e.target.value });
      });
    }
  }
};
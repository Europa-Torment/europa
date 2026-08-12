export const hooks = {
  ScrollOnChange: {
      updated() {
          this.el.scrollTop = 0;
      }
  }
};
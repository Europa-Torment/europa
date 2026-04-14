export const hooks = {
  AutoClearFlash: {
    mounted() {
        let ignoredIDs = [];
        if (ignoredIDs.includes(this.el.id)) return;

        let hideElementAfter = 3500; // ms
        let clearFlashAfter = hideElementAfter + 10; // ms

        setTimeout(() => {
            this.el.style.opacity = 0;
        }, hideElementAfter);

        setTimeout(() => {
            this.pushEvent("lv:clear-flash");
        }, clearFlashAfter);
    }
  }
}
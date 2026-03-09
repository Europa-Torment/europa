export const hooks = {
  ItemDropChangeCount: {
    mounted() {
      this.el.addEventListener('input', e => {
      this.pushEvent("change_item_drop_count", { item_drop_count: e.target.value })
    })
    }
  }
}
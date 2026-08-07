export const hooks = {
    Map: {
        mounted() {
            this.blink = true

            this.interval = setInterval(() => {
                this.blink = !this.blink
                this.drawMap()
            }, 500)

            this.setupDrag()
            this.drawMap()
        },

        updated() {
            this.drawMap()
        },

        destroyed() {
            this.removeDrag()
            if (this.interval) {
                clearInterval(this.interval)
            }
        },

        setupDrag() {
            const sensitivity = 5
            let startX = 0,
                startY = 0
            let startOffsetX = 0,
                startOffsetY = 0
            let lastMoveEvent = null
            let throttleId = null

            const onMouseDown = (e) => {
                this.isDragging = true
                startX = e.clientX
                startY = e.clientY
                startOffsetX = parseInt(this.el.dataset.offsetX || 0)
                startOffsetY = parseInt(this.el.dataset.offsetY || 0)
                this.el.style.cursor = 'grabbing'
                e.preventDefault()
            }

            const onMouseMove = (e) => {
                if (!this.isDragging) return
                lastMoveEvent = e
                if (throttleId) return
                throttleId = requestAnimationFrame(() => {
                    if (lastMoveEvent) {
                        const dx = lastMoveEvent.clientX - startX
                        const dy = lastMoveEvent.clientY - startY

                        const newX = Math.trunc(startOffsetX - (dx / sensitivity))
                        const newY = Math.trunc(startOffsetY - (dy / sensitivity))

                        this.offsetX = newX
                        this.offsetY = newY

                        lastMoveEvent = null
                    }
                    throttleId = null
                })
            }

            const onMouseUp = () => {
                this.isDragging = false
                this.el.style.cursor = 'grab'
                if (throttleId) {
                    cancelAnimationFrame(throttleId)
                    throttleId = null
                }
                lastMoveEvent = null

                this.pushEventTo(this.el, "move_map", {
                    offset_x: this.offsetX,
                    offset_y: this.offsetY
                })
            }

            this.el.addEventListener('mousedown', onMouseDown)
            document.addEventListener('mousemove', onMouseMove)
            document.addEventListener('mouseup', onMouseUp)

            this._onMouseDown = onMouseDown
            this._onMouseMove = onMouseMove
            this._onMouseUp = onMouseUp
        },

        removeDrag() {
            this.el.removeEventListener('mousedown', this._onMouseDown)
            document.removeEventListener('mousemove', this._onMouseMove)
            document.removeEventListener('mouseup', this._onMouseUp)
        },

        drawMap() {
            const canvas = this.el
            const ctx = canvas.getContext('2d')
            const data = JSON.parse(this.el.dataset.map)
            const cols = parseInt(this.el.dataset.cols)
            const rows = parseInt(this.el.dataset.rows)

            const rect = canvas.getBoundingClientRect()
            const dpr = window.devicePixelRatio || 1
            canvas.width = rect.width * dpr
            canvas.height = rect.height * dpr
            ctx.scale(dpr, dpr)

            ctx.imageSmoothingEnabled = false

            const cellSize = Math.floor(Math.min(rect.width / cols, rect.height / rows))
            const totalWidth = cellSize * cols
            const totalHeight = cellSize * rows
            const offsetX = Math.floor((rect.width - totalWidth) / 2)
            const offsetY = Math.floor((rect.height - totalHeight) / 2)

            const overlap = 0.5

            data.forEach((row, y) => {
                row.forEach((cell, x) => {
                    const left = offsetX + x * cellSize - overlap
                    const top = offsetY + y * cellSize - overlap
                    const size = cellSize + overlap * 2
                    ctx.fillStyle = cell.color
                    ctx.fillRect(left, top, size, size)
                })
            })

            const fontSize = cellSize * 1.2
            ctx.textAlign = 'center'
            ctx.textBaseline = 'middle'
            ctx.font = `${fontSize}px monospace`
            
            data.forEach((row, y) => {
                row.forEach((cell, x) => {
                    if (cell.char && this.blink) {
                        const cx = offsetX + x * cellSize + cellSize / 2
                        const cy = offsetY + y * cellSize + cellSize / 2
                        ctx.fillStyle = cell.text_color
                        ctx.fillText(cell.char, cx, cy)
                    }
                })
            })
        }
    }
};
export const hooks = {
  Aim: {
      mounted() {
        this.aims = JSON.parse(this.el.dataset.aims || '[]');
        this.show = this.el.dataset.show_aim == "true";
        this.svg = null;
        this.drawScheduled = false;

        this.drawAll = this.drawAll.bind(this);
        this.scheduleDraw = this.scheduleDraw.bind(this);
        this.updateVisibility = this.updateVisibility.bind(this);

        this.updateVisibility();

        this.resizeObserver = new ResizeObserver(() => this.scheduleDraw());
        this.resizeObserver.observe(document.body);
        window.addEventListener('resize', this.scheduleDraw);
        window.addEventListener('scroll', this.scheduleDraw);
    },

    updated() {
        const newShow = this.el.dataset.show_aim == "true";
        const newAims = JSON.parse(this.el.dataset.aims || '[]');

        if (newShow !== this.show || JSON.stringify(newAims) !== JSON.stringify(this.aims)) {
            this.show = newShow;
            this.aims = newAims;
            this.updateVisibility();
        } else if (this.show) {
            this.scheduleDraw();
        }
    },

    destroyed() {
        this.resizeObserver?.disconnect();
        window.removeEventListener('resize', this.scheduleDraw);
        window.removeEventListener('scroll', this.scheduleDraw);
        if (this.svg) this.svg.remove();
    },

    scheduleDraw() {
        if (this.drawScheduled) return;
            this.drawScheduled = true;
            requestAnimationFrame(() => {
            this.drawAll();
            this.drawScheduled = false;
        });
    },

    drawAll() {
        if (!this.show || !this.aims.length) return;

        if (!this.svg) {
            this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
            this.svg.setAttribute('class', 'multi-arrows-layer');
            this.svg.style.position = 'fixed';
            this.svg.style.top = '0';
            this.svg.style.left = '0';
            this.svg.style.width = '100%';
            this.svg.style.height = '100%';
            this.svg.style.pointerEvents = 'none';
            this.svg.style.zIndex = '100';

            document.body.appendChild(this.svg);
        }

        while (this.svg.firstChild) {
            this.svg.removeChild(this.svg.firstChild);
        }

        const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
        const marker = document.createElementNS('http://www.w3.org/2000/svg', 'marker');
        marker.setAttribute('id', 'multi-arrowhead');
        marker.setAttribute('markerWidth', '10');
        marker.setAttribute('markerHeight', '7');
        marker.setAttribute('refX', '9');
        marker.setAttribute('refY', '3.5');
        marker.setAttribute('orient', 'auto');
        const polygon = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
        polygon.setAttribute('points', '0 0, 10 3.5, 0 7');
        polygon.setAttribute('fill', 'green');
        marker.appendChild(polygon);
        defs.appendChild(marker);
        this.svg.appendChild(defs);

        this.aims.forEach((pair, idx) => {
            const fromEl = document.querySelector(pair.from);
            const toEl = document.querySelector(pair.to);
            if (!fromEl || !toEl) return;

            const rectFrom = fromEl.getBoundingClientRect();
            const rectTo = toEl.getBoundingClientRect();
            const x1 = rectFrom.left + rectFrom.width / 2;
            const y1 = rectFrom.top + rectFrom.height / 2;
            const x2 = rectTo.left + rectTo.width / 2;
            const y2 = rectTo.top + rectTo.height / 2;

            const gradientId = `gradient-${idx}`;
            const gradient = document.createElementNS('http://www.w3.org/2000/svg', 'linearGradient');
            gradient.setAttribute('id', gradientId);
            gradient.setAttribute('x1', x1);
            gradient.setAttribute('y1', y1);
            gradient.setAttribute('x2', x2);
            gradient.setAttribute('y2', y2);
            gradient.setAttribute('gradientUnits', 'userSpaceOnUse');

            const lineColor = 'green';
            const stop1 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
            stop1.setAttribute('offset', '0%');
            stop1.setAttribute('stop-color', lineColor);
            stop1.setAttribute('stop-opacity', '0');
            const stop2 = document.createElementNS('http://www.w3.org/2000/svg', 'stop');
            stop2.setAttribute('offset', '100%');
            stop2.setAttribute('stop-color', lineColor);
            stop2.setAttribute('stop-opacity', '1');

            gradient.appendChild(stop1);
            gradient.appendChild(stop2);
            this.svg.appendChild(gradient);

            const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
            line.setAttribute('x1', x1);
            line.setAttribute('y1', y1);
            line.setAttribute('x2', x2);
            line.setAttribute('y2', y2);
            line.setAttribute('stroke', `url(#${gradientId})`);
            line.setAttribute('stroke-width', '1');
            line.setAttribute('marker-end', 'url(#multi-arrowhead)');

            this.svg.appendChild(line);
        });
    },

    updateVisibility() {
        if (this.show) {
            this.scheduleDraw();
        } else if (this.svg) {
            this.svg.remove();
            this.svg = null;
        }
    }
  }
}
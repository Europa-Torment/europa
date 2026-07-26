export const hooks = {
  EventsProcessor: {
    mounted() {
      this.interval = parseInt(this.el.dataset.interval) || 1000;

      this.filterStyles = {
        red: "grayscale(100%) sepia(100%) hue-rotate(320deg) saturate(500%)",
        green: "grayscale(100%) sepia(100%) hue-rotate(60deg) saturate(200%)",
        blue: "grayscale(100%) sepia(100%) hue-rotate(175deg) saturate(400%)"
      };

      this.activeTooltips = {};
      this.activeFieldFilter = null;
      this.isTickerRunning = false;

      this.renderTooltip = (element, tooltipData) => {
        if (!element) return;
        const { text, icon } = tooltipData;

        this.removeTooltipElement(element);

        element.style.position = "relative";

        const tooltipEl = document.createElement("div");
        tooltipEl.className = "custom-events-tooltip";

        tooltipEl.style.cssText = `
          position: absolute;
          bottom: calc(100% + 8px);
          left: 50%;
          transform: translateX(-50%);
          background: transparent !important;
          color: #fff;
          padding: 0;
          border-radius: 0;
          font-size: 12px;
          white-space: nowrap;
          display: flex;
          align-items: center;
          gap: 4px;
          pointer-events: none;
          z-index: 999;
          text-shadow: 0 0 4px rgba(0, 0, 0, 0.9);
        `;

        if (icon) {
          const img = document.createElement("img");
          img.src = `/images/icons/${icon}.png`;
          img.style.cssText = "height: 1.2em; width: auto; display: inline-block; vertical-align: middle;";
          img.onerror = () => { img.style.display = "none"; };
          tooltipEl.appendChild(img);
        }

        const textNode = document.createTextNode(text);
        tooltipEl.appendChild(textNode);

        element.appendChild(tooltipEl);
        element._customTooltip = tooltipEl;
      };

      this.removeTooltipElement = (element) => {
        if (element._customTooltip) {
          element._customTooltip.remove();
          delete element._customTooltip;
        }
      };

      this.applyTooltip = (elementId, tooltipData) => {
        const element = document.getElementById(elementId);
        if (element) {
          this.renderTooltip(element, tooltipData);
          element.classList.add("has-tooltip");
        }
      };

      this.removeTooltip = (elementId) => {
        delete this.activeTooltips[elementId];
        const element = document.getElementById(elementId);
        if (element) {
          this.removeTooltipElement(element);
          element.classList.remove("has-tooltip");
        }
      };

      this.fetchEvents = () => {
        this.pushEvent("get_events", {}, (reply) => {
          const incomingIds = new Set();
          let currentTickFilter = null;
          const now = Date.now();
          const expiresAt = now + this.interval;

          if (reply && reply.events && reply.events.length > 0) {
            reply.events.forEach(({ event_owner, event_text, filter, icon }) => {
              const elementId = `tile_${event_owner}`;
              incomingIds.add(elementId);

              if (filter && this.filterStyles[filter]) {
                currentTickFilter = filter;
              }

              this.activeTooltips[elementId] = {
                text: event_text,
                icon: icon || null,
                expiresAt: expiresAt
              };
              this.applyTooltip(elementId, this.activeTooltips[elementId]);
            });
          }

          Object.keys(this.activeTooltips).forEach(elementId => {
            const tooltip = this.activeTooltips[elementId];
            if (!incomingIds.has(elementId) && now >= tooltip.expiresAt) {
              this.removeTooltip(elementId);
            }
          });

          if (currentTickFilter) {
            this.activeFieldFilter = { type: currentTickFilter, expiresAt: expiresAt };
            this.el.style.filter = this.filterStyles[currentTickFilter];
          } else if (this.activeFieldFilter && now >= this.activeFieldFilter.expiresAt) {
            this.el.style.filter = "";
            this.activeFieldFilter = null;
          }

          const hasAnyActiveEffects = Object.keys(this.activeTooltips).length > 0 || this.activeFieldFilter !== null;
          if (!hasAnyActiveEffects && (!reply || !reply.events || reply.events.length === 0)) {
            this.stopTicker();
          }
        });
      };

      this.startTicker = () => {
        if (this.isTickerRunning) return;
        if (this.ticker) clearInterval(this.ticker);
        this.ticker = setInterval(() => {
          this.fetchEvents();
        }, this.interval);
        this.isTickerRunning = true;
      };

      this.stopTicker = () => {
        if (this.ticker) {
          clearInterval(this.ticker);
          this.ticker = null;
        }
        this.isTickerRunning = false;
      };

      this.handleEvent("start_events_polling", () => {
        if (!this.isTickerRunning) {
          this.fetchEvents();
          this.startTicker();
        }
      });

      this.fetchEvents();
      this.startTicker();
    },

    updated() {
      const now = Date.now();
      let hasActiveEvents = false;

      for (const elementId in this.activeTooltips) {
        const tooltip = this.activeTooltips[elementId];
        if (now < tooltip.expiresAt) {
          this.applyTooltip(elementId, tooltip);
          hasActiveEvents = true;
        } else {
          this.removeTooltip(elementId);
        }
      }

      if (this.activeFieldFilter && now < this.activeFieldFilter.expiresAt) {
        this.el.style.filter = this.filterStyles[this.activeFieldFilter.type];
        hasActiveEvents = true;
      } else {
        this.el.style.filter = "";
        this.activeFieldFilter = null;
      }

      if (!hasActiveEvents) {
        this.fetchEvents();
        this.startTicker();
      }
    },

    destroyed() {
      this.stopTicker();
      for (const elementId in this.activeTooltips) {
        this.removeTooltip(elementId);
      }
    }
  }
};
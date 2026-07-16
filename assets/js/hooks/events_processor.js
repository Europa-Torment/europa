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

            this.getClassesForElement = (elementId) => {
                const baseClasses = ["tooltip", "tooltip-events", "tooltip-open"];
                const colorClass = elementId === "tile_player" ? "tooltip-warning" : "tooltip-error";
                return [...baseClasses, colorClass];
            };

            this.fetchEvents = () => {
                this.pushEvent("get_events", {}, (reply) => {
                    const incomingIds = new Set();
                    let currentTickFilter = null;
                    const now = Date.now();
                    const expiresAt = now + this.interval;

                    if (reply && reply.events && reply.events.length > 0) {
                        reply.events.forEach(({
                            event_owner,
                            event_text,
                            filter
                        }) => {
                            const elementId = `tile_${event_owner}`;
                            incomingIds.add(elementId);

                            if (filter && this.filterStyles[filter]) {
                                currentTickFilter = filter;
                            }

                            const element = document.getElementById(elementId);
                            if (element) {
                                this.activeTooltips[elementId] = { text: event_text, expiresAt: expiresAt };
                                this.applyTooltip(element, event_text);
                            }
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

            this.applyTooltip = (element, text) => {
                element.setAttribute("data-tip", text);
                const classes = this.getClassesForElement(element.id);
                classes.forEach(className => element.classList.add(className));
            };

            this.removeTooltip = (elementId) => {
                delete this.activeTooltips[elementId];
                const element = document.getElementById(elementId);
                if (element) {
                    const classes = this.getClassesForElement(elementId);
                    classes.forEach(className => element.classList.remove(className));
                    element.removeAttribute("data-tip");
                }
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
                    const element = document.getElementById(elementId);
                    if (element) {
                        this.applyTooltip(element, tooltip.text);
                        hasActiveEvents = true;
                    }
                } else {
                    delete this.activeTooltips[elementId];
                }
            }

            if (this.activeFieldFilter && now < this.activeFieldFilter.expiresAt) {
                this.el.style.filter = this.filterStyles[this.activeFieldFilter.type];
                hasActiveEvents = true;
            } else {
                this.activeFieldFilter = null;
            }

            if (!hasActiveEvents) {
                this.fetchEvents();
                this.startTicker();
            }
        },

        destroyed() {
            this.stopTicker();
        }
    }
}

const DeliveryZoneMap = {
  mounted() {
    try {
      if (typeof L === "undefined") {
        console.error("[DeliveryZoneMap] Leaflet (L) is not loaded. Include Leaflet.js and Leaflet.draw.js")
        return
      }

      const el = this.el
      const shopName = el.dataset.shopName || null
      const readOnly = el.dataset.readonly === "true"
      this.boundaryInput = document.getElementById(el.dataset.boundaryInputId || "")
      const defaultCenter = [-1.286389, 36.817223]
      const defaultZoom = 11

      this.map = L.map(el, {
        preferCanvas: true,
        zoomAnimation: false,
        fadeAnimation: false,
        markerZoomAnimation: false,
        zoomControl: true
      }).setView(defaultCenter, defaultZoom)

      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap contributors',
        maxZoom: 18,
        updateWhenIdle: true,
        updateWhenZooming: false,
        keepBuffer: 1
      }).addTo(this.map)

      this.drawnItems = new L.FeatureGroup()
      this.map.addLayer(this.drawnItems)

      if (!readOnly) {
        this.drawControl = new L.Control.Draw({
          draw: {
            polyline: false,
            rectangle: false,
            circle: false,
            circlemarker: false,
            marker: false,
            polygon: {
              allowIntersection: false,
              showArea: true,
              shapeOptions: { color: '#7c3aed', weight: 2, fillOpacity: 0.15 }
            }
          },
          edit: { featureGroup: this.drawnItems }
        })

        this.map.addControl(this.drawControl)

        this.map.on(L.Draw.Event.CREATED, (ev) => {
          const layer = ev.layer
          this.drawnItems.clearLayers()
          this.drawnItems.addLayer(layer)
          const geojson = layer.toGeoJSON()
          this._syncBoundary(geojson)
        })

        this.map.on(L.Draw.Event.EDITSTOP, () => {
          const layers = this.drawnItems.getLayers()
          if (layers.length > 0) {
            const geojson = layers[0].toGeoJSON()
            this._syncBoundary(geojson)
          } else {
            this._syncBoundary({})
          }
        })

        this.map.on(L.Draw.Event.DELETED, () => {
          this.drawnItems.clearLayers()
          this._syncBoundary({})
        })
      }

      // If initial geojson present in data attribute, load it
      const initial = el.dataset.initialGeojson
      if (initial && initial.length > 0) {
        try {
          const parsed = JSON.parse(initial)
          this._loadGeoJSON(parsed)
        } catch (e) {
          console.warn('[DeliveryZoneMap] invalid initial geojson', e)
        }
      }

      requestAnimationFrame(() => {
        if (this.map) {
          this.map.invalidateSize({ animate: false })
        }
      })

      this.pushEvent('map_ready', { shop_name: shopName })
    } catch (err) {
      console.error('[DeliveryZoneMap] init err', err)
    }
  },

  _loadGeoJSON(geojson) {
    this.drawnItems.clearLayers()
    try {
      const layer = L.geoJSON(geojson)
      layer.eachLayer(l => this.drawnItems.addLayer(l))
      const bounds = this.drawnItems.getBounds()
      if (bounds.isValid && bounds.isValid()) {
        this.map.fitBounds(bounds, { maxZoom: 14, padding: [20, 20], animate: false })
      }
    } catch (e) {
      console.warn('[DeliveryZoneMap] load failed', e)
    }
  },

  _syncBoundary(geojson) {
    const payload = geojson && Object.keys(geojson).length > 0 ? JSON.stringify(geojson.geometry || geojson) : ""

    if (this.boundaryInput) {
      this.boundaryInput.value = payload
      this.boundaryInput.dispatchEvent(new Event("input", { bubbles: true }))
      this.boundaryInput.dispatchEvent(new Event("change", { bubbles: true }))
    } else {
      this.pushEvent("zone_drawn", geojson)
    }
  },

  updated() {
    // allow server to push initial geojson via data attribute updates
    const initial = this.el.dataset.initialGeojson
    if (initial && initial.length > 0) {
      try { this._loadGeoJSON(JSON.parse(initial)) } catch (_) {}
    }

    if (this.map) {
      this.map.invalidateSize({ animate: false })
    }
  },

  destroyed() {
    if (this.map) { this.map.remove(); this.map = null }
  }
}

export default DeliveryZoneMap

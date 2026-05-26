const ShopLocationMap = {
  mounted() {
    try {
      if (typeof L === "undefined") {
        console.error("[ShopLocationMap] Leaflet (L) is not loaded. Include Leaflet.js")
        return
      }

      const el = this.el
      this.latInput = document.getElementById(el.dataset.latInputId || "")
      this.lngInput = document.getElementById(el.dataset.lngInputId || "")
      this.addressInput = document.getElementById(el.dataset.addressInputId || "")
      const defaultCenter = [-1.286389, 36.817223]
      const defaultZoom = 13

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

      this.marker = null

      // Handle map clicks to set marker
      this.map.on('click', (e) => {
        const { lat, lng } = e.latlng
        this._setMarker(lat, lng)
      })

      // Load initial marker if lat/lng are set
      const initialLat = this.latInput?.value
      const initialLng = this.lngInput?.value
      if (initialLat && initialLng) {
        this._setMarker(parseFloat(initialLat), parseFloat(initialLng))
      }

      requestAnimationFrame(() => {
        if (this.map) {
          this.map.invalidateSize({ animate: false })
        }
      })
    } catch (err) {
      console.error('[ShopLocationMap] init err', err)
    }
  },

  _setMarker(lat, lng) {
    if (this.marker) {
      this.map.removeLayer(this.marker)
    }

    this.marker = L.marker([lat, lng]).addTo(this.map)
    this.map.setView([lat, lng], 15)

    // Update hidden inputs
    if (this.latInput) {
      this.latInput.value = lat
      this.latInput.dispatchEvent(new Event("input", { bubbles: true }))
      this.latInput.dispatchEvent(new Event("change", { bubbles: true }))
    }
    if (this.lngInput) {
      this.lngInput.value = lng
      this.lngInput.dispatchEvent(new Event("input", { bubbles: true }))
      this.lngInput.dispatchEvent(new Event("change", { bubbles: true }))
    }

    // Reverse geocode to get address
    this._reverseGeocode(lat, lng)
  },

  async _reverseGeocode(lat, lng) {
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${lat}&lon=${lng}`,
        {
          headers: {
            'User-Agent': 'smart-kiosk/1.0'
          }
        }
      )
      const data = await response.json()
      if (data && data.display_name && this.addressInput) {
        this.addressInput.value = data.display_name
        this.addressInput.dispatchEvent(new Event("input", { bubbles: true }))
        this.addressInput.dispatchEvent(new Event("change", { bubbles: true }))
      }
    } catch (err) {
      console.warn('[ShopLocationMap] reverse geocode failed', err)
    }
  },

  updated() {
    if (this.map) {
      this.map.invalidateSize({ animate: false })
    }
  },

  destroyed() {
    if (this.map) { this.map.remove(); this.map = null }
  }
}

export default ShopLocationMap

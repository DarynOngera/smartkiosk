// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import DeliveryZoneMap from "./hooks/delivery_zone_map"
import ShopLocationMap from "./hooks/shop_location_map"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Theme Toggle Hook
const ThemeToggle = {
  mounted() {
    this.el.addEventListener("click", () => this.toggleTheme())
    this.updateIcon()
  },

  toggleTheme() {
    const html = document.documentElement
    const currentTheme = html.getAttribute("data-theme") || "light"
    const newTheme = currentTheme === "light" ? "dark" : "light"

    html.setAttribute("data-theme", newTheme)
    localStorage.setItem("theme", newTheme)
    this.updateIcon()
  },

  updateIcon() {
    const html = document.documentElement
    const currentTheme = html.getAttribute("data-theme") || "light"
    const sunIcon = this.el.querySelector(".sun-icon")
    const moonIcon = this.el.querySelector(".moon-icon")

    if (currentTheme === "dark") {
      sunIcon.classList.remove("hidden")
      moonIcon.classList.add("hidden")
    } else {
      sunIcon.classList.add("hidden")
      moonIcon.classList.remove("hidden")
    }
  }
}

// PrintReceipt hook: handles print and share events
const PrintReceipt = {
  mounted() {
    this.handleEvent("print_receipt", () => window.print())
    this.handleEvent("share", ({text}) => {
      if (navigator.share) {
        try { navigator.share({ title: "Receipt", text }) } catch (e) { console.error(e) }
      } else if (navigator.clipboard) {
        navigator.clipboard.writeText(text).then(() => alert("Receipt copied to clipboard"))
      } else {
        alert("Sharing not supported on this device")
      }
    })
  }
}

// Polygon Drawer hook for drawing GeoJSON polygons without external libs
const PolygonDrawer = {
  mounted() {
    this.canvas = this.el.querySelector('#zone-canvas')
    this.textarea = document.querySelector('#delivery-zone-form textarea[name="delivery_zone[boundary]"]')
    this.points = []
    this.svg = null

    // Create SVG overlay
    this.svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    this.svg.setAttribute('class', 'absolute inset-0 w-full h-full')
    this.svg.style.width = '100%'
    this.svg.style.height = '100%'
    this.svg.style.left = '0'
    this.svg.style.top = '0'
    this.svg.style.position = 'absolute'
    this.canvas.appendChild(this.svg)

    // Click to add point
    this.canvas.addEventListener('click', e => {
      const rect = this.canvas.getBoundingClientRect()
      const x = e.clientX - rect.left
      const y = e.clientY - rect.top
      this.addPoint([x, y])
    })

    // Buttons
    const undo = this.el.querySelector('#zd-undo')
    const clear = this.el.querySelector('#zd-clear')
    const exportBtn = this.el.querySelector('#zd-export')

    undo && undo.addEventListener('click', () => { this.undo() })
    clear && clear.addEventListener('click', () => { this.clear() })
    exportBtn && exportBtn.addEventListener('click', () => { this.exportGeoJSON() })

    // If a textarea already has JSON, try to render it
    try { this.loadFromTextarea() } catch (e) { /* ignore */ }
  },

  addPoint(pt) {
    this.points.push(pt)
    this.render()
  },

  undo() {
    this.points.pop()
    this.render()
  },

  clear() {
    this.points = []
    this.render()
    if(this.textarea) this.textarea.value = ''
  },

  render() {
    while (this.svg.firstChild) this.svg.removeChild(this.svg.firstChild)
    if (this.points.length === 0) return

    // Draw polygon
    const polygon = document.createElementNS('http://www.w3.org/2000/svg','polygon')
    polygon.setAttribute('points', this.points.map(p => p.join(',')).join(' '))
    polygon.setAttribute('fill', 'rgba(124,58,237,0.25)')
    polygon.setAttribute('stroke', 'rgba(124,58,237,0.9)')
    polygon.setAttribute('stroke-width', '2')
    this.svg.appendChild(polygon)

    // Draw markers
    this.points.forEach(p => {
      const c = document.createElementNS('http://www.w3.org/2000/svg','circle')
      c.setAttribute('cx', p[0])
      c.setAttribute('cy', p[1])
      c.setAttribute('r', 4)
      c.setAttribute('fill', 'white')
      c.setAttribute('stroke', 'rgba(124,58,237,0.9)')
      c.setAttribute('stroke-width', '2')
      this.svg.appendChild(c)
    })
  },

  exportGeoJSON() {
    if (!this.textarea) return
    // Convert pixel coordinates to a simple lon/lat approximation by
    // mapping canvas coordinates to bbox [-180,180]x[-90,90] — admin can edit later.
    const rect = this.canvas.getBoundingClientRect()
    const coords = this.points.map(([x,y]) => {
      const lon = (x / rect.width) * 360 - 180
      const lat = 90 - (y / rect.height) * 180
      return [parseFloat(lon.toFixed(6)), parseFloat(lat.toFixed(6))]
    })
    if (coords.length > 0 && coords[0] != coords[coords.length -1]) do { coords.push(coords[0]) } while(false)
    const geo = { type: 'Polygon', coordinates: [coords] }
    this.textarea.value = JSON.stringify(geo)
    this.pushEvent('validate', { 'delivery_zone': { 'boundary': this.textarea.value } })
  },

  loadFromTextarea() {
    if (!this.textarea) return
    let val = this.textarea.value
    if (!val) return
    let parsed = JSON.parse(val)
    if (parsed && parsed.type === 'Polygon' && parsed.coordinates && parsed.coordinates[0]) {
      // map lon/lat back to pixels roughly
      const rect = this.canvas.getBoundingClientRect()
      const coords = parsed.coordinates[0]
      this.points = coords.map(([lon, lat]) => {
        const x = ((lon + 180) / 360) * rect.width
        const y = ((90 - lat) / 180) * rect.height
        return [x, y]
      })
      this.render()
    }
  }
}

// Initialize theme on page load
const savedTheme = localStorage.getItem("theme") || "light"
document.documentElement.setAttribute("data-theme", savedTheme)

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {ThemeToggle, PrintReceipt, PolygonDrawer, DeliveryZoneMap, ShopLocationMap},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

import { Controller } from "@hotwired/stimulus"

// Draws the season as a journey: one stop per round, animated arcs between
// consecutive rounds, past rounds coloured by the winning constructor.
//
// Deliberately not a rails_charts `custom_chart` like the rest of the app's
// charts: ECharts ships no map data, so `registerMap` has to run before
// `setOption`, and the GeoJSON should only download on this page rather than
// riding along in application.js.
export default class extends Controller {
  static values = {
    geojson: String,   // asset path for the world outlines
    stops: Array,
    legs: Array
  }

  static MAP_NAME = "f1-world"

  async connect() {
    this.echarts = window.echarts
    if (!this.echarts || !this.stopsValue.length) return

    try {
      await this.registerWorld()
    } catch (error) {
      // A missing map asset shouldn't leave a dead grey box on the page.
      console.error("[circuit-map] could not load world outlines", error)
      this.element.remove()
      return
    }
    // The await above yields; bail if Turbo tore the page down meanwhile.
    if (!this.element.isConnected) return

    // Guard against initialising on top of leftover canvas. Turbo restores
    // currently arrive with an empty container (disconnect disposes the chart
    // first), but init'ing into a dirty node would stack canvases silently.
    this.element.replaceChildren()

    this.chart = this.echarts.init(this.element, null, { renderer: "canvas" })
    this.chart.setOption(this.buildOption())

    this.chart.on("click", (params) => {
      if (params?.data?.path) Turbo.visit(params.data.path)
    })
    this.chart.getZr().on("mousemove", ({ target }) => {
      this.element.style.cursor = target ? "pointer" : "default"
    })

    this.onResize = () => {
      this.chart.resize()
      // The next-round label needs a rebuild, not just a resize, when the card
      // crosses the width where the name no longer fits beside the marker.
      if (this.compact !== this.isCompact) this.chart.setOption(this.buildOption())
    }
    window.addEventListener("resize", this.onResize)
  }

  disconnect() {
    if (this.onResize) window.removeEventListener("resize", this.onResize)
    if (this.chart) this.chart.dispose()
    this.chart = null
  }

  // Registered once per page load; ECharts keeps maps in module-level state, so
  // re-registering on every Turbo visit would refetch 160KB for nothing.
  async registerWorld() {
    const name = this.constructor.MAP_NAME
    if (window.__f1WorldMapLoaded) return

    const response = await fetch(this.geojsonValue)
    if (!response.ok) throw new Error(`${response.status} fetching world outlines`)

    this.echarts.registerMap(name, await response.json())
    window.__f1WorldMapLoaded = true
  }

  get accent() {
    const value = getComputedStyle(document.body).getPropertyValue("--page-accent").trim()
    return value || "#e10600"
  }

  // Below this the next-round label runs off the edge of the card.
  get isCompact() {
    return this.element.clientWidth < 560
  }

  buildOption() {
    const accent = this.accent
    this.compact = this.isCompact
    const stops = this.stopsValue
    const nextRound = stops.find((stop) => !stop.past)

    const point = (stop) => ({
      name: stop.name,
      value: [...stop.coord, stop.round],
      ...stop
    })

    const legsIn = (state) => this.legsValue.filter((leg) => leg.state === state)
    const lineData = (state) =>
      legsIn(state).map((leg) => ({
        coords: leg.coords,
        lineStyle: { curveness: leg.curved ? 0.18 : 0 }
      }))

    return {
      backgroundColor: "transparent",
      animationDuration: 600,
      geo: {
        map: this.constructor.MAP_NAME,
        roam: false,
        silent: true,
        // Trim the empty polar rows so the inhabited world fills the frame, and
        // undo ECharts' default 0.75 latitude squash — with Antarctica gone the
        // true equirectangular ratio is a much better fit for a wide card.
        boundingCoords: [[-180, 76], [180, -56]],
        aspectScale: 1,
        // Pin the horizontal extent and let height follow the aspect ratio. The
        // world is wider than any container we put it in, so fitting to width
        // fills the card and can never crop; fitting to height crops on phones.
        left: 0,
        right: 0,
        itemStyle: {
          areaColor: "#262633",
          borderColor: "rgba(255, 255, 255, 0.22)",
          borderWidth: 0.5
        }
      },
      tooltip: {
        trigger: "item",
        backgroundColor: "#1a1a24",
        borderColor: "rgba(255, 255, 255, 0.12)",
        textStyle: { color: "#e8e8f0", fontSize: 12 },
        formatter: ({ data }) => {
          if (!data || !data.name) return ""
          const result = data.winner
            ? `<div style="margin-top:4px">🏆 ${data.winner}</div>`
            : `<div style="margin-top:4px;color:${accent}">Upcoming</div>`
          return `<div style="font-weight:600">R${data.round} · ${data.name}</div>` +
                 `<div style="color:#8a8a9a">${data.location} · ${data.date}</div>` +
                 result
        }
      },
      series: [
        // ── Legs ──
        {
          name: "Completed legs",
          type: "lines",
          coordinateSystem: "geo",
          zlevel: 1,
          silent: true,
          lineStyle: { color: "#9c9cb8", width: 1.1, opacity: 0.55 },
          data: lineData("done")
        },
        {
          name: "Remaining legs",
          type: "lines",
          coordinateSystem: "geo",
          zlevel: 1,
          silent: true,
          lineStyle: { color: "#71718c", width: 1, opacity: 0.5, type: "dashed" },
          data: lineData("upcoming")
        },
        {
          name: "Next leg",
          type: "lines",
          coordinateSystem: "geo",
          zlevel: 3,
          silent: true,
          effect: {
            show: true,
            period: 4,
            trailLength: 0.35,
            symbol: "arrow",
            symbolSize: 7,
            color: accent
          },
          lineStyle: { color: accent, width: 1.6, opacity: 0.9 },
          data: lineData("next")
        },

        // ── Stops ──
        {
          name: "Completed rounds",
          type: "scatter",
          coordinateSystem: "geo",
          zlevel: 4,
          symbolSize: 7,
          itemStyle: {
            color: ({ data }) => data.color || "#8a8a9a",
            borderColor: "#0d0d12",
            borderWidth: 1
          },
          emphasis: { scale: 1.8 },
          data: stops.filter((stop) => stop.past).map(point)
        },
        {
          name: "Upcoming rounds",
          type: "scatter",
          coordinateSystem: "geo",
          zlevel: 4,
          symbolSize: 6,
          itemStyle: {
            color: "transparent",
            borderColor: "#8a8a9a",
            borderWidth: 1.2
          },
          emphasis: { scale: 1.8, itemStyle: { color: "#8a8a9a" } },
          data: stops.filter((stop) => !stop.past && stop !== nextRound).map(point)
        },
        {
          name: "Next round",
          type: "effectScatter",
          coordinateSystem: "geo",
          zlevel: 5,
          symbolSize: 9,
          rippleEffect: { scale: 3.5, brushType: "stroke" },
          itemStyle: { color: accent },
          label: {
            show: !this.compact,
            position: "right",
            distance: 10,
            formatter: ({ data }) => data.name,
            color: accent,
            fontSize: 11,
            fontWeight: 600
          },
          data: nextRound ? [point(nextRound)] : []
        }
      ]
    }
  }
}

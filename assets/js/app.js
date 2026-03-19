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
import {hooks as colocatedHooks} from "phoenix-colocated/agentic_ui"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.ThemeToggle = {
  mounted() {
    // Sync cookie value to server on mount
    const saved = this.readCookie()
    if (saved && saved !== "system") {
      this.pushEvent("sync_theme", {theme: saved})
    }

    // Listen for system preference changes
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.mediaQuery.addEventListener("change", () => {
      const current = this.readCookie()
      if (!current || current === "system") this.applyTheme("system")
    })

    this.handleEvent("set_theme", ({theme}) => {
      this.applyTheme(theme)
      this.saveToCookie(theme)
    })
  },
  readCookie() {
    const m = document.cookie.match(/(?:^|; )theme=([^;]*)/)
    return m ? m[1] : null
  },
  applyTheme(theme) {
    const html = document.documentElement
    if (theme === "system") {
      const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
      html.setAttribute("data-theme", prefersDark ? "dark" : "light")
    } else {
      html.setAttribute("data-theme", theme)
    }
  },
  saveToCookie(theme) {
    document.cookie = `theme=${theme};path=/;max-age=${365 * 24 * 60 * 60};SameSite=Lax`
  }
}

Hooks.ScrollBottom = {
  mounted() {
    this.scrollToBottom()
    this.observer = new MutationObserver(() => this.scrollToBottom())
    this.observer.observe(this.el, { childList: true, subtree: true })
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTo({ top: this.el.scrollHeight, behavior: "smooth" })
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

Hooks.HeroCarousel = {
  mounted() {
    this.current = 0
    this.interval = parseInt(this.el.dataset.interval) || 5000
    this._initCarousel()

    this.el.addEventListener("carousel:prev", () => this.prev())
    this.el.addEventListener("carousel:next", () => this.next())
    this.el.addEventListener("mouseenter", () => clearInterval(this.timer))
    this.el.addEventListener("mouseleave", () => {
      if (this.total > 1) {
        this.timer = setInterval(() => this.next(), this.interval)
      }
    })
  },
  updated() {
    this._initCarousel()
  },
  _initCarousel() {
    this.track = this.el.querySelector(".carousel-track")
    this.slides = this.el.querySelectorAll(".carousel-slide")
    this.dots = this.el.querySelectorAll(".carousel-dot")
    this.total = this.slides.length

    if (this.current >= this.total) this.current = 0

    clearInterval(this.timer)
    if (this.total > 1) {
      this.slide()
      this.updateDots()
      this.timer = setInterval(() => this.next(), this.interval)
    }
  },
  next() {
    this.current = (this.current + 1) % this.total
    this.slide()
  },
  prev() {
    this.current = (this.current - 1 + this.total) % this.total
    this.slide()
  },
  slide() {
    if (this.track) {
      this.track.style.transform = `translateX(-${this.current * 100}%)`
    }
    this.updateDots()
  },
  updateDots() {
    this.dots.forEach((dot, i) => {
      dot.style.opacity = i === this.current ? "1" : "0.4"
      dot.style.transform = i === this.current ? "scale(1.3)" : "scale(1)"
    })
  },
  destroyed() {
    if (this.timer) clearInterval(this.timer)
  }
}

Hooks.ChatInput = {
  mounted() {
    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.el.closest("form").dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
      }
    })
  }
}

Hooks.SpeechToText = {
  mounted() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SpeechRecognition) {
      this.el.title = "Speech recognition not supported in this browser"
      this.el.classList.add("opacity-30", "cursor-not-allowed")
      return
    }

    this.recognition = new SpeechRecognition()
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.recognition.lang = "es-ES"
    this.listening = false
    this.userStopped = false

    this.recognition.onresult = (event) => {
      const textarea = this.el.closest("form").querySelector("textarea")
      if (!textarea) return

      let transcript = ""
      for (let i = 0; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript
      }
      textarea.value = transcript
      textarea.dispatchEvent(new Event("input", { bubbles: true }))
    }

    this.recognition.onend = () => {
      const wasUserStopped = this.userStopped
      this.listening = false
      this.userStopped = false
      this.el.classList.remove("text-error", "border-error", "animate-pulse")
      this.el.classList.add("text-base-content/40", "border-base-300")

      if (wasUserStopped) {
        const textarea = this.el.closest("form").querySelector("textarea")
        if (textarea && textarea.value.trim() !== "") {
          this.el.closest("form").dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }))
        }
      }
    }

    this.recognition.onerror = (event) => {
      this.listening = false
      this.userStopped = false
      this.el.classList.remove("text-error", "border-error", "animate-pulse")
      this.el.classList.add("text-base-content/40", "border-base-300")
      if (event.error !== "aborted" && event.error !== "no-speech") {
        console.warn("Speech recognition error:", event.error)
      }
    }

    this.el.addEventListener("click", () => {
      if (this.listening) {
        this.userStopped = true
        this.recognition.stop()
      } else {
        const lang = document.documentElement.lang || "es-ES"
        this.recognition.lang = lang
        this.recognition.start()
        this.listening = true
        this.el.classList.remove("text-base-content/40", "border-base-300")
        this.el.classList.add("text-error", "border-error", "animate-pulse")
      }
    })
  },
  destroyed() {
    if (this.recognition && this.listening) {
      this.recognition.stop()
    }
  }
}

Hooks.AnimateOut = {
  destroyed() {
    // phx-remove triggers this; CSS handles the animation
  }
}

Hooks.MobileChat = {
  mounted() {
    this.handleEvent("toggle_chat", () => {
      this.el.classList.toggle("chat-open")
    })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
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


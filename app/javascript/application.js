// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "@popperjs/core"
import "bootstrap"
// import "chartkick"
// import "Chart.bundle"
import "echarts"
import "echarts/theme/dark"
// window.echarts = echarts;

// SweetAlert2 — override Turbo's confirm dialog
import Swal from "sweetalert2"
window.Swal = Swal

Turbo.setConfirmMethod((message, element) => {
  return new Promise((resolve) => {
    Swal.fire({
      text: message,
      icon: "warning",
      showCancelButton: true,
      confirmButtonText: "Confirm",
      cancelButtonText: "Cancel",
      background: "#1a1a1a",
      color: "#e0e0e0",
      confirmButtonColor: "#e10600",
      cancelButtonColor: "#333",
      customClass: { popup: "swal-f1" }
    }).then((result) => {
      resolve(result.isConfirmed)
    })
  })
})
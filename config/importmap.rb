# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
# pin "chartkick", to: "chartkick.js"
# pin "Chart.bundle", to: "Chart.bundle.js"
# pin "chartjs-plugin-annotation", to: "https://ga.jspm.io/npm:chartjs-plugin-annotation@3.0.0/dist/chartjs-plugin-annotation.esm.js"
# pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js"
# pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.4.0/dist/chart.js"
# pin "chart.js/helpers", to: "https://ga.jspm.io/npm:chart.js@4.4.0/helpers/helpers.js"
pin "echarts", to: "echarts.min.js"
pin "echarts/theme/dark", to: "echarts/theme/dark.js"
# NOTE: echarts is vendored by the rails_charts gem and already bundles zrender
# and tslib. Pinning them here from jspm was left over from an abandoned CDN
# setup — and because importmap-rails emits a modulepreload for every pin, the
# bare directory URL "zrender@5.4.4/lib/" was fetched and 404'd on every single
# page load. Nothing in app/ imports either one.
pin "debounce", to: "https://ga.jspm.io/npm:debounce@2.0.0/index.js"
pin "sweetalert2", to: "https://cdn.jsdelivr.net/npm/sweetalert2@11.22.0/+esm"
pin "sortablejs" # @1.15.7

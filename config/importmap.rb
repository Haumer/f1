# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
pin "chartkick", to: "chartkick.js"
pin "Chart.bundle", to: "Chart.bundle.js"
pin "chartjs-plugin-annotation", to: "https://ga.jspm.io/npm:chartjs-plugin-annotation@3.0.0/dist/chartjs-plugin-annotation.esm.js"
pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js"
pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.4.0/dist/chart.js"
pin "chart.js/helpers", to: "https://ga.jspm.io/npm:chart.js@4.4.0/helpers/helpers.js"

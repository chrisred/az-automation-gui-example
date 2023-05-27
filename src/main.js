import { createApp } from 'vue'
import App from './App.vue'
import router from './router.js'
import { createVuetify } from 'vuetify'

import '@mdi/font/css/materialdesignicons.css'
import 'vuetify/styles'

const vuetify = createVuetify({
    defaults: {
        global: {},
        VTextField: {
            density: 'compact'
        },
        VSelect: {
            density: 'compact'
        },
        VCheckbox: {
            density: 'compact'
        },
        VSnackBar: {
            density: 'compact'
        }
    },
    theme: {
        defaultTheme: 'light'
    },
    icons: {
        defaultSet: 'mdi'
    }
})

const app = createApp(App)
app.use(router)
app.use(vuetify)
app.mount('#app')

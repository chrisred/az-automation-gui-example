module.exports = {
    extends: [
        'eslint:recommended',
        'plugin:vue/vue3-recommended'
    ],
    rules: {
        // https://eslint.org/docs/latest/rules
        'semi': ['warn', 'never'],
        // https://eslint.vuejs.org/rules/
        'vue/max-attributes-per-line': ['off'],
        'vue/singleline-html-element-content-newline': ['off'],
        'vue/v-slot-style': ['warn', 'longform']
    }
}
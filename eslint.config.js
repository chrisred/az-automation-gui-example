import js from '@eslint/js'
import vue from 'eslint-plugin-vue'
import globals from 'globals'

export default [
    js.configs.recommended,
    ...vue.configs['flat/recommended'],
    {
        languageOptions: {
            globals: {
                ...globals.browser,
                ...globals.node
            }
        },
        rules: {
            // https://eslint.org/docs/latest/rules
            'semi': ['warn', 'never'],
            // https://eslint.vuejs.org/rules/
            'vue/max-attributes-per-line': ['off'],
            'vue/singleline-html-element-content-newline': ['off'],
            'vue/v-slot-style': ['warn', 'longform']
        },
    },
]
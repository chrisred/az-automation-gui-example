import { createRouter, createWebHistory } from 'vue-router'
import HomeView from './views/HomeView.vue'
import RunbookView from './views/RunbookView.vue'
import HybridView from './views/HybridView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'home',
      component: HomeView
    },
    {
      path: '/runbook',
      name: 'runbook',
      component: RunbookView
    },
    {
      path: '/hybrid',
      name: 'hybrid',
      component: HybridView
    }
  ]
})

export default router

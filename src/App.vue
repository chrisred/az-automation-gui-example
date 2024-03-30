<script setup>
import { ref, provide } from 'vue'
import { RouterView } from 'vue-router'

const theme = ref('light')
const isAuthenticated = ref(false)
const userDetails = ref(null)
const avatarUrl = ref(null)
const snackbarBinding = ref(false)
const snackbarColor = ref(null)
const snackbarTimeout = ref(-1)
const snackbarMessage = ref(null)

provide('writeSnackbarMessage', writeSnackbarMessage)

function onClickTheme () {
  theme.value = theme.value === 'light' ? 'dark' : 'light'
}

function writeSnackbarMessage(message, color, timeout)
{
  snackbarBinding.value = true
  snackbarMessage.value = message
  snackbarColor.value = color
  snackbarTimeout.value = timeout
}

async function getUser()
{
  const response = await fetch('/.auth/me')
  const responseBody = await response.json()
  return responseBody
}

(async function(){
  try
  {
    const user = await getUser()
    // populate user details if we are authenticated
    if (user.clientPrincipal)
    {
      isAuthenticated.value = true
      userDetails.value = user.clientPrincipal.userDetails

      // only send the user name to generate an avatar
      const userSplit = user.clientPrincipal.userDetails.split('@')
      const encodedUser = encodeURIComponent(userSplit[0])
      avatarUrl.value = `https://ui-avatars.com/api/?format=svg&rounded=true&name=${encodedUser}`
    }
  }
  catch (e)
  {
    console.error(e)
    writeSnackbarMessage(e.message, 'error', -1)
  }
})()
</script>

<template>
  <v-app :theme="theme">
    <v-app-bar>
      <v-toolbar-title>Automation GUI Example</v-toolbar-title>
      <v-spacer />
      <v-btn :prepend-icon="theme === 'light' ? 'mdi-weather-sunny' : 'mdi-weather-night'" @click="onClickTheme">Toggle Theme</v-btn>
    </v-app-bar>
    <v-navigation-drawer>
      <v-list>
        <v-list-item v-if="isAuthenticated" lines="two" :prepend-avatar="avatarUrl" subtitle="Logged in">
          <v-list-item-title>{{ userDetails }}</v-list-item-title>
        </v-list-item>
        <v-list-item to="/">
          <v-list-item-title>Home</v-list-item-title>
        </v-list-item>
        <v-list-item to="/runbook">
          <v-list-item-title>Runbook</v-list-item-title>
        </v-list-item>
        <v-list-item to="/hybrid">
          <v-list-item-title>Hybrid Runbook</v-list-item-title>
        </v-list-item>
      </v-list>
      <template v-if="isAuthenticated" v-slot:append>
        <div class="pa-2">
          <v-btn variant="tonal" href="/.auth/logout" block>
            Logout
          </v-btn>
        </div>
      </template>
    </v-navigation-drawer>
    <v-main>
      <router-view />
      <v-snackbar v-model="snackbarBinding" :color="snackbarColor" :timeout="snackbarTimeout" multi-line>
        {{ snackbarMessage }}
        <template v-slot:actions>
          <v-btn variant="text" @click="snackbarBinding=false">Close</v-btn>
        </template>
      </v-snackbar>
    </v-main>
  </v-app>
</template>

<style>
  .v-container {
    max-width: 1000px !important;
  }
</style>
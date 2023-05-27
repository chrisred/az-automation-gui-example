<script setup>
</script>

<template>
  <v-container>
    <h2>Home</h2>
    <p>
      There are two examples provided. <router-link to="/runbook">Runbook</router-link> which executes an Automation
      job using the default Azure worker, and <router-link to="/hybrid">Hybrid Runbook</router-link> which executes a
      job on hybrid worker. Details on how to configure the hybrid worker can be found
      <a target="_blank" href="https://github.com/chrisred/az-automation-gui-example/#hybrid-runbook-setup">here</a>.
    </p>
  </v-container>
</template>
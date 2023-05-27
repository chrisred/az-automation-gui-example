<script setup>
  const props = defineProps({ messages: { type: Array, required: true }})
  defineEmits(['clear'])
</script>

<template>
  <v-card class="logging mt-4" title="Runbook Logging" variant="tonal" max-height="350" elevation="1">
    <v-divider />
    <v-card-text class="logging">
      <ul class="logging-text">
        <!-- eslint-disable-next-line vue/require-v-for-key -->
        <li v-for="message in props.messages">
          <span v-if="message.type == 'error'" class="text-red font-weight-bold">
            {{ message.text }}
          </span>
          <span v-else-if="message.type == 'warn'" class="text-yellow font-weight-bold">
            {{ message.text }}
          </span>
          <span v-else>{{ message.text }}</span>
        </li>
      </ul>
    </v-card-text>
    <v-card-actions>
      <v-spacer />
      <v-btn variant="text" @click="$emit('clear')">Clear</v-btn>
    </v-card-actions>
  </v-card>
</template>

<style scoped>
  .v-card.logging {
    display: flex !important;
    flex-direction: column;
  }

  .v-card-text.logging {
    overflow: auto;
  }

  ul.logging-text {
    list-style-type: none;
    font-family: monospace;
    white-space: pre;
  }
</style>
<script setup>
  import { ref, onMounted, onBeforeUnmount } from 'vue'
  import { useGoTo } from 'vuetify'

  const props = defineProps({ messages: { type: Array, required: true }})
  const goTo = useGoTo()
  const resizeEvent = new ResizeObserver(onResize)
  const logContainer = ref(null)
  const logCard = ref(null)

  defineEmits(['clear'])

  onMounted(() => {
    resizeEvent.observe(logCard.value.$el)
  })

  onBeforeUnmount(() => {
    resizeEvent.unobserve(logCard.value.$el)
  })

  function onResize()
  {
    // fix the warning "Vuetify: Scroll target is not reachable" when only the logCard offsetHeight is used
    const targetOffset = logCard.value.$el.offsetHeight - logContainer.value.$el.offsetHeight

    if (targetOffset > 0)
    {
      // automatically scroll the log card to show new output
      goTo(targetOffset, {container: '#logging-container', duration:0, offset:32})
    }
  }
</script>

<template>
  <v-card class="logging mt-4" title="Runbook Logging" variant="tonal" max-height="350" elevation="1">
    <v-divider />
    <v-container id="logging-container" ref="logContainer" class="logging-overflow">
      <v-card-text ref="logCard">
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
    </v-container>
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

  .v-container.logging-overflow {
    overflow: auto;
  }

  ul.logging-text {
    list-style-type: none;
    font-family: monospace;
    white-space: pre;
  }
</style>
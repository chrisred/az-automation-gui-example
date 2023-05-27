<script setup>
  import { ref } from 'vue'
  import { onBeforeRouteLeave } from 'vue-router'
  import RunbookLogCard from '../components/RunbookLogCard.vue'

  const alertMessage = ref(null)
  const alertDisplay = ref(false)
  const alertType = ref('info')
  const alertClosable = ref(false)
  const logMessages = ref([])
  const webhookName = 'RUNBOOK'

  const form = ref(null)
  const isFormValid = ref(null)
  const formDisabled = ref(false)
  const submitDisabled = ref(false)
  const formData = ref({
    selectWait: null,
    inputMessage: null,
    inputCount: null,
    checkboxWait: null
  })

  const selectWaitData = ref([
    {name: 'One', value: 1}, {name: 'Two', value: 2},
    {name: 'Three', value: 3}, {name: 'Four', value: 4},
    {name: 'Five', value: 5}, {name: 'Six', value: 6},
    {name: 'Seven', value: 7}, {name: 'Eight', value: 8},
    {name: 'Nine', value: 9}, {name: 'Ten', value: 10}
  ])

  onBeforeRouteLeave(() => {
    // test if the form is clean (no properties in formData are "truthy"), show a confirmation dialog when not clean
    if (!Object.values(formData.value).every(value => !value))
    {
      const answer = window.confirm(
        "Click OK to confirm that you want to leave — information you've entered may not be saved."
      )

      // cancel the navigation and stay on the same page
      if (!answer) return false
    }
  })

  const inputCountRules = ref([
    v => !!v || 'Required',
    v => /^\d+$/.test(v) || 'Must be a number',
    v => v < 20 || 'Must be a number less than 20'
  ])

  const inputMessageRules = ref([
    v => !!v || 'Required',
  ])

  const selectWaitRules = ref([
    v => !!v || 'Required',
  ])

  function writeAlertMessage(...messages)
  {
    alertMessage.value = messages.join(' ')
  }

  function writeLogMessage(message, type = 'info')
  {
    // covert null to a new line
    message = (null == message) ? "\r\n" : message
    logMessages.value.push({ type: type, text: message })
  }

  function clearLogMessages()
  {
    logMessages.value = []
  }

  async function submitJob(body)
  {
    const options = {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body)
    }

    const response = await fetch('/api/job/submit', options)
    const responseBody = await response.json()
    return responseBody
  }

  async function getJobStatus(jobId)
  {
    const response = await fetch(`/api/job/status/${jobId}`)
    const responseBody = await response.json()
    return responseBody
  }

  async function getJobOutput(jobId)
  {
    const response = await fetch(`/api/job/output/${jobId}`)
    const responseBody = await response.json()
    return responseBody
  }

  async function getJobDetails(jobId)
  {
    const response = await fetch(`/api/job/details/${jobId}`)
    const responseBody = await response.json()
    return responseBody
  }

  function isJobRunning(status)
  {
    const states = [
      'New', 'Activating', 'Running'
    ]
    return states.includes(status)
  }

  function isJobWaiting(status)
  {
    const states = [
      'Suspending', 'Suspended', 'Resuming'
    ]
    return states.includes(status)
  }

  function isJobFailed(status)
  {
    const states = [
      'Failed'
    ]
    return states.includes(status)
  }

  function isJobCompleted(status)
  {
    const states = [
      'Completed'
    ]
    return states.includes(status)
  }

  /**
   * Main poller function, the function passed as the param "poller" will run until "condition" is false. "updater"
   * will run on each iteration after the the wait duration. Adapted from:
   * https://stackoverflow.com/questions/46208031/polling-until-getting-specific-result/64654157#64654157
   */
  async function poll(poller, condition, updater, duration)
  {
    let result = await poller()

    while (condition(result))
    {
      await wait(duration)
      result = await poller()
      updater(result)
    }

    return result
  }

  /**
   * Wait for the duration defined. Used by the poller. 
   */
  async function wait(duration = 3000)
  {
    return new Promise(resolve => {setTimeout(resolve, duration)})
  }

  /** 
   * Returns a function called by the poller as "update()". This will invoke updates to the Alert component and
   * the log output Card component. Additional variables are defined to allow the closure to track some state.
   */
  function createJobUpdater()
  {
    // track which output message was last written to the log
    let outputIndex = 0
    let warningIndex = 0
    let errorIndex = 0

    return (pollResponse) => {
      console.log(`Running poller: ${pollResponse.status} ${pollResponse.output} ${pollResponse.errors}`)
      writeAlertMessage('Job Status:', pollResponse.status)

      const outputLength = pollResponse.output.length
      if (outputLength > 0 && (outputIndex < outputLength))
      {
        // only write log messages since the last poll, the response from the API contains every message
        for( ; outputIndex < outputLength; outputIndex++)
        {
          writeLogMessage(pollResponse.output[outputIndex])
        }
      }

      const warningLength = pollResponse.warnings.length
      if (warningLength > 0 && (warningIndex < warningLength))
      {
        for( ; warningIndex < warningLength; warningIndex++)
        {
          writeLogMessage(pollResponse.warnings[warningIndex], 'warn')
        }
      }

      const errorLength = pollResponse.errors.length
      if (errorLength > 0 && (errorIndex < errorLength))
      {
        for( ; errorIndex < errorLength; errorIndex++)
        {
          writeLogMessage(pollResponse.errors[errorIndex], 'error')
        }
      }
    }
  }
  
  function submitForm()
  {
    if (!isFormValid.value)
    {
      return false
    }

      formDisabled.value = true
      submitDisabled.value = true;

    (async function(){

      try
      {
        const requestBody = {
          'webhookName': webhookName,
          'checkboxWait': formData.value.checkboxWait,
          'inputMessage': formData.value.inputMessage,
          'inputCount': formData.value.inputCount,
          'selectWait': formData.value.selectWait
        }

        const jobResponse = await submitJob(requestBody)
        const jobStatusResponse = await getJobStatus(jobResponse.JobIds[0])
        console.log(`Job Id ${jobResponse.JobIds[0]}`)

        // show info alert with initial job status
        writeAlertMessage('Job Status:', jobStatusResponse.status)
        alertDisplay.value = true
        alertType.value = 'info'

        // setup poller functions
        const jobPoller = () => getJobDetails(jobResponse.JobIds[0])
        const jobCondition = pollResponse => isJobRunning(pollResponse.status) 
        const jobUpdater = createJobUpdater()

        const jobResult = await poll(jobPoller, jobCondition, jobUpdater)

        let jobError = jobResult.exception ? jobResult.exception : 'Unknown error.'
        if (isJobFailed(jobResult.status)) {throw new Error(jobError)}

        if (isJobCompleted(jobResult.status))
        {
          alertType.value = 'success'
          alertClosable.value = true
          writeAlertMessage('Job Status:', jobResult.status)
          resetForm()
        }
        else
        {
          alertType.value = 'warning'
          alertClosable.value = true
          writeAlertMessage('Unexpected Job Status:', jobResult.status)
        }
      }
      catch (e)
      {
        alertDisplay.value = true
        alertType.value = 'error'
        alertClosable.value = true
        writeAlertMessage('Exception:', e.message)
      }
      finally
      {
        formDisabled.value = false
        submitDisabled.value = false
      }
    })()
  }

  function resetForm()
  {
    // the v-checkbox v-model value seems to not be affected by reset(), possible vuetify bug
    formData.value.checkboxWait = null
    form.value.reset()
  }
</script>

<template>
  <v-container>
    <p>
      Example that passes form input to the Runbook as parameters. The form allows the Runbook job to generate some
      custom output which is shown in the logging area. The status of the job will be polled every 3 seconds.
    </p>
    <v-card title="Runbook Options" class=" mt-4 mb-4">
      <v-card-subtitle>
        Execute an Azure Automation Runbook, values in this form will be passed as parameters.
      </v-card-subtitle>
      <v-card-text>
        <v-form ref="form" v-model="isFormValid" validate-on="blur" :disabled="formDisabled" @submit.prevent="submitForm">
          <v-row>
            <v-col>
              <v-text-field v-model="formData.inputMessage" :rules="inputMessageRules" label="Message Text" variant="outlined" clearable />
            </v-col>
            <v-col>
              <v-text-field v-model="formData.inputCount" :rules="inputCountRules" label="Message Count" variant="outlined" clearable />
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <v-select v-model="formData.selectWait" :rules="selectWaitRules" :items="selectWaitData" item-title="name" item-value="value" varient="underlined" label="Message Wait (seconds)" clearable />
            </v-col>
            <v-col>
              <!-- v-checkbox is not affected by the form level "disabled" setting, possible vuetify bug -->
              <v-checkbox v-model="formData.checkboxWait" :disabled="formDisabled" label="Randomise Wait" />
            </v-col>
          </v-row>
          <v-card-actions>
            <v-spacer />
            <v-btn :disabled="submitDisabled" variant="text" @click="resetForm">Reset</v-btn>
            <v-btn type="submit" :disabled="submitDisabled" variant="outlined">Submit</v-btn>
          </v-card-actions>
        </v-form>
      </v-card-text>
    </v-card>
    <v-alert v-model="alertDisplay" :closable="alertClosable" :type="alertType">
      {{ alertMessage }}
    </v-alert>
    <RunbookLogCard v-bind="{messages: logMessages}" @clear="clearLogMessages" />
  </v-container>
</template>
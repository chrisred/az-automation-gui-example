<script setup>
  import { ref, onMounted } from 'vue'
  import { onBeforeRouteLeave } from 'vue-router'
  import RunbookLogCard from '../components/RunbookLogCard.vue'

  const alertMessage = ref(null)
  const alertDisplay = ref(false)
  const alertType = ref('info')
  const alertClosable = ref(false)
  const logMessages = ref([])
  const webhookName = 'HYBRID'

  const form = ref(null)
  const isFormValid = ref(null)
  const formDisabled = ref(false)
  const submitDisabled = ref(false)
  const selectGroupData = ref([])
  const formData = ref({
    inputName: null,
    inputFullName: null,
    inputPassword: null,
    inputConfirm: null,
    selectGroups: null,
    checkboxExpire: null
  })

  onMounted(() => {
    // here we only run one async fetch, but Promise.all() would allow multiple calls if needed
    Promise.all([getGroupItems()]).then((resolved) => {
      selectGroupData.value = resolved[0]
      // sort alphabetically by name, assumes all items in the array have a "Name" property
      selectGroupData.value = selectGroupData.value.sort((a, b) => a.Name.localeCompare(b.Name))
    }).catch(e => console.error(e))
  })

  onBeforeRouteLeave(() => {
    // test if the form is clean (no properties in formData are "truthy"), show a confirmation dialog when not clean
    if (!Object.values(formData.value).every(v => (v instanceof Array) ? !v.length : !v))
    {
      const answer = window.confirm(
        "Click OK to confirm that you want to leave — information you've entered may not be saved."
      )

      // cancel the navigation and stay on the same page
      if (!answer) return false
    }
  })

  const inputNameRules = ref([
    v => !!v || 'Required',
    v => v.length <= 20 || 'Must be 20 characters or less'
  ])

  const inputPasswordRules = ref([
    v => !!v || 'Required',
    v => v.length >= 8 || 'Must be 8 characters or more'
  ])

  const confirmPasswordRules = ref([
    v => !!v || 'Required',
    v => v === formData.value.inputPassword || 'Confirm Password and Password must match'
  ])

  async function getGroupItems()
  {
    const response = await fetch('/api/formdata/local-groups')
    const responseBody = await response.json()
    return responseBody
  }

  function writeAlertMessage(...messages)
  {
    alertMessage.value = messages.join(' ')
  }

  function writeLogMessage(message, type = 'info')
  {
    // covert null to a new line
    message = (null == message) ? "\n" : message
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

    console.log(options.body)

    const response = await fetch('/api/job/submit', options)
    const responseBody = await response.json()

    return {body: responseBody, status: response.status, statusText: response.statusText, ok: response.ok}
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
   * the log output Card component. Additional variabes are defined to allow the closure to track some state.
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
    (async function(){
      // force validation on submit to ensure password equality is checked
      await form.value.validate()

      if (!isFormValid.value)
      {
        return false
      }

      formDisabled.value = true
      submitDisabled.value = true

      try
      {
        const requestBody = {
          'webhookName': webhookName,
          'inputName': formData.value.inputName,
          'inputFullName': formData.value.inputFullName,
          'inputPassword': formData.value.inputPassword,
          'selectGroups': formData.value.selectGroups,
          'checkboxExpire': formData.value.checkboxExpire
        }

        const jobResponse = await submitJob(requestBody)
        if (!jobResponse.ok) {throw new Error(jobResponse.body.error)}

        const jobStatusResponse = await getJobStatus(jobResponse.body.JobIds[0])
        console.log(`Job Id ${jobResponse.body.JobIds[0]}`)

        // show info alert with initial job status
        writeAlertMessage('Job Status:', jobStatusResponse.status)
        alertDisplay.value = true
        alertType.value = 'info'

        // setup poller functions
        const jobPoller = () => getJobDetails(jobResponse.body.JobIds[0])
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
    // the v-checkbox v-model value seems to not be affected by reset(), maybe a bug
    formData.value.checkboxExpire = null
    form.value.reset()
  }
</script>

<template>
  <v-container>
    <p>
      Example for a Windows based hybrid Runbook worker. Here a local Windows user is created, the "User Groups" select
      box is populated using data synced from the worker/server. This Runbook requires <a target="_blank" href="https://github.com/chrisred/az-automation-gui-example/#hybrid-runbook-setup"> additional setup</a>.
    </p>
    <v-card title="Runbook Options" class="mt-4 mb-4">
      <v-card-subtitle>
        Execute a hybrid Azure Automation Runbook, values in this form will be passed as parameters and run on a hybrid worker.
      </v-card-subtitle>
      <v-card-text>
        <v-form ref="form" v-model="isFormValid" validate-on="blur" :disabled="formDisabled" @submit.prevent="submitForm">
          <v-row>
            <v-col>
              <v-text-field v-model="formData.inputName" :rules="inputNameRules" label="User Name" variant="outlined" clearable />
            </v-col>
            <v-col>
              <v-text-field v-model="formData.inputFullName" label="Full Name" variant="outlined" clearable />
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <v-text-field v-model="formData.inputPassword" :rules="inputPasswordRules" label="Password" variant="outlined" type="password" clearable />
            </v-col>
            <v-col>
              <v-text-field v-model="formData.inputConfirm" :rules="confirmPasswordRules" label="Confirm Password" variant="outlined" type="password" clearable />
            </v-col>
          </v-row>
          <v-row>
            <v-col>
              <!-- v-checkbox is not affected by the form level "disabled" setting, possible vuetify bug -->
              <v-checkbox v-model="formData.checkboxExpire" :disabled="formDisabled" label="Password Never Expires" />
            </v-col>
            <v-col>
              <v-select v-model="formData.selectGroups" :items="selectGroupData" item-title="Name" item-value="RowKey" varient="underlined" label="User Groups" chips multiple clearable />
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
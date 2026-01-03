<template>
    <div>
      <input type="file" @change="handleFileUpload" />
      <!-- Add more UI elements as needed -->
    </div>
</template>
  
<script>
import Ajv from 'ajv'
import axios from 'axios'
import MarkdownFileSchema from '../../schemas/markdown_file.json'

export default {
    methods: {
      handleFileUpload(event) {
        const file = event.target.files[0]
        const fileMetadata = {
          file_name: file.name,
          file_type: file.type
        }

        const ajv = new Ajv()
        const validate = ajv.compile(MarkdownFileSchema)
        
  
        if (validate(fileMetadata)) {
          // Proceed with uploading the file to the API
          this.uploadFile(file, fileMetadata)
        } else {
          // Handle validation errors
          console.error(validate.errors)
        }
      },
      async uploadFile(file, fileMetadata) {
        console.log("Validation passed!", fileMetadata)
        await axios.post('/upload', fileMetadata)
        .then(response => {
          console.log('File metadata uploaded successfully:', response.data)
          // Handle successful response
        })
        .catch(error => {
          console.error('Error uploading file metadata:', error)
          // Handle error
        })
      }
    }
};
</script>  
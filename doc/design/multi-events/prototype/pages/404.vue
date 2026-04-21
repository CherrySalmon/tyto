<template>
<div class="not_found_page_container">
    <h1>Page not found</h1>
    <br>
    <router-link to="/course">Back to courses</router-link>
</div>
</template>

<script>

export default {
    name: '404'
}

</script>

<style>
.not_found_page_container {
    padding: 100px;
    text-align: center;
}
</style>

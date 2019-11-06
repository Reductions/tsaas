# Topological Sorting as a Service (Tsaas)

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Start Phoenix endpoint with `mix phx.server`

The server run on [`localhost:4000`](http://localhost:4000) by default.

There are 2 endpoints that the server response to:

  * "/order/json" - accepts json with tasks and return json response
  * "/order/bash" - accepts json with tasks and return text response with the bash script

A few request validations are made. If the validation fails a 400 status code is returned and the response contains detail about the error:
  * in case of json the response follows the pattern:
  ```json
  {
    'error': {
      'details': {
         ...
      }
    }
  }
  ```
  * in case of bash a bash script that prints the same error is returned and exits with 1

Validations that are made are:
  * Does the request conform to a certain schema?
  * Is there more then one task with the same name?
  * Is there a task that requires task that is not in the list?
  * Does the tasks form a cyclic dependency

# FoodTruck

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Description

This application uses San Francisco's food truck [open dataset](https://data.sfgov.org/Economy-and-Community/Mobile-Food-Facility-Permit/rqzj-sfat/data) to populate an EST and provide the user a narrow set of search methods. An alternative to an EST may have been selected depending on data footprint. Additionally, the EST data is refreshed every 24 hours.

Both GET and POST methods are supported and implemented within Phoenix. However only GET via form submission is used in the UI.

The UI allows a user to search by name, food items (with basic and or logic), and by distance from their location. It also allows the user to randomize the results. 

Notes describing development decisions are available in their respective files 

## About 

This project is derived from https://github.com/peck/engineering-assessment

My work can be found:
- [lib/food_truck/database.ex](lib/food_truck/database.ex)
- [lib/food_truck_web/controllers/food_truck_search.ex](lib/food_truck_web/controllers/food_truck_search.ex)
- [lib/food_truck_web/controllers/food_truck_html/index.html.heex](lib/food_truck_web/controllers/food_truck_html/index.html.heex)
- [test/food_truck_web/controllers/food_truck_controller_test.exs](test/food_truck_web/controllers/food_truck_controller_test.exs)
- [assets/js/app.js](assets/js/app.js)
- [assets/css/app.css](assets/css/app.css)
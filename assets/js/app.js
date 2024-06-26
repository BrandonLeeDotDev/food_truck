// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

document.addEventListener('DOMContentLoaded', function () {
    const setupToggle = (checkboxId, hiddenInputId) => {
        const checkbox = document.getElementById(checkboxId);
        const hiddenInput = document.getElementById(hiddenInputId);
        const slider = checkbox?.parentElement.querySelector('.toggle-slider');
        const distanceInput = document.getElementById('distance_containter');
        const distanceTh = document.getElementById('distance_th');

        if (!checkbox || !hiddenInput) {
            console.error(`Couldn't find elements for ${checkboxId} or ${hiddenInputId}`);
            return;
        }

        const updateToggleState = (checked) => {
            const distanceTd = document.getElementsByClassName('distance_td');
            checkbox.checked = checked;
            hiddenInput.value = checked ? "1" : "0";
            slider?.classList.toggle('checked', checked);
            console.log(`${hiddenInputId} value changed to ${hiddenInput.value}`);

            if (hiddenInputId === 'geo_on') {
                distanceInput.style.display = checked ? 'block' : 'none';
                if (distanceTh) {
                    distanceTh.style.display = checked ? 'table-cell' : 'none';
                }
                if (distanceTd) {
                    for (let i = 0; i < distanceTd.length; i++) {
                        distanceTd[i].style.display = checked ? 'table-cell' : 'none';
                    }
                }                
                console.log("Geo On checkbox changed");
                checked ? getLocation() : clearLocationInputs();
            }
        };

        checkbox.addEventListener('change', function () {
            updateToggleState(this.checked);
        });

        // Return the update function so it can be called from outside
        return updateToggleState;
    }

    const clearLocationInputs = () => {
        document.getElementById('latitude').value = "";
        document.getElementById('longitude').value = "";
    }

    const updateGeoToggle = setupToggle('geo_on_checkbox', 'geo_on');
    setupToggle('rand_results_checkbox', 'rand_results');

    const distanceUpdate = document.getElementById('distance');
    distanceUpdate.addEventListener('click', function () {
        console.log("Distance changed to", this.value);
        getLocation();
    });

    // ipapi.co is a free IP geolocation API that provides latitude and longitude data based on the user's IP address.
    // that I have used in several projects. It does not require an API key. Obviously it would require notifying the user.
    // I used it inplace of the HTML5 Geolocation API because for reasons unknown, the Geolocation API was not 
    // working on my local machine.
    const fetchIpGeoData = async (retryCount = 0) => {
        try {
            const response = await fetch(`https://ipapi.co/json/`);
            return await response.json();
        } catch (error) {
            if (retryCount >= 3) return { status: "Failed", error: error };
            return fetchIpGeoData(retryCount + 1);
        }
    }

    const getLocation = async () => {
        const latitudeInput = document.getElementById('latitude');
        const longitudeInput = document.getElementById('longitude');
        const geoOn = document.getElementById('geo_on');
        const isGeoOn = geoOn.value === "1";

        if ((latitudeInput.value && longitudeInput.value) || !isGeoOn) {
            console.log("Using existing location data");
            return;
        }

        const userConsent = confirm("Would you like to share your location data to find nearby food trucks?");
        if (!userConsent) {
            handleDeclinedLocation();
            return;
        }

        console.log("User agreed to share location. Fetching IP-based location...");
        const ipGeoData = await fetchIpGeoData();
        if (ipGeoData.status !== "Failed") {
            updateLocationInputs(ipGeoData);
            updateGeoToggle(true);
        } else {
            console.error("IP-based geolocation failed:", ipGeoData.error);
            alert("Unable to get your location. Please try again later.");
            handleDeclinedLocation();
        }
    }

    const handleDeclinedLocation = () => {
        updateGeoToggle(false);
        console.log("User declined to share location.");
        alert("You can still search for food trucks but will not be able to find ones nearest you.");
    }

    const updateLocationInputs = (geoData) => {
        document.getElementById('latitude').value = geoData.latitude;
        document.getElementById('longitude').value = geoData.longitude;
    }

    // Start the location retrieval process
    getLocation();
});

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
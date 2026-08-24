const cmdsppPageTitle = "{{ pageTitle }}";
const cmdsppPageSubtitle = "{{ pageSubtitle }}";
const cmdsppPageDescription = "{{ pageDescription }}";
const enrollmentApiUrl = window?.cmdsppConfig?.enrollmentApiUrl;
const UserId = window?.cmdsppConfig?.currentUserId;
const EmailId = window?.cmdsppConfig?.currentEmailId;


$(document).ready(function () {

    const cmdsppGrid = document.getElementById("cmdsppEnrollmentGrid");
showLoader("");
console.log("Enrollment API URL:", enrollmentApiUrl);
  fetch(enrollmentApiUrl, {
    method: "POST",
    headers: {
        "Accept": "application/json",
        "Content-Type": "application/json"
    },
    body: JSON.stringify({
    action: "GetEnrollmentTypes"
})
})
.then(response => {
    if (!response.ok) {
        throw new Error(`HTTP Error: ${response.status}`);
    }
    return response.json();
})
.then(result => {

    const cmdsppEnrollmentTypes = (result || []).sort(
        (a, b) => Number(a.code) - Number(b.code)
    );

    const cmdsppIconClasses = [
        "cmdspp-purple-bg",
        "cmdspp-red-bg",
        "cmdspp-blue-bg",
        "cmdspp-orange-bg",
        "cmdspp-green-bg",
        "cmdspp-cyan-bg"
    ];
    
    cmdsppGrid.innerHTML = cmdsppEnrollmentTypes.map((item, index) => {
    return `
        <div class="cmdspp-enrollment-card">
        <div class="cmdspp-card-tooltip"> ${item.tooltip || ''} </div>
           <div class="cmdspp-card-icon ${cmdsppIconClasses[index % cmdsppIconClasses.length]}">
           <img src="${window.location.origin}${item.Icon || ''}"
           alt="${item.title || ''}"
           class="cmdspp-enrollment-icon"/>
           </div>
            <div class="cmdspp-card-content">
                <div class="cmdspp-card-title">
                    ${item.title || ''}
                </div>
            
                <div class="cmdspp-card-description">
                    ${item.description || ''}
                </div>
                <div class="cmdspp-enroll-link ${!item?.status ? 'disabled' : ''}" 
                
                 data-id="${item.id || ''}"
                 data-enrollment="${item.title || ''}"
                 data-enrollment-guid="${item.enrollment_guid || ''}">
                 Enroll Now ›
            </div>

         </div>
        </div>
    `}).join('');
})
.catch(error => {
    console.error("Enrollment Type Load Error:", error);
    cmdsppShowToast("error", "Unable to load enrollment types. Please try again.");

})
.finally(() => {

hideLoader();

});

});

$(document).on("click", ".cmdspp-enroll-link:not(.disabled)", function () {

    const enrollmentId = $(this).data("id");
    const enrollmentName = $(this).data("enrollment");
    // const enrollmentGuid = $(this).data("enrollment-guid");

    showLoader("");

    // Step 1: Check provider availability BEFORE creating the enrollment record
    fetch(enrollmentApiUrl, {
        method: "POST",
        headers: {
            "Accept": "application/json",
            "Content-Type": "application/json"
        },
        body: JSON.stringify({
            action: "GetProviderTypes",
            enrollmentGuid: enrollmentId,
            currentUserId: UserId
        })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP Error: ${response.status}`);
        }
        return response.json();
    })
    .then(providerData => {

        if (!providerData || providerData.length === 0) {
            // No provider types remaining — do not create an enrollment record
            cmdsppShowToast("error", "All provider types are in progress");
            hideLoader();
            return;
        }

        // Step 2: Providers available — proceed to create the enrollment record
        return fetch(enrollmentApiUrl, {
            method: "POST",
            headers: {
                "Accept": "application/json",
                "Content-Type": "application/json"
            },
            body: JSON.stringify({
                enrollmentType: enrollmentName,
                UserId: UserId,
                EmailId: EmailId,
                action: "SetEnrollmentId"
            })
        })
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP Error: ${response.status}`);
            }
            return response.json();
        })
        .then(result => {
            // Redirect with newly created record id
            window.location.href =
                "/Enrollment-pp/Application?id=" +
                encodeURIComponent(result.applicationNumber);
        })
        .finally(() => {
            hideLoader();
        });
    })
    .catch(error => {
        console.error("Enrollment Creation Error:", error);
        cmdsppShowToast("error", "Unable to create enrollment record. Please try again.");
        hideLoader();
    });

});
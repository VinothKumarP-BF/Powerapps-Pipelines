/**
* Power Pages Server Logic
*
* Quick References:
* - Server.Logger → diagnostics logging
*   Example: Server.Logger.Log("message")
*   Example: Server.Logger.Error("error message")
*
* - Server.Context → query params, headers, body
*   Example: Server.Context.QueryParameters["id"], Server.Context.Headers["Authorization"], Server.Context.Body
*
* - Server.Connector.HttpClient → external API calls
*   Example: await Server.Connector.HttpClient.GetAsync("<URL>/1", {"Content-Type":"application/json"});
*   Example: await Server.Connector.HttpClient.PostAsync("<URL>", "{"name":"New Object"}", {"Authorization": "Bearer "},"application/json");
*   Example: await Server.Connector.HttpClient.PatchAsync("<URL>/1", "{"capacity":"1 TB"}", {"Authorization": "Bearer "},"application/json");
*   Example: await Server.Connector.HttpClient.DeleteAsync("<URL>/1", {"Authorization": "Bearer "},"application/json");
*
* - Server.Connector.Dataverse → CRUD in Dataverse & CustomApi
*   Example: Server.Connector.Dataverse.CreateRecord("accounts", "{"name":"Contoso Ltd."}");
*   Example: Server.Connector.Dataverse.RetrieveRecord("accounts", "accountid-guid", "$select=name,telephone1");
*   Example: Server.Connector.Dataverse.UpdateRecord("accounts", "accountid-guid", "{"telephone1":"123-456-7890"}");
*   Example: Server.Connector.Dataverse.DeleteRecord("accounts", "accountid-guid");
*   Example: Server.Connector.Dataverse.InvokeCustomApi("new_CustomApiName", "{"ParameterName":"value"}");
*
* - Server.User → signed-in user info
*   Example: Server.User.fullname, Server.User.Roles
*
* Full details: see https://go.microsoft.com/fwlink/?linkid=2334908
*/
/* 
function get() {
    try {
 
        if (!Server.Context.QueryParameters["id"]) {
            const errorMsg = "Missing required query parameter: id";
            Server.Logger.Error(errorMsg);
            return JSON.stringify({ status: "error", method: "GET", message: errorMsg });
        }
 
        Server.Logger.Log("GET called"); // Logger reference
        const id = Server.Context.QueryParameters["id"]; // Context reference
 
        // 🔹 Quick HttpClient GET example
        // const response = await Server.Connector.HttpClient.GetAsync("https://api.nuget.org/v3/index.json", {"Content-Type":"application/json"});
        // return JSON.parse(response.Body);
 
 
        return JSON.stringify({ status: "success", method: "GET", id: id });
    } catch (err) {
        Server.Logger.Error("GET failed: " + err.message);
        return JSON.stringify({ status: "error", method: "GET", message: err.message });
    }
}
 
 
function post() {
    try {
        Server.Logger.Log("POST called");
        const data = Server.Context.Body;
 
        // 🔹 Quick Dataverse Create example
        // const response = Server.Connector.Dataverse.CreateRecord("accounts", JSON.stringify({ name: "New Account", telephone1: "123-456-7890" }));
 
        return JSON.stringify({ status: "success", method: "POST", data: data });
    } catch (err) {
        Server.Logger.Error("POST failed: " + err.message);
        return JSON.stringify({ status: "error", method: "POST", message: err.message });
    }
}
 
 
function put() {
    try {
        Server.Logger.Log("PUT called");
        const id = Server.Context.QueryParameters["id"];
        const data = Server.Context.Body;
 
        // 🔹 Quick Dataverse Update example
        // var response = Server.Connector.Dataverse.UpdateRecord("accounts", id, data);
 
        return JSON.stringify({ status: "success", method: "PUT", id: id, data: data });
    } catch (err) {
        Server.Logger.Error("PUT failed: " + err.message);
        return JSON.stringify({ status: "error", method: "PUT", message: err.message });
    }
}
 
 
async function patch() {
    try {
        Server.Logger.Log("PATCH called");
        const id = Server.Context.QueryParameters["id"];
        const data = Server.Context.Body;
 
        // 🔹 Quick HttpClient PATCH example
        // await Server.Connector.HttpClient.PatchAsync("<URL>" + id, JSON.stringify({ capacity: "1 TB" }), {"Authorization": "Bearer "},"application/json");
 
        return JSON.stringify({ status: "success", method: "PATCH", id: id, data: data });
    } catch (err) {
        Server.Logger.Error("PATCH failed: " + err.message);
        return JSON.stringify({ status: "error", method: "PATCH", message: err.message });
    }
}
 
 
function del() {
    try {
        // "delete" keyword should not be used in script file.
        Server.Logger.Log("DEL called");
        const id = Server.Context.QueryParameters["id"];
 
        // 🔹 Quick Dataverse Del example
        // var response = Server.Connector.Dataverse.DeleteRecord("accounts", id);
 
        return JSON.stringify({ status: "success", method: "DEL", id: id });
    } catch (err) {
        Server.Logger.Error("Deletion failed: " + err.message);
        return JSON.stringify({ status: "error", method: "DEL", message: err.message });
    }
}
*/

async function post() {
    try {
        const payload = JSON.parse(Server.Context.Body);
        const enrollmentId = payload?.enrollmentId;
        const enrollmentName = payload?.enrollmentName;
        const userId = payload?.userId;
        const emailId = payload?.emailId;

        const availableProvidersRaw = await Server.Connector.Dataverse.RetrieveMultipleRecords(
            "cmdspp_pc_pvd_enrol_map_tbs",
            `$filter=_cmdspp_p_enrol_fk_id_value eq ${enrollmentId} and statecode eq 0`
        );

        const usedProvidersRaw = await Server.Connector.Dataverse.RetrieveMultipleRecords(
            "cmdspp_p_dtl_tbs",
            `$filter=_cmdspp_created_by_user_value eq ${userId} and _cmdspp_p_provider_ty_lkpid_value ne null and cmdspp_p_appln_status ne 7 and statecode eq 0`
        );


        function parseDataverseResponse(responseRaw) {
            if (!responseRaw) return [];

            const wrapper = typeof responseRaw === "string" ? JSON.parse(responseRaw) : responseRaw;

            if (wrapper.Body) {
                const bodyObj = typeof wrapper.Body === "string" ? JSON.parse(wrapper.Body) : wrapper.Body;
                return bodyObj.value || [];
            }
            return wrapper.value || [];
        }

        const array1 = parseDataverseResponse(availableProvidersRaw);
        const array2 = parseDataverseResponse(usedProvidersRaw);

        if (!Array.isArray(array1)) {
            return JSON.stringify({ status: "error", message: "Failed to parse Dataverse arrays." });
        }

        const filteredProviders = array1.filter(a => {
            const providerTypeId = a["_cmdspp_p_pvd_fk_id_value"];
            const match = array2.find(b => b["_cmdspp_p_provider_ty_lkpid_value"] === providerTypeId);
            if (!match) return true;
        });

        if (!filteredProviders || filteredProviders.length === 0) {
            return JSON.stringify({ status: "no_providers", availableProvidersRaw, payload });
        }

        const createPayload = {
            "cmdspp_p_enrolment_type": enrollmentName,
            
            "cmdspp_created_by_user@odata.bind": `/cmdspp_g_usr_dtls_tbs(${userId})`,
            
            "cmdspp_p_enrollment_id@odata.bind": `/cmdspp_pc_enrol_typ_tbs(${enrollmentId})`,
            "cmdspp_p_appln_email": emailId,
            "cmdspp_p_first_nam": "Juan",
            "cmdspp_p_last_nam": "NARVAEZ"
        };

        const newRecordRaw = await Server.Connector.Dataverse.CreateRecord(
            "cmdspp_p_dtl_tbs",
            JSON.stringify(createPayload)
        );
        const newRecordWrapper = typeof newRecordRaw === "string" ? JSON.parse(newRecordRaw) : newRecordRaw;
        const recordId = newRecordWrapper.Headers ? newRecordWrapper.Headers.entityId : null;

        if (!recordId) {
            return JSON.stringify({ status: "error", message: "Record created, but could not extract entityId from headers." });
        }

        const fetchEnrollmentRaw = await Server.Connector.Dataverse.RetrieveMultipleRecords(
            "cmdspp_p_dtl_tbs",
            `$filter=cmdspp_p_dtl_tbid eq ${recordId} and statecode eq 0`
        );

        const fetchEnrollmentData = parseDataverseResponse(fetchEnrollmentRaw);

        let applicationNumber = "UNKNOWN"; // fallback
        if (fetchEnrollmentData && fetchEnrollmentData.length > 0) {
            applicationNumber = fetchEnrollmentData[0].cmdspp_p_sys_id;
        }
        return JSON.stringify({
            status: "success",
            applicationId: recordId,
            applicationNumber: applicationNumber
        });

    } catch (err) {
        Server.Logger.Error("Enrollment creation failed: " + err.message);
        return JSON.stringify({ status: "error", message: err.message });
    }
}
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
 
// function get() {
//     try {
 
//         if (!Server.Context.QueryParameters["id"]) {
//             const errorMsg = "Missing required query parameter: id";
//             Server.Logger.Error(errorMsg);
//             return JSON.stringify({ status: "error", method: "GET", message: errorMsg });
//         }
 
//         Server.Logger.Log("GET called"); // Logger reference
//         const id = Server.Context.QueryParameters["id"]; // Context reference
 
//         // 🔹 Quick HttpClient GET example
//         // const response = await Server.Connector.HttpClient.GetAsync("https://api.nuget.org/v3/index.json", {"Content-Type":"application/json"});
//         // return JSON.parse(response.Body);
 
 
//         return JSON.stringify({ status: "success", method: "GET", id: id });
//     } catch (err) {
//         Server.Logger.Error("GET failed: " + err.message);
//         return JSON.stringify({ status: "error", method: "GET", message: err.message });
//     }
// }
 
 
// function post() {
//     try {
//         Server.Logger.Log("POST called");
//         const data = Server.Context.Body;
 
//         // 🔹 Quick Dataverse Create example
//         // const response = Server.Connector.Dataverse.CreateRecord("accounts", JSON.stringify({ name: "New Account", telephone1: "123-456-7890" }));
 
//         return JSON.stringify({ status: "success", method: "POST", data: data });
//     } catch (err) {
//         Server.Logger.Error("POST failed: " + err.message);
//         return JSON.stringify({ status: "error", method: "POST", message: err.message });
//     }
// }
 
 
// function put() {
//     try {
//         Server.Logger.Log("PUT called");
//         const id = Server.Context.QueryParameters["id"];
//         const data = Server.Context.Body;
 
//         // 🔹 Quick Dataverse Update example
//         // var response = Server.Connector.Dataverse.UpdateRecord("accounts", id, data);
 
//         return JSON.stringify({ status: "success", method: "PUT", id: id, data: data });
//     } catch (err) {
//         Server.Logger.Error("PUT failed: " + err.message);
//         return JSON.stringify({ status: "error", method: "PUT", message: err.message });
//     }
// }
 
 
// async function patch() {
//     try {
//         Server.Logger.Log("PATCH called");
//         const id = Server.Context.QueryParameters["id"];
//         const data = Server.Context.Body;
 
//         // 🔹 Quick HttpClient PATCH example
//         // await Server.Connector.HttpClient.PatchAsync("<URL>" + id, JSON.stringify({ capacity: "1 TB" }), {"Authorization": "Bearer "},"application/json");
 
//         return JSON.stringify({ status: "success", method: "PATCH", id: id, data: data });
//     } catch (err) {
//         Server.Logger.Error("PATCH failed: " + err.message);
//         return JSON.stringify({ status: "error", method: "PATCH", message: err.message });
//     }
// }
 
 
// function del() {
//     try {
//         // "delete" keyword should not be used in script file.
//         Server.Logger.Log("DEL called");
//         const id = Server.Context.QueryParameters["id"];
 
//         // 🔹 Quick Dataverse Del example
//         // var response = Server.Connector.Dataverse.DeleteRecord("accounts", id);
 
//         return JSON.stringify({ status: "success", method: "DEL", id: id });
//     } catch (err) {
//         Server.Logger.Error("Deletion failed: " + err.message);
//         return JSON.stringify({ status: "error", method: "DEL", message: err.message });
//     }
// }
 



// SERVER LOGIC: melissaVerify
async function post() {
    try {
        const payload = JSON.parse(Server.Context.Body);
        const { address1, city, state, zip } = payload;

        // 1. Fetch Key
        // const rawKeyResponse = await Server.Connector.Dataverse.RetrieveMultipleRecords(
        //     "adx_sitesetting", 
        //     "$filter=adx_name eq 'Melissa/SandboxKey'&$select=adx_value"
        // );

        const rawKeyResponse = "lXgWJ8AzhZVDowx3aqx0Ga**";
        
        // 2. Safely parse
        const wrapper = typeof rawKeyResponse === "string" ? JSON.parse(rawKeyResponse) : rawKeyResponse;
        const bodyObj = wrapper.Body ? (typeof wrapper.Body === "string" ? JSON.parse(wrapper.Body) : wrapper.Body) : wrapper;
        const records = bodyObj.value || [];

        if (records.length === 0) {
            return JSON.stringify({ status: "error", message: "API Key missing." });
        }
        const licenseKey = records[0].adx_value;

        // 3. Construct Payload
        const melissaPayload = {
            "TransmissionReference": "PowerPagesFormVerif",
            "CustomerID": licenseKey,
            "Options": "",
            "Records": [{
                "RecordID": "1",
                "AddressLine1": address1 || "",
                "Locality": city || "",
                "AdministrativeArea": state || "",
                "PostalCode": zip || "",
                "Country": "US"
            }]
        };

        // 4. Call Melissa
        const response = await Server.Connector.Http.Send({
            method: "POST",
            url: "https://address.melissadata.net/V3/WEB/GlobalAddress/doGlobalAddress",
            headers: {
                "Content-Type": "application/json",
                "Accept": "application/json"
            },
            body: JSON.stringify(melissaPayload)
        });

        // 5. Parse and Evaluate
        const melissaResult = typeof response.Body === "string" ? JSON.parse(response.Body) : response.Body;
        const validatedRecord = melissaResult.Records[0];
        
        const resultCodes = validatedRecord.Results || "";
        const isValid = resultCodes.includes("AV2");

        if (!isValid) {
            return JSON.stringify({ status: "invalid", message: "Invalid address.", rawCodes: resultCodes });
        }

        return JSON.stringify({
            status: "success",
            standardizedAddress: {
                address1: validatedRecord.AddressLine1,
                city: validatedRecord.Locality,
                state: validatedRecord.AdministrativeArea,
                zip: validatedRecord.PostalCode
            }
        });

    } catch (err) {
        Server.Logger.Error("Melissa Verify Error: " + err.message);
        return JSON.stringify({ status: "error", message: err.message });
    }
}
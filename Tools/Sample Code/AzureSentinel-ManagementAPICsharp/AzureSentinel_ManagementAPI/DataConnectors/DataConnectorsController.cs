﻿using System;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using AzureSentinel_ManagementAPI.DataConnectors.Models;
using AzureSentinel_ManagementAPI.Infrastructure.Authentication;
using AzureSentinel_ManagementAPI.Infrastructure.Configuration;
using Microsoft.Extensions.Configuration;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;

namespace AzureSentinel_ManagementAPI.DataConnectors
{
    public class DataConnectorsController
    {
        private readonly AzureSentinelApiConfiguration[] azureConfigs;
        private readonly AuthenticationService authenticationService;
        private bool cliMode;

        public DataConnectorsController(
            AzureSentinelApiConfiguration[] azureConfig,
            IConfigurationRoot rawConfig,
            AuthenticationService authenticationService
        )
        {
            azureConfigs = azureConfig;
            this.authenticationService = authenticationService;
            cliMode = rawConfig.GetValue<bool>("Climode");
        }

        /// <summary>
        /// Get all data connectors for all instances or for a single instance
        /// </summary>
        /// <returns></returns>
        public async Task GetDataConnectors(int insId)
        {            
            if (insId != -1)
            {
                await GetDataConnectorsByInstance(insId);
            }
            else
            {
                for (var i = 0; i < azureConfigs.Length; i++)
                {
                    await GetDataConnectorsByInstance(i);
                }
            }
        }

        /// <summary>
        /// Get all data connectors for a single instance
        /// </summary>
        /// <param name="i"></param>
        /// <returns></returns>
        private async Task GetDataConnectorsByInstance(int i)
        {
            try
            {
                var url = $"{azureConfigs[i].BaseUrl}/dataConnectors?api-version={azureConfigs[i].ApiVersion}";
                var request = new HttpRequestMessage(HttpMethod.Get, url);
                await authenticationService.AuthenticateRequest(request, i);
                var http = new HttpClient();
                var response = await http.SendAsync(request);

                if (response.IsSuccessStatusCode)
                {
                    string res = await response.Content.ReadAsStringAsync();
                    JObject result = JsonConvert.DeserializeObject<JObject>(res);
                    var values = result["value"] as JArray;
                    if (values == null)
                    {
                        values = new JArray();
                    }
                    int callTimes = 1;
                    
                    while (result.ContainsKey("nextLink") && callTimes < 100)
                    {
                        try
                        {
                            var nextLink = result["nextLink"].ToString();
                            request = new HttpRequestMessage(HttpMethod.Get, nextLink);
                            await authenticationService.AuthenticateRequest(request, i);
                            var nextResponse = await http.SendAsync(request);
                            
                            if (nextResponse.IsSuccessStatusCode)
                            {
                                var newRes = await nextResponse.Content.ReadAsStringAsync();
                                JObject newResult = JsonConvert.DeserializeObject<JObject>(newRes);
                                result = newResult;
                                var newValues = result["value"] as JArray;
                                
                                if (newValues == null)
                                {
                                    newValues = new JArray();
                                }
                                
                                foreach (var v in newValues)
                                {
                                    values.Add(v);
                                }
                                callTimes++;
                            }
                            else
                            {
                                var err = await response.Content.ReadAsStringAsync();
                                Console.WriteLine("Error calling the nextLink: \n" + err);
                                break;
                            }
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine("Error in parsing nextLink: \n" + ex.Message);
                            break;
                        }
                    }

                    var formattedRes = JsonConvert.SerializeObject(values, Formatting.Indented);
                    Utils.WriteJsonStringToFile($"GetDataConnectors_{azureConfigs[i].InstanceName}.json", cliMode, formattedRes, false);
                    Console.WriteLine(formattedRes);
                    return;
                }

                var error = await response.Content.ReadAsStringAsync();
                var formatted = JsonConvert.DeserializeObject(error);
                throw new WebException("Error calling the API: \n" +
                                        JsonConvert.SerializeObject(formatted, Formatting.Indented));
            }
            catch (Exception ex)
            {
                throw new Exception($"Something went wrong on {azureConfigs[i].InstanceName}: \n"
                    + ex.Message);
            }
        }

        /// <summary>
        /// Create a data connector for all instances or for a single instance
        /// </summary>
        /// <returns></returns>
        public async Task CreateDataConnector(int insId)
        {           
            if (insId != -1)
            {
                await CreateDataConnectorByInstance(insId);
            }
            else
            {
                for (var i = 0; i < azureConfigs.Length; i++)
                {
                    await CreateDataConnectorByInstance(i);
                }
            }
        }

        /// <summary>
        /// Create a data connector for a single instance
        /// </summary>
        /// <param name="i"></param>
        /// <returns></returns>
        private async Task CreateDataConnectorByInstance(int i)
        {
            var dataConnectors = Utils.LoadPayload<ASCDataConnectorPayload[]>("DataConnectorPayload.json", cliMode);
            
            foreach (var payload in dataConnectors)
            {
                try
                {
                    var dataConnectorId = Guid.NewGuid().ToString();

                    var url =
                        $"{azureConfigs[i].BaseUrl}/dataConnectors/{dataConnectorId}?api-version={azureConfigs[i].ApiVersion}";

                    var serialized = JsonConvert.SerializeObject(payload, new JsonSerializerSettings
                    {
                        NullValueHandling = NullValueHandling.Ignore,
                        ContractResolver = new DefaultContractResolver
                        {
                            NamingStrategy = new CamelCaseNamingStrategy()
                        }
                    });

                    var request = new HttpRequestMessage(HttpMethod.Put, url)
                    {
                        Content = new StringContent(serialized, Encoding.UTF8, "application/json")
                    };
                    await authenticationService.AuthenticateRequest(request, i);

                    var http = new HttpClient();
                    var response = await http.SendAsync(request);

                    if (response.IsSuccessStatusCode)
                    {
                        var res = await response.Content.ReadAsStringAsync();
                        Console.WriteLine(JToken.Parse(res).ToString(Formatting.Indented));
                        continue;
                    }

                    var error = await response.Content.ReadAsStringAsync();
                    var formatted = JsonConvert.DeserializeObject(error);
                    throw new WebException("Error calling the API: \n" +
                                                JsonConvert.SerializeObject(formatted, Formatting.Indented));
                }
                catch (Exception ex)
                {
                    throw new Exception($"Something went wrong on {azureConfigs[i].InstanceName}: \n"
                        + ex.Message);
                }
            }
        }
        
        /// <summary>
        /// Delete a data connector by id
        /// </summary>
        /// <param name="dataConnectorId"></param>
        /// <returns></returns>
        public async Task<string> DeleteDataConnector(string dataConnectorId, int insId)
        {
            try
            {
                var url = $"{azureConfigs[insId].BaseUrl}/dataConnectors/{dataConnectorId}?api-version={azureConfigs[insId].ApiVersion}";

                var request = new HttpRequestMessage(HttpMethod.Delete, url);
                await authenticationService.AuthenticateRequest(request, insId);

                var http = new HttpClient();
                var response = await http.SendAsync(request);

                if (response.IsSuccessStatusCode) return await response.Content.ReadAsStringAsync();
                
                if (response.StatusCode == HttpStatusCode.NotFound)
                    throw new Exception("Not found, please create a new DataConnector first...");

                var error = await response.Content.ReadAsStringAsync();
                var formatted = JsonConvert.DeserializeObject(error);
                throw new WebException("Error calling the API: \n" +
                                       JsonConvert.SerializeObject(formatted, Formatting.Indented));
            }
            catch (Exception ex)
            {
                throw new Exception("Something went wrong: \n" + ex.Message);
            }
        }
    }
}
/*
 * This code will configure ESP8266 in station mode which will then connect with a WiFi network. 
 */
 
#include <ESP8266WiFi.h>
 
//Specifying the SSID and Password of the Local WiFi Network
 
const char* ssid = "FatLARDbev"; //“your_wifi_ssid”
const char* password = "fatlardr6"; //"your_wifi_password"
 
uint8_t retries=0;
 
void setup()
{
  //Start the serial communication with the computer
  Serial.begin(115200);
  delay(100);
  Serial.println();
 
  //Try and Connect to the Network
  WiFi.begin(ssid,password);
  Serial.print("Connecting to ");
  Serial.print(ssid);
  Serial.println("...");
 
  //Wait for WiFi to connect for a maximum timeout of 20 seconds
  while(WiFi.status()!=WL_CONNECTED && retries<20)
  {
    Serial.print(".");
    retries++;
    delay(1000);
  }
 
  Serial.println();
  //Inform the user whether the timeout has occured, or the ESP8266 is connected to the internet
  if(retries==20)//Timeout has occured
  {
    Serial.print("Unable to Connect to ");
    Serial.println(ssid);
  }
   
  if(WiFi.status()==WL_CONNECTED)//WiFi has succesfully Connected
  {
    Serial.print("Successfully connected to ");
    Serial.println(ssid);
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  }
}
 
void loop() {
  // Maintain your WiFi connection by checking its status before performing any internet related task
  if (WiFi.status()==WL_CONNECTED)
  {
    //EP8266 is connected to WiFi Access Point. You can access Internet or any Web Server
    Serial.println("Connected...");
    delay(1000);
  }
  else
  {
    //ESP8266 is not connected to any WiFi network. You need to wait for the internet connection before you start interacting with any web server
    Serial.print("Trying to connect with ");
    Serial.print(ssid);
    while(WiFi.status()!=WL_CONNECTED)
    {
      Serial.print(".");
      delay(1000);
    }
    Serial.println();
    Serial.print("Sucessfully Connected to ");
    Serial.println(ssid);
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  }
}
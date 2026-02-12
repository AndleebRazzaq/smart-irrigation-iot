#include <WiFi.h>
#include <FirebaseESP32.h>
#include <DHT.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

const char* ssid = "YOUR_WIFI";
const char* password = "YOUR_PASSWORD";

#define FIREBASE_HOST "smart-irrigation-aab58-default-rtdb.firebaseio.com"
#define FIREBASE_AUTH "RDkNQXPaDP8JbeFqFYDUE1w4XaQt7rUOCOxhPpBM"

#define DHTPIN 15
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

#define SOIL_PIN 34
#define WATER_LEVEL_PIN 35
#define RELAY_PIN 26

LiquidCrystal_I2C lcd(0x27, 16, 2);
FirebaseData fbdo;

void setup() {
Serial.begin(115200);

dht.begin();
lcd.init();
lcd.backlight();

pinMode(RELAY_PIN, OUTPUT);
digitalWrite(RELAY_PIN, LOW);

WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
Serial.print("Connecting to WiFi");
while (WiFi.status() != WL_CONNECTED) {
delay(500);
Serial.print(".");
}
Serial.println("\nConnected!");

Firebase.begin(FIREBASE_HOST, FIREBASE_AUTH);
Firebase.reconnectWiFi(true);
}

void loop() {
float temperature = dht.readTemperature();
float humidity = dht.readHumidity();
int soilRaw = analogRead(SOIL_PIN);
int waterRaw = analogRead(WATER_LEVEL_PIN);

int soilPercent = map(soilRaw, 3200, 1200, 0, 100);
soilPercent = constrain(soilPercent, 0, 100);
int waterPercent = map(waterRaw, 500, 3000, 0, 100);
waterPercent = constrain(waterPercent, 0, 100);

// LCD Display
lcd.clear();
lcd.setCursor(0, 0);
lcd.print("T:");
lcd.print(temperature);
lcd.print("C H:");
lcd.print(humidity);

lcd.setCursor(0, 1);
lcd.print("S:");
lcd.print(soilPercent);
lcd.print("% W:");
lcd.print(waterPercent);
lcd.print("%");

// Push data to Firebase
Firebase.setFloat(fbdo, "/sensors/temperature", temperature);
Firebase.setFloat(fbdo, "/sensors/humidity", humidity);
Firebase.setInt(fbdo, "/sensors/soilMoisture", soilPercent);
Firebase.setInt(fbdo, "/sensors/waterLevel", waterPercent);

// Read control values
bool autoMode = true;
bool manualPump = false;

Firebase.getBool(fbdo, "/controls/autoMode");
if (fbdo.dataType() == "boolean") {
autoMode = fbdo.boolData();
}

Firebase.getBool(fbdo, "/controls/manualPump");
if (fbdo.dataType() == "boolean") {
manualPump = fbdo.boolData();
}

// Control logic
bool pumpStatus = false;
if (autoMode) {
if (soilPercent < 30 && waterPercent > 30) {
pumpStatus = true;
}
} else {
pumpStatus = manualPump;
}

digitalWrite(RELAY_PIN, pumpStatus ? HIGH : LOW);
Firebase.setBool(fbdo, "/pumpStatus", pumpStatus);

delay(3000); // Update every 3 seconds
}


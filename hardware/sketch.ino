// Athletix-Data — lecture du signal du photopléthysmographe sur ESP32
// Broche de lecture analogique (reliée à la sortie Vs du montage)
// Nom sans accent : certaines chaînes de compilation refusent les identifiants accentués.
const int pinPlethysmographe = 34;

void setup() {
  // Initialisation du moniteur série pour observer le signal
  Serial.begin(115200);

  // Configuration de la broche en entrée
  pinMode(pinPlethysmographe, INPUT);
}

void loop() {
  // Lecture de la tension analogique (valeur entre 0 et 4095 sur ESP32)
  int valeurAnalogique = analogRead(pinPlethysmographe);

  // Envoi de la valeur sur le port série (visible avec le traceur série de l'IDE Arduino)
  Serial.println(valeurAnalogique);

  // Petite pause pour échantillonner le signal proprement (toutes les 20 ms = 50 Hz)
  delay(20);
}

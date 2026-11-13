// Imitations minimales du cœur Arduino ESP32 (BLE, Wire, FreeRTOS, ADC) pour COMPILER et FAIRE
// TOURNER le firmware du brassard sur un ordinateur, sans carte : tests/firmware/test_firmware_complet.cpp.
//
// Ce ne sont pas les vraies bibliothèques : seules les fonctions utilisées par le firmware existent,
// avec les mêmes noms et les mêmes paramètres que dans le cœur « esp32 » d'Espressif (version 3).
// Ça permet de vérifier que le programme se compile et que sa logique marche (commandes, paquets,
// source RAW, fatigue, natation). Ça ne remplace PAS une compilation pour l'ESP32 ni un essai sur la carte.
#pragma once

#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include <condition_variable>
#include <functional>
#include <map>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

// ---------------------------------------------------------------- banc d'essai
namespace banc {
inline uint64_t micros = 0;                                   // temps simulé
inline std::function<double(double)> signalMv = [](double) { return 0.0; };  // tension sur A0 selon t (s)
inline std::vector<std::string> lignesSerie;
inline std::mutex verrou;
inline uint8_t batterieJauge = 87;
inline bool jaugePresente = true;
}  // namespace banc

inline unsigned long micros() { return (unsigned long)(banc::micros & 0xFFFFFFFFu); }
inline unsigned long millis() { return (unsigned long)((banc::micros / 1000) & 0xFFFFFFFFu); }

const int A0 = 10;
enum { ADC_0db, ADC_2_5db, ADC_6db, ADC_11db };
inline void analogReadResolution(int) {}
inline void analogSetPinAttenuation(int, int) {}
inline uint32_t analogReadMilliVolts(int) {
  double v = banc::signalMv(banc::micros / 1e6);
  if (v < 0) v = 0;
  if (v > 3300) v = 3300;  // plage du convertisseur
  return (uint32_t)lround(v);
}

struct ImitationSerie {
  void begin(unsigned long) {}
  void println(const char *t) { garder(std::string(t)); }
  int printf(const char *format, ...) __attribute__((format(printf, 2, 3))) {
    char tampon[256];
    va_list a;
    va_start(a, format);
    int n = vsnprintf(tampon, sizeof tampon, format, a);
    va_end(a);
    std::string s(tampon);
    size_t debut = 0, fin;
    while ((fin = s.find('\n', debut)) != std::string::npos) {
      garder(s.substr(debut, fin - debut));
      debut = fin + 1;
    }
    return n;
  }
  void garder(const std::string &l) {
    std::lock_guard<std::mutex> g(banc::verrou);
    banc::lignesSerie.push_back(l);
  }
};
inline ImitationSerie Serial;

struct ImitationEsp {
  uint64_t getEfuseMac() { return 0x0000A1B2C3D4E5F6ULL; }
};
inline ImitationEsp ESP;

// ---------------------------------------------------------------- I2C (jauge MAX17048)
struct ImitationWire {
  int lus = 0;
  void begin() {}
  void beginTransmission(uint8_t) {}
  size_t write(uint8_t) { return 1; }
  uint8_t endTransmission(bool = true) { return banc::jaugePresente ? 0 : 2; }
  uint8_t requestFrom(int, int n) {
    lus = 0;
    return banc::jaugePresente ? n : 0;
  }
  int read() { return lus++ == 0 ? banc::batterieJauge : 0; }
};
inline ImitationWire Wire;

// ---------------------------------------------------------------- FreeRTOS
struct ImitationSemaphore {
  std::mutex m;
  std::condition_variable cv;
  bool donne = false;
};
typedef ImitationSemaphore *SemaphoreHandle_t;
typedef int BaseType_t;
typedef void (*TaskFunction_t)(void *);
typedef void *TaskHandle_t;
const uint32_t portMAX_DELAY = 0xFFFFFFFF;
const BaseType_t pdTRUE = 1, pdFALSE = 0;
inline SemaphoreHandle_t xSemaphoreCreateBinary() { return new ImitationSemaphore(); }
inline BaseType_t xSemaphoreGive(SemaphoreHandle_t s) {
  {
    std::lock_guard<std::mutex> g(s->m);
    s->donne = true;
  }
  s->cv.notify_one();
  return pdTRUE;
}
inline BaseType_t xSemaphoreTake(SemaphoreHandle_t s, uint32_t) {
  std::unique_lock<std::mutex> g(s->m);
  s->cv.wait(g, [s] { return s->donne; });
  s->donne = false;
  return pdTRUE;
}
// Files : copient des éléments de taille fixe, attente possible des deux côtés
struct ImitationFile {
  std::mutex m;
  std::condition_variable cv;
  std::vector<std::vector<uint8_t>> elements;
  size_t longueur, taille;
  int envois = 0;
};
typedef ImitationFile *QueueHandle_t;
inline QueueHandle_t xQueueCreate(size_t longueur, size_t taille) {
  auto *f = new ImitationFile();
  f->longueur = longueur;
  f->taille = taille;
  return f;
}
inline BaseType_t xQueueSend(QueueHandle_t f, const void *e, uint32_t attente) {
  std::unique_lock<std::mutex> g(f->m);
  if (f->elements.size() >= f->longueur) {
    if (attente == 0) return pdFALSE;
    f->cv.wait(g, [f] { return f->elements.size() < f->longueur; });
  }
  const uint8_t *o = (const uint8_t *)e;
  f->elements.emplace_back(o, o + f->taille);
  f->envois++;
  f->cv.notify_all();
  return pdTRUE;
}
inline BaseType_t xQueueReceive(QueueHandle_t f, void *e, uint32_t attente) {
  std::unique_lock<std::mutex> g(f->m);
  if (f->elements.empty()) {
    if (attente == 0) return pdFALSE;
    f->cv.wait(g, [f] { return !f->elements.empty(); });
  }
  memcpy(e, f->elements.front().data(), f->taille);
  f->elements.erase(f->elements.begin());
  f->cv.notify_all();
  return pdTRUE;
}
inline size_t elementsEnAttente(QueueHandle_t f) {
  std::lock_guard<std::mutex> g(f->m);
  return f->elements.size();
}

inline BaseType_t xTaskCreatePinnedToCore(TaskFunction_t f, const char *, uint32_t, void *p, int, TaskHandle_t *, int) {
  std::thread(f, p).detach();
  return pdTRUE;
}

// ---------------------------------------------------------------- Bluetooth LE
typedef uint8_t esp_bd_addr_t[6];
union esp_ble_gatts_cb_param_t {
  struct {
    uint16_t conn_id;
    esp_bd_addr_t remote_bda;
  } connect;
};

class BLEUUID {
 public:
  BLEUUID(uint16_t court) {
    char t[40];
    snprintf(t, sizeof t, "0000%04x-0000-1000-8000-00805f9b34fb", court);
    texte = t;
  }
  BLEUUID(const char *t) : texte(t) {}
  std::string texte;
};

class BLECharacteristic;
class BLECharacteristicCallbacks {
 public:
  virtual ~BLECharacteristicCallbacks() {}
  virtual void onWrite(BLECharacteristic *) {}
  virtual void onRead(BLECharacteristic *) {}
};

class BLEDescriptor {
 public:
  virtual ~BLEDescriptor() {}
};
class BLE2902 : public BLEDescriptor {};

class BLECharacteristic {
 public:
  static const uint32_t PROPERTY_READ = 1 << 0, PROPERTY_WRITE = 1 << 1, PROPERTY_NOTIFY = 1 << 2,
                        PROPERTY_INDICATE = 1 << 3, PROPERTY_WRITE_NR = 1 << 4;
  BLECharacteristic(const std::string &uuid, uint32_t proprietes) : uuid(uuid), proprietes(proprietes) {}

  void setValue(uint8_t *d, size_t n) { valeur.assign(d, d + n); }
  void setValue(const char *t) { valeur.assign(t, t + strlen(t)); }
  uint8_t *getData() { return valeur.data(); }
  size_t getLength() { return valeur.size(); }
  void notify() { notifications.push_back(valeur); }
  void addDescriptor(BLEDescriptor *d) { descripteurs.push_back(d); }
  void setCallbacks(BLECharacteristicCallbacks *c) { rappels = c; }
  void setAccessPermissions(uint16_t p) { permissions = p; }

  // Côté « application » du banc d'essai
  void ecrireDepuisApplication(std::vector<uint8_t> octets) {
    valeur = octets;
    if (rappels) rappels->onWrite(this);
  }
  std::vector<uint8_t> lireDepuisApplication() {
    if (rappels) rappels->onRead(this);
    return valeur;
  }

  std::string uuid;
  uint32_t proprietes;
  uint16_t permissions = 0;
  std::vector<uint8_t> valeur;
  std::vector<std::vector<uint8_t>> notifications;
  std::vector<BLEDescriptor *> descripteurs;
  BLECharacteristicCallbacks *rappels = nullptr;
};

namespace banc {
inline std::map<std::string, BLECharacteristic *> caracteristiques;
inline BLECharacteristic *caracteristique(const std::string &uuid) {
  auto i = caracteristiques.find(uuid);
  return i == caracteristiques.end() ? nullptr : i->second;
}
}  // namespace banc

class BLEService {
 public:
  explicit BLEService(const std::string &u) : uuid(u) {}
  BLECharacteristic *createCharacteristic(BLEUUID u, uint32_t proprietes) {
    auto *c = new BLECharacteristic(u.texte, proprietes);
    banc::caracteristiques[u.texte] = c;
    return c;
  }
  BLECharacteristic *createCharacteristic(const char *u, uint32_t proprietes) { return createCharacteristic(BLEUUID(u), proprietes); }
  void start() { demarre = true; }
  std::string uuid;
  bool demarre = false;
};

class BLEServer;
class BLEServerCallbacks {
 public:
  virtual ~BLEServerCallbacks() {}
  virtual void onConnect(BLEServer *) {}
  virtual void onConnect(BLEServer *, esp_ble_gatts_cb_param_t *) {}
  virtual void onDisconnect(BLEServer *) {}
};

class BLEServer {
 public:
  void setCallbacks(BLEServerCallbacks *c) { rappels = c; }
  BLEService *createService(BLEUUID u) { return new BLEService(u.texte); }
  BLEService *createService(const char *u) { return createService(BLEUUID(u)); }
  void updateConnParams(esp_bd_addr_t, uint16_t mini, uint16_t maxi, uint16_t latence, uint16_t delai) {
    intervalleMin = mini;
    intervalleMax = maxi;
    (void)latence;
    (void)delai;
  }
  BLEServerCallbacks *rappels = nullptr;
  uint16_t intervalleMin = 0, intervalleMax = 0;
};

class BLEAdvertising {
 public:
  void addServiceUUID(const char *u) { services.push_back(u); }
  void setScanResponse(bool) {}
  std::vector<std::string> services;
};

class BLEDevice {
 public:
  static void init(const char *nom) { nomAppareil() = nom; }
  static BLEServer *createServer() { return serveur() = new BLEServer(); }
  static BLEAdvertising *getAdvertising() {
    static BLEAdvertising a;
    return &a;
  }
  static void startAdvertising() { annonces()++; }
  static std::string &nomAppareil() {
    static std::string n;
    return n;
  }
  static BLEServer *&serveur() {
    static BLEServer *s = nullptr;
    return s;
  }
  static int &annonces() {
    static int n = 0;
    return n;
  }
};

# 🎯 Aria v1.0 - LiDAR Room Scanning & AR Anchors

Guida completa per il sistema di scansione LiDAR persistente con ancoramento di oggetti AR nella stanza reale.

## 📋 Breve Panoramica

Questo sistema permette di:
1. **Scansionare una stanza** con il LiDAR dell'iPhone
2. **Posizionare oggetti AR** (quadri, sculture, mobili) nel mondo reale
3. **Salvare la stanza** con una firma digitale univoca
4. **Riconoscere la stanza** quando riapri l'app
5. **Ripristinare automaticamente** gli oggetti AR negli stessi punti

## 🚀 Architettura del Sistema

```
┌─────────────────────────────────────────┐
│         MainAppView (Tab Navigation)    │
├─────────────────────────────────────────┤
│  Tab 1: Chat (ContentView)              │
│  Tab 2: LiDAR Scanner (LiDARScannerView)│
└─────────────────────────────────────────┘
         ↓
    LiDARScanManager (@Observable)
         ├─ ARSession (Real-time tracking)
         ├─ Depth Frame Collection
         ├─ Mesh Reconstruction
         └─ Room Recognition
         ↓
    ┌─────────────────┬──────────────────┐
    ↓                 ↓                  ↓
ARViewContainer  PlaneDetection    AnchorStorage
    ↓                 ↓                  ↓
RealityKit      Detection3D       RoomStorageManager
  Visualization   Processing         (JSON Files)
```

## 📂 File Creati

### Model Layer
- **`Model/LiDAR.swift`** - Data structures per room scans e anchors
  - `RoomScan` - Mesh + Anchors + Metadata
  - `ARObjectAnchor` - Posizione persistente di un oggetto
  - `LiDARFrame` - Depth map + intrinsics + pose

### ViewModel Layer
- **`ViewModels/LiDARScanManager.swift`** - Manager principale
  - Gestisce ARSession e raccolta depth frames
  - Elabora mesh dalla point cloud
  - Riconosce stanze tramite firma digitale

- **`ViewModels/RoomStorageManager.swift`** - Persistenza
  - Salva/carica room scans (JSON)
  - Gestisce export/import
  - Eliminazione stanze

### View Layer
- **`ARViewContainer.swift`** - ARView wrapper UIViewController
  - ARView RealityKit
  - MeshVisualizer - Visualizza mesh e piani
  - Gesture handling (tap per posizionare, drag per spostare)

- **`LiDARScannerView.swift`** - UI principale LiDAR
  - Controls per start/stop scan
  - Progress bar
  - Object Placer Sheet
  - Room recognition status

- **`MainAppView.swift`** - Tab bar navigation
  - Switching tra Chat e LiDAR Scanner

## 💻 Come Usare

### 1️⃣ Aprire LiDAR Scanner
```
1. Avvia l'app
2. Clicca il tab "LiDAR" in basso
3. Inserisci nome stanza (es. "Living Room")
```

### 2️⃣ Scansionare la Stanza
```
1. Clicca "Start Scan"
2. Muovi lentamente l'iPhone per tutto l'ambiente
   - Scansiona pareti (orizzontali + verticali)
   - Punta il dispositivo verso angoli e spigoli
   - Minimum: ~5 secondi di tracking
3. Clicca "Stop Scan"
4. La mesh verrà elaborata automaticamente
```

### 3️⃣ Posizionare Oggetti AR
```
1. Clicca l'icona "Cubo" in alto a destra
2. Seleziona tipo: Painting, Sculpture, Furniture, Decoration
3. Dai un nome all'oggetto (es. "Family Photo")
4. Specifica path del modello 3D (opzionale)
5. Clicca "Place at Center Screen"
6. Puoi trascinare per spostare l'oggetto
```

### 4️⃣ Salvare la Stanza
```
1. Dopo aver posizionato tutti gli oggetti
2. Clicca "Save"
3. Sistema salva:
   - Mesh 3D della stanza
   - Posizioni di tutti gli anchors
   - Firma digitale univoca (hash della mesh)
   - Timestamp
```

### 5️⃣ Riconoscimento Automatico
```
Prossima volta che apri l'app nella STESSA stanza:
1. Vai a LiDAR Scanner
2. Inizia una nuova scansione veloce (1-2 secondi)
3. Sistema compara con le stanze salvate
4. Se match trovato (>85% similarity):
   ✅ "Stanza riconosciuta: Living Room"
   ✅ Tutti gli oggetti riappare negli stessi punti!
```

## 🔧 Dettagli Tecnici

### LiDAR Depth Processing
```swift
// Sampling della depth map
- Rate: Ogni 4 pixel (riduce carico CPU)
- Filtro: depth tra 0.1m - 10m
- Backprojection: xy + depth → punto 3D
- Transform: Camera space → World space

// Mesh Decimation
- Input: ~500k vertici
- Output: ~50k vertici (configurabile)
- Metodo: Grid-based sampling
```

### Room Recognition Algorithm
```
1. Genera hash della mesh attuale
2. Compara con tutti gli hash salvati
3. Calcola similarità (percentuale match caratteri)
4. Se > 85% → Match trovato
5. Carica automaticamente gli anchors
```

### ARWorldMap Integration
```
// Salvato in RoomScan:
{
  "id": "UUID della stanza",
  "name": "Living Room",
  "meshData": "<binary mesh vertices>",
  "anchorsData": [
    {
      "type": "painting",
      "position": [0.5, 1.2, -0.3],
      "rotation": [0, 0, 0, 1],
      "scale": [1, 1, 1],
      "name": "Family Photo"
    }
  ],
  "roomSignature": "a3f2b1c9..."
}
```

## 🎨 Personalizzazione

### Modello 3D Custom
```swift
// In ObjectPlacerSheet, specifica il path:
TextField("Model Path (USDZ)", text: $modelPath)

// Poi in placeObject():
let modelPath = "models/painting.usdz"
// Sistema caricherà RealityKit ModelEntity
```

### Tipi di Oggetti
Aggiungi nuovi tipi in `LiDAR.swift`:
```swift
enum ARObjectType: String, Codable {
    case painting
    case sculpture
    case furniture
    case decoration
    case custom
    case myNewType  // ← Aggiungi qui
}
```

### Sensitivity Tuning
```swift
// In LiDARScanManager.swift

// Aumenta precisioneza mesh:
let sampleRate = 2  // (default: 4)

// Strictness riconoscimento stanza:
let threshold: Float = 0.90  // (default: 0.85)

// Max vertici mesh:
targetCount: Int = 80000  // (default: 50000)
```

## 🎯 Caso d'Uso Completo

### Scenario: Posizionare un Quadro nella Camera
```
1️⃣  PRIMO ACCESSO
   - Scansiona camera (20 sec walking around)
   - Posiziona "Landscape Painting" sulla parete nord
   - Clicca save → "My Room" salvato

2️⃣  CHIUDI APP E RIENTRA DOPO 1 SETTIMANA
   - Apri LiDAR Scanner
   - Fai scansione veloce (2 sec)
   - ✅ Sistema riconosce: "My Room"
   - 🎨 Quadro ricompare ESATTAMENTE dove l'hai messo!

3️⃣  AGGIUNGI ALTRI OGGETTI
   - Place "Family Photos" sulla parete est
   - Place "Vase" sul comodino
   - Save → Tutto aggiornato
```

## ⚠️ Limitazioni Attuali

1. **Devices**: Solo iPhone 12 Pro+ (con LiDAR)
2. **Lighting**: Scenari scarsamente illuminati = più errori
3. **Dynamic Scenes**: Oggetti che si muovono confondono tracking
4. **Mesh Quality**: Superfici glossy/specular = problematiche
5. **Scala**: Stanze > 100m² potrebbero avere artifacts

## 🚀 Futuri Miglioramenti

- [ ] Mesh texture mapping (colori da foto)
- [ ] Multi-room layout (casa intera)
- [ ] Multiplayer anchors (condividi stanza con amici)
- [ ] ML-based room classification
- [ ] Semantic segmentation (walls, floor, furniture)
- [ ] Physics anchors (gravità, collisioni)
- [ ] Voice placement ("put picture on wall")
- [ ] Cloud sync (iCloud per backup)

## 🐛 Troubleshooting

### Problem: "No mesh generated"
```
✓ Assicurati di muovere l'iPhone uniformemente
✓ Scansiona per almeno 5-10 secondi
✓ Evita superfici troppo riflettenti
```

### Problem: "Room not recognized"
```
✓ Ricontolla in stanza simile?
✓ Aumenta threshold in recognizeRoom()
✓ Fai scansione più completa (>30 sec)
```

### Problem: "Objects in wrong position"
```
✓ Assicurati ARSession sia running stably
✓ Magari la prossima volta scansiona meglio
✓ Manualmente sposta oggetti prima di save finale
```

## 📞 Support

Per domande su:
- **Feature**: Vedi MainAppView per tab structure
- **Performance**: Regola sampleRate in LiDARScanManager
- **Storage**: Check ~/Library/Application Support/LiDARScans/

---

**Version**: 1.0  
**Last Updated**: Feb 13, 2026  
**Compatibility**: iOS 17+ (LiDAR required)

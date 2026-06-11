# 🔐 EnigmaCrypt

> A faithful software simulation of the WWII Enigma cipher machine — Assembly encryption core with Python GUI

---

## 📖 What Is EnigmaCrypt?

**EnigmaCrypt** is a complete implementation of the **Enigma M3 cipher machine** used by Nazi Germany during World War II. It simulates the exact electromechanical process that encrypted military communications — but as a modern desktop application.

The project has two parts:
- **Assembly Core** (MASM) — The actual encryption engine that mimics the rotor wiring and stepping
- **Python GUI** (Tkinter) — A user-friendly interface for file selection and key entry

---

## ⚙️ What It Does

| Operation | What Happens |
|-----------|--------------|
| **Encrypt** | Reads a plaintext file → passes each letter through 3 rotors + reflector → outputs ciphertext file |
| **Decrypt** | Same process! The Enigma is self-reciprocal (encrypting ciphertext with same key restores plaintext) |
| **Analyze** | Counts letter frequency and draws a bar chart — proves encryption flattens statistical patterns |

---

## 🧠 How the Enigma Machine Works

### The Signal Path (per character)

```
        ┌─────────────────────────────────────────┐
        │                                         │
        ▼                                         │
   ┌───────┐    ┌───────┐    ┌───────┐    ┌───────┐
   │Plug-  │ →  │Rotor  │ →  │Rotor  │ →  │Rotor  │
   │board  │    │ III   │    │ II    │    │ I     │
   └───────┘    └───────┘    └───────┘    └───┬───┘
                                              │
                                              ▼
                                        ┌─────────┐
                                        │Reflector│
                                        └────┬────┘
                                              │
   ┌───────┐    ┌───────┐    ┌───────┐    ┌───▼───┐
   │Plug-  │ ←  │Rotor  │ ←  │Rotor  │ ←  │Rotor  │
   │board  │    │ III   │    │ II    │    │ I     │
   └───────┘    └───────┘    └───────┘    └───────┘
        │
        ▼
   Ciphertext
```

### Why This Is Special

| Property | Explanation |
|----------|-------------|
| **Polyalphabetic** | Same letter encrypts differently each time (rotors advance) |
| **No fixed substitution** | Unlike Caesar cipher, there's no 1-to-1 mapping |
| **Self-reciprocal** | Same machine encrypts AND decrypts |
| **17,576 starting positions** | Key space of 26³ |

### Rotor Stepping (Odometer Style)

| Press | Rotor III | Rotor II | Rotor I |
|-------|-----------|----------|---------|
| 1st key | Advances 1 step | Stays | Stays |
| 26th key | Completes full cycle | Advances 1 step | Stays |
| 676th key | Completes 26 cycles | Completes full cycle | Advances 1 step |

---

## 📊 Frequency Analysis Example

**Plaintext English** (skewed distribution):
```
E: ████████████████████████████████
T: ███████████████████████
A: ███████████████████
O: ████████████████
```

**Encrypted text** (flat distribution):
```
A: ████████████████
B: ████████████████
C: ████████████████
...
Z: ████████████████
```

This flattening is what makes Enigma resistant to frequency analysis attacks.

---

## 🔧 Technical Details

### Historical Rotor Wirings (Actual WWII Specs)

| Rotor | Wiring (A→Z mapping) |
|-------|----------------------|
| I | `EKMFLGDQVZNTOWYHXUSPAIBRCJ` |
| II | `ADKSIRUXBLHWTMCOGPNVOEYFZ` |
| III | `BDFHJLCPRTXVZYNEIWGAKMUSQO` |
| Reflector B | `YRUHQSLDPXNGOKMIEBFZCWVIJAT` |

### Key Examples

| Key | Meaning |
|-----|---------|
| `AAA` | All rotors start at position 0 (A) |
| `KEY` | Rotor I starts at K(10), II at E(4), III at Y(24) |
| `XYZ` | Rotors start at X(23), Y(24), Z(25) |

### File Processing

- Reads files up to **10KB**
- Only uppercase A-Z is encrypted
- All other characters (spaces, numbers, punctuation) pass through unchanged

---

## 🚀 Quick Start

```bash
# Build assembly core (VS Developer Command Prompt)
ml /c /coff enigma.asm
link /subsystem:console /entry:main enigma.obj irvine32.lib kernel32.lib user32.lib

# Run GUI
python enigma_gui.py
```

---

## 📁 Project Structure

```
EnigmaCrypt/
├── assembly_core/
│   └── enigma.asm      # Full Enigma implementation in MASM
├── python_gui/
│   └── enigma_gui.py   # Tkinter frontend
└── README.md
```

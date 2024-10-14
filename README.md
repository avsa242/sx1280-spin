# sx1280-spin
-------------

This is a P8X32A/Propeller, P2X8C4M64P/Propeller 2 driver object for the SX1280 LoRa/GFSK/FLRC/BLE transceiver.

**IMPORTANT**: This software is meant to be used with the [spin-standard-library](https://github.com/avsa242/spin-standard-library) (P8X32A) or ~~[p2-spin-standard-library](https://github.com/avsa242/p2-spin-standard-library) (P2X8C4M64P)~~. Please install the applicable library first before attempting to use this code, otherwise you will be missing several files required to build the project.


## Salient Features

* SPI connection at 1MHz (P1)
* Over-the-air (OTA) data rate from 125kBaud to 2MBaud (GFSK), 1.2kBaud to 63kBaud (LoRa)
* GFSK (incl. BLE), FLRC, LoRa modulation
* Set common RF parameters: Bandwidth, carrier freq, TX power (and ramp-up/down time)
* Set number of preamble bits/symbols
* Set function of SX1280's GPIO pins
* Options for increasing transmission robustness: Data whitening, CRC (1 and 2 byte)
* RSSI measurement
* Set/read/clear interrupts
* Payload received and sent flags (GFSK, BLE, FLRC only)
* Test modes: Continuous preamble, CW, frequency synthesizer modes
* Presets for common settings, data rates (LoRa DR0..7)


## Requirements

P1/SPIN1:
* spin-standard-library

~~P2/SPIN2~~:
* ~~p2-spin-standard-library~~


## Compiler Compatibility

| Processor | Language | Compiler               | Backend      | Status                |
|-----------|----------|------------------------|--------------|-----------------------|
| P1        | SPIN1    | FlexSpin (6.9.4)       | Bytecode     | OK                    |
| P1        | SPIN1    | FlexSpin (6.9.4)       | Native/PASM  | OK                    |
| P2        | SPIN2    | FlexSpin (6.9.4)       | NuCode       | Not yet implemented   |
| P2        | SPIN2    | FlexSpin (6.9.4)       | Native/PASM2 | Not yet implemented   |

(other versions or toolchains not listed are __not supported__, and _may or may not_ work)


## Limitations

* Very early in development - may malfunction, or outright fail to build
* Most settings that have modulation-specific settings availability are only implemented with GFSK in mind - others are planned/WIP
* UART interface not implemented (not currently planned)


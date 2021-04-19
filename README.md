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

* P1/SPIN1: OpenSpin (tested with 1.00.81), FlexSpin (tested with 5.3.3-beta)
* ~~P2/SPIN2: FlexSpin (tested with 5.3.3-beta)~~ _(not yet implemented)_
* ~~BST~~ (incompatible - no preprocessor)
* ~~Propeller Tool~~ (incompatible - no preprocessor)
* ~~PNut~~ (incompatible - no preprocessor)

## Limitations

* Very early in development - may malfunction, or outright fail to build
* Most settings that have modulation-specific settings availability are only implemented with GFSK in mind - others are planned/WIP
* UART interface not implemented (not currently planned)

## TODO

- [x] Add basic LoRa support (enough to successfully transmit/receive)
- [ ] Add more presets for GFSK
- [ ] TBD


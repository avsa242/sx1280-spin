{
----------------------------------------------------------------------------------------------------
    Filename:       SX1280-LoRa-SimpleRX.spin
    Description:    Simple RX demo for the SX1280 driver
        * LoRa modulation
    Author:         Jesse Burt
    Started:        Apr 18, 2021
    Updated:        Oct 14, 2024
    Copyright (c) 2024 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    _clkmode    = xtal1+pll16x
    _xinfreq    = 5_000_000


OBJ

    time:   "time"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    radio:  "wireless.transceiver.sx1280" | CS=0, SCK=1, MOSI=2, MISO=3, RST=4, BUSY_PIN=5


VAR

    byte _rxbuff[radio.PAYLD_LEN_MAX]


PUB main() | sz

    setup()
    radio.modulation(radio.LORA)
    radio.carrier_freq(2_401_000)               ' 2_400_000..2_500_000 (kHz)

    radio.preset_dr7()                          ' LoRa presets (DR0..7)
    radio.payld_len(255)                        ' max. accepted size (1..255)

    radio.int_mask(radio.RXDONE)                ' set 'receive done' interrupt
    radio.int_clear(radio.RXDONE)               ' and make sure it starts clear

    sz := 0
    repeat
        radio.rx_mode()                         ' setup for reception
        ' wait for data to be received
        repeat
        until ( radio.interrupt() & radio.RXDONE )

        ' clear the temporary buffer and read the payload in from the radio
        bytefill(@_rxbuff, 0, radio.PAYLD_LEN_MAX)
        sz := radio.last_pkt_len()              ' how many bytes was the data?
        radio.rx_payld(sz, @_rxbuff)            ' receive that many into the buffer

        ' show what was received
        ser.pos_xy(0, 3)
        ser.printf1(@"Received %d bytes:\n\r", sz)
        ser.hexdump(@_rxbuff, 0, 4, sz, 16 <# sz)

        radio.int_clear(radio.RXDONE)


PUB setup()

    ser.start()
    time.msleep(30)
    ser.clear()
    ser.strln(@"Serial terminal started")

    if ( radio.start() )
        ser.strln(@"SX1280 driver started")
    else
        ser.strln(@"SX1280 driver failed to start - halting")
        repeat


DAT
{
Copyright 2024 Jesse Burt

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT
OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
}


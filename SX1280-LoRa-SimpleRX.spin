{
    --------------------------------------------
    Filename: SX1280-LoRa-SimpleRX.spin
    Author: Jesse Burt
    Description: Simple RX demo for the SX1280 driver
        (LoRa modulation)
    Copyright (c) 2022
    Started Apr 18, 2021
    Updated Nov 13, 2022
    See end of file for terms of use.
    --------------------------------------------
}

CON

    _clkmode    = cfg#_clkmode
    _xinfreq    = cfg#_xinfreq

' -- User-defined constants
    SER_BAUD    = 115_200
    LED         = cfg#LED1

    CS_PIN      = 8
    SCK_PIN     = 9
    MOSI_PIN    = 10
    MISO_PIN    = 11
    RST_PIN     = 12
    BUSY_PIN    = 13
' --
    PAYLD_MAX   = sx1280#PAYLD_MAX

OBJ

    cfg   : "boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    sx1280: "wireless.transceiver.sx1280"

VAR

    byte _rxbuff[PAYLD_MAX]

PUB main{} | sz

    setup{}
    sx1280.modulation(sx1280#LORA)
    sx1280.carrier_freq(2_401_000)              ' 2_400_000..2_500_000 (kHz)

    sx1280.preset_dr7{}                         ' LoRa presets (DR0..7)
    sx1280.payld_len(255)                       ' max. accepted size (1..255)

    sx1280.int_mask(sx1280#RXDONE)              ' set 'receive done' interrupt
    sx1280.int_clr(sx1280#RXDONE)               ' and make sure it starts clear

    sz := 0
    repeat
        sx1280.rx_mode{}                        ' setup for reception
        ' wait for data to be received
        repeat until (sx1280.interrupt{} & sx1280#RXDONE)
        bytefill(@_rxbuff, 0, 255)              ' clear the payload buffer
        sz := sx1280.last_pkt_len{}             ' how many bytes was the data?
        sx1280.rx_payld(sz, @_rxbuff)           ' receive that many into buffer

        ' show what was received
        ser.pos_xy(0, 3)
        ser.printf2(string("Received %d bytes: %s"), sz, @_rxbuff)
        ser.clear_line{}

        sx1280.int_clr(sx1280#RXDONE)

PUB setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if sx1280.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RST_PIN, BUSY_PIN)
        ser.strln(string("SX1280 driver started"))
    else
        ser.strln(string("SX1280 driver failed to start - halting"))
        repeat

DAT
{
Copyright 2022 Jesse Burt

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


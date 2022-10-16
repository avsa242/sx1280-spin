{
    --------------------------------------------
    Filename: SX1280-SimpleTX.spin
    Author: Jesse Burt
    Description: Simple TX demo for the SX1280 driver
        (GFSK modulation)
    Copyright (c) 2022
    Started Apr 18, 2021
    Updated Oct 16, 2022
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
    str   : "string"

VAR

    byte _txbuff[PAYLD_MAX]

PUB main{} | count, sz, user_str

    setup{}

'    sx1280.preset_gfsk_125k_0p3bw
'    sx1280.data_rate(250_000)
'    repeat sz from 80_000 to 250_000 step 10_000
'        sx1280.freqdeviation(sz)
'        ser.printf2(string("%d   --   %d\n"), sz, sx1280.mod_idx(-2))
'    repeat
    ' user-modifiable string to send over the air
    user_str := string("This is message # $%4.4x")

    sx1280.preset_gfsk_125k_0p3bw{}             ' GFSK, 125kbps, 300kHz BW
    sx1280.data_rate(250_000)
    sx1280.rx_bw(300_000)
'    sx1280.freqdeviation(125_000)
    sx1280.mod_idx(3_00)
    ser.dec(sx1280.mod_idx(-2))
    sx1280.bt(0)
    sx1280.data_rate(250_000)
'    repeat
    sx1280.carrier_freq(2_401_000)               ' 2_400_000..2_500_000 (kHz)

    sx1280.tx_pwr(-18)                         ' -18..13 dBm

    sx1280.int_mask(sx1280#TXDONE)               ' set 'transmit done' interrupt
    sx1280.int_clr(sx1280#TXDONE)              ' and make sure it starts clear

    count := 0
    repeat
        bytefill(@_txbuff, 0, 255)              ' clear the payload buffer
        str.sprintf1(@_txbuff, user_str, count++)' copy user str w/counter to it
        sz := strsize(@_txbuff)                 ' get the final size
        sx1280.payld_len(sz)

        ' show what will be transmitted
        ser.position(0, 3)
        ser.printf2(string("Transmitting %d bytes: %s\n"), sz, @_txbuff)

        sx1280.tx_payld(sz, @_txbuff)          ' queue the payload
        sx1280.tx_mode{}                         ' now transmit it
        repeat until sx1280.payld_sent{}       ' wait until radio is done
        sx1280.int_clr(sx1280#TXDONE)
        time.sleep(1)

PUB Setup{}

    ser.start(SER_BAUD)
    time.msleep(30)
    ser.clear{}
    ser.strln(string("Serial terminal started"))
    if sx1280.startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RST_PIN, BUSY_PIN)
        ser.strln(string("SX1280 driver started"))
    else
        ser.strln(string("SX1280 driver failed to start - halting"))
        time.msleep(5)
        ser.stop
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


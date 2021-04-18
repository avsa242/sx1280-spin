{
    --------------------------------------------
    Filename: SX1280-TXDemo.spin
    Author: Jesse Burt
    Description: Simple TX demo for the SX1280 driver
        (GFSK modulation)
    Copyright (c) 2021
    Started Apr 18, 2021
    Updated Apr 18, 2021
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

    cfg   : "core.con.boardcfg.flip"
    ser   : "com.serial.terminal.ansi"
    time  : "time"
    sx1280: "wireless.transceiver.sx1280.spi"
    sf    : "string.format"
VAR

    byte _txbuff[PAYLD_MAX]

PUB Main{} | count, sz, user_str

    setup{}

    ' user-modifiable string to send over the air
    user_str := string("This is message # $%x")

    sx1280.preset_gfsk_125k_0p3bw{}             ' GFSK, 125kbps, 300kHz BW
    sx1280.carrierfreq(2_401_000)               ' 2_400_000..2_500_000 (kHz)

    sx1280.txpower(-18)                         ' -18..13 dBm

    sx1280.intmask(sx1280#TXDONE)               ' set 'transmit done' interrupt
    sx1280.intclear(sx1280#TXDONE)              ' and make sure it starts clear

    count := 0
    repeat
        bytefill(@_txbuff, 0, 255)              ' clear the payload buffer
        sf.sprintf1(@_txbuff, user_str, count++)' copy user str w/counter to it
        sz := strsize(@_txbuff)                 ' get the final size
        sx1280.payloadlen(sz)

        ' show what will be transmitted
        ser.position(0, 3)
        ser.printf2(string("Transmitting %d bytes: %s\n"), sz, @_txbuff)

        sx1280.txpayload(sz, @_txbuff)          ' queue the payload
        sx1280.txmode{}                         ' now transmit it
        repeat until sx1280.payloadsent{}       ' wait until radio is done
        sx1280.intclear(sx1280#TXDONE)
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
    --------------------------------------------------------------------------------------------------------
    TERMS OF USE: MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    --------------------------------------------------------------------------------------------------------
}

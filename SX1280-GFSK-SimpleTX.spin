{
----------------------------------------------------------------------------------------------------
    Filename:       SX1280-GFSK-SimpleTX.spin
    Description:    Simple TX demo for the SX1280 driver
        * GFSK modulation
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
    str:    "string"
    ser:    "com.serial.terminal.ansi" | SER_BAUD=115_200
    radio:  "wireless.transceiver.sx1280" | CS=0, SCK=1, MOSI=2, MISO=3, RST=4, BUSY_PIN=5


VAR

    byte _txbuff[radio.PAYLD_LEN_MAX]


PUB main() | count, sz, user_str

    setup()

    ' user-modifiable string to send over the air
    ' NOTE: the format should match the parameters in the sprintf() call below
    user_str := @"This is message # $%04.4x"

    radio.preset_gfsk_125k_0p3bw()              ' GFSK preset: 125kbps, 300kHz BW
    radio.carrier_freq(2_401_000)               ' 2_400_000..2_500_000 (kHz)

    radio.tx_pwr(-18)                           ' -18..13 dBm

    radio.int_mask(radio.TXDONE)                ' set 'transmit done' interrupt
    radio.int_clear(radio.TXDONE)               ' and make sure it starts clear

    count := 0
    repeat
        ' clear the temporary string buffer and copy the user string with a counter to it
        bytefill(@_txbuff, 0, radio.PAYLD_LEN_MAX)
        str.sprintf1(@_txbuff, user_str, count++)

        ' get the final size of the string and tell the radio about it
        sz := strsize(@_txbuff)
        radio.payld_len(sz)

        ' show what will be transmitted
        ser.pos_xy(0, 3)
        ser.printf1(@"Transmitting %d bytes:\n\r", sz)
        ser.hexdump(@_txbuff, 0, 4, sz, 16 <# sz)

        ' queue and transmit it
        radio.tx_payld(sz, @_txbuff)
        radio.tx_mode()

        ' wait until the radio is done
        repeat
        until radio.payld_sent()
        radio.int_clear(radio.TXDONE)
        time.sleep(1)


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


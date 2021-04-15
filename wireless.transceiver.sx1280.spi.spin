{
    --------------------------------------------
    Filename: wireless.transceiver.sx1280.spi.spin
    Author: Jesse Burt
    Description: Driver for the SX1280 2.4GHz transceiver
    Copyright (c) 2021
    Started Feb 14, 2020
    Updated Apr 15, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

    OSC         = 52_000_000
    TWO_18      = 1 << 18
    ' calc frequency resolution: (chip oscillator / 2^18)
    ' scale up to preserve precision, then round up as an int
    F_RES       = round((float(OSC) / float(TWO_18)) * 1000.0)

' Modulation modes
    GFSK        = 0
    LORA        = 1
    RANGING     = 2
    FLRC        = 3
    BLE         = 4

VAR

    long _CS, _RESET, _BUSY
    long _bw, _freq, _intmask, _modulation, _rate, _txpwr
    byte _status

OBJ

    spi : "com.spi.4w"
    core: "core.con.sx1280"
    time: "time"
    u64 : "math.unsigned64"

PUB Null{}
' This is not a top-level object

PUB Startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN, BUSY_PIN): status
' Start using custom I/O settings
    if (status := spi.init(SCK_PIN, MOSI_PIN, MISO_PIN, core#SPI_MODE))
            _CS := CS_PIN
            _RESET := RESET_PIN
            _BUSY := BUSY_PIN
            reset{}
            outa[_CS] := 1
            dira[_CS] := 1
            dira[_BUSY] := 0
            return
    return FALSE                                                'If we got here, something went wrong

PUB Stop{}

    dira[_CS] := 0
    spi.deinit{}

PUB Busy{}: isbusy
' Get device busy status
'   Returns: TRUE (-1) or FALSE (0)
    return (ina[_BUSY] == 1)

PUB Carrierfreq(freq)
' Set carrier frequency, in kHz
'   Valid values: 2_400_000..2_500_000
'   Any other value is ignored
    case freq
        2_400_000..2_500_000:
            _freq := freq
            freq := u64.multdiv(freq, 1_000_000, F_RES) 
            cmd(core#SET_RFFREQ, @freq, 3, 0, 0)
        other:
            return

PUB FIFOTXBasePtr(txp) | tmp
' Set start of the transmit buffer within the transceiver's FIFO
    case txp
        0..255:
            tmp.byte[1] := txp
            tmp.byte[0] := 127  'xxx RX buffer ptr hardcoded
            cmd(core#SET_BUFF_BASEADDR, @tmp, 2, 0, 0)
        other:
            return

PUB Idle{} | tmp
' Change transceiver to idle state
    tmp := 0                                    ' [b0]: Run on RC OSC (13MHz)
    cmd(core#SET_STDBY, @tmp, 1, 0, 0)

PUB Modulation(mode)
' Set OTA modulation
'   Valid values:
'       GFSK (0)
'       LORA (1)
'       RANGING (2)
'       FLRC (3)
'       BLE (4)
'   NOTE: This setting must be configured before any others, as no
'   existing settings are preserved when this setting is changed, and
'   some settings have a modulation-specific meaning
    case mode
        GFSK, LORA, RANGING, FLRC, BLE:
            _modulation := mode
            idle{}                              ' must be set in idle/standby
            cmd(core#SET_PKTTYPE, @mode, 1, 0, 0)
        other:
            return

PUB Reset
' Reset device
    outa[_RESET] := 1
    dira[_RESET] := 1
    time.msleep(20)
    outa[_RESET] := 0
    time.msleep(50)
    outa[_RESET] := 1
    time.msleep(20)

PUB RXMode{} | tmp
' Change chip state to receive
    tmp := 00_00_00                             ' no timeout - stay in RX until
    cmd(core#SET_RX, @tmp, 3, 0, 0)             ' packet is received

PUB RXPayload(nr_bytes, ptr_buff)
' Receive data from FIFO
'   Valid values:
'       nr_bytes: 1..255
    case nr_bytes
        1..255:
            repeat until not busy{}
            outa[_CS] := 0
            spi.wr_byte(core#RD_BUFF)
            spi.wr_byte(0)                      ' offset within RX FIFO
            spi.rdblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return

PUB Sleep{} | tmp
' Power down chip
    tmp := 0                                    '[b1..0]: RAM flushed in sleep
    cmd(core#SET_SLEEP, @tmp, 1, 0, 0)

PUB StatusReg{}: stat
' Read status register
    cmd(core#GET_STATUS, 0, 0, 0, 0)
    return _status

PUB TESTCONT_PREAMBLE{}
' Enable continuous preamble transmit
'   (intended for testing only)
    cmd(core#SET_TXCONT_PREAMBLE, 0, 0, 0, 0)

PUB TESTCW{}
' Enable continuous carrier transmit
'   (intended for testing only)
    cmd(core#SET_TXCW, 0, 0, 0, 0)

PUB TESTFS{}
' Enable frequency synthesizer mode - lock PLL to carrier freq
'   (intended for testing only)
    cmd(core#SET_FS, 0, 0, 0, 0)

PUB TXMode{} | tmp
' Change chip state to transmit
    tmp := 00_00_00                             ' no timeout, stay in TX until
    cmd(core#SET_TX, @tmp, 3, 0, 0)             ' packet is transmitted

PUB TXPayload(nr_bytes, ptr_buff)
' Transmit data queued in FIFO
'   Valid values:
'       nr_bytes: 1..255
    case nr_bytes
        1..255:
            repeat until not busy{}
            outa[_CS] := 0
            spi.wr_byte(core#WR_BUFF)
            spi.wr_byte(0)                      ' offset within TX FIFO
            spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return

PUB TXPower(pwr): curr_pwr
' Set transmit mode RF output power, in dBm
'   Valid values: -18..13
'   Any other value is ignored
    case pwr
        -18..13:
            pwr += 18
            _txpwr := pwr
            pwr.byte[1] := $e0  'xxx hardcoded (ramp time, us)
            cmd(core#SET_TXPARAMS, @pwr, 2, 0, 0)
        other:
            return _txpwr-18

PRI cmd(cmd_val, ptr_params, nr_params, ptr_resp, sz_resp) | cmd_pkt
' Send command to device
    repeat until not busy
    case cmd_val
        core#GET_STATUS:
            outa[_CS] := 0
            spi.wr_byte(cmd_val)
            _status := spi.rd_byte{}
            outa[_CS] := 1
            return
        $00, $03, $17, $1F, $C1, $C5, $D1, $D2, $D5: ' 0
            outa[_CS] := 0
            spi.wr_byte(cmd_val)
            outa[_CS] := 1
            return
        core#GET_PKTSTATUS:
            cmd_pkt.byte[0] := core#GET_PKTSTATUS
            cmd_pkt.byte[1] := core#NOOP
            outa[_CS] := 0
            spi.wrblock_lsbf(@cmd_pkt, 2)
            spi.rdblock_msbf(ptr_resp, 5)
            outa[_CS] := 1
            return
        core#GET_IRQSTATUS:
            cmd_pkt.byte[0] := core#GET_IRQSTATUS
            cmd_pkt.byte[1] := core#NOOP
            outa[_CS] := 0
            spi.wrblock_lsbf(@cmd_pkt, 2)
            spi.rdblock_msbf(ptr_resp, 2)
            outa[_CS] := 1
            return
        core#CLR_IRQSTATUS:
            outa[_CS] := 0
            spi.wr_byte(cmd_val)
            spi.wrblock_msbf(ptr_params, 2)
            outa[_CS] := 1
        $1B, $84, $80, $8A, $88, $96, $98, $9B, $9D, $9E, $A3: ' 1
        $1A, $8E, $8F: ' 2
        $83, $82, $86, $88, $8B: ' 3
        $94: ' 6
        $8C: ' 7
        core#SET_DIOIRQPARAMS: ' 8
        other:
            return
'    cmd(core#SET_STDBY, @tmp, 1, 0, 0)
    outa[_CS] := 0
    spi.wr_byte(cmd_val)
    spi.wrblock_msbf(ptr_params, nr_params)
    outa[_CS] := 1

PUB readreg(reg, nr_bytes, ptr_buff) | cmd_pkt[2], tmp
' Read nr_bytes from register 'reg' to address 'ptr_buff'

    case reg
{        core#GETPACKETTYPE, $15, $17, $1D, $1F:
            cmd_pkt.byte[0] := reg
            cmd_pkt.byte[1] := core#NOOP

            outa[_CS] := 0
            time.usleep(125)
            spi.wrblock_lsbf(@cmd_pkt, 2)
            spi.rdblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1}
{$153}  0..$FFFF:
            cmd_pkt.byte[0] := core#READREG
            cmd_pkt.byte[1] := reg.byte[1]
            cmd_pkt.byte[2] := reg.byte[0]
            cmd_pkt.byte[3] := core#NOOP

            repeat until not busy{}
            outa[_CS] := 0
            time.usleep(125)
            spi.wrblock_lsbf(@cmd_pkt, 4)
            spi.rdblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
    repeat until not busy{}

PRI writeReg(reg_nr, nr_bytes, ptr_buff) | i
' Write nr_bytes to register 'reg' stored at ptr_buff

    case reg_nr
        $9CE:
        other:
            return

    outa[_CS] := 0
    spi.wr_byte(core#WRITEREG)
    spi.wrword_msbf(reg_nr)
    spi.wrblock_lsbf(ptr_buff, nr_bytes)
    outa[_CS] := 1

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

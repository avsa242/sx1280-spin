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

    OSC                 = 52_000_000
    TWO_18              = 1 << 18
    ' calc frequency resolution: (chip oscillator / 2^18)
    ' scale up to preserve precision, then round up as an int
    F_RES               = round((float(OSC) / float(TWO_18)) * 1000.0)

' Operating modes
    OPMODE_SLEEP        = 0
    OPMODE_STDBY        = 1
    OPMODE_FS           = 2
    OPMODE_TX           = 3
    OPMODE_RX           = 4

' Modulation modes
    GFSK                = 0
    LORA                = 1
    RANGING             = 2
    FLRC                = 3
    BLE                 = 4

' Interrupts
    TXDONE              = 1 << 0
    RXDONE              = 1 << 1
    SYNCWDVALID         = 1 << 2
    SYNCWDERROR         = 1 << 3
    HDRVALID            = 1 << 4
    HDRERROR            = 1 << 5
    CRCERROR            = 1 << 6
    RNG_SLVRESPDONE     = 1 << 7
    RNG_SLVRESPDISCARD  = 1 << 8
    RNG_MASTRESULTVALID = 1 << 9
    RNG_MASTTIMEOUT     = 1 << 10
    RNG_SLVREQVALID     = 1 << 11
    CADDONE             = 1 << 12
    CADDETECT           = 1 << 13
    RXTXTIMEOUT         = 1 << 14
    PREAMDETECT         = 1 << 15
    ADVRANGEDONE        = 1 << 15

VAR

    long _CS, _RESET, _BUSY
    long _bw, _freq, _intmask, _modulation, _opmode, _preamble_len
    long _ramptime, _rate, _txpwr
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

PUB DataRate(rate) | tmp
' Set data rate, in bps
'   Valid values:
'       GFSK/BLE:
'       125_000, 250_000, 400_000, 500_000, 800_000, 1_000_000,
'       1_600_000, 2_000_000
    case rate
        2_000_000:
            tmp.byte[2] := core#GFSK_BLE_BR_2_000_BW_2_4
        1_600_000:
            tmp.byte[2] := core#GFSK_BLE_BR_2_000_BW_2_4
        1_000_000:
            case _bw
                2_400_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_1_000_BW_2_4
                1_200_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_1_000_BW_1_2
                other:
                    return
        800_000:
            case _bw
                2_400_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_800_BW_2_4
                1_200_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_800_BW_1_2
                other:
                    return
        500_000:
            case _bw
                1_200_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_500_BW_1_2
                600_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_500_BW_0_6
                other:
                    return
        400_000:
            case _bw
                1_200_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_400_BW_1_2
                600_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_400_BW_0_6
                other:
                    return
        250_000:
            case _bw
                600_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_250_BW_0_6
                300_000:
                    tmp.byte[2] := core#GFSK_BLE_BR_0_250_BW_0_3
                other:
                    return
        125_000:
            tmp.byte[2] := core#GFSK_BLE_BR_0_125_BW_0_3
        other:
            return

    _rate := rate
    tmp.byte[1] := core#MOD_IND_1_00
    tmp.byte[0] := core#BT_0_5
    cmd(core#SET_MODPARAMS, @tmp, 3, 0, 0)

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

PUB IntClear(mask)
' Clear interrupts
'   Valid values:
'       Bit Desc.                           Valid when Modulation() is:
'       15  Preamble detected               LORA, GFSK, BLE
'       15  Adv. ranging done               RANGING
'       14  RxTx Timeout                    All
'       13  Channel act. detected           LORA
'       12  Ch. act. check done             LORA
'       11  Range request valid (slave)     RANGING
'       10  Range timeout (master)          RANGING
'       9   Range result valid (master)     RANGING
'       8   Range req. discarded (slave)    LORA, RANGING
'       7   Range resp. complete (slave)    RANGING
'       6   CRC error                       GFSK, BLE, FLRC, LORA
'       5   Header error                    LORA, RANGING
'       4   Header valid                    LORA, RANGING
'       3   Syncword error                  FLRC
'       2   Syncword valid                  GFSK, BLE, FLRC
'       1   RX complete                     GFSK, BLE, FLRC, LORA
'       0   TX complete                     GFSK, BLE< FLRC, LORA
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            cmd(core#CLR_IRQSTATUS, @mask, 2, 0, 0)
        other:
            return

PUB Interrupt{}: int_src
' Flag indicating interrupt(s) asserted
'   Returns: 16bit mask
'       Bit Desc.                           Valid when Modulation() is:
'       15  Preamble detected               LORA, GFSK, BLE
'       15  Adv. ranging done               RANGING
'       14  RxTx Timeout                    All
'       13  Channel act. detected           LORA
'       12  Ch. act. check done             LORA
'       11  Range request valid (slave)     RANGING
'       10  Range timeout (master)          RANGING
'       9   Range result valid (master)     RANGING
'       8   Range req. discarded (slave)    LORA, RANGING
'       7   Range resp. complete (slave)    RANGING
'       6   CRC error                       GFSK, BLE, FLRC, LORA
'       5   Header error                    LORA, RANGING
'       4   Header valid                    LORA, RANGING
'       3   Syncword error                  FLRC
'       2   Syncword valid                  GFSK, BLE, FLRC
'       1   RX complete                     GFSK, BLE, FLRC, LORA
'       0   TX complete                     GFSK, BLE< FLRC, LORA
    cmd(core#GET_IRQSTATUS, 0, 0, @int_src, 2)

PUB IntMask(mask): curr_mask | tmp[2]
' Set interrupt mask
'   Valid values:
'       Bit Desc.                           Valid when Modulation() is:
'       15  Preamble detected               LORA, GFSK, BLE
'       15  Adv. ranging done               RANGING
'       14  RxTx Timeout                    All
'       13  Ch. act. detected               LORA
'       12  Ch. act. check done             LORA
'       11  Range req. valid (slave)        RANGING
'       10  Range timeout (master)          RANGING
'       9   Range result valid (master)     RANGING
'       8   Range req. discarded (slave)    LORA, RANGING
'       7   Range resp. complete (slave)    RANGING
'       6   CRC error                       GFSK, BLE, FLRC, LORA
'       5   Header error                    LORA, RANGING
'       4   Header valid                    LORA, RANGING
'       3   Syncword error                  FLRC
'       2   Syncword valid                  GFSK, BLE, FLRC
'       1   RX complete                     GFSK, BLE, FLRC, LORA
'       0   TX complete                     GFSK, BLE< FLRC, LORA
    longfill(@tmp, 0, 2)
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            _intmask := mask
            tmp.byte[0] := mask.byte[1]
            tmp.byte[1] := mask.byte[0]
            'tmp.byte[2..7] := 0 xxx hardcoded (DIO config)
            cmd(core#SET_DIOIRQPARAMS, @tmp, 8, 0, 0)
        other:
            return _intmask

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

PUB OpMode(mode): curr_mode
' Set operating mode
'   Valid values:
'       OPMODE_SLEEP (0): Sleep/lowest power mode
'       OPMODE_STDBY (1): Standby/idle
'       OPMODE_FS (2): Frequency synthesis mode (for PLL test purposes only)
'       OPMODE_TX (3): Transmit mode
'       OPMODE_RX (4): Receive mode
'   Any other value returns the current (cached) setting
    case mode
        OPMODE_SLEEP:
            sleep{}
        OPMODE_STDBY:
            idle{}
        OPMODE_FS:
        OPMODE_TX:
            txmode{}
        OPMODE_RX:
            rxmode{}
        other:
            return _opmode

PUB PacketParams(sncwd_len, sncwd_mode, plen_mode, plen, crcen, white) | tmp[2]
' Set packet parameters (XXX temporary)
    tmp.byte[0] := _preamble_len
    tmp.byte[1] := sncwd_len
    tmp.byte[2] := sncwd_mode
    tmp.byte[3] := plen_mode
    tmp.byte[4] := plen
    tmp.byte[5] := crcen
    tmp.byte[6] := white

    cmd(core#SET_PKTPARAMS, @tmp, 7, 0, 0)

PUB PacketStatus(ptr_stat)
' Get packet status
'   Valid values:
'       pointer to buffer (5-byte minimum)
'   Byte    Desc                Valid when Modulation() is:
'   0       RFU                         BLE, GFSK, FLRC
'   0       RSSI when syncword detected LORA, RANGING
'   1       RSSI_SYNC                   BLE, GFSK, FLRC
'   1       Signal to noise ratio       LORA, RANGING
'   2       Errors                      BLE, GFSK, FLRC
'       b6: Sync addr. detection status
'       b5: RX payload length greather than expected
'       b4: CRC check status
'       b3: Current packet RX/TX aborted
'       b2: Header received
'       b1: Payload received
'       b0: Packet controller busy (RX/TX)
'   3       Status                      BLE, GFSK, FLRC
'       b5: NO_ACK field of RX'd packet
'       b0: Packet sent/TX complete
'   4       Sync                        BLE, GFSK, FLRC
'       b2..0: Code of sync address detected
'           %000: Sync address detection error
'           %001: Sync address 1 detected
'           %010: Sync address 2 detected
'           %100: Sync address 3 detected
    cmd(core#GET_PKTSTATUS, 0, 0, ptr_stat, 5)

PUB PreambleLen(len): curr_len
' Set preamble length, in bits (when Modulation() == GFSK)
'   Valid values: 4, 8, 12, 16, 20, 24, 28, 32
'   Any other value returns the current (cached) setting
    case len
        4, 8, 12, 16, 20, 24, 28, 32:
            len := lookdownz(len: 4, 8, 12, 16, 20, 24, 28, 32) << 4
        other:
            curr_len := _preamble_len >> 4
            return lookupz(curr_len: 4, 8, 12, 16, 20, 24, 28, 32)

PUB RampTime(rtime): curr_rtime
' Set power amplifier rise/fall time of ramp up/down, in microseconds
'   Valid values:
'       *20, 16, 12, 10, 8, 6, 4, 2
'   Any other returns the current (cached) setting
    case rtime
        20, 16, 12, 10, 8, 6, 4, 2:
            _ramptime := lookdownz(rtime: 2, 4, 6, 8, 10, 12, 16, 20)
            _ramptime <<= 5
        other:
            curr_rtime := _ramptime >> 5
            return lookupz(curr_rtime: 2, 4, 6, 8, 10, 12, 16, 20)

PUB Reset
' Reset device
    outa[_RESET] := 1
    dira[_RESET] := 1
    time.msleep(20)
    outa[_RESET] := 0
    time.msleep(50)
    outa[_RESET] := 1
    time.msleep(20)

PUB RXBandwidth(bw): curr_bw
' Set transceiver bandwidth (DSB), in Hz
'   Valid values: 300_000, 600_000, 1_200_000, 2_400_000
'   Any other value returns the current (cached) setting
    case bw
        300_000, 600_000, 1_200_000, 2_400_000:
            _bw := bw
        other:
            return _bw

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

PUB SyncWord(ptr_sw)
' Set syncword
'   Valid values:
'       pointer to 5-byte array containing syncword
    writereg(core#SYNCWD1, 5, ptr_sw)

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
    cmd(core#SET_TX, @tmp, 3, 0, 0)             ' packet is transmitted xxx hardcoded

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
'   Any other value returns the current (cached) setting
    case pwr
        -18..13:
            pwr.byte[0] := pwr+18
            pwr.byte[1] := _ramptime
            cmd(core#SET_TXPARAMS, @pwr, 2, 0, 0)
            _txpwr := pwr.byte[0]
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

    outa[_CS] := 0
    spi.wr_byte(cmd_val)
    spi.wrblock_msbf(ptr_params, nr_params)
    outa[_CS] := 1

PUB readreg(reg, nr_bytes, ptr_buff) | cmd_pkt[2], tmp
' Read nr_bytes from register 'reg' to address 'ptr_buff'

    case reg
        0..$FFFF:
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

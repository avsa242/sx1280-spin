{
----------------------------------------------------------------------------------------------------
    Filename:       wireless.transceiver.sx1280.spin
    Description:    Driver for the SX1280 2.4GHz transceiver
    Author:         Jesse Burt
    Started:        Feb 14, 2020
    Updated:        Jan 13, 2026
    Copyright (c) 2026 - See end of file for terms of use.
----------------------------------------------------------------------------------------------------
}

CON

    { default I/O settings; these can be overridden in the parent object }
    ' SPI
    CS                  = 0
    SCK                 = 1
    MOSI                = 2
    MISO                = 3
    RST                 = 4
    SPI_FREQ            = 1_000_000
    BUSY_PIN            = 6

    ' oscillator
    OSC                 = 52_000_000
    ' --

    ' limits
    PAYLD_LEN_MAX       = 255                   ' max possible payload size

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

    ' Syncword modes
    SWD_DISABLE         = $00
    SWD1                = $10
    SWD2                = $20
    SWD1_2              = $30
    SWD3                = $40
    SWD1_3              = $50
    SWD2_3              = $60
    SWD1_2_3            = $70

    ' Packet length modes
    PKTLEN_FIXED        = $00
    PKTLEN_VAR          = $20

    ' Packet status bits
    PSTAT_PAYLDSENT     = 1 << 0
    PSTAT_PAYLDRDY      = 1 << 1


    TWO_18              = 1 << 18
    ' calc frequency resolution: (chip oscillator / 2^18)
    ' scale up to preserve precision, then round up as an int
    F_RES               = round((float(OSC) / float(TWO_18)) * 1000.0)


VAR

    long _CS, _RESET, _BUSY
    long _bw, _freq, _modulation, _opmode
    long _rate

    ' SET_DIOIRQPARAMS
    word _gpio3mask, _gpio2mask, _gpio1mask, _intmask

    ' SET_TXPARAMS
    byte _pa_ramp_time, _txpwr

    ' PACKETPARAMS
    byte _data_whiten, _crclen, _paylen, _pktlencfg, _syncwd_mode, _syncwd_len, _preamble_len

    byte _lora_iqswap, _lora_crclen, _lora_paylen, _lora_pktlencfg, _lora_preamble

    ' GET_RXBUFFSTATUS
    byte _lastrx_paylen, _rxbuff_stptr'xxx

    ' SET_BUFF_BASEADDR
    byte _rxfifoptr, _txfifoptr

    byte _status, _pktstatus[5]'xxx

    ' SET_MODPARAMS
    byte _mod_bwt, _modidx, _br_bw
    byte _lora_cr, _lora_bw, _lora_sf


OBJ

    core:   "core.con.sx1280"                   ' HW-specific constants
    spi:    "com.spi.1mhz"                      ' SPI engine
    time:   "time"                              ' timekeeping methods
    u64:    "math.unsigned64"                   ' unsigned 64-bit math routines


PUB null()
' This is not a top-level object


PUB start(): status
' Start the driver using default I/O settings
    return startx(CS, SCK, MOSI, MISO, RST, BUSY_PIN)


PUB startx(CS_PIN, SCK_PIN, MOSI_PIN, MISO_PIN, RESET_PIN, BUSY__PIN): status
' Start the driver with custom I/O settings
'   CS_PIN:     Chip Select (0..31)
'   SCK_PIN:    Serial Clock (0..31)
'   MOSI_PIN:   Master-Out Slave-In (0..31)
'   MISO_PIN:   Master-In Slave-Out (0..31)
'   RESET_PIN:  Reset (0..31)
'   BUSY__PIN:  Busy (0..31)
'   Returns:
'       cog ID+1 of SPI engine on success (= calling cog ID+1, if the bytecode SPI engine is used)
'       0 on failure
    if ( status := spi.init(SCK_PIN, MOSI_PIN, MISO_PIN, core.SPI_MODE) )
        _CS := CS_PIN
        _RESET := RESET_PIN
        _BUSY := BUSY__PIN
        reset()
        outa[_CS] := 1
        dira[_CS] := 1
        dira[_BUSY] := 0
        return
    ' if this point is reached, something above failed
    ' Double check I/O pin assignments, connections, power
    ' Lastly - make sure you have at least one free core/cog
    return FALSE


PUB stop()
' Stop the driver
    dira[_CS] := 0
    dira[_RESET] := 0
    spi.deinit()


PUB preset_gfsk_125k_0p3bw()
' GFSK modulation, 125kbps, 300kHz bandwidth
' Modulation Index: 1.0
' BT: 0.5
' 5-byte syncwd length, match stored syncwd #1 only
' Variable-length packet mode
    modulation(GFSK)

    ' SET_MODPARAMS
    _br_bw := core.GFSK_BLE_BR_0_125_BW_0_3
    _modidx := core.MOD_IND_1_00
    _mod_bwt := core.BT_0_5
    cmd(core.SET_MODPARAMS, @_mod_bwt, 3)
    _rate := 125_000
    _bw := 300_000


    ' SET_PKTPARAMS
    _preamble_len := core.PREAMBLE_LEN_08_BITS  ' 8 bits
    _syncwd_len := core.SYNC_WORD_LEN_5_B       ' 5 bytes
    _syncwd_mode := SWD1                        ' match syncword # 1
    _pktlencfg := PKTLEN_VAR                    ' variable length payloads
    _paylen := 255                              ' max len=255
    _crclen := core.RADIO_CRC_2_BYTES           ' 2-byte CRC
    _data_whiten := core.WHITENING_DISABLE      ' disable data whitening
    cmd(core.SET_PKTPARAMS, @_data_whiten, 7)

    set_syncwd( string($e7, $e6, $e5, $e4, $e3) )

    ' SET_TXPARAMS
    _txpwr := -18 + 18                          ' -18dBm
    _pa_ramp_time := core.RADIO_RAMP_20_US      ' 20uS
    cmd(core.SET_TXPARAMS, @_pa_ramp_time, 2)


PUB preset_lora()
' LoRa presets
'   Spread factor 12
'   BW 812.5kHz
'   Code rate 4/5
'   12-symbol preamble
'   variable-length packets
'   CRC enabled
'   I/Q standard
    _lora_sf := core.LORA_SF_12
    _lora_bw := core.LORA_BW_800
    _lora_cr := core.LORA_CR_4_5
    cmd(core.SET_MODPARAMS, @_lora_sr, 3)

    _lora_preamble := (core.LORA_PBLE_LEN_EXP_DEF << 4) | core.LORA_PBLE_LEN_MANT_DEF
    _lora_paylen := 255
    _lora_pktlencfg := core.EXPLICIT_HEADER
    _lora_crclen := core.LORA_CRC_ENABLE
    _lora_iqswap := core.LORA_IQ_STD
    cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)

    _txpwr := -18 + 18                          ' -18dBm
    _pa_ramp_time := core.RADIO_RAMP_20_US      ' 20uS
    cmd(core.SET_TXPARAMS, @_pa_ramp_time, 2)


PUB preset_dr0()
' Physical bitrate (Rb) 1200
    preset_lora()
    spread_fact(12)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr1()
' Physical bitrate (Rb) 2100
    preset_lora()
    spread_fact(11)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr2()
' Physical bitrate (Rb) 3900
    preset_lora()
    spread_fact(10)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr3()
' Physical bitrate (Rb) 7100
    preset_lora()
    spread_fact(9)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr4()
' Physical bitrate (Rb) 12_700
    preset_lora()
    spread_fact(8)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr5()
' Physical bitrate (Rb) 22_200
    preset_lora()
    spread_fact(7)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr6()
' Physical bitrate (Rb) 38_000
    preset_lora()
    spread_fact(6)
    rx_bw(812_500)
    preamble_len(12)


PUB preset_dr7()
' Physical bitrate (Rb) 63_000
    preset_lora()
    spread_fact(5)
    rx_bw(812_500)
    preamble_len(12)


PUB bt(b_t): curr_bt
' Set bandwidth-time product (BT)
'   Valid values:
'       0 (off)
'       1_0 (1.0)
'       0_5 (0.5)
'   Any other value returns the current (cached) setting
'   NOTE: Used when modulation() == GFSK
    case b_t
        0, 1_0, 0_5:
            _mod_bwt := (lookdownz(b_t: 0, 1_0, 0_5) << 4)
            cmd(core.SET_MODPARAMS, @_mod_bwt, 3)
        other:
            curr_bt := _mod_bwt >> 4
            return lookupz(curr_bt: 0, 1_0, 0_5)


PUB busy(): isbusy
' Get device busy status
'   Returns: TRUE (-1) or FALSE (0)
    return ( ina[_BUSY] == 1 )


PUB carrier_freq(freq)
' Set carrier frequency, in kHz
'   Valid values: 2_400_000..2_500_000
'   Any other value is ignored
    case freq
        2_400_000..2_500_000:
            _freq := freq
            freq := u64.multdiv(freq, 1_000_000, F_RES) 
            cmd(core.SET_RFFREQ, @freq, 3)
        other:
            return


PUB code_rate(rate=-2): curr_rate
' Set Error code rate
'   Valid values:
'                k/n
'       $04_05 = 4/5
'       $04_06 = 4/6
'       $04_07 = 4/7
'       $04_08 = 4/8
'   Values with long-interleaving enabled:
'       $14_05 = 4/5
'       $14_06 = 4/6
'       $14_08 = 4/8
'   Any other value returns the current (cached) setting
    case rate
        $04_05..$04_08, $14_05, $14_06, $14_08:
            rate := lookdown(rate: $04_05, $04_06, $04_07, $04_08, $14_05, $14_06, $14_08)
            _lora_cr := rate
            cmd(core.SET_MODPARAMS, @_lora_sf, 3) ' set 3 params: SF, BW, CR
        other:
            curr_rate := _lora_cr
            return lookup(rate: $04_05, $04_06, $04_07, $04_08, $14_05, $14_06, $14_08)



PUB crc_check_ena(state=-2): curr_state
' Enable CRC generation (TX) and checking (RX)
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    case modulation()
        GFSK:
            case ||(state)
                0:
                    _crclen := core.RADIO_CRC_OFF
                1:
                    ' is CRC length already set to something valid? (1 or 2 bytes)
                    ' if so, leave it as-is
                    ' if it's not enabled yet (0), enable it (set it to 1 byte)
                    ifnot ( lookdown(_crclen: core.RADIO_CRC_1_BYTES, core.RADIO_CRC_2_BYTES) )
                        _crclen := core.RADIO_CRC_1_BYTES
                other:
                    ' are CRC checks enabled? (1 or 2)
                    ' if so, return TRUE
                    return ( lookdown(_crclen: core.RADIO_CRC_1_BYTES, core.RADIO_CRC_2_BYTES) > 0 )
            cmd(core.SET_PKTPARAMS, @_preamble_len, 7)
        LORA:
            case ||(state)
                0, 1:
                    _lora_crclen := lookdown(||(state): $00, $20)
                    cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)
                other:
                    return ( lookdown(_lora_crclen: $00, $20) == 1 )


PUB crc_len(length=-2): curr_len
' Set CRC encoding scheme length, in bytes
'   Valid values: 0 (no CRC), 1, 2
'   Any other value returns the current (cached) setting
    case length
        0, 1, 2:
            _crclen := length << 4
            cmd(core.SET_PKTPARAMS, @_preamble_len, 7)
        other:
            return _crclen >> 4


PUB data_rate(rate=-2)
' Set data rate, in bps
'   Valid values:
'       GFSK/BLE:
'       125_000, 250_000, 400_000, 500_000, 800_000, 1_000_000, 1_600_000, 2_000_000
'   NOTE: Bandwidth is set using rx_bw()
    case rate
        2_000_000:
            _br_bw := GFSK_BLE_BR_2_000_BW_2_4
        1_600_000:
            _br_bw := GFSK_BLE_BR_2_000_BW_2_4
        1_000_000:
            case _bw
                2_400_000:
                    _br_bw := GFSK_BLE_BR_1_000_BW_2_4
                1_200_000:
                    _br_bw := GFSK_BLE_BR_1_000_BW_1_2
                other:
                    return
        800_000:
            case _bw
                2_400_000:
                    _br_bw := GFSK_BLE_BR_0_800_BW_2_4
                1_200_000:
                    _br_bw := GFSK_BLE_BR_0_800_BW_1_2
                other:
                    return
        500_000:
            case _bw
                1_200_000:
                    _br_bw := GFSK_BLE_BR_0_500_BW_1_2
                600_000:
                    _br_bw := GFSK_BLE_BR_0_500_BW_0_6
                other:
                    return
        400_000:
            case _bw
                1_200_000:
                    _br_bw := GFSK_BLE_BR_0_400_BW_1_2
                600_000:
                    _br_bw := GFSK_BLE_BR_0_400_BW_0_6
                other:
                    return
        250_000:
            case _bw
                600_000:
                    _br_bw := GFSK_BLE_BR_0_250_BW_0_6
                300_000:
                    _br_bw := GFSK_BLE_BR_0_250_BW_0_3
                other:
                    return
        125_000:
            _br_bw := GFSK_BLE_BR_0_125_BW_0_3
        other:
            return _rate

    _rate := rate

    cmd(core.SET_MODPARAMS, @_mod_bwt, 3)


PUB data_whiten_ena(state=-2): curr_state
' Enable data whitening
'   Valid values: *TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
    case ||(state)
        0, 1:
            _data_whiten := lookupz(||(state): $08, $00)
            cmd(core.SET_PKTPARAMS, @_preamble_len, 7)
        other:
            ' negate lookdown result, so 1 becomes -1 (TRUE)
            return -lookdown(_data_whiten: $08, $00)


PUB fifo_rx_base_ptr(rxp=-2)
' Set start of the receive buffer within the transceiver's FIFO
'   Valid values: 0..255
'   Any other value returns the current (cached) setting
    case rxp
        0..255:
            _rxfifoptr := rxp
            cmd(core.SET_BUFF_BASEADDR, @_txfifoptr, 2)
        other:
            return _rxfifoptr


PUB fifo_rx_current_addr(): addr
' Start address (in FIFO) of last packet received
'   Returns: Starting address of last packet received
    rx_buff_status()
    return _lastrx_paylen


PUB fifo_tx_base_ptr(txp=-2)
' Set start of the transmit buffer within the transceiver's FIFO
'   Valid values: 0..255
'   Any other value returns the current (cached) setting
    case txp
        0..255:
            _txfifoptr := txp
            cmd(core.SET_BUFF_BASEADDR, @_txfifoptr, 2)
        other:
            return _txfifoptr


PUB freq_dev(freq=-2): curr_freq | modidx
' Set frequency deviation, in Hz
'   Valid values: 62_500..1_000_000
'   Any other value is ignored
'   NOTE: Valid only when modulation() == GFSK, BLE
    case modulation()
        GFSK, BLE:
            case freq
                62_500..1_000_000:
                    modidx := (8 * ((freq * 1_00) / _rate)) - 1_00
                    ifnot ( lookdown(modidx: 0_35..4_00) )
                        return                  ' mod idx > 4.00 is invalid
                    mod_idx(modidx)
        other:
            return


PUB gpio1(mask=-2): curr_mask
' Configure signal output on DIO1
'   Valid values:
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
'   Any other value returns the current (cached) setting
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            _gpio1mask := mask
            cmd(core.SET_DIOIRQPARAMS, @_gpio3mask, 8)
        other:
            return _gpio1mask


PUB gpio2(mask=-2): curr_mask
' Configure signal output on DIO2
'   Valid values:
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
'   Any other value returns the current (cached) setting
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            _gpio2mask := mask
            cmd(core.SET_DIOIRQPARAMS, @_gpio3mask, 8)
        other:
            return _gpio2mask


PUB gpio3(mask=-2): curr_mask
' Configure signal output on DIO3
'   Valid values:
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
'   Any other value returns the current (cached) setting
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            _gpio3mask := mask
            cmd(core.SET_DIOIRQPARAMS, @_gpio3mask, 8)
        other:
            return _gpio3mask


PUB idle() | tmp
' Change transceiver to idle state
    tmp := 0                                    ' [b0]: Run on RC OSC (13MHz)
    cmd(core.SET_STDBY, @tmp, 1)


PUB int_clear(mask=$ffff)
' Clear interrupts
'   Valid values:
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            cmd(core.CLR_IRQSTATUS, @mask, 2)
        other:
            return


PUB interrupt(): int_src
' Flag indicating interrupt(s) asserted
'   Returns: 16bit mask
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
    cmd(core.GET_IRQSTATUS, 0, 0, @int_src, 2)


PUB int_mask(mask=-2): curr_mask
' Set interrupt mask
'   Valid values:
'       Bit Desc.                           Valid when modulation() is:
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
'       0   TX complete                     GFSK, BLE, FLRC, LORA
    case mask
        %0000_0000_0000_0000..%1111_1111_1111_1111:
            _intmask := mask
            cmd(core.SET_DIOIRQPARAMS, @_gpio3mask, 8)
        other:
            return _intmask


PUB iq_inv(state=-2): curr_state
' Invert I/Q
'   Valid values: TRUE (-1 or 1), FALSE (0)
'   Any other value returns the current (cached) setting
'   NOTE: Only valid when modulation() == LORA
    case ||(state)
        0, 1:
            _lora_iqswap := lookdownz(||(state): core.LORA_IQ_STD, core.LORA_IQ_INVERTED)
            cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)
        other:
            curr_state := _lora_iqswap
            return ( lookupz(curr_state: core.LORA_IQ_STD, core.LORA_IQ_INVERTED) == 1 )


PUB last_pkt_len(): nr_bytes
' Return number of payload bytes of last packet received
    rx_buff_status()
    return _lastrx_paylen


PUB modulation(mode=-2)
' Set OTA modulation
'   Valid values:
'       GFSK (0)
'       LORA (1)
'       RANGING (2)
'       FLRC (3)
'       BLE (4)
'   NOTE: This setting must be configured before any others, as no existing settings are preserved
'   when this setting is changed, and some settings have a modulation-specific meaning
    case mode
        GFSK, LORA, RANGING, FLRC, BLE:
            _modulation := mode
            idle()                              ' must be set in idle/standby
            cmd(core.SET_PKTTYPE, @mode, 1)
        other:
            return _modulation


PUB mod_idx(idx=-2): curr_idx
' Set modulation index
'   Valid values:
'       0_35 (=0.35), 0_50..4_00 (=4.00), in increments of 0_25
'   Any other value returns the current (cached) setting
'   NOTE: For use when modulation() == GFSK
    case idx
        0_35..4_00:
            _modidx := (idx/25)-1
            cmd(core.SET_MODPARAMS, @_mod_bwt, 3)
        other:
            if ( _modidx == 0 )
                return 0_35
            else
                return ( (_modidx + 1) * 25 )


PUB opmode(mode=-2): curr_mode
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
            sleep()
        OPMODE_STDBY:
            idle()
        OPMODE_FS:
        OPMODE_TX:
            tx_mode()
        OPMODE_RX:
            rx_mode()
        other:
            return _opmode


PUB pkt_status(ptr_stat)
' Get packet status
'   Valid values:
'       pointer to buffer (5-byte minimum)
'   Byte    Desc                Valid when modulation() is:
'   0       RFU                         BLE, GFSK, FLRC
'   0       RSSI when syncwd detected LORA, RANGING
'   1       RSSI_SYNC                   BLE, GFSK, FLRC
'   1       Signal to noise ratio       LORA, RANGING
'   2       Errors                      BLE, GFSK, FLRC
'       b6: Sync addr. detection status
'       b5: RX payload length greater than expected
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
    cmd(core.GET_PKTSTATUS, 0, 0, ptr_stat, 5)


PUB payld_len(length=-2): curr_len
' Set packet length, in bytes
'   Valid values: 0..255
'   Any other value returns the current (cached) setting
    case modulation()
        GFSK:
            case length
                0..255:
                    _paylen := length
                    cmd(core.SET_PKTPARAMS, @_data_whiten, 7)
                other:
                    return _paylen
        LORA:
            case length
                0..255:
                    _lora_paylen := length
                    cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)
                other:
                    return _lora_paylen


PUB payld_len_cfg(mode=-2): curr_mode
' Set packet length mode
'   Valid values:
'       PKTLEN_FIXED ($00): Fixed-length packet/payload
'       PKTLEN_VAR ($20): Variable-length packet/payload
'   Any other value returns the current (cached) setting
    case modulation()
        GFSK:
            case mode
                PKTLEN_FIXED, PKTLEN_VAR:
                    _pktlencfg := mode
                other:
                    return _pktlencfg
            cmd(core.SET_PKTPARAMS, @_data_whiten, 7)
        LORA:
            case mode
                PKTLEN_FIXED:
                PKTLEN_VAR:
                    mode := core.IMPLICIT_HEADER
                other:
                    if ( _lora_pktlencfg == core.IMPLICIT_HEADER )
                        return PKTLEN_VAR
                    else
                        return PKTLEN_FIXED
            _lora_pktlencfg := mode
            cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)


PUB payld_rdy(): flag
' Flag indicating payload ready/received
'   Returns: TRUE (-1) or FALSE (0)
'   NOTE: Applies when modulation() == BLE, GFSK, or FLRC
'   When modulation() == LORA, set int_mask() to RXDONE and check interrupt() & RXDONE
    pkt_status(@_pktstatus)
    return ( (_pktstatus[2] & PSTAT_PAYLDRDY) <> 0 )


PUB payld_sent(): flag
' Flag indicating payload sent
'   Returns: TRUE (-1) or FALSE (0)
'   NOTE: Applies when modulation() == BLE, GFSK, FLRC
'   When modulation() == LORA, set int_mask() to TXDONE and check interrupt() & TXDONE
    pkt_status(@_pktstatus)
    return ( (_pktstatus[3] & PSTAT_PAYLDSENT) <> 0 )


PUB preamble_len(len=-2): curr_len | mant, exp, len_calc
' Set preamble length, in bits (when modulation() == GFSK)
'   Valid values: 4, 8, 12, 16, 20, 24, 28, 32
'   Any other value returns the current (cached) setting
    case modulation()
        GFSK:
            case len
                4, 8, 12, 16, 20, 24, 28, 32:
                    _preamble_len := lookdownz(len: 4, 8, 12, 16, 20, 24, 28, 32) << 4
                    cmd(core.SET_PKTPARAMS, @_data_whiten, 7)
                other:
                    curr_len := _preamble_len >> 4
                    return lookupz(curr_len: 4, 8, 12, 16, 20, 24, 28, 32)
        LORA:
            case len
                2..491_520:
                    if ( len // 2 )             ' must be an even number; round up
                        len++
                    mant := exp := 1
                    ' find closest matching mantissa/exponent to pre. length
                    repeat exp from 1 to 15
                        repeat mant from 1 to 15
                            len_calc := ( mant * (1 << exp) )
                            if ( len_calc => len )
                                quit
                        if ( len_calc => len )
                            quit
                    _lora_preamble := ( (exp << 4) | mant )
                    cmd(core.SET_PKTPARAMS, @_lora_iqswap, 5)
                other:
                    exp := (_lora_preamble >> 4) & $f
                    mant := _lora_preamble & $f
                    return mant * (1 << exp)


PUB pa_ramp_time(rtime=-2): curr_rtime
' Set power amplifier rise/fall time of ramp up/down, in microseconds
'   Valid values:
'       20, 16, 12, 10, 8, 6, 4, 2 (default: 20)
'   Any other returns the current (cached) setting
    case rtime
        20, 16, 12, 10, 8, 6, 4, 2:
            _pa_ramp_time := lookdownz(rtime: 2, 4, 6, 8, 10, 12, 16, 20)
            _pa_ramp_time <<= 5
            cmd(core.SET_TXPARAMS, @_pa_ramp_time, 2)
        other:
            curr_rtime := _pa_ramp_time >> 5
            return lookupz(curr_rtime: 2, 4, 6, 8, 10, 12, 16, 20)


PUB reset()
' Reset device
    outa[_RESET] := 1
    dira[_RESET] := 1
    time.msleep(20)
    outa[_RESET] := 0
    time.msleep(50)
    outa[_RESET] := 1
    time.msleep(20)


PUB rssi(): curr_rssi
' Received Signal Strength Indicator
'   Returns: RSSI in dBm
    curr_rssi := 0
    cmd(core.GET_RSSIINST, 0, 0, @curr_rssi, 1)
    return (-curr_rssi)/2


PUB rx_bandwidth = rx_bw
PUB rx_bw(bw=-2): curr_bw
' Set transceiver bandwidth (DSB), in Hz
'   Valid values:
'       modulation()    Values
'       GFSK            300_000, 600_000, 1_200_000, 2_400_000
'       LORA            203_125, 406_250, 812_500, 1_625_000
'   Any other value returns the current (cached) setting
    case modulation()
        GFSK:
            case bw
                300_000:
                    case _rate
                        125_000:
                            _bw := core.GFSK_BLE_BR_0_125_BW_0_3
                        250_000:
                            _bw := core.GFSK_BLE_BR_0_250_BW_0_3
                        other:
                            _bw := core.GFSK_BLE_BR_0_125_BW_0_3
                600_000:
                    case _rate
                        250_000:
                            _bw := core.GFSK_BLE_BR_0_250_BW_0_6
                        400_000:
                            _bw := core.GFSK_BLE_BR_0_400_BW_0_6
                        500_000:
                            _bw := core.GFSK_BLE_BR_0_500_BW_0_6
                        other:
                            _bw := core.GFSK_BLE_BR_0_250_BW_0_6
                1_200_000:
                    case _rate
                        400_000:
                            _bw := core.GFSK_BLE_BR_0_400_BW_1_2
                        500_000:
                            _bw := core.GFSK_BLE_BR_0_500_BW_1_2
                        800_000:
                            _bw := core.GFSK_BLE_BR_0_800_BW_1_2
                        1_000_000:
                            _bw := core.GFSK_BLE_BR_1_000_BW_1_2
                        other:
                            _bw := core.GFSK_BLE_BR_0_400_BW_1_2
                2_400_000:
                    case _rate
                        800_000:
                            _bw := core.GFSK_BLE_BR_0_800_BW_2_4
                        1_000_000:
                            _bw := core.GFSK_BLE_BR_1_000_BW_2_4
                        1_600_000:
                            _bw := core.GFSK_BLE_BR_1_600_BW_2_4
                        2_000_000:
                            _bw := core.GFSK_BLE_BR_2_000_BW_2_4
                        other:
                            _bw := core.GFSK_BLE_BR_0_800_BW_2_4
                other:
                    return _bw
            cmd(core.SET_MODPARAMS, @_bitrate_bw, 3)
        LORA:
            case bw
                203_125, 406_250, 812_500, 1_625_000:
                    bw := lookdown(bw: 203_125, 406_250, 812_500, 1_625_000)
                    _lora_bw := lookup(bw: $34, $26, $18, $0A)
                    cmd(core.SET_MODPARAMS, @_lora_sf, 3)
                other:
                    curr_bw := lookdown(_lora_bw: $34, $26, $18, $0A)
                    return lookup(curr_bw: 203_125, 406_250, 812_500, 1_625_000)


PUB rx_buff_status(): stat
' Receive buffer status
'   Returns:
'       LSB: length of last received packet
'       MSB: FIFO address/offset of first received
    cmd(core.GET_RXBUFFSTATUS, 0, 0, @stat, 2)
    _lastrx_paylen := stat.byte[0]
    _rxbuff_stptr := stat.byte[1]


PUB rx_mode() | tmp
' Change chip state to receive
    int_clear()                                 ' clear interrupts
    tmp := 0                                    ' no timeout - stay in RX until
    cmd(core.SET_RX, @tmp, 3)                   ' packet is received


PUB rx_payld(nr_bytes, ptr_buff)
' Receive data from FIFO
'   Valid values:
'       nr_bytes: 1..255
    case nr_bytes
        1..255:
            repeat
            until not busy()
            outa[_CS] := 0
                spi.wr_byte(core.RD_BUFF)
                spi.wr_byte(0)                      ' offset within RX FIFO
                spi.wr_byte(core.NOOP)
                spi.rdblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return


PUB set_syncwd(ptr_syncwd)
' Set syncword
'   ptr_syncwd: pointer to copy syncword data from
'   NOTE: Syncword is expected to be 5 bytes in length
    writereg(core.SYNCWD1, 5, ptr_syncwd)


PUB sleep() | tmp
' Power down chip
    tmp := 0                                    '[b1..0]: RAM flushed in sleep
    cmd(core.SET_SLEEP, @tmp, 1)


PUB spread_fact(sf=-2): curr_sf | tmp
' Set spreading factor
'   Valid values: 5, 6, 7, 8, 9, 10, 11, 12
'   Any other value returns the current (cached) setting
    case sf
        5, 6:
            tmp := core.SF5_6
        7, 8:
            tmp := core.SF7_8
        9..12:
            tmp := core.SF9TO12
        other:
            return _lora_sf >> 4

    _lora_sf := sf << 4
    cmd(core.SET_MODPARAMS, @_lora_sf, 3)       ' set 3 params: SF, BW, CR
    writereg(core.SF, 1, @tmp)
    tmp := 1
    writereg(core.FREQERRCOMP, 1, @tmp)


PUB status_reg(): stat
' Read status register
    cmd(core.GET_STATUS)
    return _status


PUB syncwd(ptr_sw)
' Get current syncword
'   ptr_syncwd: pointer to copy syncword data to
    readreg(core.SYNCWD1, 5, ptr_syncwd)


PUB syncwd_len(length=-2): curr_len
' Set syncword length, in bytes
'   Valid values: 1..5
'   Any other value returns the current (cached) setting
    case length
        1..5:
            _syncwd_len := lookup(length: $00, $02, $04, $06, $08)
            cmd(core.SET_PKTPARAMS, @_data_whiten, 7)
        other:
            return lookdown(_syncwd_len: 1..5)


PUB syncwd_mode(mode=-2): curr_mode
' Set syncword mode/combination
'   Valid values:
'       Symbol              rx_mode()           tx_mode()
'       SWD_DISABLE ($00)   Disable syncword    No syncword
'       SWD1 ($10)          Syncword 1          Syncword 1
'       SWD2 ($20)          Syncword 2          Syncword 2
'       SWD1_2 ($30)        Syncword 1 or 2     Syncword 1
'       SWD3 ($40)          Syncword 3          Syncword 3
'       SWD1_3 ($50)        Syncword 1 or 3     Syncword 1
'       SWD2_3 ($60)        Syncword 2 or 3     Syncword 1
'       SWD1_2_3 ($70)      Syncword 1, 2 or 3  Syncword 1
'   Any other value returns the current (cached) setting
    case mode
        SWD_DISABLE, SWD1, SWD2, SWD1_2, SWD3, SWD1_3, SWD2_3, SWD1_2_3:
            _syncwd_mode := mode
            cmd(core.SET_PKTPARAMS, @_data_whiten, 7)
        other:
            return _syncwd_mode


PUB test_cont_preamble()
' Enable continuous preamble transmit
'   (intended for testing only)
    cmd(core.SET_TXCONT_PREAMBLE)


PUB test_cw()
' Enable continuous carrier transmit
'   (intended for testing only)
    cmd(core.SET_TXCW)


PUB test_fs()
' Enable frequency synthesizer mode - lock PLL to carrier freq
'   (intended for testing only)
    cmd(core.SET_FS)


PUB tx_mode() | tmp
' Change chip state to transmit
    int_clear()                                 ' clear interrupts
    tmp := 0                                    ' no timeout, stay in TX until
    cmd(core.SET_TX, @tmp, 3)                   ' packet is transmitted


PUB tx_payld(nr_bytes, ptr_buff)
' Transmit data queued in FIFO
'   Valid values:
'       nr_bytes: 1..255
    case nr_bytes
        1..255:
            repeat until not busy()
            outa[_CS] := 0
                spi.wr_byte(core.WR_BUFF)
                spi.wr_byte(0)                      ' offset within TX FIFO
                spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return


PUB tx_pwr(pwr=-255): curr_pwr
' Set transmit mode RF output power, in dBm
'   Valid values: -18..13
'   Any other value returns the current (cached) setting
    case pwr
        -18..13:
            _txpwr := pwr + 18
            cmd(core.SET_TXPARAMS, @_txpwr, 2)
        other:
            return _txpwr-18


PRI cmd(cmd_val, ptr_params=0, nr_params=0, ptr_resp=0, sz_resp=0) | cmd_pkt, b
' Send command to device
    repeat
    until not busy()
    case cmd_val
        core.GET_STATUS:
            outa[_CS] := 0
                spi.wr_byte(cmd_val)
                _status := spi.rd_byte()
            outa[_CS] := 1
            return
        core.GET_IRQSTATUS:
            outa[_CS] := 0
                spi.wr_byte(cmd_val)
                _status := spi.rd_byte()
                spi.rdblock_msbf(ptr_resp, 2)
            outa[_CS] := 1
            return
        core.GET_PKTSTATUS, core.GET_RXBUFFSTATUS, core.GET_RSSIINST, core.GET_PKTTYPE:
            outa[_CS] := 0
                spi.wr_byte(cmd_val)
                _status := spi.rd_byte()
                spi.rdblock_lsbf(ptr_resp, sz_resp)
            outa[_CS] := 1
            return
        core.SET_TX, core.SET_RX, core.SET_RFFREQ, core.SET_TXPARAMS, core.SET_BUFF_BASEADDR, ...
        core.SET_MODPARAMS, core.SET_PKTPARAMS, core.SET_DIOIRQPARAMS, core.CLR_IRQSTATUS, ...
        core.SET_PKTTYPE, core.SET_SLEEP, core.SET_STDBY:
            outa[_CS] := 0
                spi.wr_byte(cmd_val)
                spi.wrblock_msbf(ptr_params, nr_params)
            outa[_CS] := 1
            return
        core.SET_FS, core.SET_CAD, core.SET_TXCW, core.SET_TXCONT_PREAMBLE, core.SET_SAVECONTEXT:
            outa[_CS] := 0
                spi.wr_byte(cmd_val)
            outa[_CS] := 1
            return

        other:
            return


PUB readreg(reg, nr_bytes, ptr_buff) | cmd_pkt[2], tmp
' Read nr_bytes from register 'reg' to address 'ptr_buff'
    case reg
        0..$FFFF:
            cmd_pkt.byte[0] := core.READREG
            cmd_pkt.byte[1] := reg.byte[1]
            cmd_pkt.byte[2] := reg.byte[0]
            cmd_pkt.byte[3] := core.NOOP
            repeat
            until not busy()
            outa[_CS] := 0
                time.usleep(125)
                spi.wrblock_lsbf(@cmd_pkt, 4)
                spi.rdblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1


PRI writereg(reg_nr, nr_bytes, ptr_buff) | i
' Write nr_bytes to register 'reg' stored at ptr_buff
    case reg_nr
        core.SYNCWD1, core.SF, core.FREQERRCOMP:
            outa[_CS] := 0
                spi.wr_byte(core.WRITEREG)
                spi.wrword_msbf(reg_nr)
                spi.wrblock_lsbf(ptr_buff, nr_bytes)
            outa[_CS] := 1
        other:
            return

DAT
{
Copyright 2026 Jesse Burt

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


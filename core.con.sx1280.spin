{
    --------------------------------------------
    Filename: core.con.sx1280.spin
    Author: Jesse Burt
    Description: SX1280 low-level constants
    Copyright (c) 2021
    Started Feb 14, 2020
    Updated Apr 18, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' SPI Configuration
    SCK_MAX_FREQ                = 18_000_000
    SPI_MODE                    = 0

' Commands
    NOOP                        = $00
    GETPKTTYPE                  = $03

    GET_IRQSTATUS               = $15
    GET_RXBUFFSTATUS            = $17
    WRITEREG                    = $18
    READREG                     = $19
    WR_BUFF                     = $1A
    RD_BUFF                     = $1B
    GET_PKTSTATUS               = $1D
    GET_RSSIINST                = $1F

    SET_STDBY                   = $80
    SET_RX                      = $82
    SET_TX                      = $83
    SET_SLEEP                   = $84
    SET_RFFREQ                  = $86
    SET_CADPARAMS               = $88
    SET_PKTTYPE                 = $8A
    SET_MODPARAMS               = $8B
    SET_PKTPARAMS               = $8C
    SET_DIOIRQPARAMS            = $8D
    SET_TXPARAMS                = $8E
    SET_BUFF_BASEADDR           = $8F

    SET_RXDUTYCYCLE             = $94
    SET_REGULATORMODE           = $96
    CLR_IRQSTATUS               = $97
    SET_LONGPREAMBLE            = $9B
    SET_PERFCTRMODE             = $9C
    SET_UARTSPEED               = $9D
    SET_AUTOFS                  = $9E

    SET_RANGINGROLE             = $A3

    GET_STATUS                  = $C0
    SET_FS                      = $C1
    SET_CAD                     = $C5

    SET_TXCW                    = $D1
    SET_TXCONT_PREAMBLE         = $D2
    SET_SAVECONTEXT             = $D5

' Symbols
    GFSK_BLE_BR_2_000_BW_2_4    = $04
    GFSK_BLE_BR_1_600_BW_2_4    = $28
    GFSK_BLE_BR_1_000_BW_2_4    = $4C
    GFSK_BLE_BR_1_000_BW_1_2    = $45
    GFSK_BLE_BR_0_800_BW_2_4    = $70
    GFSK_BLE_BR_0_800_BW_1_2    = $69
    GFSK_BLE_BR_0_500_BW_1_2    = $8D
    GFSK_BLE_BR_0_500_BW_0_6    = $86
    GFSK_BLE_BR_0_400_BW_1_2    = $B1
    GFSK_BLE_BR_0_400_BW_0_6    = $AA
    GFSK_BLE_BR_0_250_BW_0_6    = $CE
    GFSK_BLE_BR_0_250_BW_0_3    = $C7
    GFSK_BLE_BR_0_125_BW_0_3    = $EF

    MOD_IND_0_35                = $00
    MOD_IND_0_5                 = $01
    MOD_IND_0_75                = $02
    MOD_IND_1_00                = $03
    MOD_IND_1_25                = $04
    MOD_IND_1_50                = $05
    MOD_IND_1_75                = $06
    MOD_IND_2_00                = $07
    MOD_IND_2_25                = $08
    MOD_IND_2_50                = $09
    MOD_IND_2_75                = $0A
    MOD_IND_3_00                = $0B
    MOD_IND_3_25                = $0C
    MOD_IND_3_50                = $0D
    MOD_IND_3_75                = $0E
    MOD_IND_4_00                = $0F

    BT_OFF                      = $00
    BT_1_0                      = $10
    BT_0_5                      = $20

    PREAMBLE_LEN_04_BITS        = $00
    PREAMBLE_LEN_08_BITS        = $10
    PREAMBLE_LEN_12_BITS        = $20
    PREAMBLE_LEN_16_BITS        = $30
    PREAMBLE_LEN_20_BITS        = $40
    PREAMBLE_LEN_24_BITS        = $50
    PREAMBLE_LEN_28_BITS        = $60
    PREAMBLE_LEN_32_BITS        = $70

    SYNC_WORD_LEN_1_B           = $00
    SYNC_WORD_LEN_2_B           = $02
    SYNC_WORD_LEN_3_B           = $04
    SYNC_WORD_LEN_4_B           = $06
    SYNC_WORD_LEN_5_B           = $08

    RX_MATCH_SYNCWD_OFF         = $00
    RX_MATCH_SYNCWD_1           = $00
    RX_MATCH_SYNCWD_2           = $00
    RX_MATCH_SYNCWD_1_2         = $00
    RX_MATCH_SYNCWD_3           = $00
    RX_MATCH_SYNCWD_1_3         = $00
    RX_MATCH_SYNCWD_2_3         = $00
    RX_MATCH_SYNCWD_1_2_3       = $00

    PKT_FIXED_LEN               = $00
    PKT_VAR_LEN                 = $20

    CRC_OFF                     = $00
    CRC_1_BYTES                 = $10
    CRC_2_BYTES                 = $20

    WHITE_ENA                   = $00
    WHITE_DIS                   = $08

' Registers
    FIRMWARE_MSB                = $0153

    SF                          = $0925
        SF5_6                   = $1E
        SF7_8                   = $37
        SF9TO12                 = $32

    FREQERRCOMP                 = $093C

    SYNCWD1                     = $09CE 'MSB .. $09D2 (LSB)
    SYNCWD2                     = $09D3 'MSB .. $09D7 (LSB)
    SYNCWD3                     = $09D8 'MSB .. $09DC (LSB)

    CRCPOLY_MSB                 = $9C6
    CRCPOLY_LSB                 = $9C7
    CRCINIT_MSB                 = $9C8
    CRCINIT_LSB                 = $9C9

' -- Modulation/packet type-specific settings
' BLE 4.2
    BLE_4_2_BR_1_000_BW_1_2     = $45
    BLE_4_2_MOD_IND_0_5         = $01
    BLE_4_2_BT_0_5              = $20

' LoRa
'   SetPacketParams:
    LORA_PBLE_LEN_MANT_DEF      = 6             ' preamble default:
    LORA_PBLE_LEN_EXP_DEF       = 1             '   12 symbols

    EXPLICIT_HEADER             = $00
    IMPLICIT_HEADER             = $80

    LORA_CRC_ENABLE             = $20
    LORA_CRC_DISABLE            = $00

    LORA_IQ_INVERTED            = $00
    LORA_IQ_STD                 = $40

PUB Null
' This is not a top-level object

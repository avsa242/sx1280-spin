{
    --------------------------------------------
    Filename: core.con.sx1280.spin
    Author: Jesse Burt
    Description: SX1280 low-level constants
    Copyright (c) 2021
    Started Feb 14, 2020
    Updated Apr 12, 2021
    See end of file for terms of use.
    --------------------------------------------
}

CON

' SPI Configuration
    SCK_MAX_FREQ                = 18_000_000
    SPI_MODE                    = 0

' Commands
    NOOP                        = $00
    GETPACKETTYPE               = $03

    GETIRQSTATUS                = $15
    GETRXBUFFERSTATUS           = $17
    WRITEREG                    = $18
    READREG                     = $19
    WRITEBUFFER                 = $1A
    READBUFFER                  = $1B
    GETPACKETSTATUS             = $1D
    GETRSSIINST                 = $1F

    SETSTANDBY                  = $80
    SETRX                       = $82
    SETTX                       = $83
    SETSLEEP                    = $84
    SETRFFREQ                   = $86
    SETCADPARAMS                = $88
    SETPACKETTYPE               = $8A
    SETMODULATIONPARAMS         = $8B
    SETPACKETPARAMS             = $8C
    SETDIOIRQPARAMS             = $8D
    SETTXPARAMS                 = $8E
    SETBUFFERBASEADDRESS        = $8F

    SETRXDUTYCYCLE              = $94
    SETREGULATORMODE            = $96
    CLRIRQSTATUS                = $97
    SETLONGPREAMBLE             = $9B
    SETPERFCOUNTERMODE          = $9C
    SETUARTSPEED                = $9D
    SETAUTOFS                   = $9E

    SETRANGINGROLE              = $A3

    GETSTATUS                   = $C0
    SETFS                       = $C1
    SETCAD                      = $C5

    SETTXCW                     = $D1
    SETTXCONT_PREAMBLE          = $D2
    SETSAVECONTEXT              = $D5

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

    PREAMBLE_LENGTH_04_BITS     = $00
    PREAMBLE_LENGTH_08_BITS     = $10
    PREAMBLE_LENGTH_12_BITS     = $20
    PREAMBLE_LENGTH_16_BITS     = $30
    PREAMBLE_LENGTH_20_BITS     = $40
    PREAMBLE_LENGTH_24_BITS     = $50
    PREAMBLE_LENGTH_28_BITS     = $60
    PREAMBLE_LENGTH_32_BITS     = $70

    SYNC_WORD_LEN_1_B           = $00
    SYNC_WORD_LEN_2_B           = $02
    SYNC_WORD_LEN_3_B           = $04
    SYNC_WORD_LEN_4_B           = $06
    SYNC_WORD_LEN_5_B           = $08

    RADIO_RX_MATCH_SYNCWORD_OFF = $00
    RADIO_RX_MATCH_SYNCWORD_1   = $00
    RADIO_RX_MATCH_SYNCWORD_2   = $00
    RADIO_RX_MATCH_SYNCWORD_1_2 = $00
    RADIO_RX_MATCH_SYNCWORD_3   = $00
    RADIO_RX_MATCH_SYNCWORD_1_3 = $00
    RADIO_RX_MATCH_SYNCWORD_2_3 = $00
    RADIO_RX_MATCH_SYNCWORD_1_2_3   = $00

    RADIO_PACKET_FIXED_LENGTH   = $00
    RADIO_PACKET_VARIABLE_LENGTH    = $20

    RADIO_CRC_OFF                   = $00
    RADIO_CRC_1_BYTES               = $10
    RADIO_CRC_2_BYTES               = $20

    WHITENING_ENABLE                = $00
    WHITENING_DISABLE               = $08

' Registers
    FIRMWARE_MSB                    = $0153
    SYNCWORD1                       = $09CE 'MSB .. $09D2 (LSB)
    SYNCWORD2                       = $09D3 'MSB .. $09D7 (LSB)
    SYNCWORD3                       = $09D8 'MSB .. $09DC (LSB)

    CRCPOLYNOMIAL_MSB               = $9C6
    CRCPOLYNOMIAL_LSB               = $9C7
    CRCINIT_MSB                     = $9C8
    CRCINIT_LSB                     = $9C9

' BLE 4.2
    BLE_4_2_BR_1_000_BW_1_2             = $45
    BLE_4_2_MOD_IND_0_5                 = $01
    BLE_4_2_BT_0_5                      = $20

PUB Null
' This is not a top-level object

; State 1 = 0 to 60 (0 - 0.294 V)
; State 2 = 60 to 240 (0.294 - 1.176 V)
; State 3 = 240 to 360 (1.176 - 1.17604 V)
; State 4 = 360 to 1023 (1.17604 - 5 V )

    #include <p16F887.inc>
		__CONFIG    _CONFIG1, _LVP_OFF & _FCMEN_OFF & _IESO_OFF & _BOR_OFF & _CPD_OFF & _CP_OFF & _MCLRE_OFF & _PWRTE_ON & _WDT_OFF & _INTRC_OSC_NOCLKOUT
		__CONFIG    _CONFIG2, _WRT_OFF & _BOR21V

	cblock 0x20       
    	overflow_count
    endc

    org 0
    goto Start

    org 4
	goto ISR

ISR:
    bcf 		PIR1, TMR1IF		; clear the flag
    incf 		overflow_count,f 	; increment counter  
	movf 		overflow_count,w	; store counter 

    xorlw		0x02				; check if overflow twice 
    btfss 		STATUS, Z			; If match, Z = 1 then skip, else continue
    retfie        					; wait for 2 overflows

    clrf 		overflow_count		; ready for next overflow cycle

    ;thresholding logic 
State1:
    movf        ADRESH, W       
    sublw       .15             ; W = 15 - ADRESH
    btfss       STATUS, C       ; if C = 0, means ADRESH > threshold, go next threshold and check
    goto    State2
    movlw       b'00000001'    ; Light one LED 
    movwf       PORTD
    goto    ReloadTimer

State2:
    movf        ADRESH, W       
    sublw       .60             ; W = 60 - ADRESH
    btfss       STATUS, C       ; if C = 0, means ADRESH > threshold, go next threshold and check
    goto    State3
    movlw       b'00000011'    ; Light one LED 
    movwf       PORTD
    goto    ReloadTimer

State3:
    movf        ADRESH, W       
    sublw       .90             ; W = 90 - ADRESH
    btfss       STATUS, C       ; if C = 0, means ADRESH > threshold, go next threshold and check
    goto    State4
    movlw       b'00000111'    ; Light one LED 
    movwf       PORTD
    goto    ReloadTimer

State4:
    movlw       b'00001111'    ; Light one LED 
    movwf       PORTD
    goto    ReloadTimer

ReloadTimer:
    movlw		0xDB
    movwf		TMR1H
    movlw		0x08
    movwf		TMR1L

    retfie

Start:
    banksel     ANSEL
    movlw       b'00000001'    ; AN0 = analog, others digital (set bits for analog RAx you need)
    movwf       ANSEL
    banksel		ANSELH
    clrf 		ANSELH           ; Digital for Port B
    banksel     TRISA
    movlw       b'00000001'    ; AN0 = analog, others digital (set bits for analog RAx you need)
    movwf       TRISA           ; Make PortA all input
    banksel     TRISB
    bsf 		TRISB, 0         ; RB0 Input
    bsf 		TRISB, 1         ; RB1 Input
    banksel		TRISD
    clrf 		TRISD            ; Port D all output

    banksel     PORTD
	clrf      	PORTD           ; off all portd
	clrf 		overflow_count

    ;timer preload stuff
    movlw		0xDB
    movwf		TMR1H
    movlw		0x08
    movwf		TMR1L
	movlw		b'00110001'		; 1:8 prescalar, fosc/4
	movwf		T1CON			; Maximum Prescaler

    ;adc stuff
    banksel     ADCON1
    movlw       0x00           ; Left Justified, all PortA analog
    movwf       ADCON1
    banksel     ADCON0
    movlw       0x41
    movwf       ADCON0         ; configure A2D for Fosc/8, Channel 0 (RA0), and turn on the A2D module

    ;interrupt stuff
	bsf			STATUS, RP0 	; Bank 1
	bsf			PIE1, TMR1IE	; enable Timer1 interrupt
	bcf 		STATUS, RP0 	; Bank 0
	bcf			PIR1, TMR1IF   	; clear initially  
	bsf 	   	INTCON, PEIE   	; enable peripheral interrupts
	bsf 	   	INTCON, GIE    	; enable global interrupts

Main:
    btfss		PORTB, 0     ; if press will clear, then go State0 (idle) 
    goto State0
    nop
    nop
    nop
    nop
    nop

    banksel		ADCON0
    bsf			ADCON0, GO       ; start conversion

WaitADC:
    banksel 	ADCON0
    btfsc 		ADCON0, GO     ; still converting?
    goto WaitADC    			; if GO is 1 means not done
    goto Main

State0:
	clrf		PORTD		 ; clear all the output PORTD 	

	btfss		PORTB, 1     ; if press will clear, exit this loop
    goto Main
	goto State0

end
	     

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

    movf        ADRESH, W       ; Copy the display to the LEDs
    movwf       PORTD
    clrf 		overflow_count		; ready for next overflow cycle

    ; reload Timer1
    movlw		0xDB
    movwf		TMR1H
    movlw		0x08
    movwf		TMR1L

    retfie

Start:
	banksel		ANSELH
    clrf 		ANSELH           ; Digital for Port B
	movlw       0xFF           ; we want all Port A pins Analog
    movwf       ANSEL
    banksel		TRISD
    clrf 		TRISD            ; Port D all output
    bsf 		TRISB, 0         ; RB0 Input
    bsf 		TRISB, 1         ; RB1 Input
    movlw       0xFF
    movwf       TRISA           ; Make PortA all input
    bcf 		STATUS, RP0     ; Bank 0
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
    movlw       b'01000101'
    movwf       ADCON0         ; configure A2D for Fosc/8, Channel 0 (RA0), and turn on the A2D module

    ;interrupt stuff
	bsf			STATUS, RP0 	; Bank 1
	bsf			PIE1, TMR1IE	; enable Timer1 interrupt
	bcf 		STATUS, RP0 	; Bank 0
	bcf			PIR1, TMR1IF   	; clear initially  
	bsf 	   	INTCON, PEIE   	; enable peripheral interrupts
	bsf 	   	INTCON, GIE    	; enable global interrupts

WaitADC:
    nop                      ; wait 5uS for A2D amp to settle and capacitor to charge.
    nop                      ; wait 1uS
    nop                      ; wait 1uS
    nop                      ; wait 1uS 
    nop                      ; wait 1uS
    bsf         ADCON0,GO_DONE ; start conversion

Main:
    btfss		PORTB, 0     ; if press will clear, then go State0 (idle) 
    goto State0
    btfsc       ADCON0,GO_DONE ; this bit will change to zero when the conversion is complete
	goto        WaitADC
    goto Main

State0:
	clrf		PORTD		 ; clear all the output PORTD 	

	btfss		PORTB, 1     ; if press will clear, exit this loop
    goto Main
	goto State0

end
	     

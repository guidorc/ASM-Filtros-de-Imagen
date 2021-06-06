extern ReforzarBrillo_c
global ReforzarBrillo_asm

section .text
ReforzarBrillo_asm:
; armado stack frame
	push rbp
	mov rbp, rsp

; void ReforzarBrillo_asm (uint8_t *src, uint8_t *dst, int width, int height,
;                      int src_row_size, int dst_row_size, int xmm14, int xmm13, int brilloSup, int brilloInf);
;	rdi: 		rdi
;	rsi: 		rsi
;	edx: 		ancho
; 	ecx: 		alto
;	r8d:	 	src_row_size
;	r9d:  		dst_row_size
;	[rbp+16]: 	umbralSup
;	[rbp+24]:	umbralInf
; 	[rbp+32]:	brilloSup
;	[rbp+40]:	brilloInf
	
; xmm15: mascara de transparencia
	mov r10d, 0xff000000					
	movd xmm0, r10d
	pshufd xmm15, xmm0, 0000
	; xmm15: ff000000ff000000ff000000ff000000


; xmm14: contiene el umbral superior desplegado cuatro veces (los umbrales son enteros de 32 bits)
	movd xmm14, [rbp+16]
	movd xmm14, [rbp+16]
	pshufd xmm14, xmm14, 00000000b 

; xmm13: contiene el umbral inferior desplegado cuatro veces (los umbrales son enteros de 32 bits)
	movd xmm13, [rbp+24]
	movd xmm13, [rbp+24]
	pshufd xmm13, xmm13, 00000000b 

; xmm12: contiene el incremento (brilloSup) empaquetado en todos los bytes del registro
	movd xmm12, [rbp+32]
	movd xmm12, [rbp+32]
	pxor xmm0, xmm0
	packusdw xmm12, xmm0
	packuswb xmm12, xmm0 	; el incremento es a byte
	pshufb xmm12, xmm0 		; broadcast incremento

; xmm11: contiene el decremento (brilloInf) empaquetado en todos los bytes del registro
	movd xmm11, [rbp+40]
	movd xmm11, [rbp+40]
	packusdw xmm11, xmm0
	packuswb xmm11, xmm0 	; el decremento es a byte
	pshufb xmm11, xmm0 		; broadcast incremento


	mov eax, edx
	shr eax, 2
	mul rcx			
	mov rcx, rax	; rcx: (ancho/4)*alto

	.recorrer:		
	; leer 4 pixeles
		movdqu xmm0, [rdi]
		movdqu xmm0, [rdi]
	; calcular los b 
		; anular transparencia
		movdqu xmm1, xmm15
		pandn xmm1, xmm0
		movdqu xmm0, xmm1
		; extender en dos registros de words
		pmovzxbw xmm1, xmm0	 ; xmm1: mitad baja
		movdqu xmm2, xmm0
		pxor xmm3, xmm3
		punpckhbw xmm2, xmm3 ; xmm2: mitad alta 
		; 2*g
		mov r10, 00000000ffff0000h
		movq xmm5, r10
		pinsrq xmm5, r10, 1
		; xmm5: 00000000ffff000000000000ffff0000h
		; mitad baja
		movdqu xmm3, xmm1
		pand xmm3, xmm5
		paddw xmm1, xmm3 ; sumar bytes extendidos a word no desborda
		; mitad alta
		movdqu xmm3, xmm2
		pand xmm3, xmm5
		paddw xmm2, xmm3 ; sumar bytes extendidos a word no desborda
		; (b+2*g+r)
		; juntar mitades mediante sumar horizontal
		phaddw xmm1, xmm2
		phaddw xmm1, xmm1
		movdqu xmm2, xmm1
		; /4
		psrlw xmm2, 2
		; extender los b a dw (los umbrales son int)

		pmovzxwd xmm2, xmm2
	; -> xmm2: | b3 | b2 | b1 | b0 |

	; comparar los b con  los umbrales
		; cmp umbral superior
		movdqu xmm3, xmm2
		;pmaxud xmm3, xmm14
		pcmpgtd xmm3, xmm14
		;pcmpeqd xmm3, xmm2 ; xmm3: mascara superior
		; cmp umbral inferior
		movdqu xmm4, xmm13
		pcmpgtd xmm4, xmm2
		;pminud xmm4, xmm13
		;pcmpeqd xmm4, xmm2 ; xmm4: mascara inferior

	; incrementar brillo (solo pixeles que superan)
		movdqu xmm1, xmm12
		pand xmm1, xmm3
		paddusb xmm0, xmm1
	; decrementar brillo (solo pixeles por debajo)	
		movdqu xmm1, xmm11
		pand xmm1, xmm4
		psubusb xmm0, xmm1
	; restaurar transparencia
		por xmm0, xmm15

	; escribir dst
		movdqu [rsi], xmm0
		movdqu [rsi], xmm0

	; avanzar punteros
		add rdi, 16
		add rsi, 16

	dec rcx
	cmp rcx, 0
	jnz .recorrer ; (rcx: alto*ancho)/4

; desarmado stack frame
	pop rbp
	ret

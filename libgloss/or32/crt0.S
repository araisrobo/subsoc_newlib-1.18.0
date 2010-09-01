/* crt0.S. C Runtime startup file.

   Copyright (C) 2004, Jacob Bower
   Copyright (C) 2010, Embecosm Limited <info@embecosm.com>

   Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

   This file is part of Newlib.

   The original work by Jacob Bower is provided as-is without any kind of
   warranty. Use it at your own risk!

   All subsequent work is bound by version 3 of the GPL as follows.

   This program is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by the Free
   Software Foundation; either version 3 of the License, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful, but WITHOUT
   ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
   FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
   more details.

   You should have received a copy of the GNU General Public License along
   with this program.  If not, see <http://www.gnu.org/licenses/>.            */
/* -------------------------------------------------------------------------- */
/* This program is commented throughout in a fashion suitable for processing
   with Doxygen.                                                              */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/* CRT reference: http://opencores.net/forum,OpenRISC,0,3493                  */
/* -------------------------------------------------------------------------- */
/* 	.file   "start.s"

	.text
	.org	0x100		# The reset routine goes at 0x100

	.global _start
_start:
	l.addi	r1,r0,0x7f00	# Set SP to value 0x7f00
	l.addi	r2,r1,0x0	# FP and SP are the same
	l.mfspr	r3,r0,17	# Get SR value
	l.ori	r3,r3,0x2	# Set TT exception enable bit
	l.jal   _main		# Jump to main routine
	l.mtspr	r0,r3,17	# Enable exceptions (DELAY SLOT)

	.org	0xFFC
	l.nop			# Guarantee the exception vector space
				# does not have general purpose cod
 */
/* or32-elf-ld -nostartfiles -nodefaultlibs -nostdlib -Ttext 0x0 \
   start.o wibble.o -o wibble */
/* -------------------------------------------------------------------------- */

#include "spr-defs.h"
#include "or1ksim-board.h"

/* -------------------------------------------------------------------------- */
/*!Exception vectors                                                          */
/* -------------------------------------------------------------------------- */
	.section .vectors,"ax"

	/* 0x100: RESET exception */
        .org	0x100 	
_reset:
	/* Jump to program initialisation code */
	l.j	_start
	l.nop

	/* Pad to the end */
	.org	0x01fc
	l.nop

/* -------------------------------------------------------------------------- */
/*!Main entry point
  
   We initialise the stack and frame pointer first, before we set up the
   caches, since otherwise we'll need to disable the instruction cache when
   patching the bus error vector code.

   The remaining tasks are then:
   - clear BSS
   - call global and static constructors
   - set up destructors to be called from exit
   - initialize the UART (may be dummy, if no UART supported)
   - jump to the main function
   - call exit if the main function ever returns.
   - loop forever (should never get here)                                     */
/* -------------------------------------------------------------------------- */
	/* The stack grows down from the top of writable memory. */
	.section .data
	.global	stack
stack:	.space	4,0

	.section .text
	.global	_start
        .type	_start,@function
_start:
	/* Initialise stack and frame pointer (set to same value) */
	l.addi	r1,r0,0x3f00      # Set SP to value 0x7f00
	l.addi	r2,r1,0x0         # FP and SP are the same

	/* Clear BSS */
        l.movhi r28,hi(__bss_start)
	l.ori   r28,r28,lo(__bss_start)
	l.movhi r30,hi(end)
	l.ori   r30,r30,lo(end)

.L1:    l.sw    (0)(r28),r0
        l.sfltu r28,r30           # Set Flag if Less Than Unsigned
        l.bf    .L1
        l.addi  r28,r28,4	  /* Delay slot */

	/* Call global and static constructors */
	l.jal	init
	l.nop
	
	/* Initialise UART in a C function. If the UART isn't present, we'll */
	/* link against a dummy function. */
	l.jal    _uart_init
	l.nop

	/* Jump to main program entry point (argc = argv = envp = 0) */
	l.or	r3,r0,r0
	l.or	r4,r0,r0
	l.jal   main
	l.or	r5,r0,r0		/* Delay slot */
	
        /* If program exits, call exit routine */
	l.jal   _exit
	l.addi  r3,r11,0		/* Delay slot */

	/* Loop forever */
.L2:	l.j	.L2
	l.nop

	.size	_start, .-_start

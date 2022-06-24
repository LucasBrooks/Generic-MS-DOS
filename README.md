# Generic MS-DOS
Generic (non-OEM, PC-Compatible) versions of MS-DOS, BIOS source code and Format routines.

# Information
The source code contained in this repository came from disassembly (reverse engineering) of various IBM PC-DOS components. OEMs were supposed to provide their own DOS BIOS code and FORMAT routines, and since IBM PC-DOS is the only official 'OEM' version of MS-DOS that targeted the IBM PC (PC itself, not its clones), its routines are ideal for making generic versions of MS-DOS using only the OEM Adaptation Kits Microsoft provided to OEMs.

Most code here are based on Michal Necasek's disassembly of the PC-DOS 2.10 BIOS and FORMAT module. Changes I have made:
 - Fixed all identifiable hard coded offsets
 - Converted tabs to spaces, fixed all formatting issues
 - Added switches to build MS-DOS versions
 - Disassembled PC-DOS 2.00's DOS BIOS and FORMAT module (used label names and comments from Michal Necasek's disassembly, for ease of comparison)
 - Disassembled PC-DOS 2.x's ANSI driver (ANSI.SYS) and added it to the BIOS code (for MS-DOS only)

If you have the IBM or IBMVER switch turned on, the resulting binary will match the original binary (provided that you link it to the correct objects). If you have the MSVER switch turned on, you will be able to link them with SYSINIT.OBJ (and SYSIMES.OBJ) and FORMAT.OBJ (and FORMES.OBJ) from the OAKs provided by Microsoft to obtain a working copy of MS-DOS 2.00 or 2.11.

# Copyright
Code originally written by Microsoft and/or IBM. Microsoft first released the generic DOS BIOS and FORMAT code to OEMs at roughly the time of MS-DOS 3.20, and OEMs were able to freely customize whatever they were provided with. There should be no problems with publishing and customizing the code contained in this repository as later versions of the same code were released as samples for OEM to read and customize, and Microsoft open sourced MS-DOS 2.11 in 2014.

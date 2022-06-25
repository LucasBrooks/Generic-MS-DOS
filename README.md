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

# Building
To build a working copy of MS-DOS 2.x, you must assemble the source code here to object files with MASM and link them with the other object files provided by Microsoft. You will need IO.SYS, FDISK.COM and FORMAT.COM to make a fully functional adaptation of MS-DOS 2.x. Make sure you download the source code ZIP file from the Releases section, GitHub is known to replace CRLFs with LFs which may cause problems.
## DOS BIOS
`masm dosbios.asm;`<br>
`link dosbios.obj+sysinit.obj+sysimes.obj;`<br>
`exe2bin dosbios.exe io.sys` (enter `70` when prompted)
## FORMAT
_Note: FORMAT and FORMES may have been provided in the form of source code in MS-DOS 2.11. You'll need to assemble those files too if you do not see FORMAT.OBJ and FORMES.OBJ in your OAK._<br>
`masm oemfor.asm;`<br>
`link format.obj+formes.obj+oemfor.obj;`<br>
`exe2bin format.exe format.com`
## FDISK
You must write your own FDISK utility (FDISK.COM). PC-DOS's FDISK.COM can be used as well.

## Bootable Disk
_Note: If you are building MS-DOS 2.11, you must also assemble PRINT and SORT from the source code Microsoft provided in the OAK. You may also need to link MSDOS.SYS yourself._<br>
1. Format a blank 180KB (or 360KB) 5.25" floppy disk with the FORMAT.COM you just built.
2. Copy IO.SYS to that floppy disk.
3. Copy MSDOS.SYS to that floppy disk.
4. Use DEBUG to give those files RHSA attributes (0x27).
5. Copy COMMAND.COM to that floppy disk.
6. Copy CHKDSK.COM, DEBUG.COM, DISKCOPY.COM, EDLIN.COM, EXE2BIN.EXE, FC.EXE, FDISK.COM, FIND.EXE, FORMAT.COM, MORE.COM, PRINT.COM, RECOVER.COM, SORT.EXE and SYS.COM to that floppy disk.
7. Try booting from it.

# Copyright
Code originally written by Microsoft and/or IBM. Microsoft first released the generic DOS BIOS and FORMAT code to OEMs at roughly the time of MS-DOS 3.20, and OEMs were able to freely customize whatever they were provided with. There should be no problems with publishing and customizing the code contained in this repository as later versions of the same code were released as samples for OEM to read and customize, and Microsoft open sourced MS-DOS 2.11 in 2014.

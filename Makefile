
NASM=nasm
NASM_PARAMS=

PERL=perl

BIOS_SIZE=8192

all: wdbios.bin

%.bin: %.asm
	$(NASM) $< $(NASM_PARAMS) -o $@
	perl tools/checksum.pl $@ $(BIOS_SIZE)

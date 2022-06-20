
NASM=nasm
NASM_PARAMS=-f bin -O0

PERL=perl

BIOS_SIZE=8192

TARGETS=wdbios.bin

all: $(TARGETS)

%.bin: %.asm
	$(NASM) $< $(NASM_PARAMS) -o $@ -l $(basename $@).lst
	perl tools/checksum.pl $@ $(BIOS_SIZE)

.PHONY: clean
clean:
	rm -f $(TARGETS) $(basename $(TARGETS)).lst

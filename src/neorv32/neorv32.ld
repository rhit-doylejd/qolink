OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
  IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
  DMEM (rwx) : ORIGIN = 0x80000000, LENGTH = 8K
}

__stack_size = 2K;

SECTIONS
{
  .text :
  {
    KEEP(*(.text.init))
    *(.text .text.*)
    *(.rodata .rodata.* .srodata .srodata.*)
    . = ALIGN(4);
  } > IMEM

  .data :
  {
    __data_start = .;
    __global_pointer$ = . + 0x800;
    *(.data .data.* .sdata .sdata.*)
    . = ALIGN(4);
    __data_end = .;
  } > DMEM AT > IMEM
  __data_load = LOADADDR(.data);

  .bss (NOLOAD) :
  {
    __bss_start = .;
    *(.bss .bss.* .sbss .sbss.* COMMON)
    . = ALIGN(4);
    __bss_end = .;
  } > DMEM

  .stack (NOLOAD) :
  {
    . = ALIGN(16);
    . += __stack_size;
    __stack_top = .;
  } > DMEM

  /DISCARD/ : { *(.eh_frame*) *(.comment) }
}
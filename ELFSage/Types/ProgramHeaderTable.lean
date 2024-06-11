import ELFSage.Types.Sizes
import ELFSage.Util.ByteArray
import ELFSage.Types.ELFHeader
import ELFSage.Util.Hex

class ProgramHeaderTableEntry (α : Type) where
  /-- Type of the segment -/
  p_type   : α → Nat
  /-- Segment flags -/
  p_flags  : α → Nat
  /-- Offset from beginning of file for segment -/
  p_offset : α → Nat
  /-- Virtual address for segment in memory -/
  p_vaddr  : α → Nat
  /-- Physical address for segment -/
  p_paddr  : α → Nat
  /-- Size of segment in file, in bytes -/
  p_filesz : α → Nat
  /-- Size of segment in memory image, in bytes -/
  p_memsz  : α → Nat
  /-- Segment alignment memory for memory and file -/
  p_align  : α → Nat
  /-- Underlying Bytes, requires Endianness --/
  bytes    : α → (isBigendian : Bool) → ByteArray

def ProgramHeaderTableEntry.ph_end [ProgramHeaderTableEntry α] (ph : α) :=
  p_offset ph + p_filesz ph

-- Alignment requirements from man 5 elf
-- For now, we assumpe 4K as page size. For future reference:
-- https://stackoverflow.com/questions/3351940/detecting-the-memory-page-size
def ProgramHeaderTableEntry.checkAlignment
  [ProgramHeaderTableEntry α]
  (ph : α)
  : Except String Unit := do
  if p_type ph == PT_LOAD ∧ p_vaddr ph % 0x1000 != p_offset ph % 0x1000 then .error $
    s! "Misaligned loadable segment: p_vaddr={Hex.toHex $ p_vaddr ph} and " ++
    s! "p_offset={Hex.toHex $ p_offset ph} are not aligned modulo the page size 0x1000"
  if p_align ph < 2 then return ()
  if p_vaddr ph % p_align ph != p_offset ph % p_align ph then .error $
      s! "Misaligned segment: p_offset is {Hex.toHex $ p_offset ph}, " ++
      s! "and p_vaddr is {Hex.toHex $ p_vaddr ph}. These are required to be " ++
      s! "congruent mod p_align={Hex.toHex $ p_align ph}."
  where PT_LOAD := 1 -- TODO: replace me with a constant

structure ELF64ProgramHeaderTableEntry where
  /-- Type of the segment -/
  p_type   : elf64_word
  /-- Segment flags -/
  p_flags  : elf64_word
  /-- Offset from beginning of file for segment -/
  p_offset : elf64_off
  /-- Virtual address for segment in memory -/
  p_vaddr  : elf64_addr
  /-- Physical address for segment -/
  p_paddr  : elf64_addr
  /-- Size of segment in file, in bytes -/
  p_filesz : elf64_xword
  /-- Size of segment in memory image, in bytes -/
  p_memsz  : elf64_xword
  /-- Segment alignment memory for memory and file -/
  p_align  : elf64_xword
  deriving Repr

def mkELF64ProgramHeaderTableEntry
  (isBigEndian : Bool)
  (bs : ByteArray)
  (offset : Nat)
  (h : bs.size - offset ≥ 0x38) :
  ELF64ProgramHeaderTableEntry := {
    p_type   := getUInt32from (offset + 0x00) (by omega),
    p_flags  := getUInt32from (offset + 0x04) (by omega),
    p_offset := getUInt64from (offset + 0x08) (by omega),
    p_vaddr  := getUInt64from (offset + 0x10) (by omega),
    p_paddr  := getUInt64from (offset + 0x18) (by omega),
    p_filesz := getUInt64from (offset + 0x20) (by omega),
    p_memsz  := getUInt64from (offset + 0x28) (by omega),
    p_align  := getUInt64from (offset + 0x30) (by omega),
  } where
    getUInt16from := if isBigEndian then bs.getUInt16BEfrom else bs.getUInt16LEfrom
    getUInt32from := if isBigEndian then bs.getUInt32BEfrom else bs.getUInt32LEfrom
    getUInt64from := if isBigEndian then bs.getUInt64BEfrom else bs.getUInt64LEfrom

def mkELF64ProgramHeaderTableEntry?
  (isBigEndian : Bool)
  (bs : ByteArray)
  (offset : Nat)
  : Except String ELF64ProgramHeaderTableEntry :=
  if h : bs.size - offset ≥ 0x38
  then .ok $ mkELF64ProgramHeaderTableEntry isBigEndian bs offset h
  else .error $ "Program header table entry offset {offset} doesn't leave enough space for the entry, " ++
                "which requires 0x20 bytes."

def ELF64ProgramHeaderTableEntry.bytes (phte : ELF64ProgramHeaderTableEntry) (isBigEndian : Bool) :=
  getBytes32 phte.p_type ++
  getBytes32 phte.p_flags ++
  getBytes64 phte.p_offset ++
  getBytes64 phte.p_vaddr ++
  getBytes64 phte.p_paddr ++
  getBytes64 phte.p_filesz ++
  getBytes64 phte.p_memsz ++
  getBytes64 phte.p_align
  where getBytes32 := if isBigEndian then UInt32.getBytesBEfrom else UInt32.getBytesLEfrom
        getBytes64 := if isBigEndian then UInt64.getBytesBEfrom else UInt64.getBytesLEfrom

def ELF64Header.mkELF64ProgramHeaderTable?
  (eh : ELF64Header)
  (bytes : ByteArray)
  : Except String (List ELF64ProgramHeaderTableEntry):=
  let isBigendian := ELFHeader.isBigendian eh
  List.mapM
    (λoffset ↦ mkELF64ProgramHeaderTableEntry? isBigendian bytes offset)
    (ELFHeader.getProgramHeaderOffsets eh)

instance : ProgramHeaderTableEntry ELF64ProgramHeaderTableEntry where
  p_type ph   := ph.p_type.toNat
  p_flags ph  := ph.p_flags.toNat
  p_offset ph := ph.p_offset.toNat
  p_vaddr ph  := ph.p_vaddr.toNat
  p_paddr ph  := ph.p_paddr.toNat
  p_filesz ph := ph.p_filesz.toNat
  p_memsz ph  := ph.p_memsz.toNat
  p_align ph  := ph.p_align.toNat
  bytes ph    := ph.bytes

structure ELF32ProgramHeaderTableEntry where
  /-- Type of the segment -/
  p_type   : elf32_word
  /-- Offset from beginning of file for segment -/
  p_offset : elf32_off
  /-- Virtual address for segment in memory -/
  p_vaddr  : elf32_addr
  /-- Physical address for segment -/
  p_paddr  : elf32_addr
  /-- Size of segment in file, in bytes -/
  p_filesz : elf32_word
  /-- Size of segment in memory image, in bytes -/
  p_memsz  : elf32_word
  /-- Segment flags -/
  p_flags  : elf32_word
  /-- Segment alignment memory for memory and file -/
  p_align  : elf64_word
  deriving Repr

def mkELF32ProgramHeaderTableEntry
  (isBigEndian : Bool)
  (bs : ByteArray)
  (offset : Nat)
  (h : bs.size - offset ≥ 0x20) :
  ELF32ProgramHeaderTableEntry := {
    p_type   := getUInt32from (offset + 0x00) (by omega),
    p_offset := getUInt32from (offset + 0x04) (by omega),
    p_vaddr  := getUInt32from (offset + 0x08) (by omega),
    p_paddr  := getUInt32from (offset + 0x0C) (by omega),
    p_filesz := getUInt32from (offset + 0x10) (by omega),
    p_memsz  := getUInt32from (offset + 0x14) (by omega),
    p_flags  := getUInt32from (offset + 0x18) (by omega),
    p_align  := getUInt32from (offset + 0x1C) (by omega),
  } where
    getUInt16from := if isBigEndian then bs.getUInt16BEfrom else bs.getUInt16LEfrom
    getUInt32from := if isBigEndian then bs.getUInt32BEfrom else bs.getUInt32LEfrom

def ELF32ProgramHeaderTableEntry.bytes (phte : ELF32ProgramHeaderTableEntry) (isBigEndian : Bool) :=
  getBytes32 phte.p_type ++
  getBytes32 phte.p_flags ++
  getBytes32 phte.p_offset ++
  getBytes32 phte.p_vaddr ++
  getBytes32 phte.p_paddr ++
  getBytes32 phte.p_filesz ++
  getBytes32 phte.p_memsz ++
  getBytes32 phte.p_align
  where getBytes32 := if isBigEndian then UInt32.getBytesBEfrom else UInt32.getBytesLEfrom

def mkELF32ProgramHeaderTableEntry?
  (isBigEndian : Bool)
  (bs : ByteArray)
  (offset : Nat)
  : Except String ELF32ProgramHeaderTableEntry :=
  if h : bs.size - offset ≥ 0x20
  then .ok $ mkELF32ProgramHeaderTableEntry isBigEndian bs offset h
  else .error $ "Program header table entry offset {offset} doesn't leave enough space for the entry, " ++
                "which requires 0x20 bytes."

def ELF32Header.mkELF32ProgramHeaderTable?
  (eh : ELF32Header)
  (bytes : ByteArray)
  : Except String (List ELF32ProgramHeaderTableEntry):=
  let isBigendian := ELFHeader.isBigendian eh
  List.mapM
    (λoffset ↦ mkELF32ProgramHeaderTableEntry? isBigendian bytes offset)
    (ELFHeader.getProgramHeaderOffsets eh)

instance : ProgramHeaderTableEntry ELF32ProgramHeaderTableEntry where
  p_type ph   := ph.p_type.toNat
  p_flags ph  := ph.p_flags.toNat
  p_offset ph := ph.p_offset.toNat
  p_vaddr ph  := ph.p_vaddr.toNat
  p_paddr ph  := ph.p_paddr.toNat
  p_filesz ph := ph.p_filesz.toNat
  p_memsz ph  := ph.p_memsz.toNat
  p_align ph  := ph.p_align.toNat
  bytes ph    := ph.bytes

inductive RawProgramHeaderTableEntry where
  | elf32 : ELF32ProgramHeaderTableEntry → RawProgramHeaderTableEntry
  | elf64 : ELF64ProgramHeaderTableEntry → RawProgramHeaderTableEntry
  deriving Repr

instance : ProgramHeaderTableEntry RawProgramHeaderTableEntry where
  p_type ph   := match ph with | .elf32 ph => ph.p_type.toNat   | .elf64 ph => ph.p_type.toNat
  p_flags ph  := match ph with | .elf32 ph => ph.p_flags.toNat  | .elf64 ph => ph.p_flags.toNat
  p_offset ph := match ph with | .elf32 ph => ph.p_offset.toNat | .elf64 ph => ph.p_offset.toNat
  p_vaddr ph  := match ph with | .elf32 ph => ph.p_vaddr.toNat  | .elf64 ph => ph.p_vaddr.toNat
  p_paddr ph  := match ph with | .elf32 ph => ph.p_paddr.toNat  | .elf64 ph => ph.p_paddr.toNat
  p_filesz ph := match ph with | .elf32 ph => ph.p_filesz.toNat | .elf64 ph => ph.p_filesz.toNat
  p_memsz ph  := match ph with | .elf32 ph => ph.p_memsz.toNat  | .elf64 ph => ph.p_memsz.toNat
  p_align ph  := match ph with | .elf32 ph => ph.p_align.toNat  | .elf64 ph => ph.p_align.toNat
  bytes ph    := match ph with | .elf32 ph => ph.bytes          | .elf64 ph => ph.bytes

def mkRawProgramHeaderTableEntry?
  (bs : ByteArray)
  (is64Bit : Bool)
  (isBigendian : Bool)
  (offset : Nat)
  : Except String RawProgramHeaderTableEntry :=
  match is64Bit with
  | true  => .elf64 <$> mkELF64ProgramHeaderTableEntry? isBigendian bs offset
  | false => .elf32 <$> mkELF32ProgramHeaderTableEntry? isBigendian bs offset

inductive RawProgramHeaderTable where
  | elf32 : List ELF32ProgramHeaderTableEntry → RawProgramHeaderTable
  | elf64 : List ELF64ProgramHeaderTableEntry → RawProgramHeaderTable

def RawProgramHeaderTable.length : RawProgramHeaderTable → Nat
  | elf32 pht => pht.length
  | elf64 pht => pht.length

def ELFHeader.mkRawProgramHeaderTable?
  [ELFHeader α]
  (eh : α)
  (bytes : ByteArray)
  : Except String RawProgramHeaderTable :=
  let shoffsets := (List.range (ELFHeader.e_phnum eh)).map λidx ↦ ELFHeader.e_phoff eh + ELFHeader.e_phentsize eh * idx
  let isBigendian := ELFHeader.isBigendian eh
  let is64Bit := ELFHeader.is64Bit eh
  if is64Bit
  then .elf64 <$> List.mapM (λoffset ↦ mkELF64ProgramHeaderTableEntry? isBigendian bytes offset) shoffsets
  else .elf32 <$> List.mapM (λoffset ↦ mkELF32ProgramHeaderTableEntry? isBigendian bytes offset) shoffsets

import Cli
import ELFSage.Util.Cli
import ELFSage.Types.ELFHeader
import ELFSage.Types.ProgramHeaderTable
import ELFSage.Constants.SectionHeaderTable
import ELFSage.Types.SectionHeaderTable
import ELFSage.Types.SymbolTable

def checkImplemented (p: Cli.Parsed) : Except String Unit := do
  let unimplemented := 
    [ "a", "all"
    , "g", "section-groups"
    , "t", "section-details"
    , "s", "syms", "symbols"
    , "lto-syms"
    , "sym-base"
    , "C", "demangle"
    , "n", "notes"
    , "r", "relocs"
    , "u", "unwind"
    , "d", "dynamic"
    , "V", "version-info"
    , "A", "arch-specific"
    , "c", "archive-index"
    , "D", "use-dynamic"
    , "L", "lint"
    , "x", "hex-dump"
    , "p", "string-dump"
    , "R", "relocated-dump"
    , "z", "decompress"
    ]
  for flag in unimplemented do
    if p.hasFlag flag 
    then throw s!"The flag --{flag} isn't implemented yet, sorry!"

  return ()

def runReadCmd (p: Cli.Parsed): IO UInt32 := do
  
  match checkImplemented p with
  | .error warn => IO.println warn *> return 1
  | .ok _ => do

  let targetBinary := (p.positionalArg! "targetBinary").as! System.FilePath
  let bytes ← IO.FS.readBinFile targetBinary

  match mkRawELFHeader? bytes with
  | .error warn => IO.println warn *> return 1
  | .ok elfheader => do

  if p.hasFlag "file-header" ∨ p.hasFlag "headers"
  then IO.println $ repr elfheader

  if p.hasFlag "program-headers" ∨ p.hasFlag "segments" ∨ p.hasFlag "headers"
  then for idx in [:elfheader.phnum] do
    IO.println s!"\nProgram Header {idx}\n"
    let offset := elfheader.phoff + (idx * elfheader.phentsize)
    match mkRawProgramHeaderTableEntry? bytes elfheader.is64Bit elfheader.isBigendian offset with
    | .error warn => IO.println warn
    | .ok programHeader => IO.println $ repr programHeader

  if p.hasFlag "section-headers" ∨ p.hasFlag "sections" ∨ p.hasFlag "headers"
  then for idx in [:elfheader.shnum] do
    IO.println s!"\nSection Header {idx}\n"
    let offset := elfheader.shoff + (idx * elfheader.shentsize)
    match mkRawSectionHeaderTableEntry? bytes elfheader.is64Bit elfheader.isBigendian offset with
    | .error warn => IO.println warn
    | .ok sectionHeader => IO.println $ repr sectionHeader

  if p.hasFlag "dyn-syms"
  then for idx in [:elfheader.shnum] do
    let offset := elfheader.shoff + (idx * elfheader.shentsize)
    match mkRawSectionHeaderTableEntry? bytes elfheader.is64Bit elfheader.isBigendian offset with
    | .error _ => pure ()
    | .ok sectionHeader =>

    if sectionHeader.sh_type != ELFSectionHeaderTableEntry.Type.SHT_DYNSYM
    then pure ()
    else for idx in [:sectionHeader.sh_size / sectionHeader.sh_entsize] do
      IO.print s!"Symbol {idx}: "
      let offset := sectionHeader.sh_offset + (idx * sectionHeader.sh_entsize)
      match mkRawSymbolTableEntry? bytes elfheader.is64Bit elfheader.isBigendian offset with
      | .error warn => IO.println warn
      | .ok symboltable => IO.println $ repr symboltable

  return 0

library EraMap;
{
DESCRIPTION:  HMM 3.5 WogEra
AUTHOR:       Alexander Shostak (aka Berserker aka EtherniDee aka BerSoft)
}

uses
  VFS, MapSettings, MapExt;
  
const
  INIT_HANDLER_ADDR_HOLDER  = $5AA9B8;

begin
  PINTEGER(INIT_HANDLER_ADDR_HOLDER)^ :=  integer(@MapExt.AsmInit);
end.

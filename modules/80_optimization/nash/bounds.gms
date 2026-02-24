*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/bounds.gms

***-----------------------------------------------------------------------------
***  EMIOPT: allow negative permits to compute efficient Nash solution
***  Overrides the fixed-to-zero bounds set in 41_emicapregi/none/bounds.gms
***-----------------------------------------------------------------------------
$ifthen.emiopt %emicapregi% == 'none'
if (cm_emiscen eq 6,
  vm_perm.lo(t,regi) = -10;
  vm_perm.up(t,regi) = 10000;
);
$endif.emiopt

***-----------------------------------------------------------------------------
***  EMIOPT: restrict permit trade to the initial policy period
***  Without this, indeterminate permit trade in later periods causes numerical
***  problems when only total budgets are meaningful.
***-----------------------------------------------------------------------------
loop(ttot$(ttot.val ne cm_startyear),
  vm_Xport.fx(ttot,regi,"perm")$(cm_emiscen eq 6) = 0;
  vm_Mport.fx(ttot,regi,"perm")$(cm_emiscen eq 6) = 0;
);

*** EOF ./modules/80_optimization/nash/bounds.gms

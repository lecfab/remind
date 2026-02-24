*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/presolve.gms

***-----------------------------------------------------------------------------
***  Update inter-regional externalities from previous iteration
***  Only applied for regions that had a feasible solution (pm_SolNonInfes = 1).
***  This preserves the last good estimate for infeasible regions.
***-----------------------------------------------------------------------------

*** Learning-by-doing spillover: foreign cumulative capacity for each learning technology
pm_capCumForeign(ttot,regi,teLearn)$(
    (ttot.val ge 2005) AND (pm_SolNonInfes(regi) eq 1))
  = sum(regi2$(NOT sameas(regi,regi2)), pm_capCum0(ttot,regi2,teLearn));

*** If cm_LearningSpillover is 0, freeze foreign capacity at 2020 levels
*** (simulates a protectionist world with no further cross-border technology learning)
pm_capCumForeign(ttot,regi,teLearn)$(
    (ttot.val ge 2025) AND (pm_SolNonInfes(regi) eq 1) AND (cm_LearningSpillover eq 0))
  = sum(regi2$(NOT sameas(regi,regi2)), pm_capCum0("2020",regi2,teLearn));

*** Aggregate foreign efficiency for CES productivity spillover
pm_cumEff(ttot,regi,in)$(ttot.val ge 2005 AND pm_SolNonInfes(regi) eq 1)
  = sum(regi2$(pm_SolNonInfes(regi2) eq 1),
      pm_cesdata("2005",regi2,in,"eff") * vm_effGr.l(ttot,regi2,in))
    - (pm_cesdata("2005",regi,in,"eff") * vm_effGr.l(ttot,regi,in));

*** Climate externality: sum of co2eq emissions from all other regions
pm_co2eqForeign(ttot,regi)$(
    (ttot.val ge 2005) AND (pm_SolNonInfes(regi) eq 1))
  = sum(regi2$(NOT sameas(regi,regi2)), pm_co2eq0(ttot,regi2));

*** Foreign fuel extraction (used for resource cost externalities)
pm_fuExtrForeign(ttot,regi,enty,rlf)$(
    (ttot.val ge 2005) AND (pm_SolNonInfes(regi) eq 1))
  = sum(regi2$(NOT sameas(regi,regi2)), vm_fuExtr.l(ttot,regi2,enty,rlf));

display pm_capCumForeign, pm_co2eqForeign;

*** EOF ./modules/80_optimization/nash/presolve.gms

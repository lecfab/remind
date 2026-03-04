*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/equations.gms

*' @equations

*' **Intertemporal trade balance (Nash mode only)**
*'
*' The net present value of trade must be zero: each region's exports must
*' exactly offset its imports over all time periods and all traded commodities.
*' A price anticipation term (scaled by sm_fadeoutPriceAnticip) introduces a
*' penalty that discourages large deviations from the previous iteration's
*' trade pattern, helping markets converge.
q80_budg_intertemp(regi)..
  0 =e=
    pm_nfa_start(regi) * pm_pvp("2005","good")
  + sum(ttot$(ttot.val ge 2005),
      pm_ts(ttot)
      * (
          sum(trade$(NOT tradeSe(trade) AND NOT tradeCap(trade)),
            (vm_Xport(ttot,regi,trade) - vm_Mport(ttot,regi,trade))
            * pm_pvp(ttot,trade)
            * ( 1
              + sm_fadeoutPriceAnticip * p80_etaXp(trade)
                * (   (pm_Xport0(ttot,regi,trade)  - p80_Mport0(ttot,regi,trade))
                    - (vm_Xport(ttot,regi,trade)   - vm_Mport(ttot,regi,trade))
                    - p80_taxrev0(ttot,regi)$(ttot.val gt 2005)$(sameas(trade,"good"))
                    + vm_taxrev(ttot,regi)$(ttot.val gt 2005)$(sameas(trade,"good"))
                  )
                / (p80_normalize0(ttot,regi,trade) + sm_eps)
              )
          )
        + vm_capacityTradeBalance(ttot,regi)
        + pm_pvp(ttot,"good") * pm_NXagr(ttot,regi)
        )
    );

*' **Quadratic Nash trade adjustment costs**
*'
*' Penalizes deviations of each region's net trade position from the
*' previous iteration, across all markets.  Using squared deviations keeps
*' the problem convex near the current solution and ensures the penalty is
*' symmetric around the last iteration's trade pattern.
q80_costAdjNash(ttot,regi)$(ttot.val ge cm_startyear)..
  vm_costAdjNash(ttot,regi)
  =e= sum(trade$(NOT tradeSe(trade)),
        pm_pvp(ttot,trade)
        * p80_etaAdj(trade)
        * sqr( (pm_Xport0(ttot,regi,trade) - p80_Mport0(ttot,regi,trade))
             - (vm_Xport(ttot,regi,trade)  - vm_Mport(ttot,regi,trade)) )
        / (p80_normalize0(ttot,regi,trade) + sm_eps)
      );

*' **Regional permit budget constraint (EMIOPT only)**
*'
*' Restricts cumulative regional emissions to the allocated permit budget.
*' Only active when cm_emiscen = 6 (permit trading with budget allocation).
q80_budgetPermRestr(regi)$(cm_emiscen=6)..
  sum(ttot$(ttot.val lt sm_endBudgetCO2eq AND ttot.val ge cm_startyear),
    pm_ts(ttot) * vm_perm(ttot,regi))
  + sum(ttot$(ttot.val eq sm_endBudgetCO2eq),
    pm_ts(ttot)/2 * vm_perm(ttot,regi))
  =l=
  pm_budgetCO2eq(regi)
  - sum(ttot$((ttot.val ge 2005) AND (ttot.val lt cm_startyear)),
      pm_ts(ttot) * vm_co2eq(ttot,regi));

*' @stop
*** EOF ./modules/80_optimization/nash/equations.gms

*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/postsolve.gms

***=============================================================================
***  Section 1: Current account and trade pattern updates
***=============================================================================

*** Calculate current account (exports minus imports, deflated to consumption price)
p80_curracc(ttot,regi) =
  sum(trade$(NOT tradeSe(trade)),
    pm_pvp(ttot,trade) / max(pm_pvp(ttot,"good"),sm_eps)
    * (vm_Xport.l(ttot,regi,trade) - vm_Mport.l(ttot,regi,trade))
  );

*** Update tax revenue from last feasible solution
p80_taxrev0(ttot,regi)$(
    (ttot.val ge max(2010,cm_startyear)) AND (pm_SolNonInfes(regi) eq 1))
  = vm_taxrev.l(ttot,regi);

*** Update market volume normalization parameters for next iteration
*** For infeasible regions, carry over the previous iteration's value.
p80_normalize0(ttot,regi,"good")$(ttot.val ge 2005)
  = max(  vm_cons.l(ttot,regi)$(pm_SolNonInfes(regi) eq 1)
        + p80_normalize0(ttot,regi,"good")$(pm_SolNonInfes(regi) eq 0),
        sm_eps);

p80_normalize0(ttot,regi,"perm")$(ttot.val ge 2005)
  = max(abs(pm_shPerm(ttot,regi) * pm_emicapglob("2050")), sm_eps);

p80_normalize0(ttot,regi,tradePe)$(ttot.val ge 2005)
  = max(  0.5 * (sum(rlf, vm_fuExtr.l(ttot,regi,tradePe,rlf)) + vm_prodPe.l(ttot,regi,tradePe))
            $(pm_SolNonInfes(regi) eq 1)
        + p80_normalize0(ttot,regi,tradePe)$(pm_SolNonInfes(regi) eq 0),
        sm_eps);

***=============================================================================
***  Section 2: Market surplus calculation
***=============================================================================

*** Residual surplus = sum of net trade across regions
*** For infeasible regions, use previous-iteration trade pattern
loop(ttot$(ttot.val ge 2005),
  loop(trade$(NOT tradeSe(trade)),
    p80_surplus(ttot,trade,iteration)
      = sum(regi,
          (vm_Xport.l(ttot,regi,trade) - vm_Mport.l(ttot,regi,trade))$(pm_SolNonInfes(regi) eq 1)
        + (pm_Xport0(ttot,regi,trade)  - p80_Mport0(ttot,regi,trade))$(pm_SolNonInfes(regi) eq 0)
        );
  );
);

***=============================================================================
***  Section 3: Price anticipation deviation diagnostics
***=============================================================================

*** Calculate size of price change due to anticipation effect (in %)
*** and resulting monetary deviation of trade expenditure (in trillion USD)
loop(ttot$(ttot.val ge 2005),
  loop(trade$(NOT tradeSe(trade)),
    loop(regi,
      p80_PriceChangePriceAnticipReg(ttot,trade,regi)
        = 100
        * sm_fadeoutPriceAnticip * p80_etaXp(trade)
        * (   (pm_Xport0(ttot,regi,trade) - p80_Mport0(ttot,regi,trade))
            - (vm_Xport.l(ttot,regi,trade) - vm_Mport.l(ttot,regi,trade))
            - p80_taxrev0(ttot,regi)$(ttot.val gt 2005)$(sameas(trade,"good"))
            + vm_taxrev.l(ttot,regi)$(ttot.val gt 2005)$(sameas(trade,"good"))
          )
        / (p80_normalize0(ttot,regi,trade) + sm_eps);

      p80_DevPriceAnticipReg(ttot,trade,regi)
        = (vm_Xport.l(ttot,regi,trade) - vm_Mport.l(ttot,regi,trade))
        * pm_pvp(ttot,trade) / pm_pvp(ttot,"good")
        * p80_PriceChangePriceAnticipReg(ttot,trade,regi);
    );
    p80_DevPriceAnticipGlob(ttot,trade)
      = sum(regi, abs(p80_DevPriceAnticipReg(ttot,trade,regi)));
  );
  p80_DevPriceAnticipGlobAll(ttot)
    = sum(trade$(NOT tradeSe(trade)), p80_DevPriceAnticipGlob(ttot,trade));
);

*** Running maximum of anticipation deviation
p80_DevPriceAnticipGlobMax(ttot,trade)$((ttot.val ge cm_startyear) AND (NOT tradeSe(trade)))
  = smax(ttot2$(ttot2.val ge cm_startyear AND ttot2.val le ttot.val),
      p80_DevPriceAnticipGlob(ttot2,trade));

p80_DevPriceAnticipGlobAllMax(ttot)$(ttot.val ge cm_startyear)
  = smax(ttot2$(ttot2.val ge cm_startyear AND ttot2.val le ttot.val),
      p80_DevPriceAnticipGlobAll(ttot2));

*** Track over iterations
p80_DevPriceAnticipGlobIter(ttot,trade,iteration)$((ttot.val ge cm_startyear) AND (NOT tradeSe(trade)))
  = p80_DevPriceAnticipGlob(ttot,trade);
p80_DevPriceAnticipGlobMax2100Iter(trade,iteration)$(NOT tradeSe(trade))
  = p80_DevPriceAnticipGlobMax("2100",trade);
p80_DevPriceAnticipGlobAllMax2100Iter(iteration)
  = p80_DevPriceAnticipGlobAllMax("2100");

*** Round anticipation price change to 0.1% for display
o80_PriceChangePriceAnticipReg(ttot,trade,regi)
  = round(p80_PriceChangePriceAnticipReg(ttot,trade,regi), 1);

*** Track largest absolute anticipation price change over iterations
o80_PriceChangePriceAnticipRegMaxIter("2100",iteration)
  = smax((ttot,trade,regi)$(ttot.val le 2100), abs(o80_PriceChangePriceAnticipReg(ttot,trade,regi)));
o80_PriceChangePriceAnticipRegMaxIter("2150",iteration)
  = smax((ttot,trade,regi)$(ttot.val ge 2110), abs(o80_PriceChangePriceAnticipReg(ttot,trade,regi)));

display
  p80_DevPriceAnticipGlob,
  p80_DevPriceAnticipGlobMax,
  p80_DevPriceAnticipGlobAllMax,
  p80_DevPriceAnticipGlobMax2100Iter,
  p80_DevPriceAnticipGlobAllMax2100Iter,
  p80_DevPriceAnticipGlobAll,
  o80_PriceChangePriceAnticipReg,
  o80_PriceChangePriceAnticipRegMaxIter
;

***=============================================================================
***  Section 4: Price correction calculation for next iteration
***=============================================================================

*** Intertemporal (long-term) normalization volume
loop(trade$(NOT tradeSe(trade)),
  p80_normalizeLT(trade)
    = sum(ttot$(ttot.val ge 2005),
        sum(regi, pm_pvp(ttot,trade) * pm_ts(ttot) * p80_normalize0(ttot,regi,trade)));
  if (p80_normalizeLT(trade) = 0, p80_normalizeLT(trade) = sm_eps);
);

*** Long-term price correction: proportional to the intertemporal surplus-weighted sum
p80_etaLT_correct(trade,iteration)$(NOT tradeSe(trade))
  = p80_etaLT(trade)
  * sum(ttot2$(ttot2.val ge cm_startyear),
      pm_pvp(ttot2,trade) * pm_ts(ttot2) * p80_surplus(ttot2,trade,iteration))
  / p80_normalizeLT(trade);

*** Short-term price correction: proportional to the current-period surplus,
*** scaled by the permitting price level to dampen corrections for low-price periods
p80_etaST_correct(ttot,trade,iteration)$((ttot.val ge 2005) AND (NOT tradeSe(trade)))
  = p80_etaST(trade)
  * ((  (1-sm_fadeoutPriceAnticip)
      + sm_fadeoutPriceAnticip * sqrt(pm_pvp(ttot,"good")/pm_pvp("2100","good"))
     )$(sameas(trade,"perm"))
     + 1$(NOT sameas(trade,"perm")))
  * ((  (sm_fadeoutPriceAnticip + (1-sm_fadeoutPriceAnticip) * (pm_pvp(ttot,"good")/pm_pvp('2040',"good")))
     )$(sameas(trade,"perm"))
     + 1$(NOT sameas(trade,"perm")))
  * ((  (sm_fadeoutPriceAnticip + (1-sm_fadeoutPriceAnticip) * (pm_pvp(ttot,trade)/pm_pvp('2050',trade)))
     )$(tradePe(trade))
     + 1$(NOT tradePe(trade)))
  * p80_surplus(ttot,trade,iteration)
  / max(sm_eps, sum(regi, p80_normalize0(ttot,regi,trade)));

*** Save a copy before applying the additional convergence push (for diagnostics)
p80_etaST_correct_safecopy(ttot,trade,iteration)$(NOT tradeSe(trade))
  = p80_etaST_correct(ttot,trade,iteration);

***=============================================================================
***  Section 5: Additional convergence push for persistently off-target markets
***  Applied from iteration 15 onwards when surplus has same sign for many
***  consecutive iterations. Push multiplied by 4, 8, or 16 depending on
***  how long the market has been stuck.
***=============================================================================

*** Track sign of the surplus for markets above tolerance
if (iteration.val > 2,
  loop(ttot$(ttot.val ge 2005),
    loop(trade$(tradePe(trade) OR sameas(trade,"good")),
      if (abs(p80_surplus(ttot,trade,iteration)) gt p80_surplusMaxTolerance(trade),
        o80_SurplusOverTolerance(ttot,trade,iteration)
          = Sign(p80_surplus(ttot,trade,iteration));
      );
    );
  );
);

*** Track consecutive iterations with the same surplus sign
if (iteration.val > 2,
  loop(ttot$(ttot.val ge 2005),
    loop(trade$(tradePe(trade) OR sameas(trade,"good")),
      if (   Sign(p80_surplus(ttot,trade,iteration))
          eq Sign(p80_surplus(ttot,trade,iteration-1))
          AND abs(p80_surplus(ttot,trade,iteration)) gt p80_surplusMaxTolerance(trade),
        o80_trackSurplusSign(ttot,trade,iteration)
          = o80_trackSurplusSign(ttot,trade,iteration-1) + 1;
      else
        o80_trackSurplusSign(ttot,trade,iteration) = 0;
      );
    );
  );
);

*** Apply progressively stronger push for markets that have been stuck
if (iteration.val > 15,
  loop(ttot$(ttot.val ge 2005),
    loop(trade$(tradePe(trade) OR sameas(trade,"good")),
      if (abs(p80_surplus(ttot,trade,iteration)) gt p80_surplusMaxTolerance(trade),

        *** Level 1 push (iteration > 15): multiply by 4 if stuck for >= 5 iterations
        if (   abs(sum(iteration2$(   iteration2.val le iteration.val
                                  AND iteration2.val ge (iteration.val - 4)),
                     p80_surplus(ttot,trade,iteration2)))
            ge (5 * p80_surplusMaxTolerance(trade))
            AND o80_trackSurplusSign(ttot,trade,iteration) ge 5,
          p80_etaST_correct(ttot,trade,iteration) = 4 * p80_etaST_correct(ttot,trade,iteration);
          o80_counter_iteration_trade_ttot(ttot,trade,iteration) = 1;

          *** Level 2 push (iteration > 20): multiply by another 2 if stuck for >= 10 iterations
          if (iteration.val gt 20,
            if (   abs(sum(iteration2$(   iteration2.val le iteration.val
                                      AND iteration2.val ge (iteration.val - 9)),
                         p80_surplus(ttot,trade,iteration2)))
                ge (10 * p80_surplusMaxTolerance(trade))
                AND o80_trackSurplusSign(ttot,trade,iteration) ge 10,
              p80_etaST_correct(ttot,trade,iteration) = 2 * p80_etaST_correct(ttot,trade,iteration);
              o80_counter_iteration_trade_ttot(ttot,trade,iteration) = 2;

              *** Level 3 push (iteration > 25): multiply by another 2 if stuck for >= 15 iterations
              if (iteration.val gt 25,
                if (   abs(sum(iteration2$(   iteration2.val le iteration.val
                                          AND iteration2.val ge (iteration.val - 14)),
                             p80_surplus(ttot,trade,iteration2)))
                    ge (15 * p80_surplusMaxTolerance(trade))
                    AND o80_trackSurplusSign(ttot,trade,iteration) ge 15,
                  p80_etaST_correct(ttot,trade,iteration) = 2 * p80_etaST_correct(ttot,trade,iteration);
                  o80_counter_iteration_trade_ttot(ttot,trade,iteration) = 3;
                );
              );
            );
          );
        );
      );
    ); !! trade
  ); !! ttot
); !! iteration > 15

***=============================================================================
***  Section 6: Price update and trade pattern update for next iteration
***=============================================================================

*** New prices: apply long-term and short-term corrections.
*** Price corrections are capped to prevent prices from turning negative.
p80_pvp_itr(ttot,trade,iteration+1)$((ttot.val ge cm_startyear) AND (NOT tradeSe(trade)))
  = pm_pvp(ttot,trade)
  * max(0.05,                       !! floor: prevent extreme negative price corrections
      (1 - p80_etaLT_correct(trade,iteration)
         - p80_etaST_correct(ttot,trade,iteration)
      )
    );

*** Feed updated prices and quantities into the next iteration.
*** For infeasible regions, increase imports slightly to encourage feasibility.
loop(trade$(NOT tradeSe(trade)),
  loop(regi,
    loop(ttot$(ttot.val ge cm_startyear),
      pm_pvp(ttot,trade) = p80_pvp_itr(ttot,trade,iteration+1);
      pm_Xport0(ttot,regi,trade)$(pm_SolNonInfes(regi) eq 1) = vm_Xport.l(ttot,regi,trade);
      p80_Mport0(ttot,regi,trade)$(pm_SolNonInfes(regi) eq 1) = vm_Mport.l(ttot,regi,trade);
      p80_Mport0(ttot,regi,trade)$(pm_SolNonInfes(regi) eq 0) = 1.2 * vm_Mport.l(ttot,regi,trade);
    );
  );
);

***=============================================================================
***  Section 7: Convergence diagnostics
***=============================================================================

*** Aggregate tax revenues
p80_taxrev_agg(ttot,iteration)$(ttot.val ge 2005) = sum(regi, vm_taxrev.l(ttot,regi));

*** Maximum absolute surplus until each time step
p80_surplusMax_iter(trade,iteration,ttot)$((ttot.val ge cm_startyear) AND (NOT tradeSe(trade)))
  = smax(ttot2$(ttot2.val ge cm_startyear AND ttot2.val le ttot.val),
      abs(p80_surplus(ttot2,trade,iteration)));

*** Maximum relative surplus until each time step
p80_surplusMaxRel(trade,iteration,ttot)$((ttot.val ge cm_startyear) AND (NOT tradeSe(trade)))
  = 100 * smax(ttot2$(ttot2.val ge cm_startyear AND ttot2.val le ttot.val),
      abs(p80_surplus(ttot2,trade,iteration))
      / sum(regi, p80_normalize0(ttot2,regi,trade)));

p80_surplusMax2100(trade)$(NOT tradeSe(trade))
  = p80_surplusMax_iter(trade,iteration,"2100");

*** Monetary market imbalance (Negishi-equivalent defic_sum)
loop(trade$(NOT tradeSe(trade)),
  p80_defic_trade(trade)
    = 1/pm_pvp("2005","good")
    * sum(ttot$(ttot.val ge 2005),
        pm_ts(ttot) * (
          abs(p80_surplus(ttot,trade,iteration)) * pm_pvp(ttot,trade)
          + sum(regi, abs(p80_taxrev0(ttot,regi)) * pm_pvp(ttot,"good"))
              $(sameas(trade,"good") AND (ttot.val ge max(2010,cm_startyear)))
          + sum(regi, abs(vm_costAdjNash.l(ttot,regi)) * pm_pvp(ttot,"good"))
              $(sameas(trade,"good") AND (ttot.val ge 2005))
        )
      );
);
p80_defic_sum("1")      = 1;
p80_defic_sum(iteration)     = sum(trade$(NOT tradeSe(trade)), p80_defic_trade(trade));
p80_defic_sum_rel(iteration) = 100 * p80_defic_sum(iteration)
                              / (p80_normalizeLT("good") / pm_pvp("2005","good"));

***=============================================================================
***  Section 8: Price anticipation fadeout
***  Once markets are reasonably cleared, start fading out the anticipation
***  terms over subsequent iterations. This is the "second phase" of convergence.
***=============================================================================

if (   smax(tradePe, p80_surplusMax_iter(tradePe,iteration,'2150')) lt (10 * 0.05)
   AND p80_surplusMax_iter("good",iteration,'2150') lt (10 * 0.1)
   AND p80_surplusMax_iter("perm",iteration,'2150') lt (5  * 0.2)
   AND s80_fadeoutPriceAnticipStartingPeriod eq 0,
  s80_fadeoutPriceAnticipStartingPeriod = iteration.val;
);

if (s80_fadeoutPriceAnticipStartingPeriod ne 0,
  sm_fadeoutPriceAnticip
    = 0.7**(iteration.val - s80_fadeoutPriceAnticipStartingPeriod + 1);
);
display s80_fadeoutPriceAnticipStartingPeriod, sm_fadeoutPriceAnticip;

*** Save final energy prices for monitoring over iterations
pm_FEPrice_iter(iteration,t,regi,enty,sector,emiMkt) = pm_FEPrice(t,regi,enty,sector,emiMkt);

***=============================================================================
***  Section 9: Convergence check
***  Reset s80_nashConverging to 1. Set to 0 if any active criterion is not met.
***=============================================================================
s80_nashConverging = 1;
p80_messageShow(convMessage80)         = NO;
p80_messageFailedMarket(ttot,all_enty) = NO;

*** Criterion "surplus": are all markets sufficiently cleared?
loop(trade$(NOT tradeSe(trade)),
  if (p80_surplusMax_iter(trade,iteration,"2100") gt p80_surplusMaxTolerance(trade),
    s80_nashConverging = 0;
    p80_messageShow("surplus") = YES;
    loop(ttot$((ttot.val ge cm_startyear) AND (ttot.val le 2100)),
      if (abs(p80_surplus(ttot,trade,iteration)) gt p80_surplusMaxTolerance(trade),
        p80_messageFailedMarket(ttot,trade) = YES;
      );
    );
  );
  if (p80_surplusMax_iter(trade,iteration,"2150") gt 10 * p80_surplusMaxTolerance(trade),
    s80_nashConverging = 0;
    p80_messageShow("surplus") = YES;
    loop(ttot$((ttot.val ge cm_startyear) AND (ttot.val gt 2100)),
      if (abs(p80_surplus(ttot,trade,iteration)) gt p80_surplusMaxTolerance(trade),
        p80_messageFailedMarket(ttot,trade) = YES;
      );
    );
  );
);

*** Criterion "infes": are all regions feasible or at worst locally non-optimal?
*** Criterion "nonopt": if status 7, is the objective close enough to the last optimal?
loop(regi,
  if (   p80_repy(regi,'modelstat') ne 2
     AND p80_repy(regi,'modelstat') ne 7,
    s80_nashConverging = 0;
    p80_messageShow("infes") = YES;
  );

  p80_convNashObjVal_iter(iteration,regi) = p80_repy(regi,'objval') - p80_repyLastOptim(regi,'objval');

  if (1 le iteration.val,
    if (   p80_repy(regi,'modelstat') eq 7
        AND p80_convNashObjVal_iter(iteration,regi) lt -1e-4,
      s80_nashConverging = 0;
      p80_messageShow("nonopt") = YES;
      display "Not all regions were status 2 in the last iteration. The deviation of the objective function from the last optimal solution is too large to be accepted:";
      display p80_convNashObjVal_iter;
    );
  );
);

*** Criterion "anticip" (informational only, not used to stop convergence):
*** are price anticipation terms sufficiently small?
p80_fadeoutPriceAnticip_iter(iteration) = sm_fadeoutPriceAnticip;
if (sm_fadeoutPriceAnticip gt cm_maxFadeOutPriceAnticip,
  p80_messageShow("anticip") = YES;
);

*** Criterion "DevPriceAnticip": is the monetary impact of anticipation small enough?
if (p80_DevPriceAnticipGlobAllMax2100Iter(iteration) gt 0.1 * p80_surplusMaxTolerance("good"),
  s80_nashConverging = 0;
  p80_messageShow("DevPriceAnticip") = YES;
);

*** Criterion "IterationNumber": has REMIND run at least 18 iterations?
*** (This minimum allows EDGE-T to run at least 4 times before declaring convergence.)
if (iteration.val le 17,
  s80_nashConverging = 0;
  p80_messageShow("IterationNumber") = YES;
);

*** Criterion "taxconv": have tax revenues converged? (optional, controlled by cm_TaxConvCheck)
p80_convNashTaxrev_iter(iteration,t,regi) = 0;
loop(regi,
  loop(t,
    p80_convNashTaxrev_iter(iteration,t,regi) = vm_taxrev.l(t,regi) / vm_cesIO.l(t,regi,"inco");
    if (cm_TaxConvCheck eq 1,
      if (abs(p80_convNashTaxrev_iter(iteration,t,regi)) gt 0.001,
        s80_nashConverging = 0;
        p80_messageShow("taxconv") = YES;
      );
    );
  );
);

*** Criterion "regiTarget": were regional emission market targets reached?
$ifthen.emiMkt not "%cm_emiMktTarget%" == "off"
loop((ttot,ttot2,ext_regi,emiMktExt)$pm_emiMktTarget_dev(ttot,ttot2,ext_regi,emiMktExt),
  if (NOT(pm_allTargetsConverged(ext_regi) eq 1),
    s80_nashConverging = 0;
    p80_messageShow("regiTarget") = YES;
  );
);
$endif.emiMkt

*** Criterion "NDC": were NDC emission targets reached?
$ifthen.NDC "%carbonprice%" == "NDC"
$ifthen.targetCheck "%cm_NDC_TargetCheckConv%" == "on"
loop((t,regi)$pm_NDCEmiTargetDeviation(t,regi),
  if (pm_NDCEmiTargetDeviation(t,regi) le -cm_NDC_target_DevTol,
    s80_nashConverging = 0;
    p80_messageShow("NDC") = YES;
  );
);
$endif.targetCheck
$endif.NDC

*** Criterion "implicitEnergyTarget": were quantity targets reached by implicit taxes/subsidies?
$ifthen.cm_implicitQttyTarget not "%cm_implicitQttyTarget%" == "off"
p80_implicitQttyTarget_dev_iter(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup)
  = pm_implicitQttyTarget_dev(ttot,ext_regi,qttyTarget,qttyTargetGroup);
loop((ttot,ext_regi,taxType,targetType,qttyTarget,qttyTargetGroup)$pm_implicitQttyTarget(ttot,ext_regi,taxType,targetType,qttyTarget,qttyTargetGroup),
  if (abs(p80_implicitQttyTarget_dev_iter(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup))
      gt cm_implicitQttyTarget_tolerance,
    if (NOT (   (sameas(taxType,"tax") AND p80_implicitQttyTarget_dev_iter(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup) lt 0)
             OR (sameas(taxType,"sub") AND p80_implicitQttyTarget_dev_iter(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup) gt 0)),
      if (NOT(pm_implicitQttyTarget_isLimited(iteration,ttot,ext_regi,qttyTarget,qttyTargetGroup) eq 1),
        s80_nashConverging = 0;
        p80_messageShow("implicitEnergyTarget") = YES;
      );
    );
  );
);
$endif.cm_implicitQttyTarget

*** Criterion "cm_implicitPriceTarget": were final energy price targets reached?
$ifthen.cm_implicitPriceTarget not "%cm_implicitPriceTarget%" == "off"
loop((t,regi,entyFe,entySe,sector)$pm_implicitPriceTarget(t,regi,entyFe,entySe,sector),
  if (pm_implicitPrice_NotConv(regi,sector,entyFe,entySe,t),
    s80_nashConverging = 0;
    p80_messageShow("cm_implicitPriceTarget") = YES;
  );
);
$endIf.cm_implicitPriceTarget

*** Criterion "cm_implicitPePriceTarget": were primary energy price targets reached?
$ifthen.cm_implicitPePriceTarget not "%cm_implicitPePriceTarget%" == "off"
loop((t,regi,entyPe)$pm_implicitPePriceTarget(t,regi,entyPe),
  if (pm_implicitPePrice_NotConv(regi,entyPe,t),
    s80_nashConverging = 0;
    p80_messageShow("cm_implicitPePriceTarget") = YES;
  );
);
$endIf.cm_implicitPePriceTarget

*** Criterion "globalbudget": is the global CO2 budget within tolerance?
p80_globalBudget_absDev_iter(iteration) = sm_globalBudget_absDev;
if (abs(p80_globalBudget_absDev_iter(iteration)) gt cm_budgetCO2_absDevTol,
  s80_nashConverging = 0;
  p80_messageShow("globalbudget") = YES;
);

*** Criteria "peakbudgyr" and "peakbudget": is the peak budget year and level correct?
$ifthen.carbonprice %carbonprice% == "functionalForm"
if (   cm_iterative_target_adj eq 9
   AND cm_peakBudgYr ne sm_peakBudgYr_check,
  s80_nashConverging = 0;
  p80_messageShow("peakbudgyr") = YES;
);
if (   cm_iterative_target_adj eq 9
   AND abs(sm_peakbudget_diff) gt sm_peakbudget_diff_tolerance,
  s80_nashConverging = 0;
  p80_messageShow("peakbudget") = YES;
);
$endIf.carbonprice

*** Criterion "regiBudget": were regional budget targets reached?
$ifthen.carbonpriceRegi %carbonprice% == "functionalFormRegi"
p80_regionalBudget_absDev_iter(iteration,regi) = pm_budgetDeviation(regi);
loop(regi,
  if (p80_regionalBudget_absDev_iter(iteration,regi) ge 0,
    if (abs(p80_regionalBudget_absDev_iter(iteration,regi)) gt pm_regionalBudget_absDevTol(regi),
      s80_nashConverging = 0;
      p80_messageShow("regiBudget") = YES;
    );
  else
    if (   abs(p80_regionalBudget_absDev_iter(iteration,regi)) gt abs(cm_budgetCO2_absDevTol)
       AND pm_taxCO2eq("2100",regi) gt (1 * sm_DptCO2_2_TDpGtC),
      s80_nashConverging = 0;
      p80_messageShow("regiBudget") = YES;
    );
  );
);
$endIf.carbonpriceRegi

*** Criterion "damage": has the damage iteration converged?
p80_sccConvergenceMaxDeviation_iter(iteration) = pm_sccConvergenceMaxDeviation;
p80_gmt_conv_iter(iteration) = pm_gmt_conv;
$ifthen.internalizeDamages not "%internalizeDamages%" == "off"
if (   p80_sccConvergenceMaxDeviation_iter(iteration) gt cm_sccConvergence
    OR p80_gmt_conv_iter(iteration) gt cm_tempConvergence,
  s80_nashConverging = 0;
  p80_messageShow("damage") = YES;
);
$endIf.internalizeDamages

***=============================================================================
***  Section 10: Per-iteration convergence report
***=============================================================================
display "####";
display "Convergence diagnostics";
display "Iteration number: ";
o_iterationNumber = iteration.val;
display o_iterationNumber;
option decimals = 3;

display "In the following you find some diagnostics on whether the model converged in this iteration: ";
display "solvestat and modelstat parameters: ";
display p80_repy;
display "trade convergence indicators";
display p80_surplusMaxTolerance, p80_surplusMax2100;
display p80_defic_trade, p80_defic_sum, p80_defic_sum_rel;

display "Reasons for non-convergence in this iteration (if not yet converged)";

loop(convMessage80$(p80_messageShow(convMessage80)),
  if (sameas(convMessage80,"infes"),
    display "#### 1.) Infeasibilities found in at least some regions in the last iteration. Please check parameter p80_repy for details. ";
    display "#### Try a different gdx, or re-run the optimization with cm_nash_mode set to debug in order to debug the infes.";
  );
  if (sameas(convMessage80,"surplus"),
    display "#### 2.) Some markets failed to reach a residual surplus below the prescribed threshold. ";
    display "#### In the following, the offending markets are indicated by a 1:";
    option decimals = 0;
    display p80_messageFailedMarket;
    option decimals = 3;
    display "#### You will find detailed trade convergence indicators below, search for p80_defic_trade";
  );
  if (sameas(convMessage80,"nonopt"),
    display "#### 3.) Found a feasible, but non-optimal solution. This is the infamous status-7 problem: ";
    display "#### We can't accept this solution, because it is non-optimal, and, in addition, too far away from the last known optimal solution. ";
    display "#### Just trying a different gdx may help.";
  );
  if (sameas(convMessage80,"taxconv"),
    display "#### 4.) Taxes did not converge in all regions and time steps. Absolute level of tax revenue must be smaller than 0.1 percent of GDP. Check p80_convNashTaxrev_iter below.";
  );
  if (sameas(convMessage80,"DevPriceAnticip"),
    display "#### 5.) The total monetary value of the price anticipation term times the traded amount are larger than the goods imbalance threshold * 0.1";
    display "#### Check out p80_DevPriceAnticipGlobAllMax2100Iter, which needs to be below 0.1 * the threshold for goods imbalance, p80_surplusMaxTolerance";
  );
  if (sameas(convMessage80,"anticip"),
    display "#### 5b.) only for checking, not anymore a criterion that stops convergence: The fadeout price anticipation terms are not sufficiently small.";
    display "#### Check out sm_fadeoutPriceAnticip which needs to be below cm_maxFadeOutPriceAnticip.";
    display sm_fadeoutPriceAnticip, cm_maxFadeOutPriceAnticip;
  );
  if (sameas(convMessage80,"globalbudget"),
    display "#### 6.) A global climate target has not been reached yet.";
    display "#### check sm_globalBudget_absDev for the deviation from the global target CO2 budget (convergence criterion defined via cm_budgetCO2_absDevTol [default = 2 Gt CO2]), as well as";
    display "#### pm_taxCO2eq_iter (regional CO2 tax path tracked over iterations [T$/GtC]) and";
    display "#### pm_taxCO2eq_anchor_iterationdiff (difference in global anchor carbon price to the last iteration [T$/GtC]) in diagnostics section below.";
    display sm_globalBudget_absDev;
  );
$ifthen.carbonprice %carbonprice% == "functionalForm"
  if (sameas(convMessage80,"peakbudgyr"),
    display "#### 6.) Years are different: cm_peakBudgYr is not equal to sm_peakBudgYr_check.";
    display cm_peakBudgYr;
  );
  if (sameas(convMessage80,"peakbudget"),
    display "#### 6.) PeakBudget not reached: sm_peakbudget_diff is greater than sm_peakbudget_diff_tolerance.";
    display sm_peakbudget_diff;
  );
$endIf.carbonprice
$ifthen.emiMkt not "%cm_emiMktTarget%" == "off"
  if (sameas(convMessage80,"regiTarget"),
    display "#### 7.) A regional climate target has not been reached yet.";
    display "#### Check out the pm_emiMktTarget_dev parameter of 47_regipol module.";
    display "#### For budget targets, the parameter gives the percentage deviation of current emissions in relation to the target value.";
    display "#### For yearly targets, the parameter gives the current emissions minus the target value in relative terms to the 2005 emissions.";
    display "#### The deviation must to be less than pm_emiMktTarget_tolerance. By default within 1%, i.e. in between -0.01 and 0.01 of 2005 emissions to reach convergence.";
    display pm_emiMktTarget_tolerance, pm_emiMktTarget_dev, pm_factorRescaleemiMktCO2Tax, pm_emiMktCurrent, pm_emiMktTarget, pm_emiMktRefYear;
    display pm_emiMktTarget_dev_iter;
    display pm_taxemiMkt_iteration;
  );
$endif.emiMkt
$ifthen.NDC "%carbonprice%" == "NDC"
  if (sameas(convMessage80,"NDC"),
    display "#### 8.) Some regional NDC target has not been reached within the tolerance of cm_NDC_target_DevTol";
    display "#### Check pm_NDCEmiTargetDeviation, which is the relative deviation of emissions from the target";
    display pm_NDCEmiTargetDeviation;
  );
$endif.NDC
$ifthen.cm_implicitQttyTarget not "%cm_implicitQttyTarget%" == "off"
  if (sameas(convMessage80,"implicitEnergyTarget"),
    display "#### 10.) A quantity target has not been reached yet.";
    display "#### Check out the pm_implicitQttyTarget_dev parameter of 47_regipol module.";
    display "#### The relative deviation must to be less than cm_implicitQttyTarget_tolerance, which is 1 percent by default.";
    display "#### For taxes, this means every value > +0.01, while for subsidies everything < -0.01 is problematic in the following lines.";
    display cm_implicitQttyTarget_tolerance, pm_implicitQttyTarget_dev;
  );
$endif.cm_implicitQttyTarget
$ifthen.cm_implicitPriceTarget not "%cm_implicitPriceTarget%" == "off"
  if (sameas(convMessage80,"cm_implicitPriceTarget"),
    display "#### 11.) A price target has not been reached yet.";
    display "#### Check out below the pm_implicitPrice_NotConv parameter values for non convergence cases.";
    display "####     Deviations must be lower than 5%.";
    display "#### The pm_implicitPrice_ignConv stores the cases disconsidered in the convergence check.";
    display pm_implicitPrice_NotConv, pm_implicitPrice_ignConv;
  );
$endIf.cm_implicitPriceTarget
$ifthen.cm_implicitPePriceTarget not "%cm_implicitPePriceTarget%" == "off"
  if (sameas(convMessage80,"cm_implicitPePriceTarget"),
    display "#### 11.) A primary energy price target has not been reached yet.";
    display "#### Check out below the pm_implicitPePrice_NotConv parameter values for non convergence cases.";
    display "####     Deviations must be lower than 5%.";
    display "#### The pm_implicitPePrice_ignConv stores the cases disconsidered in the convergence check.";
    display pm_implicitPePrice_NotConv, pm_implicitPePrice_ignConv;
  );
$endIf.cm_implicitPePriceTarget
$ifthen.internalizeDamages not "%internalizeDamages%" == "off"
  if (sameas(convMessage80,"damage"),
    display "#### 12.) The damage iteration did not converge.";
    display "#### Check out below the values for pm_gmt_conv and pm_sccConvergenceMaxDeviation.";
    display "#### They should be below 0.05.";
    display pm_gmt_conv, pm_sccConvergenceMaxDeviation;
  );
$endIf.internalizeDamages
  if (sameas(convMessage80,"IterationNumber"),
    display "#### 0.) REMIND did not run sufficient iterations (currently set at 18, to allow for at least 4 iterations with EDGE-T)";
  );
);

display "See the indicators below to dig deeper on the respective reasons of non-convergence: ";
display "tax convergence indicators";
display p80_convNashTaxrev_iter;
display "detailed trade convergence indicators";
display p80_defic_trade, p80_defic_sum, p80_defic_sum_rel;
option decimals = 7;
display p80_surplus;
option decimals = 3;
display "Carbon tax tracked over iterations of 45_carbonprice/functionalForm/postsolve";
display pm_taxCO2eq_iter;
display "Carbon tax difference to last iteration for global targets of 45_carbonprice/functionalForm/postsolve";
display pm_taxCO2eq_anchor_iterationdiff;
display "display effect of additional convergence push";
display o80_trackSurplusSign, o80_SurplusOverTolerance, o80_counter_iteration_trade_ttot,
        p80_etaST_correct_safecopy, p80_etaST_correct, p80_pvp_itr;

***=============================================================================
***  Section 11: Final failure report (only at max iterations without convergence)
***=============================================================================
if ((s80_nashConverging eq 0) AND (iteration.val eq cm_iteration_max),
  option decimals = 3;
  display "################################################################################################";
  display "####################################  Nash Solution Report  ####################################";
  display "################################################################################################";
  display "####  !! Nash did NOT converge within the maximum number of iterations allowed !!";
  display "#### The reasons for failing to successfully converge are:";

  loop(convMessage80$(p80_messageShow(convMessage80)),
    if (sameas(convMessage80,"infes"),
      display "####";
      display "#### 1.) Infeasibilities found in at least some regions in the last iteration. Please check parameter p80_repy for details. ";
      display "#### Try a different gdx, or re-run the optimization with cm_nash_mode set to debug in order to debug the infes.";
      display p80_repy;
    );
    if (sameas(convMessage80,"surplus"),
      display "####";
      display "#### 2.) Some markets failed to reach a residual surplus below the prescribed threshold. ";
      display "#### You may try less stringent convergence target (a lower cm_nash_autoconverge), or a different gdx. ";
      display "#### In the following, the offending markets are indicated by a 1:";
      option decimals = 0;
      display p80_messageFailedMarket;
      option decimals = 3;
    );
    if (sameas(convMessage80,"nonopt"),
      display "####";
      display "#### 3.) Found a feasible, but non-optimal solution. This is the infamous status-7 problem: ";
      display "#### We can't accept this solution, because it is non-optimal, and too far away from the last known optimal solution. ";
      display "#### Just trying a different gdx may help.";
    );
    if (sameas(convMessage80,"taxconv"),
      display "####";
      display "#### 4.) Taxes did not converge in all regions and time steps. Absolute level of tax revenue must be smaller than 0.1 percent of GDP. Check p80_convNashTaxrev_iter.";
    );
    if (sameas(convMessage80,"anticip"),
      display "#### 5.) The fadeout price anticipation terms are not sufficiently small.";
    );
    if (sameas(convMessage80,"globalbudget"),
      display "#### 6.) A global climate target has not been reached yet.";
      display "#### check sm_globalBudget_absDev for the deviation from the global target CO2 budget (convergence criterion defined via cm_budgetCO2_absDevTol [default = 2 Gt CO2]), as well as";
      display "#### pm_taxCO2eq_iter (regional CO2 tax path tracked over iterations [T$/GtC]) and";
      display "#### pm_taxCO2eq_anchor_iterationdiff (difference in global anchor carbon price to the last iteration [T$/GtC]) in diagnostics section below.";
      display sm_globalBudget_absDev;
    );
$ifthen.carbonprice %carbonprice% == "functionalForm"
    if (sameas(convMessage80,"peakbudgyr"),
      display "#### 6.) Years are different: cm_peakBudgYr is not equal to sm_peakBudgYr_check.";
      display cm_peakBudgYr;
    );
    if (sameas(convMessage80,"peakbudget"),
      display "#### 6.) PeakBudget not reached: sm_peakbudget_diff is greater than sm_peakbudget_diff_tolerance.";
      display sm_peakbudget_diff;
    );
$endIf.carbonprice
$ifthen.emiMkt not "%cm_emiMktTarget%" == "off"
    if (sameas(convMessage80,"regiTarget"),
      display "#### 7.) A regional climate target has not been reached yet.";
      display "#### Check out the pm_emiMktTarget_dev parameter of 47_regipol module.";
      display "#### For budget targets, the parameter gives the percentage deviation of current emissions in relation to the target value.";
      display "#### For yearly targets, the parameter gives the current emissions minus the target value in relative terms to the 2005 emissions.";
      display "#### The deviation must to be less than pm_emiMktTarget_tolerance. By default within 1%, i.e. in between -0.01 and 0.01 of 2005 emissions to reach convergence.";
      display pm_emiMktTarget_tolerance, pm_emiMktTarget_dev, pm_factorRescaleemiMktCO2Tax, pm_emiMktCurrent, pm_emiMktTarget, pm_emiMktRefYear;
      display pm_emiMktTarget_dev_iter;
      display pm_taxemiMkt_iteration;
    );
$endif.emiMkt
$ifthen.cm_implicitQttyTarget not "%cm_implicitQttyTarget%" == "off"
    if (sameas(convMessage80,"implicitEnergyTarget"),
      display "#### 10.) A quantity target has not been reached yet.";
      display "#### Check out the pm_implicitQttyTarget_dev parameter of 47_regipol module.";
      display "#### The deviation must to be less than cm_implicitQttyTarget_tolerance. By default within 1%, i.e. in between -0.01 and 0.01 of the defined target.";
      display cm_implicitQttyTarget_tolerance, pm_implicitQttyTarget_dev;
    );
$endif.cm_implicitQttyTarget
$ifthen.cm_implicitPriceTarget not "%cm_implicitPriceTarget%" == "off"
    if (sameas(convMessage80,"cm_implicitPriceTarget"),
      display "#### 11.) A final energy price target has not been reached yet.";
      display "#### Check out below the pm_implicitPrice_NotConv parameter values for non convergence cases.";
      display "####     Deviations must be lower than 5%.";
      display "#### The pm_implicitPrice_ignConv stores the cases disconsidered in the convergence check.";
      display pm_implicitPrice_NotConv, pm_implicitPrice_ignConv;
    );
$endIf.cm_implicitPriceTarget
$ifthen.cm_implicitPePriceTarget not "%cm_implicitPePriceTarget%" == "off"
    if (sameas(convMessage80,"cm_implicitPePriceTarget"),
      display "#### 11.) A primary energy price target has not been reached yet.";
      display "#### Check out below the pm_implicitPePrice_NotConv parameter values for non convergence cases.";
      display "####     Deviations must be lower than 5%.";
      display "#### The pm_implicitPePrice_ignConv stores the cases disconsidered in the convergence check.";
      display pm_implicitPePrice_NotConv, pm_implicitPePrice_ignConv;
    );
$endIf.cm_implicitPePriceTarget
  );

  display "#### Info: These residual market surpluses in current monetary values are:";
  display p80_defic_trade;
  display "#### The sum of those, normalized to the total consumption, given in percent is: ";
  display p80_defic_sum_rel;
  display "################################################################################################";
  display "################################################################################################";
);

***=============================================================================
***  Section 12: Convergence success report
***=============================================================================
if (s80_nashConverging eq 1,
  if (   (sm_magpieIter lt sm_magpieIterEnd)
     AND (cm_MAgPIE_Nash eq 1),
    display "######################################################################################################";
    display "Nash converged but MAgPIE hasn't run often enough yet. Continuing Nash.";
    display "######################################################################################################";
  else
    if (cm_nash_autoconverge ne 0,
      cm_iteration_max = iteration.val - 1;
    );
    option decimals = 3;
    s80_numberIterations = cm_iteration_max + 1;
    display "######################################################################################################";
    display "Run converged!!";
    display "#### Nash Solution Report";
    display "#### Convergence threshold reached within ", s80_numberIterations, "iterations.";
    display "############";
    display "Model solution parameters of last iteration";
    display p80_repy;
    display "#### Residual market surpluses in 2100 are:";
    display p80_surplusMax2100;
    display "#### This meets the prescribed tolerance requirements of: ";
    display p80_surplusMaxTolerance;
    display "#### Info: These residual market surpluses in monetary are :";
    display p80_defic_trade;
    display "#### Info: And the sum of those (equivalent to Negishi's defic_sum):";
    display p80_defic_sum;
    display "#### This value in percent of the NPV of consumption is: ";
    display p80_defic_sum_rel;
    display "############";
    display "######################################################################################################";
    option decimals = 3;
    s80_converged = 1;
  );
);

***=============================================================================
***  Section 13: Consecutive failure handling
***  If a region fails to solve cm_abortOnConsecFail times in a row,
***  automatically start debug mode or abort.
***=============================================================================
if (cm_abortOnConsecFail gt 0,
  loop(regi,
    if (   (    p80_repy_iteration(regi,"solvestat",iteration) eq 1
            AND p80_repy_iteration(regi,"modelstat",iteration) eq 2)
        OR (    p80_repy_iteration(regi,"solvestat",iteration) eq 4
            AND p80_repy_iteration(regi,"modelstat",iteration) eq 7),
      p80_trackConsecFail(regi) = 0;      !! region solved successfully
    else
      p80_trackConsecFail(regi) = p80_trackConsecFail(regi) + 1;
    );
  );

  if (smax(regi, p80_trackConsecFail(regi)) >= cm_abortOnConsecFail,
    if ((s80_runInDebug eq 0) AND (cm_nash_mode ne 1),
      if (sum(regi, pm_SolNonInfes(regi) ne 0) eq 0,
        execute_unload "abort.gdx";
        abort "Run was aborted because the maximum number of consecutive failures was reached in at least one region! No debug started since all regions are infeasible.";
      else
        s80_runInDebug = 1;
        cm_nash_mode   = 1;
        display "Starting nash in debug mode after maximum number of consecutive failures was reached in at least one region.";
      );
    else
      execute_unload "abort.gdx";
      abort "After debug mode run was aborted because the maximum number of consecutive failures was still reached in at least one region!";
    );
  else
    if (s80_runInDebug eq 1,
      s80_runInDebug = 0;
      cm_nash_mode   = 2;
      display "Set nash mode back to parallel after regions got feasible in auto-debug mode.";
    );
  );
);

***=============================================================================
***  Section 14: EMIOPT – efficient permit budget reallocation
***  Iteratively equalizes regional marginals of cumulative emissions and
***  permit budgets to find the efficient permit allocation.
***  Only active when cm_emiscen = 6 and emicapregi = 'none'.
***=============================================================================
$ifthen.emiopt %emicapregi% == 'none'
if (cm_emiscen eq 6,

  *** Marginals of the two binding constraints
  p80_eoMargEmiCum(regi)  = 5 * abs(qm_co2eqCum.m(regi))$(pm_SolNonInfes(regi) eq 1);
  p80_eoMargPermBudg(regi) = 5 * abs(q80_budgetPermRestr.m(regi))$(pm_SolNonInfes(regi) eq 1);

  display pm_budgetCO2eq;

  *** Welfare weights: inverse of the 2050 marginal utility of income
  loop(regi,
    p80_eoWeights(regi) = 1 / max(abs(qm_budget.m("2050",regi)), 1E-9);
  );
  p80_eoWeights(regi) = p80_eoWeights(regi) / sum(regi2, p80_eoWeights(regi2));

  *** Welfare-weighted combined marginal
  p80_eoEmiMarg(regi) = p80_eoWeights(regi) * (p80_eoMargPermBudg(regi) + p80_eoMargEmiCum(regi));

  *** Use the maximum marginal as a stand-in for infeasible regions
  p80_count = smax(regi, p80_eoEmiMarg(regi));
  loop(regi,
    if (pm_SolNonInfes(regi) eq 0,
      p80_eoEmiMarg(regi) = p80_count;
    );
  );

  p80_eoMargAverage = sum(regi, p80_eoEmiMarg(regi)) / card(regi);

  *** Use average for non-optimal (status 7) regions with zero marginals
  loop(regi,
    if (   p80_SolNonOpt(regi) eq 1
       AND p80_eoMargEmiCum(regi) eq EPS
       AND p80_eoMargPermBudg(regi) eq EPS,
      p80_eoEmiMarg(regi) = p80_eoMargAverage;
    );
  );

  p80_eoMargAverage = sum(regi, p80_eoEmiMarg(regi)) / card(regi);

  *** Compute budget adjustment: proportional to deviation from the average marginal
  p80_eoMargDiff(regi) = iteration.val**0.8 * 10 * (p80_eoEmiMarg(regi) - p80_eoMargAverage);
  p80_eoDeltaEmibudget = min(50, sum(regi2, pm_budgetCO2eq(regi2) * abs(p80_eoMargDiff(regi2))));
  pm_budgetCO2eq(regi) = max(0, pm_budgetCO2eq(regi) + p80_eoMargDiff(regi) * p80_eoDeltaEmibudget);

  *** Reporting
  p80_eoEmibudget1RegItr(regi,iteration)  = pm_budgetCO2eq(regi);
  p80_eoMargDiffItr(regi,iteration)       = p80_eoMargDiff(regi);
  p80_eoEmibudgetDiffAbs(iteration) = sum(regi, abs(p80_eoMargDiff(regi) * p80_eoDeltaEmibudget));

  option decimals = 5;
  display p80_eoMargEmiCum, p80_eoMargPermBudg, p80_eoEmiMarg, p80_eoMargAverage,
          p80_eoMargDiff, p80_eoDeltaEmibudget, p80_eoWeights, p80_eoEmibudget1RegItr;
);
$endif.emiopt

*** EOF ./modules/80_optimization/nash/postsolve.gms

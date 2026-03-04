*** |  (C) 2006-2024 Potsdam Institute for Climate Impact Research (PIK)
*** |  authors, and contributors see CITATION.cff file. This file is part
*** |  of REMIND and licensed under AGPL-3.0-or-later. Under Section 7 of
*** |  AGPL-3.0, you are granted additional permissions described in the
*** |  REMIND License Exception, version 1.0 (see LICENSE file).
*** |  Contact: remind@pik-potsdam.de
*** SOF ./modules/80_optimization/nash/datainput.gms

***-----------------------------------------------------------------------------
***  Welfare weights: equal across regions in Nash mode
***-----------------------------------------------------------------------------
pm_w(regi) = 1;

*** Surplus sign tracking only applies to non-secondary-energy trade goods
o80_trackSurplusSign(ttot,trade,iteration)$(NOT tradeSe(trade)) = 0;

***-----------------------------------------------------------------------------
***  Initialization of externality parameters
***-----------------------------------------------------------------------------
*** Initialize learning productivity spillover at unity (no spillover yet)
pm_cumEff(t, regi, in) = 100;

*** Initialize climate externality from global permit allocation
pm_co2eqForeign(t, regi) = (1 - pm_shPerm(t,regi)) * pm_emicapglob(t);

***-----------------------------------------------------------------------------
***  Convergence thresholds (cm_nash_autoconverge controls stringency)
***  Maximum tolerable absolute residual market surplus in 2100:
***    tradePe (primary energy): in TWa
***    good    (consumption):    in trillion USD2017
***    perm    (permits):        in GtC
***-----------------------------------------------------------------------------
if (cm_nash_autoconverge gt 0,
  cm_iteration_max = 100;

  if (cm_nash_autoconverge eq 1,   !! coarse convergence
    p80_surplusMaxTolerance(tradePe) = 1.5 * sm_EJ_2_TWa;         !! 1.5 EJ/yr -> TWa
    p80_surplusMaxTolerance("good")  = 100 / 1000;                !! 100 billion USD/yr
    p80_surplusMaxTolerance("perm")  = 300 * 12/44 / 1000;        !! 300 MtCO2eq/yr -> GtC
  );

  if (cm_nash_autoconverge eq 2,   !! fine convergence
    p80_surplusMaxTolerance(tradePe) = 0.3 * sm_EJ_2_TWa;         !! 0.3 EJ/yr -> TWa
    p80_surplusMaxTolerance("good")  = 20 / 1000;                 !! 20 billion USD/yr
    p80_surplusMaxTolerance("perm")  = 70 * 12/44 / 1000;         !! 70 MtCO2eq/yr -> GtC
  );

  if (cm_nash_autoconverge eq 3,   !! very coarse convergence
    p80_surplusMaxTolerance(tradePe) = 2 * 1.5 * sm_EJ_2_TWa;    !! 3 EJ/yr -> TWa
    p80_surplusMaxTolerance("good")  = 2 * 100 / 1000;            !! 200 billion USD/yr
    p80_surplusMaxTolerance("perm")  = 2 * 300 * 12/44 / 1000;   !! 600 MtCO2eq/yr -> GtC
  );
);

***-----------------------------------------------------------------------------
***  Nash trade adjustment cost weights
***  Trade-off: too low -> markets jump far from clearance; too high -> slow convergence
***-----------------------------------------------------------------------------
p80_etaAdj(tradePe)  = 80;
p80_etaAdj("good")   = 100;
p80_etaAdj("perm")   = 10;

***-----------------------------------------------------------------------------
***  Price anticipation elasticities
***  p80_etaXp: within-iteration price anticipation
***  p80_etaLT: long-term (intertemporal) price adjustment between iterations
***  p80_etaST: short-term (per time step) price adjustment between iterations
***  Note: etaST is sensitive. Increase toward 1 if markets diverge; decrease if they oscillate.
***-----------------------------------------------------------------------------
p80_etaXp(tradePe)   = 0.1;
p80_etaXp("good")    = 0.1;
p80_etaXp("perm")    = 0.2;

p80_etaLT(trade)     = 0;
p80_etaLT("perm")    = 0.03;

p80_etaST(tradePe)   = 0.3;
p80_etaST("good")    = 0.25;
p80_etaST("perm")    = 0.3;

*** Permit market reacts more sensitively in banking and budget modes
$ifi %banking%     == "banking" p80_etaST("perm") = 0.2;
$ifi %emicapregi%  == "budget"  p80_etaST("perm") = 0.25;

*** Bio-energy market converges better with a higher short-term elasticity
p80_etaST("pebiolc") = 0.8;
*** Uranium market is more price-sensitive, use a lower adjustment speed
p80_etaST("peur")    = 0.2;

***-----------------------------------------------------------------------------
***  Initialize convergence and iteration state
***-----------------------------------------------------------------------------
s80_converged                         = 0;
s80_fadeoutPriceAnticipStartingPeriod = 0;
sm_fadeoutPriceAnticip                = 1;

***-----------------------------------------------------------------------------
***  Pre-set variable and parameter values before GDX loading
***  GAMS only reads values from GDX for items that have been previously assigned.
***  Setting NA here tells GAMS to look for these in the input GDX.
***-----------------------------------------------------------------------------
pm_pvp(ttot,trade)$(ttot.val ge 2005)          = NA;
p80_pvpFallback(ttot,trade)$(ttot.val ge 2005) = NA;
pm_Xport0(ttot,regi,trade)$(ttot.val ge 2005)  = NA;
p80_Mport0(ttot,regi,trade)$(ttot.val ge 2005) = NA;
vm_Xport.l(ttot,regi,trade)$(ttot.val ge 2005) = NA;
vm_Mport.l(ttot,regi,trade)$(ttot.val ge 2005) = NA;
vm_cons.l(ttot,regi)$(ttot.val ge 2005)        = 0;
vm_emiTe.l(ttot,regi,"CO2")$(ttot.val ge 2005) = NA;
vm_fuExtr.l(ttot,regi,tradePe,rlf)$(ttot.val ge 2005) = 0;
vm_prodPe.l(ttot,regi,tradePe)$(ttot.val ge 2005)     = 0;
vm_taxrev.l(ttot,regi)$(ttot.val gt 2005)      = 0;
vm_co2eq.l(ttot,regi)                          = 0;
vm_emiAll.l(ttot,regi,enty)                    = 0;
p80_repy(all_regi,solveinfo80)                 = 0;
p80_repy_iteration(all_regi,solveinfo80,iteration)            = 0;
p80_repy_nashitr_solitr(all_regi,solveinfo80,iteration,sol_itr) = 0;
pm_capCumForeign(ttot,regi,teLearn)$(ttot.val ge 2005) = 0;
qm_co2eqCum.m(regi)         = 0;
q80_budgetPermRestr.m(regi) = 0;

***-----------------------------------------------------------------------------
***  Fallback price path (used if GDX prices are missing or unusable)
***-----------------------------------------------------------------------------
$include "./modules/80_optimization/nash/input/prices_NASH.inc";

***-----------------------------------------------------------------------------
***  EMIOPT: initialize permit budget shares and marginals
***  Only active when cm_emiscen eq 6 and emicapregi is 'none'
***-----------------------------------------------------------------------------
if (cm_emiscen eq 6,
$ifthen.emiopt %emicapregi% == "none"
  p80_eoMargEmiCum(regi)  = 0;
  p80_eoMargPermBudg(regi) = 0;
  *** Initial permit budget shares based on 2050 population share
  *** (convergence is sensitive to initial allocation)
  pm_shPerm("2050",regi) = pm_pop("2050",regi) / sum(regi2, pm_pop("2050",regi2));
$endif.emiopt
);

*** EOF ./modules/80_optimization/nash/datainput.gms
